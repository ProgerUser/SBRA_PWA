// SBRA PWA/Services/BiometricManager.swift
import Foundation
import LocalAuthentication
import SwiftUI
import Combine
import KeychainSwift

class BiometricManager: ObservableObject {
    static let shared = BiometricManager()
    
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    @Published var biometricType: LABiometryType = .none
    @Published var isBiometricEnabled = false
    
    private let keychain = KeychainSwift()
    private let biometricEnabledKey = "biometric_enabled"
    private let savedUsernameKey = "saved_username"
    private let savedPasswordKey = "saved_password"
    
    private init() {
        checkBiometricType()
        checkBiometricEnabled()
    }
    
    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }
    
    func checkBiometricEnabled() {
        isBiometricEnabled = keychain.getBool(biometricEnabledKey) ?? false
    }
    
    func saveCredentials(username: String, password: String, enableBiometric: Bool) {
        if enableBiometric {
            keychain.set(username, forKey: savedUsernameKey)
            keychain.set(password, forKey: savedPasswordKey)
            keychain.set(true, forKey: biometricEnabledKey)
            isBiometricEnabled = true
            print("BiometricManager: Credentials saved with biometric enabled")
        } else {
            keychain.delete(savedUsernameKey)
            keychain.delete(savedPasswordKey)
            keychain.set(false, forKey: biometricEnabledKey)
            isBiometricEnabled = false
            print("BiometricManager: Biometric disabled")
        }
    }
    
    func getSavedCredentials() -> (username: String, password: String)? {
        guard let username = keychain.get(savedUsernameKey),
              let password = keychain.get(savedPasswordKey) else {
            return nil
        }
        return (username, password)
    }
    
    func clearCredentials() {
        keychain.delete(savedUsernameKey)
        keychain.delete(savedPasswordKey)
        keychain.set(false, forKey: biometricEnabledKey)
        isBiometricEnabled = false
        print("BiometricManager: Credentials cleared")
    }
    
    func authenticateUser(completion: @escaping (Bool, String?) -> Void) {
        // Предотвращаем множественные запросы
        guard !isAuthenticating else {
            completion(false, "Аутентификация уже выполняется")
            return
        }
        
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Войдите с помощью биометрии для доступа к приложению"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    if success {
                        self.isAuthenticated = true
                        completion(true, nil)
                    } else {
                        self.isAuthenticated = false
                        if let error = error {
                            completion(false, error.localizedDescription)
                        } else {
                            completion(false, "Аутентификация отменена")
                        }
                    }
                }
            }
        } else {
            // Если биометрия не доступна, используем пароль устройства
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Введите пароль устройства для доступа к приложению"
                
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                    DispatchQueue.main.async {
                        self.isAuthenticating = false
                        if success {
                            self.isAuthenticated = true
                            completion(true, nil)
                        } else {
                            self.isAuthenticated = false
                            if let error = error {
                                completion(false, error.localizedDescription)
                            } else {
                                completion(false, "Аутентификация отменена")
                            }
                        }
                    }
                }
            } else {
                isAuthenticating = false
                let message = error?.localizedDescription ?? "Биометрия не настроена на устройстве"
                completion(false, message)
            }
        }
    }
    
    var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "lock.shield"
        }
    }
    
    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "биометрию"
        }
    }
}
