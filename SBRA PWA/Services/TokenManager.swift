// SBRA PWA/Services/TokenManager.swift
import Foundation
import KeychainSwift

class TokenManager {
    static let shared = TokenManager()
    private let keychain = KeychainSwift()
    private let tokenKey = "auth_token"
    private let usernameKey = "username"
    
    private init() {
        // Настройка Keychain
        keychain.synchronizable = false
        keychain.accessGroup = nil
    }
    
    func saveToken(_ token: String, username: String) {
        keychain.set(token, forKey: tokenKey)
        keychain.set(username, forKey: usernameKey)
        print("TokenManager: Token saved for user: \(username)")
        
        // Отправляем уведомление об изменении статуса
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .authStateChanged, object: nil)
        }
    }
    
    func getToken() -> String? {
        let token = keychain.get(tokenKey)
        if token != nil {
            print("TokenManager: Token retrieved")
        } else {
            print("TokenManager: No token found")
        }
        return token
    }
    
    func getUsername() -> String? {
        return keychain.get(usernameKey)
    }
    
    func clearToken() {
        keychain.delete(tokenKey)
        keychain.delete(usernameKey)
        print("TokenManager: Token cleared")
        
        // Отправляем уведомление об изменении статуса
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .authStateChanged, object: nil)
        }
    }
    
    var isAuthenticated: Bool {
        return getToken() != nil
    }
}
