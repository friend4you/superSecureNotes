import CryptoKit
import Foundation
import SecureCryptoProtocol

public struct BIP39MnemonicEncoder: MnemonicEncoding {
    public let wordCount = 12
    public let entropyLength = 16

    public init() {}

    public func words(from entropy: Data) throws -> [String] {
        guard entropy.count == entropyLength else {
            throw SecureCryptoError.invalidInput("Mnemonic entropy must be exactly 16 bytes.")
        }

        let hash = Array(SHA256.hash(data: entropy))
        var combinedBits = entropyBits(from: entropy)
        combinedBits.append(contentsOf: entropyBits(from: Data(hash)).prefix(entropy.count * 8 / 32))

        return try words(fromBits: combinedBits)
    }

    public func validate(_ words: [String]) throws -> Data {
        try entropy(from: words)
    }

    public func entropy(from words: [String]) throws -> Data {
        guard words.count == wordCount else {
            throw SecureCryptoError.invalidInput("Mnemonic must contain exactly 12 words.")
        }

        var combinedBits: [Bool] = []
        combinedBits.reserveCapacity(wordCount * 11)

        for word in words {
            let normalized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let index = BIP39Wordlist.index(of: normalized) else {
                throw SecureCryptoError.invalidInput("Mnemonic contains unknown word: \(word)")
            }
            combinedBits.append(contentsOf: indexBits(from: index))
        }

        let checksumBitCount = entropyLength * 8 / 32
        let entropyBitValues = Array(combinedBits.prefix(entropyLength * 8))
        let checksumBits = Array(combinedBits.suffix(checksumBitCount))
        let entropy = data(from: entropyBitValues)

        let hash = Array(SHA256.hash(data: entropy))
        let expectedChecksum = Array(entropyBits(from: Data(hash)).prefix(checksumBitCount))

        guard checksumBits == expectedChecksum else {
            throw SecureCryptoError.invalidInput("Mnemonic checksum is invalid.")
        }

        return entropy
    }

    private func words(fromBits bits: [Bool]) throws -> [String] {
        guard bits.count == wordCount * 11 else {
            throw SecureCryptoError.decodingFailed("Invalid mnemonic bit length.")
        }

        var words: [String] = []
        words.reserveCapacity(wordCount)

        for chunkStart in stride(from: 0, to: bits.count, by: 11) {
            let chunk = Array(bits[chunkStart ..< (chunkStart + 11)])
            var index = 0
            for bit in chunk {
                index = (index << 1) | (bit ? 1 : 0)
            }
            words.append(BIP39Wordlist.word(at: index))
        }

        return words
    }

    private func entropyBits(from data: Data) -> [Bool] {
        var result: [Bool] = []
        result.reserveCapacity(data.count * 8)

        for byte in data {
            for shift in stride(from: 7, through: 0, by: -1) {
                result.append((byte >> shift) & 1 == 1)
            }
        }

        return result
    }

    private func indexBits(from index: Int) -> [Bool] {
        (0 ..< 11).reversed().map { shift in
            (index >> shift) & 1 == 1
        }
    }

    private func data(from bits: [Bool]) -> Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(bits.count / 8)

        for chunkStart in stride(from: 0, to: bits.count, by: 8) {
            var byte: UInt8 = 0
            for offset in 0 ..< 8 {
                if bits[chunkStart + offset] {
                    byte |= 1 << (7 - offset)
                }
            }
            bytes.append(byte)
        }

        return Data(bytes)
    }
}

public enum BIP39Mnemonic {
    private static let encoder = BIP39MnemonicEncoder()

    public static let wordCount = 12
    public static let entropyLength = 16

    public static func words(from entropy: Data) throws -> [String] {
        try encoder.words(from: entropy)
    }

    public static func validate(_ words: [String]) throws -> Data {
        try encoder.validate(words)
    }

    public static func entropy(from words: [String]) throws -> Data {
        try encoder.entropy(from: words)
    }
}
