import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var password = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        isAuthenticated = TokenManager.shared.isAuthenticated
        if isAuthenticated {
            username = TokenManager.shared.getUsername() ?? ""
        }
        
        // Подписка на уведомление о разлогине
        NotificationCenter.default.addObserver(forName: APIService.unauthorizedNotification, object: nil, queue: .main) { [weak self] _ in
            print("AuthViewModel: Received unauthorized notification, logging out...")
            self?.logout()
        }
    }
    
    func login() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Заполните все поля"
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
                }
            } receiveValue: { [weak self] token in
                TokenManager.shared.saveToken(token.accessToken, username: self?.username ?? "")
                self?.isAuthenticated = true
            }
            .store(in: &cancellables)
    }
    
    func logout() {
        TokenManager.shared.clearToken()
        isAuthenticated = false
        username = ""
        password = ""
    }
}
