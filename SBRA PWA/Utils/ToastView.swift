// SBRA PWA/Utils/ToastView.swift (полностью обновленный)
import SwiftUI

struct ToastView: View {
    let toast: Toast
    let onCancelTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.icon)
                .foregroundColor(toast.style.color)
                .font(.title3)
            
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
            
            Spacer(minLength: 10)
            
            Button(action: onCancelTapped) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Эффект стекла
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(0.95)
                
                // Цветная полоска слева
                HStack {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(toast.style.color)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                    Spacer()
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: toast.style.color.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let toast = toast {
                VStack {
                    Spacer()
                    ToastView(
                        toast: toast,
                        onCancelTapped: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                self.toast = nil
                            }
                        }
                    )
                }
                .zIndex(1)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    // Автоматически скрываем через duration
                    DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                        withAnimation {
                            if self.toast?.message == toast.message {
                                self.toast = nil
                            }
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(toast: Binding<Toast?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}
