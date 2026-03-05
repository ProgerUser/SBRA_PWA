import Foundation
import KeychainSwift

class TokenManager {
    static let shared = TokenManager()
    private let keychain = KeychainSwift()
    private let tokenKey = "auth_token"
    private let usernameKey = "username"
    
    private init() {}
    
    func saveToken(_ token: String, username: String) {
        keychain.set(token, forKey: tokenKey)
        keychain.set(username, forKey: usernameKey)
    }
    
    func getToken() -> String? {
        return keychain.get(tokenKey)
    }
    
    func getUsername() -> String? {
        return keychain.get(usernameKey)
    }
    
    func clearToken() {
        keychain.delete(tokenKey)
        keychain.delete(usernameKey)
    }
    
    var isAuthenticated: Bool {
        return getToken() != nil
    }
}
