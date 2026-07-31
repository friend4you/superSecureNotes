import CryptoKit
import SecureCrypto
import XCTest

final class NotesDatabaseKeyTests: XCTestCase {
    func testDeriveNotesDatabaseKeyIsDeterministic() {
        let udk = SymmetricKey(size: .bits256)

        let first = deriveNotesDatabaseKey(from: udk)
        let second = deriveNotesDatabaseKey(from: udk)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 32)
    }

    func testDeriveNotesDatabaseKeyDiffersFromRawUDK() {
        let udk = SymmetricKey(size: .bits256)
        let rawUDK = udk.withUnsafeBytes { Data($0) }
        let derived = deriveNotesDatabaseKey(from: udk)

        XCTAssertNotEqual(derived, rawUDK)
    }
}
