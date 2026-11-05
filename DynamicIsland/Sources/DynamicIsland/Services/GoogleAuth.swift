import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

/// Signs in to Google with OAuth and PKCE in a browser sheet (ASWebAuthenticationSession),
/// using the app's own client ID of type iOS, which needs no client secret. The redirect is the
/// reversed client ID as a URL scheme. The refresh token is kept in a file only this user can read.
@MainActor
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Credentials {
        let clientID: String

        /// "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
        var redirectScheme: String {
            let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
            return "com.googleusercontent.apps." + prefix
        }

        var redirectURI: String { redirectScheme + ":/oauth2redirect" }
    }

    /// The client ID built into the app (GoogleClientID in Info.plist).
    static var builtInClientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Reads the calendar list and reads and writes events, for the assistant.
    static let scope = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/calendar.events"

    private struct Stored: Codable {
        var refreshToken: String
        var account: String?
        /// The scopes Google granted, to ask again when the app needs more.
        var scope: String?
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let expiresIn: Double?
        let refreshToken: String?
        let scope: String?
        let error: String?
        let errorDescription: String?
    }

    private var stored: Stored?
    private var accessToken: String?
    private var expiry = Date.distantPast

    /// Signed in with every scope the app asks for. An older sign-in without event access needs a new one.
    var isSignedIn: Bool { stored?.scope?.contains("auth/calendar.events") == true }
    var account: String? { stored?.account }

    override init() {
        stored = Self.load()
        super.init()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) ?? NSWindow() }
    }

    /// Opens Google's consent page and waits for the browser to come back. Cancel the task to give up.
    func signIn(_ credentials: Credentials) async throws {
        let verifier = Self.randomString()
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomString()

        let redirect = credentials.redirectURI
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

        let callback = try await authenticate(url: url, scheme: credentials.redirectScheme)
        var query: [String: String] = [:]
        for item in URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }
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
        stored = Stored(refreshToken: refreshToken, account: nil, scope: token.scope ?? Self.scope)
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

    private var session: ASWebAuthenticationSession?

    /// Shows Google's sign-in in a browser sheet and returns the redirect it ends on.
    private func authenticate(url: URL, scheme: String) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { url, error in
                    if let url {
                        continuation.resume(returning: url)
                    } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: error ?? AuthError.badResponse)
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.session = session
                NSApp.activate()
                if !session.start() {
                    self.session = nil
                    continuation.resume(throwing: AuthError.badResponse)
                }
            }
        } onCancel: {
            Task { @MainActor in self.session?.cancel() }
        }
    }

    private func requestToken(_ fields: [String: String], _ credentials: Credentials) async throws -> TokenResponse {
        var fields = fields
        fields["client_id"] = credentials.clientID
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
