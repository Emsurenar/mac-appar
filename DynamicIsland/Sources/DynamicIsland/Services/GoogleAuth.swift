import AppKit
import CryptoKit
import Foundation
import Network

/// Signs in to Google in the browser with OAuth for desktop apps: a loopback redirect to
/// 127.0.0.1 and PKCE. The refresh token is kept in a file only this user can read.
@MainActor
final class GoogleAuth {
    struct Credentials {
        let clientID: String
        let clientSecret: String
    }

    enum AuthError: LocalizedError {
        case signedOut
        case google(String, String?)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .signedOut: "Signed out of Google. Sign in again."
            case let .google(code, description): description.map { "\($0) (\(code))" } ?? "Google said: \(code)"
            case .badResponse: "Google sent an unexpected answer. Try again."
            }
        }
    }

    static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    private struct Stored: Codable {
        var refreshToken: String
        var account: String?
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let expiresIn: Double?
        let refreshToken: String?
        let error: String?
        let errorDescription: String?
    }

    private var stored: Stored?
    private var accessToken: String?
    private var expiry = Date.distantPast

    var isSignedIn: Bool { stored != nil }
    var account: String? { stored?.account }

    init() {
        stored = Self.load()
    }

    /// Opens Google's consent page and waits for the browser to come back. Cancel the task to give up.
    func signIn(_ credentials: Credentials) async throws {
        let verifier = Self.randomString()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomString()

        let receiver = try LoopbackReceiver()
        defer { receiver.stop() }
        let port = try await receiver.start()
        let redirect = "http://127.0.0.1:\(port)"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: credentials.clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]
        guard let url = components.url else { throw AuthError.badResponse }
        NSWorkspace.shared.open(url)

        let query = try await receiver.waitForRedirect()
        guard query["state"] == state else { throw AuthError.badResponse }
        if let error = query["error"] {
            if error == "access_denied" { throw CancellationError() }
            throw AuthError.google(error, nil)
        }
        guard let code = query["code"] else { throw AuthError.badResponse }

        let token = try await requestToken([
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirect,
        ], credentials)
        guard let refreshToken = token.refreshToken, let accessToken = token.accessToken else { throw AuthError.badResponse }
        stored = Stored(refreshToken: refreshToken, account: nil)
        save()
        self.accessToken = accessToken
        expiry = Date().addingTimeInterval(token.expiresIn ?? 3600)
    }

    /// A valid access token, refreshed when it is about to run out.
    func validAccessToken(_ credentials: Credentials) async throws -> String {
        if let accessToken, expiry > Date().addingTimeInterval(60) { return accessToken }
        guard let refreshToken = stored?.refreshToken else { throw AuthError.signedOut }
        let token: TokenResponse
        do {
            token = try await requestToken(["grant_type": "refresh_token", "refresh_token": refreshToken], credentials)
        } catch AuthError.google("invalid_grant", _) {
            // Revoked, expired or from another client.
            forget()
            throw AuthError.signedOut
        }
        guard let accessToken = token.accessToken else { throw AuthError.badResponse }
        self.accessToken = accessToken
        expiry = Date().addingTimeInterval(token.expiresIn ?? 3600)
        return accessToken
    }

    /// After a 401, so the next call refreshes.
    func invalidateAccessToken() {
        accessToken = nil
    }

    func setAccount(_ account: String?) {
        guard stored != nil, stored?.account != account else { return }
        stored?.account = account
        save()
    }

    func signOut() {
        if let token = stored?.refreshToken {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formEncoded(["token": token])
            URLSession.shared.dataTask(with: request).resume()
        }
        forget()
    }

    // MARK: Private

    private func forget() {
        stored = nil
        accessToken = nil
        expiry = .distantPast
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    private func requestToken(_ fields: [String: String], _ credentials: Credentials) async throws -> TokenResponse {
        var fields = fields
        fields["client_id"] = credentials.clientID
        if !credentials.clientSecret.isEmpty { fields["client_secret"] = credentials.clientSecret }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncoded(fields)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let token = try? decoder.decode(TokenResponse.self, from: data) else { throw AuthError.badResponse }
        if let error = token.error { throw AuthError.google(error, token.errorDescription) }
        return token
    }

    private static var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Dynamic Island", isDirectory: true)
            .appendingPathComponent("google-account.json")
    }

    private static func load() -> Stored? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func save() {
        guard let stored, let data = try? JSONEncoder().encode(stored) else { return }
        let url = Self.fileURL
        let manager = FileManager.default
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.truncate(atOffset: 0)
            try? handle.write(contentsOf: data)
            try? handle.close()
        }
    }

    private static func randomString() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func formEncoded(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }
}

/// A one-shot HTTP server on 127.0.0.1 that catches Google's redirect after sign-in.
private final class LoopbackReceiver: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.emresunar.DynamicIsland.google-sign-in")
    private var ready: CheckedContinuation<UInt16, Error>?
    private var redirect: CheckedContinuation<[String: String], Error>?
    private var pending: Result<[String: String], Error>?

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
    }

    /// Starts listening and returns the port the system picked.
    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.ready = continuation
                self.listener.stateUpdateHandler = { [weak self] state in self?.handle(state) }
                self.listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                self.listener.start(queue: self.queue)
            }
        }
    }

    /// The query of the first request that carries one.
    func waitForRedirect() async throws -> [String: String] {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    if let pending = self.pending {
                        self.pending = nil
                        continuation.resume(with: pending)
                    } else {
                        self.redirect = continuation
                    }
                }
            }
        } onCancel: {
            queue.async { self.deliver(.failure(CancellationError())) }
        }
    }

    func stop() {
        queue.async {
            self.listener.cancel()
            self.ready?.resume(throwing: CancellationError())
            self.ready = nil
        }
    }

    // Everything below runs on `queue`.

    private func handle(_ state: NWListener.State) {
        switch state {
        case .ready:
            ready?.resume(returning: listener.port?.rawValue ?? 0)
            ready = nil
        case let .failed(error):
            ready?.resume(throwing: error)
            ready = nil
            deliver(.failure(error))
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            let hasHeaders = buffer.range(of: Data("\r\n\r\n".utf8)) != nil
            if !hasHeaders && !isComplete && error == nil && buffer.count < 16_384 {
                self.receive(on: connection, buffer: buffer)
            } else {
                self.respond(to: buffer, on: connection)
            }
        }
    }

    private func respond(to request: Data, on connection: NWConnection) {
        let line = String(decoding: request, as: UTF8.self).components(separatedBy: "\r\n").first ?? ""
        let parts = line.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET",
              let components = URLComponents(string: "http://127.0.0.1" + parts[1]),
              let items = components.queryItems, !items.isEmpty else {
            send("404 Not Found", body: "", on: connection)
            return
        }
        var query: [String: String] = [:]
        for item in items { query[item.name] = item.value ?? "" }
        let message = query["code"] != nil
            ? "You're signed in. You can close this tab and go back to Dynamic Island."
            : "Sign-in didn't finish. You can close this tab."
        send("200 OK", body: """
            <!doctype html><meta charset="utf-8"><title>Dynamic Island</title>
            <body style="font: 16px -apple-system, sans-serif; display: grid; place-items: center; height: 90vh; color: #333">
            <p>\(message)</p></body>
            """, on: connection)
        deliver(.success(query))
    }

    private func send(_ status: String, body: String, on connection: NWConnection) {
        let body = Data(body.utf8)
        let header = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func deliver(_ result: Result<[String: String], Error>) {
        if let redirect {
            self.redirect = nil
            redirect.resume(with: result)
        } else if pending == nil {
            pending = result
        }
    }
}
