import Foundation

struct PublicKeyResponseDTO: Decodable {
    let publicKey: String
    let algorithmId: Int
}

struct ErrorResponseDTO: Decodable {
    let error: String
    let message: String
}

enum VaultJSON {
    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
