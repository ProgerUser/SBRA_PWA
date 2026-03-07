// SBRA PWA/Views/Auth/LoginView.swift
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingAlert = false
    @State private var animate = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username
        case password
    }
    
    var body: some View {
        ZStack {
            // Современный градиентный фон с анимацией
            MeshGradientBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    // Анимированный логотип
                    VStack(spacing: 20) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 90))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                            .scaleEffect(animate ? 1 : 0.8)
                            .opacity(animate ? 1 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: animate)
                        
                        VStack(spacing: 8) {
                            Text("Oracle Processor")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Мобильная версия")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                        }
                    }
                    .padding(.top, 60)
                    
                    Spacer(minLength: 20)
                    
                    // Карточка входа с эффектом стекла
                    VStack(spacing: 25) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Поле логина
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Логин")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 20)
                                    
                                    TextField("", text: $viewModel.username)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .focused($focusedField, equals: .username)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                        .placeholder(when: viewModel.username.isEmpty) {
                                            Text("Введите логин")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(focusedField == .username ? Color.white : Color.white.opacity(0.2), lineWidth: focusedField == .username ? 2 : 1)
                                )
                            }
                            
                            // Поле пароля
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Пароль")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 20)
                                    
                                    SecureField("", text: $viewModel.password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            login()
                                        }
                                        .placeholder(when: viewModel.password.isEmpty) {
                                            Text("Введите пароль")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(focusedField == .password ? Color.white : Color.white.opacity(0.2), lineWidth: focusedField == .password ? 2 : 1)
                                )
                            }
                        }
                        
                        // Кнопка входа
                        Button(action: login) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Text("Войти")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                        .disabled(viewModel.isLoading)
                        .scaleEffect(viewModel.isLoading ? 0.98 : 1)
                        .animation(.spring(), value: viewModel.isLoading)
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                        )
                                )
                                .transition(.scale.combined(with: .opacity))
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
                    VStack(spacing: 8) {
                        Text("Для продолжения работы требуется авторизация")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Версия 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.bottom, 30)
                }
                .frame(minHeight: UIScreen.main.bounds.height)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
    
    private func login() {
        viewModel.login()
    }
}

// MARK: - Mesh Gradient Background
struct MeshGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Базовый градиент
            LinearGradient(
                colors: [
                    Color(hex: "0052FF"),
                    Color(hex: "7C3AED"),
                    Color(hex: "FF6B6B")
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            
            // Анимированные круги
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animateGradient ? -100 : 100, y: animateGradient ? -200 : 200)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animateGradient)
            
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animateGradient ? 150 : -150, y: animateGradient ? 300 : -300)
                .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animateGradient)
            
            // Шумовая текстура
            Color.white.opacity(0.02)
                .blendMode(.overlay)
        }
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - Placeholder Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
