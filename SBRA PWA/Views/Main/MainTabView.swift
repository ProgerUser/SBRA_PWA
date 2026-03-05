import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProcessingView()
                .tabItem {
                    Label("Обработки", systemImage: "play.circle")
                }
                .tag(0)
            
            TasksView()
                .tabItem {
                    Label("Задачи", systemImage: "clock")
                }
                .tag(1)
            
            HistoryView()
                .tabItem {
                    Label("История", systemImage: "list.bullet")
                }
                .tag(2)
            
            AccountGroupsView()
                .tabItem {
                    Label("Группы", systemImage: "folder")
                }
                .tag(3)
            
            BalanceReportView()
                .tabItem {
                    Label("Остатки", systemImage: "chart.pie")
                }
                .tag(4)
            
            CardActivationView()
                .tabItem {
                    Label("Активация", systemImage: "creditcard")
                }
                .tag(5)
            
            WhiteListView()
                .tabItem {
                    Label("Белый список", systemImage: "checkmark.seal")
                }
                .tag(6)
            
            // Новая вкладка настроек/выхода
            VStack(spacing: 20) {
                Image(systemName: "person.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text(authViewModel.username)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Button(action: {
                    authViewModel.logout()
                }) {
                    Text("Выйти из аккаунта")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .tabItem {
                Label("Профиль", systemImage: "person.circle")
            }
            .tag(7)
        }
        .buttonStyle(HapticButtonStyle())
        .accentColor(.blue)
        .onReceive(authViewModel.$isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                // Переход на экран входа
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: LoginView())
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
                    window.makeKeyAndVisible()
                }
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
