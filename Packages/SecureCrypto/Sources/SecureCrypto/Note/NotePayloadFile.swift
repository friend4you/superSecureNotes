import Foundation
import SecureCryptoProtocol

public func validateNotePayloadFile(_ data: Data) throws {
    guard !data.isEmpty else {
        throw SecureCryptoError.invalidInput("Note payload file must not be empty.")
    }
}

public func readNotePayloadFile(from url: URL) throws -> Data {
    let data = try Data(contentsOf: url)
    try validateNotePayloadFile(data)
    return data
}

public func writeNotePayloadFile(_ encryptedPayload: Data, to url: URL) throws {
    try validateNotePayloadFile(encryptedPayload)
    try encryptedPayload.write(to: url, options: .atomic)
}
