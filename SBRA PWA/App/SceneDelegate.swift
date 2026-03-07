// SBRA PWA/App/SceneDelegate.swift
import UIKit
import SwiftUI
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Создаем окно
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        
        // Определяем начальный экран
        updateRootViewController(for: window)
        
        self.window = window
        window.makeKeyAndVisible()
        
        // Подписываемся на уведомления об изменении статуса аутентификации
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChange),
            name: .authStateChanged,
            object: nil
        )
    }
    
    @objc private func handleAuthStateChange() {
        guard let window = window else { return }
        DispatchQueue.main.async {
            self.updateRootViewController(for: window)
        }
    }
    
    private func updateRootViewController(for window: UIWindow) {
        let isAuthenticated = TokenManager.shared.isAuthenticated
        let rootView: AnyView
        
        if isAuthenticated {
            print("SceneDelegate: Authenticated, showing MainTabView")
            rootView = AnyView(MainTabView())
        } else {
            print("SceneDelegate: Not authenticated, showing LoginView")
            rootView = AnyView(LoginView())
        }
        
        let hostingController = UIHostingController(rootView: rootView)
        
        // Анимированная смена корневого контроллера
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = hostingController
        }
    }
}

// Добавляем notification name
extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
}
