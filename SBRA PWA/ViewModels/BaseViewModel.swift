// SBRA PWA/ViewModels/BaseViewModel.swift
import Foundation
import Combine
import SwiftUI

// MARK: - Toast Types
enum ToastStyle {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return Color(hex: "10B981") // Зеленый
        case .error: return Color(hex: "EF4444")   // Красный
        case .warning: return Color(hex: "F59E0B") // Оранжевый
        case .info: return Color(hex: "3B82F6")    // Синий
        }
    }
}

// MARK: - Toast Model
struct Toast: Equatable {
    let message: String
    let style: ToastStyle
    var duration: Double = 2.0
}

// MARK: - Toast Protocol
protocol ToastCapable: AnyObject {
    var toast: Toast? { get set }
}

extension ToastCapable {
    func showToast(_ message: String, style: ToastStyle = .info) {
        toast = Toast(message: message, style: style)
        
        // Автоматически скрываем через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.toast?.message == message {
                self?.toast = nil
            }
        }
    }
    
    func showSuccess(_ message: String) {
        showToast(message, style: .success)
    }
    
    func showError(_ message: String) {
        showToast(message, style: .error)
    }
    
    func showWarning(_ message: String) {
        showToast(message, style: .warning)
    }
}
