import Foundation

struct ReportInfo: Codable, Identifiable {
    let filename: String
    let size: Int
    let created: String
    let modified: String
    
    var id: String { filename }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    var formattedDate: String {
        let dateFormatter = ISO8601DateFormatter()
        guard let date = dateFormatter.date(from: created) else { return created }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .short
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
}

// MARK: - Generic API Response Types

struct UploadResponse: Codable {
    let message: String
    let filename: String?
    let count: Int?
}

struct CountResponse: Codable {
    let count: Int
}

struct MessageResponse: Codable {
    let message: String
}

// MARK: - White List

struct WhiteListCard: Codable, Identifiable {
    let cardNum: String
    let typeCon: String
    let createdAt: String?
    
    var id: String { cardNum }
    
    enum CodingKeys: String, CodingKey {
        case cardNum = "CARD_NUM"
        case typeCon = "TYPE_CON"
        case createdAt = "CREATED_AT"
    }
}

struct WhiteListResponse: Codable {
    let success: Bool
    let cards: [WhiteListCard]
    let count: Int
}

// MARK: - Balance Report

struct BalanceReportItem: Codable, Identifiable {
    let type: String
    let groupName: String
    let rest: Double
    
    var id: String { "\(type)-\(groupName)" }
    
    enum CodingKeys: String, CodingKey {
        case type = "TYPE"
        case groupName = "GROUP_NAME"
        case rest = "REST"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        groupName = try container.decode(String.self, forKey: .groupName)
        
        if let doubleValue = try? container.decode(Double.self, forKey: .rest) {
            rest = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .rest),
                  let doubleValue = Double(stringValue) {
            rest = doubleValue
        } else {
            rest = 0.0 // Default value or throw error if preferred
        }
    }
    
    var formattedRest: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: rest)) ?? "\(rest)"
    }
}

struct BalanceReportSummary: Codable {
    let totalCards: Double
    let totalAccounts: Double
    let totalSum: Double
    let recordsCount: Int
    
    enum CodingKeys: String, CodingKey {
        case totalCards = "total_cards"
        case totalAccounts = "total_accounts"
        case totalSum = "total_sum"
        case recordsCount = "records_count"
    }
}

struct BalanceReportDetailedResponse: Codable {
    let data: [BalanceReportItem]
    let summary: BalanceReportSummary
    let generatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case data
        case summary
        case generatedAt = "generated_at"
    }
}

// MARK: - History Item

struct HistoryItem: Codable, Identifiable {
    let operDate: String
    let groupType: String
    let cardNum: String
    let accountNum: String?
    let paymentSum: Double
    let errorText: String?
    
    var id: String { "\(operDate)-\(cardNum)-\(paymentSum)" }
    
    enum CodingKeys: String, CodingKey {
        case operDate = "OPERDATE"
        case groupType = "GROUP_TYPE"
        case cardNum = "CARDNUM"
        case accountNum = "ACCOUNT_NUM"
        case paymentSum = "PAYMENT_SUM"
        case errorText = "ERROR_TEXT"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operDate = try container.decode(String.self, forKey: .operDate)
        groupType = try container.decode(String.self, forKey: .groupType)
        cardNum = try container.decode(String.self, forKey: .cardNum)
        accountNum = try container.decodeIfPresent(String.self, forKey: .accountNum)
        errorText = try container.decodeIfPresent(String.self, forKey: .errorText)
        
        if let doubleValue = try? container.decode(Double.self, forKey: .paymentSum) {
            paymentSum = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .paymentSum),
                  let doubleValue = Double(stringValue) {
            paymentSum = doubleValue
        } else {
            paymentSum = 0.0
        }
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: operDate) else { return operDate }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .short
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
    
    var formattedSum: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = "."
        return formatter.string(from: NSNumber(value: paymentSum)) ?? "\(paymentSum)"
    }
}
