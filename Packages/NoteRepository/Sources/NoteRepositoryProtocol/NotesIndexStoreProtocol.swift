import Foundation

public protocol NotesIndexStoreProtocol: Actor {
    var isOpen: Bool { get }
    func open(passphrase: Data) async throws
    func close() async
}
