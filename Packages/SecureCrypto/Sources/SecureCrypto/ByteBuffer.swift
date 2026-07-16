import Foundation

public struct ByteBuffer: Sendable {
    private var storage: Data
    private var readIndex: Int

    public init() {
        storage = Data()
        readIndex = 0
    }

    public init(data: Data) {
        storage = data
        readIndex = 0
    }

    public var bytes: Data { storage }

    public var remainingBytes: Int {
        storage.count - readIndex
    }

    public var isAtEnd: Bool {
        readIndex >= storage.count
    }

    public mutating func appendUInt8(_ value: UInt8) {
        storage.append(value)
    }

    public mutating func appendUInt16BE(_ value: UInt16) {
        storage.append(UInt8((value >> 8) & 0xFF))
        storage.append(UInt8(value & 0xFF))
    }

    public mutating func appendUInt32BE(_ value: UInt32) {
        storage.append(UInt8((value >> 24) & 0xFF))
        storage.append(UInt8((value >> 16) & 0xFF))
        storage.append(UInt8((value >> 8) & 0xFF))
        storage.append(UInt8(value & 0xFF))
    }

    public mutating func appendUInt64BE(_ value: UInt64) {
        storage.append(UInt8((value >> 56) & 0xFF))
        storage.append(UInt8((value >> 48) & 0xFF))
        storage.append(UInt8((value >> 40) & 0xFF))
        storage.append(UInt8((value >> 32) & 0xFF))
        storage.append(UInt8((value >> 24) & 0xFF))
        storage.append(UInt8((value >> 16) & 0xFF))
        storage.append(UInt8((value >> 8) & 0xFF))
        storage.append(UInt8(value & 0xFF))
    }

    public mutating func appendFixedBytes(_ bytes: Data) {
        storage.append(bytes)
    }

    public mutating func appendLengthPrefixedBytes(_ bytes: Data) throws {
        guard bytes.count <= UInt32.max else {
            throw SecureCryptoError.invalidInput("Length-prefixed field exceeds UInt32 capacity.")
        }
        appendUInt32BE(UInt32(bytes.count))
        storage.append(bytes)
    }

    public mutating func appendLengthPrefixedString(_ string: String) throws {
        guard let encoded = string.data(using: .utf8) else {
            throw SecureCryptoError.decodingFailed("String is not valid UTF-8.")
        }
        try appendLengthPrefixedBytes(encoded)
    }

    public mutating func readUInt8() throws -> UInt8 {
        try readFixedBytes(count: 1)[0]
    }

    public mutating func readUInt16BE() throws -> UInt16 {
        let bytes = try readFixedBytes(count: 2)
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }

    public mutating func readUInt32BE() throws -> UInt32 {
        let bytes = try readFixedBytes(count: 4)
        return (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])
    }

    public mutating func readUInt64BE() throws -> UInt64 {
        let bytes = try readFixedBytes(count: 8)
        var value: UInt64 = 0
        for byte in bytes {
            value = (value << 8) | UInt64(byte)
        }
        return value
    }

    public mutating func readFixedBytes(count: Int) throws -> Data {
        guard count >= 0 else {
            throw SecureCryptoError.invalidInput("Cannot read a negative number of bytes.")
        }
        guard remainingBytes >= count else {
            throw SecureCryptoError.insufficientData
        }
        let range = readIndex ..< (readIndex + count)
        let slice = storage.subdata(in: range)
        readIndex += count
        return slice
    }

    public mutating func readLengthPrefixedBytes() throws -> Data {
        let length = Int(try readUInt32BE())
        return try readFixedBytes(count: length)
    }

    public mutating func readLengthPrefixedString() throws -> String {
        let data = try readLengthPrefixedBytes()
        guard let string = String(data: data, encoding: .utf8) else {
            throw SecureCryptoError.decodingFailed("Length-prefixed field is not valid UTF-8.")
        }
        return string
    }

    public mutating func readMagic(count: Int) throws -> Data {
        try readFixedBytes(count: count)
    }

    public mutating func expectMagic(_ expected: [UInt8]) throws {
        let actual = try readMagic(count: expected.count)
        guard actual.elementsEqual(expected) else {
            throw SecureCryptoError.invalidMagic(
                expected: Self.magicString(expected),
                actual: Self.magicString(actual)
            )
        }
    }

    private static func magicString(_ bytes: Data) -> String {
        magicString([UInt8](bytes))
    }

    private static func magicString(_ bytes: [UInt8]) -> String {
        String(bytes.map { Character(UnicodeScalar($0)) })
    }
}
