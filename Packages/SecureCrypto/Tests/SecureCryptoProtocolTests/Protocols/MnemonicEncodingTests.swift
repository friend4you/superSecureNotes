import XCTest

@testable import SecureCryptoProtocol

final class MnemonicEncodingTests: XCTestCase {
    func testMockWordsValidateEntropyMethods() throws {
        let encoder = MockMnemonicEncoder()
        let entropy = Data(repeating: 0x01, count: encoder.entropyLength)
        let words = Array(repeating: "word", count: encoder.wordCount)

        XCTAssertEqual(encoder.wordCount, 12)
        XCTAssertEqual(encoder.entropyLength, 16)
        XCTAssertEqual(try encoder.words(from: entropy), words)
        XCTAssertEqual(try encoder.validate(words), entropy)
        XCTAssertEqual(try encoder.entropy(from: words), entropy)
    }
}

private struct MockMnemonicEncoder: MnemonicEncoding {
    let wordCount = 12
    let entropyLength = 16

    func words(from entropy: Data) throws -> [String] {
        Array(repeating: "word", count: wordCount)
    }

    func validate(_ words: [String]) throws -> Data {
        Data(repeating: 0x01, count: entropyLength)
    }

    func entropy(from words: [String]) throws -> Data {
        Data(repeating: 0x01, count: entropyLength)
    }
}
