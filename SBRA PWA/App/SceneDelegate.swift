// SBRA PWA/App/SceneDelegate.swift
import UIKit
import SwiftUI
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var splashView: UIView?
    private var cancellables = Set<AnyCancellable>()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        
        // Определяем начальный экран
        updateRootViewController(for: window)
        
        self.window = window
        window.makeKeyAndVisible()
        
        // Показываем кастомную заставку
        showCustomSplash(on: window)
        
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
        let isBiometricEnabled = BiometricManager.shared.isBiometricEnabled
        let rootView: AnyView
        
        if isAuthenticated {
            print("SceneDelegate: Authenticated, showing MainTabView")
            rootView = AnyView(MainTabView())
        } else {
            if isBiometricEnabled {
                print("SceneDelegate: Biometric enabled, showing BiometricAuthView")
                rootView = AnyView(BiometricAuthView(onAuthenticated: {
                    DispatchQueue.main.async {
                        self.updateRootViewController(for: window)
                    }
                }))
            } else {
                print("SceneDelegate: Not authenticated, showing LoginView")
                rootView = AnyView(LoginView())
            }
        }
        
        let hostingController = UIHostingController(rootView: rootView)
        
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = hostingController
        }
    }
    
    private func showCustomSplash(on window: UIWindow) {
        // Создаем view для заставки
        let splashView = UIView(frame: window.bounds)
        splashView.backgroundColor = UIColor(red: 26/255, green: 26/255, blue: 28/255, alpha: 1) // Theme.background
        
        // Создаем контейнер для логотипа
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        splashView.addSubview(containerView)
        
        // Контейнер для иконки со скругленными краями и тенью
        let imageContainerView = UIView()
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.backgroundColor = .clear
        imageContainerView.layer.shadowColor = UIColor(red: 0/255, green: 82/255, blue: 255/255, alpha: 0.5).cgColor
        imageContainerView.layer.shadowOffset = CGSize(width: 0, height: 10)
        imageContainerView.layer.shadowRadius = 20
        imageContainerView.layer.shadowOpacity = 0.5
        imageContainerView.layer.masksToBounds = false
        containerView.addSubview(imageContainerView)
        
        // Добавляем иконку SplashLogo (увеличена до 70% от ширины экрана)
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(red: 0/255, green: 82/255, blue: 255/255, alpha: 1) // Theme.primary
        imageView.layer.cornerRadius = 40
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = UIColor(red: 45/255, green: 45/255, blue: 50/255, alpha: 1) // Легкий фон для контраста
        
        // Используем кастомную иконку из Assets
        if let customImage = UIImage(named: "SplashLogo") {
            imageView.image = customImage
        } else {
            // Системная иконка как запасной вариант
            let config = UIImage.SymbolConfiguration(pointSize: 140, weight: .regular)
            imageView.image = UIImage(systemName: "externaldrive.fill", withConfiguration: config)
        }
        
        imageContainerView.addSubview(imageView)
        
        // Добавляем название приложения
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "StreamPay"
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .bold)
        titleLabel.textColor = UIColor(red: 26/255, green: 31/255, blue: 54/255, alpha: 1) // Theme.textPrimary
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // Добавляем версию
        let versionLabel = UILabel()
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.text = "Версия 1.0.0"
        versionLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        versionLabel.textColor = UIColor(red: 155/255, green: 155/255, blue: 155/255, alpha: 1) // Theme.textSecondary
        versionLabel.textAlignment = .center
        containerView.addSubview(versionLabel)
        
        // Настройка констрейнтов
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: splashView.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: splashView.widthAnchor),
            
            // Контейнер для иконки
            imageContainerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageContainerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageContainerView.widthAnchor.constraint(equalTo: splashView.widthAnchor, multiplier: 0.7),
            imageContainerView.heightAnchor.constraint(equalTo: imageContainerView.widthAnchor),
            
            // Иконка внутри контейнера
            imageView.topAnchor.constraint(equalTo: imageContainerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 50),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            versionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            versionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            versionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor)
        ])
        
        // Добавляем на окно
        window.addSubview(splashView)
        self.splashView = splashView
        
        // Начальное состояние для анимации
        imageContainerView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        imageContainerView.alpha = 0
        titleLabel.alpha = 0
        versionLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 40)
        versionLabel.transform = CGAffineTransform(translationX: 0, y: 40)
        
        // Анимация появления
        UIView.animate(withDuration: 1.2, delay: 0.2, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
            imageContainerView.transform = .identity
            imageContainerView.alpha = 1
            titleLabel.alpha = 1
            versionLabel.alpha = 1
            titleLabel.transform = .identity
            versionLabel.transform = .identity
        })
        
        // Дополнительная анимация тени (пульсация)
        let shadowAnimation = CABasicAnimation(keyPath: "shadowRadius")
        shadowAnimation.fromValue = 20
        shadowAnimation.toValue = 30
        shadowAnimation.duration = 1.5
        shadowAnimation.autoreverses = true
        shadowAnimation.repeatCount = 2
        imageContainerView.layer.add(shadowAnimation, forKey: "shadowPulse")
        
        // Скрываем заставку через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.5, animations: {
                splashView.alpha = 0
            }) { _ in
                splashView.removeFromSuperview()
                self.splashView = nil
            }
        }
    }
}

extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
}
