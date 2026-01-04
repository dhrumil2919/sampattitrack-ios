import XCTest
@testable import SampattiTrack

final class LoginViewModelTests: XCTestCase {

    var viewModel: LoginViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LoginViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testLogin_WithEmptyUsername_SetsError() {
        viewModel.username = ""
        viewModel.password = "password123"

        viewModel.login()

        XCTAssertEqual(viewModel.errorMessage, "Please enter both username and password")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLogin_WithEmptyPassword_SetsError() {
        viewModel.username = "user"
        viewModel.password = ""

        viewModel.login()

        XCTAssertEqual(viewModel.errorMessage, "Please enter both username and password")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLogin_WithLongUsername_SetsError() {
        let longUsername = String(repeating: "a", count: 101)
        viewModel.username = longUsername
        viewModel.password = "password123"

        viewModel.login()

        XCTAssertEqual(viewModel.errorMessage, "Username must be 100 characters or fewer")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLogin_WithLongPassword_SetsError() {
        viewModel.username = "user"
        let longPassword = String(repeating: "a", count: 101)
        viewModel.password = longPassword

        viewModel.login()

        XCTAssertEqual(viewModel.errorMessage, "Password must be 100 characters or fewer")
        XCTAssertFalse(viewModel.isLoading)
    }
}
