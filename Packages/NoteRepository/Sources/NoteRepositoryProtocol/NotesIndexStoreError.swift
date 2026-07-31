import Foundation

public enum NotesIndexStoreError: Error, Equatable, Sendable {
    case notOpen
    case openFailed(code: Int32)
    case sqliteError(message: String)
}
