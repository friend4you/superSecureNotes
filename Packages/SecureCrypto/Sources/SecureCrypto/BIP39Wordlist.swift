import Foundation

enum BIP39Wordlist {
    static let wordCount = 2048
    private static let loader = Loader()

    static var words: [String] { loader.words }

    static func contains(_ word: String) -> Bool {
        loader.index(of: word) != nil
    }

    static func word(at index: Int) -> String {
        loader.words[index]
    }

    static func index(of word: String) -> Int? {
        loader.index(of: word)
    }

    private struct Loader {
        let words: [String]
        private let wordToIndex: [String: Int]

        init() {
            guard let url = Bundle.module.url(forResource: "english", withExtension: "txt") else {
                fatalError("Missing BIP39 english wordlist resource.")
            }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("Failed to read BIP39 english wordlist.")
            }

            words = content
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard words.count == BIP39Wordlist.wordCount else {
                fatalError("BIP39 english wordlist must contain 2048 words.")
            }

            wordToIndex = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
        }

        func index(of word: String) -> Int? {
            wordToIndex[word.lowercased()]
        }
    }
}
