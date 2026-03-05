import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var authViewModel = AuthViewModel()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Устанавливаем UIHostingController
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        
        // Определяем начальный экран
        let rootView: any View
        if authViewModel.isAuthenticated {
            print("SceneDelegate: Authenticated, showing MainTabView")
            rootView = MainTabView()
        } else {
            print("SceneDelegate: Not authenticated, showing LoginView")
            rootView = LoginView()
        }
        
        window.rootViewController = UIHostingController(rootView: AnyView(rootView))
        self.window = window
        window.makeKeyAndVisible()
    }
}
