// SBRA PWA/ViewModels/AuthViewModel.swift
import Foundation
import Combine
import LocalAuthentication

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var password = ""
    @Published var showBiometricPrompt = false
    @Published var useBiometric = false
    @Published var isBiometricLoginInProgress = false // Новый флаг
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        // Проверяем, есть ли сохраненный токен
        checkExistingSession()
    }
    
    private func checkExistingSession() {
        isAuthenticated = TokenManager.shared.isAuthenticated
        
        if isAuthenticated {
            username = TokenManager.shared.getUsername() ?? ""
            print("AuthViewModel: User is authenticated: \(username)")
            
            // Проверяем, включена ли биометрия
            if BiometricManager.shared.isBiometricEnabled {
                // Будет показан экран биометрии
                print("AuthViewModel: Biometric is enabled, will show biometric screen")
            }
        } else {
            print("AuthViewModel: No authenticated user")
        }
        
        // Подписка на уведомление о разлогине
        NotificationCenter.default.addObserver(
            forName: APIService.unauthorizedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("AuthViewModel: Received unauthorized notification, logging out...")
            self?.logout()
        }
    }
    
    func login(completionHandler: @escaping (Bool) -> Void = { _ in }) {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Заполните все поля"
            completionHandler(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        apiService.login(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("AuthViewModel: Login failed - \(error.localizedDescription)")
                    completionHandler(false)
                }
            } receiveValue: { [weak self] token in
                guard let self = self else { return }
                
                TokenManager.shared.saveToken(token.accessToken, username: self.username)
                
                // Проверяем, нужно ли предложить включить биометрию
                if !BiometricManager.shared.isBiometricEnabled &&
                   BiometricManager.shared.biometricType != .none {
                    self.showBiometricPrompt = true
                    completionHandler(false) // Не завершаем, покажем диалог
                } else {
                    self.isAuthenticated = true
                    NotificationCenter.default.post(name: .authStateChanged, object: nil)
                    print("AuthViewModel: Successfully logged in as \(self.username)")
                    completionHandler(true)
                }
            }
            .store(in: &cancellables)
    }
    
    func loginWithBiometrics(completionHandler: @escaping (Bool) -> Void = { _ in }) {
        // Защита от множественных вызовов
        guard !isBiometricLoginInProgress else {
            print("AuthViewModel: Biometric login already in progress")
            completionHandler(false)
            return
        }
        
        guard let credentials = BiometricManager.shared.getSavedCredentials() else {
            errorMessage = "Нет сохраненных учетных данных"
            completionHandler(false)
            return
        }
        
        isBiometricLoginInProgress = true
        isLoading = true
        errorMessage = nil
        username = credentials.username
        password = credentials.password
        
        apiService.login(username: credentials.username, password: credentials.password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.isBiometricLoginInProgress = false
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("AuthViewModel: Biometric login failed - \(error.localizedDescription)")
                    completionHandler(false)
                }
            } receiveValue: { [weak self] token in
                TokenManager.shared.saveToken(token.accessToken, username: credentials.username)
                self?.isAuthenticated = true
                self?.isBiometricLoginInProgress = false
                NotificationCenter.default.post(name: .authStateChanged, object: nil)
                print("AuthViewModel: Successfully logged in with biometrics as \(credentials.username)")
                completionHandler(true)
            }
            .store(in: &cancellables)
    }
    
    func enableBiometric() {
        BiometricManager.shared.saveCredentials(
            username: username,
            password: password,
            enableBiometric: true
        )
        showBiometricPrompt = false
        isAuthenticated = true
        NotificationCenter.default.post(name: .authStateChanged, object: nil)
    }
    
    func skipBiometric() {
        showBiometricPrompt = false
        isAuthenticated = true
        NotificationCenter.default.post(name: .authStateChanged, object: nil)
    }
    
    func resetToLogin() {
        TokenManager.shared.clearToken()
        BiometricManager.shared.clearCredentials()
        isAuthenticated = false
        username = ""
        password = ""
        showBiometricPrompt = false
        NotificationCenter.default.post(name: .authStateChanged, object: nil)
    }
    
    func logout() {
        print("AuthViewModel: Logging out...")
        TokenManager.shared.clearToken()
        // Не очищаем биометрию при обычном выходе
        
        isAuthenticated = false
        username = ""
        password = ""
        NotificationCenter.default.post(name: .authStateChanged, object: nil)
        print("AuthViewModel: Logged out successfully")
    }
}
