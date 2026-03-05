import Foundation

struct Constants {
    static let baseURL = "https://10.111.170.74:5500" // Замените на ваш URL
    
    struct API {
        static let token = "/token"
        static let availableProcessings = "/available-processings"
        static let executeProcessing = "/execute-processing"
        static let userTasks = "/user-tasks"
        static let taskStatus = "/task-status"
        static let reports = "/reports"
        static let downloadReport = "/download-report"
        static let processingHistory = "/processing-history"
        static let availableGroups = "/available-groups"
        static let accountGroups = "/account-groups"
        static let checkAccountExists = "/check-account-exists"
        static let uploadExcel = "/upload-excel-file"
        static let ruslanCardCount = "/ruslan-card-count"
        static let balanceReport = "/balance-report"
        static let activateCard = "/activate-card"
        static let activateCardsExcel = "/activate-cards-excel"
        static let activationHistory = "/activation-history"
        static let clearActivationHistory = "/activation-history/clear"
        static let health = "/health"
    }
    
    struct UserDefaults {
        static let username = "username"
    }
    
    struct Notifications {
        static let sessionExpired = "sessionExpired"
    }
}
