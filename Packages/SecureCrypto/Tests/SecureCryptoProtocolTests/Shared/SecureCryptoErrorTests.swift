import XCTest

@testable import SecureCryptoProtocol

final class SecureCryptoErrorTests: XCTestCase {
    func testEquatableCases() {
        XCTAssertEqual(SecureCryptoError.insufficientData, .insufficientData)
        XCTAssertEqual(
            SecureCryptoError.invalidMagic(expected: "SSNV", actual: "ABCD"),
            .invalidMagic(expected: "SSNV", actual: "ABCD")
        )
        XCTAssertEqual(SecureCryptoError.unsupportedVersion(2), .unsupportedVersion(2))
        XCTAssertEqual(SecureCryptoError.authenticationFailed, .authenticationFailed)
        XCTAssertEqual(SecureCryptoError.invalidInput("bad"), .invalidInput("bad"))
        XCTAssertEqual(SecureCryptoError.decodingFailed("oops"), .decodingFailed("oops"))
    }

    func testLocalizedErrorDescriptions() {
        XCTAssertEqual(
            SecureCryptoError.insufficientData.errorDescription,
            "Unexpected end of data while parsing binary format."
        )
        XCTAssertEqual(
            SecureCryptoError.invalidMagic(expected: "SSNV", actual: "ABCD").errorDescription,
            "Invalid magic bytes: expected SSNV, got ABCD."
        )
        XCTAssertEqual(
            SecureCryptoError.unsupportedVersion(9).errorDescription,
            "Unsupported format version: 9."
        )
        XCTAssertEqual(
            SecureCryptoError.authenticationFailed.errorDescription,
            "Authentication failed; data may be corrupted or the key is incorrect."
        )
        XCTAssertEqual(
            SecureCryptoError.invalidInput("bad input").errorDescription,
            "bad input"
        )
        XCTAssertEqual(
            SecureCryptoError.decodingFailed("bad field").errorDescription,
            "Decoding failed: bad field."
        )
    }
}
