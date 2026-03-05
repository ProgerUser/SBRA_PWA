import Foundation

struct ProcessingTask: Codable, Identifiable {
    let taskId: String
    let processingType: String
    let parameters: String?
    let status: TaskStatus
    let createdAt: String
    let createdBy: String
    let completedAt: String?
    let resultsCount: Int?
    let filename: String?
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "TASK_ID"
        case processingType = "PROCESSING_TYPE"
        case parameters = "PARAMETERS"
        case status = "STATUS"
        case createdAt = "CREATED_AT"
        case createdBy = "CREATED_BY"
        case completedAt = "COMPLETED_AT"
        case resultsCount = "RESULTS_COUNT"
        case filename = "FILENAME"
        case errorMessage = "ERROR_MESSAGE"
    }
    
    var id: String { taskId }
}

enum TaskStatus: String, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидание"
        case .running: return "Выполняется"
        case .completed: return "Завершено"
        case .error: return "Ошибка"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "warning"
        case .running: return "info"
        case .completed: return "success"
        case .error: return "danger"
        }
    }
}
