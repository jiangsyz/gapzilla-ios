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

    func testPasswordUsesEightToTwentyPrintableASCIICharacters() {
        XCTAssertFalse(RegistrationInputRules.isPasswordValid("1234567"))
        XCTAssertTrue(RegistrationInputRules.isPasswordValid("12345678"))
        XCTAssertTrue(RegistrationInputRules.isPasswordValid(String(repeating: "a", count: 20)))
        XCTAssertTrue(RegistrationInputRules.isPasswordValid("Abc123!@"))

        XCTAssertFalse(RegistrationInputRules.isPasswordValid(String(repeating: "a", count: 21)))
        XCTAssertFalse(RegistrationInputRules.isPasswordValid("密码password"))
        XCTAssertFalse(RegistrationInputRules.isPasswordValid("password 123"))
        XCTAssertFalse(RegistrationInputRules.isPasswordValid("password🙂"))
    }

    func testPasswordIssueExplainsLengthAndUnsupportedCharacters() {
        XCTAssertEqual(
            RegistrationInputRules.passwordIssue("abc"),
            .tooShort(remaining: 5)
        )
        XCTAssertEqual(
            RegistrationInputRules.passwordIssue(String(repeating: "a", count: 21)),
            .tooLong
        )
        XCTAssertEqual(
            RegistrationInputRules.passwordIssue("密码password"),
            .unsupportedCharacters
        )
        XCTAssertNil(RegistrationInputRules.passwordIssue("valid-pass"))
    }

    func testPasswordStrengthUsesGuessabilityInsteadOfCompositionRules() {
        XCTAssertEqual(RegistrationInputRules.passwordStrength(""), .empty)
        XCTAssertEqual(RegistrationInputRules.passwordStrength("12345678"), .weak)

        let repeated = RegistrationInputRules.passwordStrength("kkkkkkkkkkkkkkkkkkkk")
        let varied = RegistrationInputRules.passwordStrength("v7#Qm2!xP9@rT4$k")
        let usernameRelated = RegistrationInputRules.passwordStrength(
            "jiangshen2026!",
            username: "jiangshen"
        )

        XCTAssertLessThan(repeated.rawValue, varied.rawValue)
        XCTAssertLessThan(usernameRelated.rawValue, varied.rawValue)
    }
}
