import Foundation
import SecureCryptoProtocol

public func validateNoteBodyFile(_ data: Data) throws {
    guard !data.isEmpty else {
        throw SecureCryptoError.invalidInput("Note body file must not be empty.")
    }
    _ = try parseNoteFile(data)
}

public func readNoteBodyFile(from url: URL) throws -> Data {
    let data = try Data(contentsOf: url)
    try validateNoteBodyFile(data)
    return data
}

public func writeNoteBodyFile(_ body: Data, to url: URL) throws {
    try validateNoteBodyFile(body)
    try body.write(to: url, options: .atomic)
}
