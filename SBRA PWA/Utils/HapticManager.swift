import UIKit
import AudioToolbox

class HapticManager {
    static let shared = HapticManager()
    
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    private init() {
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            lightImpact.impactOccurred()
            AudioServicesPlaySystemSound(1519)
        case .medium:
            mediumImpact.impactOccurred()
            AudioServicesPlaySystemSound(1520)
        case .heavy:
            heavyImpact.impactOccurred()
            AudioServicesPlaySystemSound(1521)
        @unknown default:
            mediumImpact.impactOccurred()
            AudioServicesPlaySystemSound(1520)
        }
        prepare()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        switch type {
        case .error:
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        case .success:
            AudioServicesPlaySystemSound(1521)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AudioServicesPlaySystemSound(1519)
            }
        case .warning:
            AudioServicesPlaySystemSound(1520)
        @unknown default:
            break
        }
        prepare()
    }
    
    func selection() {
        selectionGenerator.selectionChanged()
        AudioServicesPlaySystemSound(1519)
        prepare()
    }
    
    func success() {
        notification(type: .success)
    }
    
    func error() {
        notification(type: .error)
    }
    
    func warning() {
        notification(type: .warning)
    }
    
    private func prepare() {
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
    }
}
