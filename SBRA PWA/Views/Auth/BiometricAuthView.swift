// SBRA PWA/Views/Auth/BiometricAuthView.swift
import SwiftUI

struct BiometricAuthView: View {
    @StateObject private var biometricManager = BiometricManager.shared
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLoginScreen = false
    @State private var hasAttemptedAuth = false
    
    var onAuthenticated: () -> Void
    
    var body: some View {
        ZStack {
            if showLoginScreen {
                LoginView()
            } else {
                // Градиентный фон
                MeshGradientBackground()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Иконка приложения
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Text("StreamPay")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Карточка биометрии
                    VStack(spacing: 25) {
                        // Иконка биометрии
                        Image(systemName: biometricManager.biometricIconName)
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .symbolRenderingMode(.multicolor)
                        
                        if let credentials = biometricManager.getSavedCredentials() {
                            Text("Добро пожаловать, \(credentials.username)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Text("Для доступа к приложению используйте \(biometricManager.biometricDisplayName)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if biometricManager.isAuthenticating || isAuthenticating {
                            VStack(spacing: 15) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                Text("Ожидание подтверждения...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                        } else {
                            Button(action: authenticate) {
                                HStack {
                                    Image(systemName: biometricManager.biometricIconName)
                                    Text("Войти с \(biometricManager.biometricDisplayName)")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(Color(red: 0/255, green: 82/255, blue: 255/255))
                                .cornerRadius(16)
                                .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            
                            Button(action: {
                                showLoginScreen = true
                            }) {
                                Text("Войти с другим логином")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .underline()
                            }
                        }
                    }
                    .padding(30)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(.ultraThinMaterial)
                                .opacity(0.9)
                            
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 20)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Подвал
                    Text("Защищено \(biometricManager.biometricDisplayName)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 30)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Автоматически запускаем аутентификацию только один раз
            if !hasAttemptedAuth && !biometricManager.isAuthenticating {
                hasAttemptedAuth = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticate()
                }
            }
        }
        .onChange(of: biometricManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Автоматический вход с сохраненными данными
                authViewModel.loginWithBiometrics(completionHandler: { success in
                    if success {
                        onAuthenticated()
                    }
                })
            }
        }
        .alert("Ошибка аутентификации", isPresented: $showError) {
            Button("Повторить", role: .cancel) {
                authenticate()
            }
            Button("Войти с паролем", role: .destructive) {
                showLoginScreen = true
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func authenticate() {
        // Защита от множественных вызовов
        guard !biometricManager.isAuthenticating && !isAuthenticating else {
            print("BiometricAuthView: Already authenticating")
            return
        }
        
        isAuthenticating = true
        
        biometricManager.authenticateUser { success, error in
            isAuthenticating = false
            
            if !success {
                if let error = error {
                    errorMessage = error
                    showError = true
                }
            }
            // При успехе сработает onChange
        }
    }
}
