import XCTest

@testable import NoteRepository
@testable import NoteRepositoryProtocol

final class NotesIndexStoreTests: XCTestCase {
    func testOpenSetsIsOpen() async throws {
        let store = NotesIndexStore()

        let isOpenBefore = await store.isOpen
        XCTAssertFalse(isOpenBefore)

        try await store.open(passphrase: Data([0x01, 0x02, 0x03]))

        let isOpenAfter = await store.isOpen
        XCTAssertTrue(isOpenAfter)
    }

    func testCloseClearsIsOpen() async throws {
        let store = NotesIndexStore()
        try await store.open(passphrase: Data([0x01]))

        await store.close()

        let isOpenAfter = await store.isOpen
        XCTAssertFalse(isOpenAfter)
    }

    func testNotesIndexStoreErrorIsEquatable() {
        XCTAssertEqual(NotesIndexStoreError.notOpen, .notOpen)
    }
}
