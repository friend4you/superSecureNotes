import Foundation
import NoteRepositoryProtocol

public actor NotesIndexStore: NotesIndexStoreProtocol {
    public private(set) var isOpen = false

    public init() {}

    public func open(passphrase: Data) async throws {
        _ = passphrase
        isOpen = true
    }

    public func close() async {
        isOpen = false
    }
}
