import XCTest
@testable import DynamicIsland

final class GoogleAuthTests: XCTestCase {
    func testRedirectIsTheReversedClientID() {
        let credentials = GoogleAuth.Credentials(clientID: "123-abc.apps.googleusercontent.com")
        XCTAssertEqual(credentials.redirectScheme, "com.googleusercontent.apps.123-abc")
        XCTAssertEqual(credentials.redirectURI, "com.googleusercontent.apps.123-abc:/oauth2redirect")
    }
}
