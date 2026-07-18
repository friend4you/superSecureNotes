import XCTest

@testable import SecureCryptoProtocol

final class BIP39WordlistTests: XCTestCase {
    func testLoads2048WordsFromBundle() {
        XCTAssertEqual(BIP39Wordlist.wordCount, 2048)
        XCTAssertEqual(BIP39Wordlist.words.count, 2048)
        XCTAssertEqual(BIP39Wordlist.word(at: 0), "abandon")
        XCTAssertEqual(BIP39Wordlist.word(at: 2047), "zoo")
    }

    func testIndexOfReturnsNilForUnknownWord() {
        XCTAssertNil(BIP39Wordlist.index(of: "notaword"))
    }

    func testIndexOfFindsKnownWord() {
        XCTAssertEqual(BIP39Wordlist.index(of: "abandon"), 0)
        XCTAssertEqual(BIP39Wordlist.index(of: "ABANDON"), 0)
    }
}
