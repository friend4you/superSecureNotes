import Foundation

public func splitNoteFile(_ wireBlob: Data) throws -> (
    metadata: NoteMetadata,
    wrappedFEK: Data,
    encryptedPayload: Data
) {
    let sections = try parseNoteFile(wireBlob)
    return (sections.metadata, sections.wrappedFEK, sections.encryptedPayload)
}
