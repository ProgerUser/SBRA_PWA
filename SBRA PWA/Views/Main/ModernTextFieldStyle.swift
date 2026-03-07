// SBRA PWA/Views/Main/ModernTextFieldStyle.swift
import SwiftUI

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.textTertiary.opacity(0.3), lineWidth: 1)
            )
    }
}
