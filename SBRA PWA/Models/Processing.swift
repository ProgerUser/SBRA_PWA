import Foundation

struct AvailableProcessing: Codable, Identifiable {
    let code: String
    let name: String
    let description: String?
    
    var id: String { code }
}

struct ProcessingRequest: Codable {
    let processingType: String
    let parameters: String?
    
    enum CodingKeys: String, CodingKey {
        case processingType = "processing_type"
        case parameters
    }
}

struct ProcessingResult: Codable {
    let taskId: String
    let status: String
    let resultsCount: Int?
    let filename: String?
    let error: String?
    let createdAt: String?
    let completedAt: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "TASK_ID"
        case taskId_snake = "task_id"
        case status = "STATUS"
        case status_snake = "status"
        case resultsCount = "RESULTS_COUNT"
        case resultsCount_snake = "results_count"
        case filename = "FILENAME"
        case filename_snake = "filename"
        case error = "ERROR"
        case error_snake = "error"
        case createdAt = "CREATED_AT"
        case createdAt_snake = "created_at"
        case completedAt = "COMPLETED_AT"
        case completedAt_snake = "completed_at"
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try TASK_ID then task_id
        if let id = try? container.decode(String.self, forKey: .taskId) {
            taskId = id
        } else {
            taskId = try container.decode(String.self, forKey: .taskId_snake)
        }
        
        // Try STATUS then status
        if let s = try? container.decode(String.self, forKey: .status) {
            status = s
        } else {
            status = try container.decode(String.self, forKey: .status_snake)
        }
        
        resultsCount = (try? container.decodeIfPresent(Int.self, forKey: .resultsCount)) ?? (try? container.decodeIfPresent(Int.self, forKey: .resultsCount_snake))
        filename = (try? container.decodeIfPresent(String.self, forKey: .filename)) ?? (try? container.decodeIfPresent(String.self, forKey: .filename_snake))
        error = (try? container.decodeIfPresent(String.self, forKey: .error)) ?? (try? container.decodeIfPresent(String.self, forKey: .error_snake))
        createdAt = (try? container.decodeIfPresent(String.self, forKey: .createdAt)) ?? (try? container.decodeIfPresent(String.self, forKey: .createdAt_snake))
        completedAt = (try? container.decodeIfPresent(String.self, forKey: .completedAt)) ?? (try? container.decodeIfPresent(String.self, forKey: .completedAt_snake))
        message = try? container.decodeIfPresent(String.self, forKey: .message)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(resultsCount, forKey: .resultsCount)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(message, forKey: .message)
    }
}
