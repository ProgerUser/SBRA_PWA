// SBRA PWA/Views/Main/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Фоновый слой
            MeshBackground()
            
            // Основной контент
            TabView(selection: $selectedTab) {
                ProcessingView()
                    .tabItem {
                        Label("Обработки", systemImage: "play.circle.fill")
                    }
                    .tag(0)
                
                TasksView()
                    .tabItem {
                        Label("Задачи", systemImage: "clock.badge.checkmark")
                    }
                    .tag(1)
                
                HistoryView()
                    .tabItem {
                        Label("История", systemImage: "list.bullet.rectangle")
                    }
                    .tag(2)
                
                AccountGroupsView()
                    .tabItem {
                        Label("Группы", systemImage: "folder.circle")
                    }
                    .tag(3)
                
                BalanceReportView()
                    .tabItem {
                        Label("Остатки", systemImage: "chart.pie.fill")
                    }
                    .tag(4)
                
                CardActivationView()
                    .tabItem {
                        Label("Активация", systemImage: "creditcard.and.123")
                    }
                    .tag(5)
                
                WhiteListView()
                    .tabItem {
                        Label("Белый список", systemImage: "checkmark.seal.fill")
                    }
                    .tag(6)
                
                // Профиль
                ProfileView(authViewModel: authViewModel)
                    .tabItem {
                        Label("Профиль", systemImage: "person.crop.circle.fill")
                    }
                    .tag(7)
            }
            .tint(Theme.primary)
            .onAppear {
                // Настройка внешнего вида TabBar для iOS
                setupTabBarAppearance()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Проверяем аутентификацию при активации приложения
                if !TokenManager.shared.isAuthenticated && authViewModel.isAuthenticated {
                    authViewModel.logout()
                }
            }
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.3)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// Выносим профиль в отдельное вью для чистоты
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Аватар
                    Circle()
                        .fill(Theme.primaryGradient)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(String(authViewModel.username.prefix(1)).uppercased())
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Theme.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Text(authViewModel.username)
                        .font(.title2.weight(.bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    // Карточка с информацией
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Версия приложения", systemImage: "apps.iphone")
                                .font(.headline)
                            
                            HStack {
                                Text("1.0.0 (2026)")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("Актуально")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.success.opacity(0.1))
                                    .foregroundColor(Theme.success)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Кнопка выхода
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal)
                }
                .padding(.top, 40)
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .background(MeshBackground())
            .alert("Выход из аккаунта", isPresented: $showingLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    print("ProfileView: Logout button pressed")
                    authViewModel.logout()
                }
            } message: {
                Text("Вы уверены, что хотите выйти?")
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
