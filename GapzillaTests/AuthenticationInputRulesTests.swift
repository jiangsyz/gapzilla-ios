import XCTest
@testable import Gapzilla

final class AuthenticationInputRulesTests: XCTestCase {
    func testUsernameUsesProductRangeAndSupportedCharacters() {
        XCTAssertTrue(RegistrationInputRules.isUsernameValid("abc"))
        XCTAssertTrue(RegistrationInputRules.isUsernameValid(String(repeating: "a", count: 20)))

        XCTAssertFalse(RegistrationInputRules.isUsernameValid("ab"))
        XCTAssertFalse(RegistrationInputRules.isUsernameValid(String(repeating: "a", count: 21)))
        XCTAssertFalse(RegistrationInputRules.isUsernameValid("Uppercase"))
        XCTAssertFalse(RegistrationInputRules.isUsernameValid("has-hyphen"))
    }

    func testPasswordShowsSimpleMinimumButKeepsTechnicalSafetyLimit() {
        XCTAssertFalse(RegistrationInputRules.isPasswordValid("1234567"))
        XCTAssertTrue(RegistrationInputRules.isPasswordValid("12345678"))
        XCTAssertTrue(RegistrationInputRules.isPasswordValid(String(repeating: "密", count: 24)))
        XCTAssertFalse(RegistrationInputRules.isPasswordValid(String(repeating: "密", count: 25)))
    }

    func testPasswordStrengthProgressesWithoutBecomingARegistrationRule() {
        XCTAssertEqual(RegistrationInputRules.passwordStrength(""), .empty)
        XCTAssertEqual(RegistrationInputRules.passwordStrength("1234567"), .weak)
        XCTAssertEqual(RegistrationInputRules.passwordStrength("12345678"), .usable)
        XCTAssertEqual(RegistrationInputRules.passwordStrength("quietbase2026"), .good)
        XCTAssertEqual(RegistrationInputRules.passwordStrength("QuietBase_2026_ok"), .strong)
    }
}
