import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case encodingError
    case networkError(Error)
    case serverError(Int, String?)
    case unauthorized
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .noData:
            return "Нет данных от сервера"
        case .decodingError:
            return "Ошибка декодирования данных"
        case .encodingError:
            return "Ошибка кодирования данных"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Ошибка сервера (\(code)): \(message ?? "Неизвестная ошибка")"
        case .unauthorized:
            return "Не авторизован"
        case .unknown:
            return "Неизвестная ошибка"
        }
    }
}

class APIService {
    static let shared = APIService()
    private let baseURL = "http://localhost:5500" // Замените на ваш URL
    
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Authentication
    
    func login(username: String, password: String) -> AnyPublisher<Token, APIError> {
        let url = URL(string: "\(baseURL)/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "username=\(username)&password=\(password)&grant_type=password"
        request.httpBody = body.data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<Token, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode != 200 {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: Token.self, decoder: JSONDecoder())
                    .mapError { _ in APIError.decodingError }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, APIError> {
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<T, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: T.self, decoder: JSONDecoder())
                    .mapError { _ in APIError.decodingError }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Processings
    
    func getAvailableProcessings() -> AnyPublisher<[AvailableProcessing], APIError> {
        guard let request = createRequest("/available-processings") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    func executeProcessing(_ request: ProcessingRequest) -> AnyPublisher<ProcessingResult, APIError> {
        guard let body = try? JSONEncoder().encode(request),
              let urlRequest = createRequest("/execute-processing", method: "POST", body: body) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return performRequest(urlRequest)
    }
    
    // MARK: - Tasks
    
    func getUserTasks() -> AnyPublisher<[ProcessingTask], APIError> {
        guard let request = createRequest("/user-tasks") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
            .map { (response: [String: [ProcessingTask]]) -> [ProcessingTask] in
                return response["tasks"] ?? []
            }
            .eraseToAnyPublisher()
    }
    
    func getTaskStatus(taskId: String) -> AnyPublisher<ProcessingTask, APIError> {
        guard let request = createRequest("/task-status/\(taskId)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    // MARK: - History
    
    func getProcessingHistory(groupName: String? = nil, startDate: String? = nil, endDate: String? = nil, daysBack: Int = 7) -> AnyPublisher<[[String: Any]], APIError> {
        var components = URLComponents(string: "\(baseURL)/processing-history")
        var queryItems: [URLQueryItem] = []
        
        if let groupName = groupName {
            queryItems.append(URLQueryItem(name: "group_name", value: groupName))
        }
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        if startDate == nil && endDate == nil {
            queryItems.append(URLQueryItem(name: "days_back", value: "\(daysBack)"))
        }
        
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = components?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [[String: Any]] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    throw APIError.decodingError
                }
                return json
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Account Groups
    
    func getAccountGroups() -> AnyPublisher<[AccountGroup], APIError> {
        guard let request = createRequest("/account-groups") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
            .map { (response: AccountGroupResponse) -> [AccountGroup] in
                return response.groups
            }
            .eraseToAnyPublisher()
    }
    
    func createAccountGroup(accNum: String, grpName: String) -> AnyPublisher<[String: Any], APIError> {
        let body: [String: Any] = ["acc_num": accNum, "grp_name": grpName]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = createRequest("/account-groups", method: "POST", body: jsonData) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [String: Any] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError
                }
                return json
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    func updateAccountGroup(accNum: String, newAccNum: String, grpName: String) -> AnyPublisher<[String: Any], APIError> {
        let body: [String: Any] = ["acc_num": newAccNum, "grp_name": grpName]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = createRequest("/account-groups/\(accNum)", method: "PUT", body: jsonData) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [String: Any] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError
                }
                return json
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    func deleteAccountGroup(accNum: String) -> AnyPublisher<[String: Any], APIError> {
        guard let request = createRequest("/account-groups/\(accNum)", method: "DELETE") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [String: Any] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError
                }
                return json
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Balance Report
    
    func getBalanceReport() -> AnyPublisher<[[String: Any]], APIError> {
        guard let request = createRequest("/balance-report") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [[String: Any]] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let data = json["data"] as? [[String: Any]] else {
                    throw APIError.decodingError
                }
                return data
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Card Activation
    
    func activateSingleCard(cardNumber: String) -> AnyPublisher<CardActivationResult, APIError> {
        let body = "card_number=\(cardNumber)".data(using: .utf8)
        guard let url = URL(string: "\(baseURL)/activate-card") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = body
        
        return performRequest(request)
    }
    
    func uploadActivationFile(fileData: Data, fileName: String) -> AnyPublisher<BatchActivationResult, APIError> {
        let boundary = UUID().uuidString
        guard let url = URL(string: "\(baseURL)/activate-cards-excel") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return performRequest(request)
            .map { (response: [String: Any]) -> BatchActivationResult in
                let result = response["result"] as? [String: Any] ?? [:]
                let results = (result["results"] as? [[String: Any]] ?? []).compactMap { item -> CardActivationResult? in
                    guard let data = try? JSONSerialization.data(withJSONObject: item),
                          let cardResult = try? JSONDecoder().decode(CardActivationResult.self, from: data) else {
                        return nil
                    }
                    return cardResult
                }
                
                return BatchActivationResult(
                    total: result["total"] as? Int ?? 0,
                    success: result["success"] as? Int ?? 0,
                    failed: result["failed"] as? Int ?? 0,
                    results: results
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getActivationHistory(startDate: String? = nil, endDate: String? = nil, limit: Int = 1000) -> AnyPublisher<[ActivationHistory], APIError> {
        var components = URLComponents(string: "\(baseURL)/activation-history")
        var queryItems: [URLQueryItem] = []
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [ActivationHistory] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let historyData = json["history"] else {
                    throw APIError.decodingError
                }
                
                let historyJson = try JSONSerialization.data(withJSONObject: historyData)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode([ActivationHistory].self, from: historyJson)
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
    
    func clearActivationHistory() -> AnyPublisher<[String: Any], APIError> {
        guard let request = createRequest("/activation-history/clear", method: "DELETE") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .tryMap { data, response -> [String: Any] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw APIError.decodingError
                }
                return json
            }
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
    }
}
