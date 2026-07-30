import Foundation
import SecureCryptoProtocol

public struct LocalNoteBodySections: Equatable, Sendable {
    public let metadata: NoteMetadata
    public let encryptedPayload: Data

    public init(metadata: NoteMetadata, encryptedPayload: Data) {
        self.metadata = metadata
        self.encryptedPayload = encryptedPayload
    }
}

public func assembleLocalNoteBody(
    metadata: NoteMetadata,
    encryptedPayload: Data
) throws -> Data {
    var buffer = ByteBuffer()
    buffer.appendFixedBytes(Data(NoteMetadata.magic))
    buffer.appendUInt8(NoteMetadata.formatVersion)
    try metadata.appendFields(to: &buffer)
    try buffer.appendLengthPrefixedBytes(encryptedPayload)
    return buffer.bytes
}

public func parseLocalNoteBody(_ data: Data) throws -> LocalNoteBodySections {
    var reader = ByteBuffer(data: data)
    try reader.expectMagic(NoteMetadata.magic)

    let version = try reader.readUInt8()
    guard version == NoteMetadata.formatVersion else {
        throw SecureCryptoError.unsupportedVersion(version)
    }

    let metadata = try NoteMetadata.readFields(from: &reader)
    let encryptedPayload = try reader.readLengthPrefixedBytes()

    guard reader.isAtEnd else {
        throw SecureCryptoError.invalidInput("Local note body contains trailing bytes.")
    }

    return LocalNoteBodySections(
        metadata: metadata,
        encryptedPayload: encryptedPayload
    )
}

extension NoteMetadata {
    public static func fromLocalNoteBody(_ data: Data) throws -> NoteMetadata {
        try parseLocalNoteBody(data).metadata
    }
}
