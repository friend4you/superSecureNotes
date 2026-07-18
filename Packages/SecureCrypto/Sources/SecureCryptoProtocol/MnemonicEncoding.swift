import Foundation

public protocol MnemonicEncoding: Sendable {
    var wordCount: Int { get }
    var entropyLength: Int { get }

    func words(from entropy: Data) throws -> [String]
    func validate(_ words: [String]) throws -> Data
    func entropy(from words: [String]) throws -> Data
}
