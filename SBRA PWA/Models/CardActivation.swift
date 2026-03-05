import Foundation

struct CardActivationResult: Codable {
    let success: Bool
    let cardNumber: String
    let message: String
    let details: ActivationDetails?
    let cleanCard: String?
    let cardId: String?
    
    enum CodingKeys: String, CodingKey {
        case success = "SUCCESS"
        case cardNumber = "CARD_NUMBER"
        case message = "MESSAGE"
        case details = "DETAILS"
        case cleanCard = "CLEAN_CARD"
        case cardId = "CARD_ID"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingAnyKey.self)
        
        // Helper to try multiple keys
        func decodeAny<T: Decodable>(_ type: T.Type, keys: [String]) -> T? {
            for key in keys {
                if let val = try? container.decode(T.self, forKey: DecodingAnyKey(stringValue: key)!) {
                    return val
                }
            }
            return nil
        }
        
        // Success: try SUCCESS, success
        if let boolSuccess = decodeAny(Bool.self, keys: ["SUCCESS", "success"]) {
            success = boolSuccess
        } else if let intSuccess = decodeAny(Int.self, keys: ["SUCCESS", "success"]) {
            success = intSuccess != 0
        } else if let stringSuccess = decodeAny(String.self, keys: ["SUCCESS", "success"]) {
            success = (stringSuccess.lowercased() == "true" || stringSuccess == "1" || stringSuccess.lowercased() == "success")
        } else {
            success = false
        }
        
        cardNumber = decodeAny(String.self, keys: ["CARD_NUMBER", "card_number"]) ?? ""
        message = decodeAny(String.self, keys: ["MESSAGE", "message"]) ?? ""
        details = decodeAny(ActivationDetails.self, keys: ["DETAILS", "details"])
        cleanCard = decodeAny(String.self, keys: ["CLEAN_CARD", "clean_card"])
        cardId = decodeAny(String.self, keys: ["CARD_ID", "card_id"])
    }
}

struct ActivationDetails: Codable {
    let responseCode: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingAnyKey.self)
        responseCode = try? container.decode(String.self, forKey: DecodingAnyKey(stringValue: "RESPONSE_CODE")!) ?? 
                       container.decode(String.self, forKey: DecodingAnyKey(stringValue: "response_code")!)
    }
}

struct BatchActivationResult: Codable {
    let total: Int
    let success: Int
    let failed: Int
    let results: [CardActivationResult]
    
    enum CodingKeys: String, CodingKey {
        case total = "TOTAL"
        case success = "SUCCESS"
        case failed = "FAILED"
        case results = "RESULTS"
    }
    
    init(total: Int, success: Int, failed: Int, results: [CardActivationResult]) {
        self.total = total
        self.success = success
        self.failed = failed
        self.results = results
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingAnyKey.self)
        
        func decodeInt(keys: [String]) -> Int {
            for key in keys {
                let anyKey = DecodingAnyKey(stringValue: key)!
                if let val = try? container.decode(Int.self, forKey: anyKey) { return val }
                if let str = try? container.decode(String.self, forKey: anyKey), let val = Int(str) { return val }
            }
            return 0
        }
        
        total = decodeInt(keys: ["TOTAL", "total"])
        success = decodeInt(keys: ["SUCCESS", "success"])
        failed = decodeInt(keys: ["FAILED", "failed"])
        results = (try? container.decode([CardActivationResult].self, forKey: DecodingAnyKey(stringValue: "RESULTS")!)) ?? 
                  (try? container.decode([CardActivationResult].self, forKey: DecodingAnyKey(stringValue: "results")!)) ?? []
    }
}

// AnyKey helper for dynamic keys
struct DecodingAnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}

struct ActivationHistory: Codable, Identifiable {
    let id: Int?
    let cardNumber: String?
    let cleanCard: String?
    let cardId: String?
    let success: Int
    let message: String?
    let details: ActivationDetails?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case cardNumber = "CARD_NUMBER"
        case cleanCard = "CLEAN_CARD"
        case cardId = "CARD_ID"
        case success = "SUCCESS"
        case message = "MESSAGE"
        case details = "DETAILS"
        case createdAt = "CREATED_AT"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingAnyKey.self)
        
        func decodeAny<T: Decodable>(_ type: T.Type, keys: [String]) -> T? {
            for key in keys {
                if let val = try? container.decode(T.self, forKey: DecodingAnyKey(stringValue: key)!) {
                    return val
                }
            }
            return nil
        }
        
        // ID
        if let intId = decodeAny(Int.self, keys: ["ID", "id"]) {
            id = intId
        } else if let stringId = decodeAny(String.self, keys: ["ID", "id"]), let intId = Int(stringId) {
            id = intId
        } else {
            id = nil
        }
        
        cardNumber = decodeAny(String.self, keys: ["CARD_NUMBER", "card_number"])
        cleanCard = decodeAny(String.self, keys: ["CLEAN_CARD", "clean_card"])
        cardId = decodeAny(String.self, keys: ["CARD_ID", "card_id"])
        
        // Success
        if let intSuccess = decodeAny(Int.self, keys: ["SUCCESS", "success"]) {
            success = intSuccess
        } else if let stringSuccess = decodeAny(String.self, keys: ["SUCCESS", "success"]), let intSuccess = Int(stringSuccess) {
            success = intSuccess
        } else {
            success = 0
        }
        
        message = decodeAny(String.self, keys: ["MESSAGE", "message"])
        details = decodeAny(ActivationDetails.self, keys: ["DETAILS", "details"])
        createdAt = decodeAny(String.self, keys: ["CREATED_AT", "created_at"]) ?? ""
    }
    
    var idValue: String { "\(id ?? 0)-\(createdAt)" }
}
