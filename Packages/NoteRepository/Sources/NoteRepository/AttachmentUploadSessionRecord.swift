import Foundation

struct AttachmentUploadSessionRecord: Equatable, Sendable {
    let noteID: UUID
    let attachmentID: UUID
    let uploadID: UUID
    let wireSize: Int
    let chunkSize: Int
    let totalChunks: Int
    var completedChunkIndices: Set<Int>
    let ifMatch: String?

    init(
        noteID: UUID,
        attachmentID: UUID,
        uploadID: UUID,
        wireSize: Int,
        chunkSize: Int,
        totalChunks: Int,
        completedChunkIndices: Set<Int> = [],
        ifMatch: String? = nil
    ) {
        self.noteID = noteID
        self.attachmentID = attachmentID
        self.uploadID = uploadID
        self.wireSize = wireSize
        self.chunkSize = chunkSize
        self.totalChunks = totalChunks
        self.completedChunkIndices = completedChunkIndices
        self.ifMatch = ifMatch
    }
}
