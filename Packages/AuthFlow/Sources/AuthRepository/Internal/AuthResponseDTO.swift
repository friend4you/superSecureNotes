import Foundation

struct CredentialsRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct UserDTO: Decodable {
    let id: String
    let email: String
    let createdAt: Date

    func toUser() -> User {
        User(id: id, email: email, createdAt: createdAt)
    }
}

struct AuthSuccessResponseDTO: Decodable {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct RefreshResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct ErrorResponseDTO: Decodable {
    let error: String
    let message: String
}

struct AuthAPIResult {
    let user: User
    let session: AuthSession
}

enum AuthJSON {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        JSONEncoder()
    }
}
