import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(25)
            .shadow(radius: 10)
            .padding(.bottom, 50)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let msg = message {
                VStack {
                    Spacer()
                    ToastView(message: msg)
                }
                .zIndex(1)
            }
        }
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        self.modifier(ToastModifier(message: message))
    }
}
