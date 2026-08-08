import Foundation
import SecureCryptoProtocol

public struct NoteMetadata: Equatable, Sendable {
    public static let magic = Array("SSNT".utf8)
    public static let formatVersion: UInt8 = 1
    public static let noteIDLength = 16

    public let noteID: UUID
    public let title: String
    public let createdAt: UInt64
    public let updatedAt: UInt64
    public let attachmentCount: UInt32
    public let attachmentsTotalSize: UInt64

    public init(
        noteID: UUID,
        title: String,
        createdAt: UInt64,
        updatedAt: UInt64,
        attachmentCount: UInt32,
        attachmentsTotalSize: UInt64
    ) {
        self.noteID = noteID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attachmentCount = attachmentCount
        self.attachmentsTotalSize = attachmentsTotalSize
    }

    /// Returns metadata whose attachment manifest matches stored ciphertext blob sizes.
    public func withStoredAttachmentManifest(_ ciphertexts: [UUID: Data]) -> NoteMetadata {
        NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: UInt32(ciphertexts.count),
            attachmentsTotalSize: ciphertexts.values.reduce(0) { $0 + UInt64($1.count) }
        )
    }

    /// Returns metadata with a zero attachment manifest for the initial body PUT on new notes.
    public func withZeroAttachmentManifest() -> NoteMetadata {
        NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: 0,
            attachmentsTotalSize: 0
        )
    }

    public static func fromNoteFile(_ data: Data) throws -> NoteMetadata {
        try parseNoteFile(data).metadata
    }

    func appendFields(to buffer: inout ByteBuffer) throws {
        buffer.appendFixedBytes(try noteIDBytes())
        try buffer.appendLengthPrefixedString(title)
        buffer.appendUInt64BE(createdAt)
        buffer.appendUInt64BE(updatedAt)
        buffer.appendUInt32BE(attachmentCount)
        buffer.appendUInt64BE(attachmentsTotalSize)
    }

    static func readFields(from reader: inout ByteBuffer) throws -> NoteMetadata {
        let noteID = try readNoteID(from: &reader)
        let title = try reader.readLengthPrefixedString()
        let createdAt = try reader.readUInt64BE()
        let updatedAt = try reader.readUInt64BE()
        let attachmentCount = try reader.readUInt32BE()
        let attachmentsTotalSize = try reader.readUInt64BE()

        return NoteMetadata(
            noteID: noteID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            attachmentCount: attachmentCount,
            attachmentsTotalSize: attachmentsTotalSize
        )
    }

    private func noteIDBytes() throws -> Data {
        var uuid = noteID.uuid
        let bytes = withUnsafeBytes(of: &uuid) { Data($0) }
        guard bytes.count == Self.noteIDLength else {
            throw SecureCryptoError.invalidInput("Note ID must be exactly \(Self.noteIDLength) bytes.")
        }
        return bytes
    }

    private static func readNoteID(from reader: inout ByteBuffer) throws -> UUID {
        let bytes = try reader.readFixedBytes(count: noteIDLength)
        let uuid: uuid_t = bytes.withUnsafeBytes { buffer in
            let values = buffer.bindMemory(to: UInt8.self)
            return (
                values[0], values[1], values[2], values[3],
                values[4], values[5], values[6], values[7],
                values[8], values[9], values[10], values[11],
                values[12], values[13], values[14], values[15]
            )
        }
        return UUID(uuid: uuid)
    }
}

public struct NoteFileSections: Equatable, Sendable {
    public let metadata: NoteMetadata
    public let wrappedFEK: Data
    public let encryptedPayload: Data

    public init(metadata: NoteMetadata, wrappedFEK: Data, encryptedPayload: Data) {
        self.metadata = metadata
        self.wrappedFEK = wrappedFEK
        self.encryptedPayload = encryptedPayload
    }
}

public func assembleNoteFile(
    metadata: NoteMetadata,
    wrappedFEK: Data,
    encryptedPayload: Data
) throws -> Data {
    var buffer = ByteBuffer()
    buffer.appendFixedBytes(Data(NoteMetadata.magic))
    buffer.appendUInt8(NoteMetadata.formatVersion)
    try metadata.appendFields(to: &buffer)
    try buffer.appendLengthPrefixedBytes(wrappedFEK)
    try buffer.appendLengthPrefixedBytes(encryptedPayload)
    return buffer.bytes
}

public func parseNoteFile(_ data: Data) throws -> NoteFileSections {
    var reader = ByteBuffer(data: data)
    try reader.expectMagic(NoteMetadata.magic)

    let version = try reader.readUInt8()
    guard version == NoteMetadata.formatVersion else {
        throw SecureCryptoError.unsupportedVersion(version)
    }

    let metadata = try NoteMetadata.readFields(from: &reader)
    let wrappedFEK = try reader.readLengthPrefixedBytes()
    let encryptedPayload = try reader.readLengthPrefixedBytes()

    guard reader.isAtEnd else {
        throw SecureCryptoError.invalidInput("Note file contains trailing bytes.")
    }

    return NoteFileSections(
        metadata: metadata,
        wrappedFEK: wrappedFEK,
        encryptedPayload: encryptedPayload
    )
}
