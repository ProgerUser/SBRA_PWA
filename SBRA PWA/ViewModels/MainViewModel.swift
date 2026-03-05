import Foundation
import Combine

class MainViewModel: ObservableObject {
    @Published var activeTasksCount = 0
    @Published var systemStatus: SystemStatus = .unknown
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    enum SystemStatus {
        case connected
        case disconnected
        case unknown
        
        var color: String {
            switch self {
            case .connected: return "success"
            case .disconnected: return "danger"
            case .unknown: return "secondary"
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Подключено"
            case .disconnected: return "Отключено"
            case .unknown: return "Неизвестно"
            }
        }
    }
    
    func checkHealth() {
        // Проверка здоровья системы
        // Можно добавить отдельный эндпоинт для проверки
    }
    
    func updateActiveTasksCount(_ count: Int) {
        activeTasksCount = count
    }
}
