import Foundation

struct User: Codable {
    let username: String
    let disabled: Bool?
}

struct UserInDB: Codable {
    let username: String
    let hashedPassword: String
    let disabled: Bool
}

struct Token: Codable {
    let accessToken: String
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct TokenData {
    let username: String
}
