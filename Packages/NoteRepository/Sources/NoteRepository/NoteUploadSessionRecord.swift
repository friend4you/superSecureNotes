import Foundation

struct NoteUploadSessionRecord: Equatable, Sendable {
    let noteID: UUID
    let uploadID: UUID
    let wireSize: Int
    let chunkSize: Int
    let totalChunks: Int
    var completedChunkIndices: Set<Int>
    let ifMatch: String?

    init(
        noteID: UUID,
        uploadID: UUID,
        wireSize: Int,
        chunkSize: Int,
        totalChunks: Int,
        completedChunkIndices: Set<Int> = [],
        ifMatch: String? = nil
    ) {
        self.noteID = noteID
        self.uploadID = uploadID
        self.wireSize = wireSize
        self.chunkSize = chunkSize
        self.totalChunks = totalChunks
        self.completedChunkIndices = completedChunkIndices
        self.ifMatch = ifMatch
    }
}
