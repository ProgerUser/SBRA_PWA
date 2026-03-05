import Foundation
import Combine

// MARK: - Error Types

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

// MARK: - APIService

class APIService: NSObject, URLSessionDelegate {
    static let shared = APIService()
    static let unauthorizedNotification = Notification.Name("APIServiceUnauthorized")
    private let baseURL = "https://10.111.170.74:5500" // Замените на ваш URL
    
    private var session: URLSession!
    private var cancellables = Set<AnyCancellable>()
    
    func downloadFile(request: URLRequest, completion: @escaping (URL?, URLResponse?, Error?) -> Void) {
        let task = session.downloadTask(with: request, completionHandler: completion)
        task.resume()
    }
    
    override private init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - SSL Bypass
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - Authentication
    
    func login(username: String, password: String) -> AnyPublisher<Token, APIError> {
        guard let url = URL(string: "\(baseURL)/token") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "username=\(username)&password=\(password)"
        request.httpBody = body.data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<Token, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
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
        
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    func getExportHistoryExcelURL(groupName: String? = nil, startDate: String? = nil, endDate: String? = nil, daysBack: Int = 7) -> URL? {
        var components = URLComponents(string: "\(baseURL)/export-history-excel")
        var queryItems = [URLQueryItem(name: "days_back", value: "\(daysBack)")]
        if let groupName = groupName { queryItems.append(URLQueryItem(name: "group_name", value: groupName)) }
        if let startDate = startDate { queryItems.append(URLQueryItem(name: "start_date", value: startDate)) }
        if let endDate = endDate { queryItems.append(URLQueryItem(name: "end_date", value: endDate)) }
        components?.queryItems = queryItems
        return components?.url
    }
    
    func getExportBalanceReportExcelURL() -> URL? {
        return URL(string: "\(baseURL)/export-balance-report-excel")
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, APIError> {
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<T, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: T.self, decoder: JSONDecoder())
                    .mapError { error in
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("Decoding error: \(error)")
                            print("Raw JSON response: \(jsonString)")
                        }
                        return APIError.decodingError
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Ruslan / Groups
    
    func getAvailableGroups() -> AnyPublisher<[String], APIError> {
        guard let request = createRequest("/available-groups") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
            .map { (response: AvailableGroupsResponse) -> [String] in
                return response.groups
            }
            .eraseToAnyPublisher()
    }
    
    func uploadRuslanFile(fileData: Data, fileName: String) -> AnyPublisher<UploadResponse, APIError> {
        let boundary = UUID().uuidString
        guard let url = URL(string: "\(baseURL)/upload-excel-file") else {
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
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<UploadResponse, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: UploadResponse.self, decoder: JSONDecoder())
                    .mapError { _ in APIError.decodingError }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func getRuslanCardCount() -> AnyPublisher<Int, APIError> {
        guard let request = createRequest("/ruslan-card-count") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
            .map { (response: CountResponse) -> Int in
                return response.count
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
    
    func getProcessingHistory(groupName: String? = nil, startDate: String? = nil, endDate: String? = nil, daysBack: Int = 7) -> AnyPublisher<[HistoryItem], APIError> {
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
            .flatMap { data, response -> AnyPublisher<[HistoryItem], APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataArray = json["data"] {
                        let historyJson = try JSONSerialization.data(withJSONObject: dataArray)
                        let decoder = JSONDecoder()
                        let items = try decoder.decode([HistoryItem].self, from: historyJson)
                        return Just(items).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let historyJson = try JSONSerialization.data(withJSONObject: jsonArray)
                        let decoder = JSONDecoder()
                        let items = try decoder.decode([HistoryItem].self, from: historyJson)
                        return Just(items).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else {
                        return Fail(error: APIError.decodingError).eraseToAnyPublisher()
                    }
                } catch {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("History decoding error: \(error)")
                        print("Raw JSON response: \(jsonString)")
                    }
                    return Fail(error: APIError.decodingError).eraseToAnyPublisher()
                }
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
    
    func createAccountGroup(accNum: String, grpName: String) -> AnyPublisher<AccountGroup, APIError> {
        let body: [String: Any] = ["acc_num": accNum, "grp_name": grpName]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = createRequest("/account-groups", method: "POST", body: jsonData) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<AccountGroup, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: AccountGroup.self, decoder: JSONDecoder())
                    .mapError { _ in APIError.decodingError }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func updateAccountGroup(accNum: String, newAccNum: String, grpName: String) -> AnyPublisher<AccountGroup, APIError> {
        let body: [String: Any] = ["acc_num": newAccNum, "grp_name": grpName]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = createRequest("/account-groups/\(accNum)", method: "PUT", body: jsonData) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<AccountGroup, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: AccountGroup.self, decoder: JSONDecoder())
                    .mapError { _ in APIError.decodingError }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func deleteAccountGroup(accNum: String) -> AnyPublisher<MessageResponse, APIError> {
        guard let request = createRequest("/account-groups/\(accNum)", method: "DELETE") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    // MARK: - Balance Report
    
    func getBalanceReport() -> AnyPublisher<[BalanceReportItem], APIError> {
        guard let request = createRequest("/balance-report") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<[BalanceReportItem], APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataArray = json["data"] {
                        let reportJson = try JSONSerialization.data(withJSONObject: dataArray)
                        let decoder = JSONDecoder()
                        let items = try decoder.decode([BalanceReportItem].self, from: reportJson)
                        return Just(items).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else {
                        print("Balance report: 'data' key not found in response")
                        return Fail(error: APIError.decodingError).eraseToAnyPublisher()
                    }
                } catch {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Balance report decoding error: \(error)")
                        print("Raw JSON response: \(jsonString)")
                    }
                    return Fail(error: APIError.decodingError).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getDetailedBalanceReport() -> AnyPublisher<BalanceReportDetailedResponse, APIError> {
        guard let request = createRequest("/balance-report/detailed") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    func getBalanceReportByGroup(groupName: String) -> AnyPublisher<[BalanceReportItem], APIError> {
        guard let request = createRequest("/balance-report/group/\(groupName)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    // MARK: - White List Management
    
    func getWhiteListCards() -> AnyPublisher<[WhiteListCard], APIError> {
        guard let request = createRequest("/white-list-cards") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
            .map { (response: WhiteListResponse) -> [WhiteListCard] in
                return response.cards
            }
            .eraseToAnyPublisher()
    }
    
    func addSingleCardToWhiteList(cardNum: String, typeCon: String) -> AnyPublisher<MessageResponse, APIError> {
        let body: [String: Any] = ["card_num": cardNum, "group_name": typeCon]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = createRequest("/add-single-card-to-white-list", method: "POST", body: jsonData) else {
            return Fail(error: APIError.encodingError).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    func addCardsToWhiteList(fileData: Data, fileName: String) -> AnyPublisher<UploadResponse, APIError> {
        let boundary = UUID().uuidString
        guard let url = URL(string: "\(baseURL)/add-cards-to-white-list") else {
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
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<UploadResponse, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: UploadResponse.self, decoder: JSONDecoder())
                    .mapError { _ in APIError.decodingError }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func deleteWhiteListCard(cardNum: String) -> AnyPublisher<MessageResponse, APIError> {
        guard let request = createRequest("/white-list-cards/\(cardNum)", method: "DELETE") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    func clearWhiteListByGroup(groupName: String) -> AnyPublisher<MessageResponse, APIError> {
        guard let request = createRequest("/white-list-cards/clear-by-group/\(groupName)", method: "DELETE") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
    
    // MARK: - Card Activation (Continued)
    
    func activateSingleCard(cardNumber: String) -> AnyPublisher<CardActivationResult, APIError> {
        guard let url = URL(string: "\(baseURL)/activate-card") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = "card_number=\(cardNumber)"
        request.httpBody = body.data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<CardActivationResult, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: CardActivationResult.self, decoder: JSONDecoder())
                    .mapError { error in
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("Single Activation Decoding error: \(error)")
                            print("Raw JSON response: \(jsonString)")
                        }
                        return APIError.decodingError
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
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
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<BatchActivationResult, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                return Just(data)
                    .decode(type: BatchActivationResult.self, decoder: JSONDecoder())
                    .mapError { error in
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("Batch Activation Decoding error: \(error)")
                            print("Raw JSON response: \(jsonString)")
                        }
                        return APIError.decodingError
                    }
                    .eraseToAnyPublisher()
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
            .flatMap { data, response -> AnyPublisher<[ActivationHistory], APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.unknown).eraseToAnyPublisher()
                }
                
                if httpResponse.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    return Fail(error: APIError.serverError(httpResponse.statusCode, message)).eraseToAnyPublisher()
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let historyData = json["history"] {
                        let historyJson = try JSONSerialization.data(withJSONObject: historyData)
                        let decoder = JSONDecoder()
                        let items = try decoder.decode([ActivationHistory].self, from: historyJson)
                        return Just(items).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else {
                        return Fail(error: APIError.decodingError).eraseToAnyPublisher()
                    }
                } catch {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Activation history decoding error: \(error)")
                        print("Raw JSON response: \(jsonString)")
                    }
                    return Fail(error: APIError.decodingError).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func clearActivationHistory() -> AnyPublisher<MessageResponse, APIError> {
        guard let request = createRequest("/activation-history/clear", method: "DELETE") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        return performRequest(request)
    }
}
