import Foundation
import Combine
import UIKit

class HistoryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    @Published var paginatedItems: [HistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var availableGroups: [String] = []
    
    // Фильтры
    @Published var selectedGroup = ""
    @Published var startDate = Date()
    @Published var endDate = Date()
    @Published var daysBack = 7
    
    // Пагинация
    @Published var currentPage = 1
    @Published var itemsPerPage = 20
    @Published var totalPages = 1
    
    // Статистика
    struct Stats {
        let recordCount: Int
        let totalSum: Double
        var formattedTotal: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.groupingSeparator = " "
            return formatter.string(from: NSNumber(value: totalSum)) ?? "\(totalSum)"
        }
    }
    @Published var stats: Stats?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        loadAvailableGroups()
        resetFilters()
    }
    
    func loadAvailableGroups() {
        apiService.getAvailableGroups()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] groups in
                self?.availableGroups = groups
            }
            .store(in: &cancellables)
    }
    
    func loadHistory() {
        isLoading = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)
        
        apiService.getProcessingHistory(
            groupName: selectedGroup.isEmpty ? nil : selectedGroup,
            startDate: startDateStr,
            endDate: endDateStr,
            daysBack: daysBack
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] items in
            self?.processHistoryItems(items)
        }
        .store(in: &cancellables)
    }
    
    private func processHistoryItems(_ items: [HistoryItem]) {
        var totalSum: Double = 0
        
        for item in items {
            totalSum += item.paymentSum
        }
        
        self.historyItems = items
        self.stats = Stats(recordCount: items.count, totalSum: totalSum)
        self.totalPages = max(1, Int(ceil(Double(items.count) / Double(itemsPerPage))))
        self.currentPage = 1
        updatePaginatedItems()
    }
    
    func updatePaginatedItems() {
        let startIndex = (currentPage - 1) * itemsPerPage
        guard startIndex < historyItems.count else {
            paginatedItems = []
            return
        }
        
        let endIndex = min(startIndex + itemsPerPage, historyItems.count)
        paginatedItems = Array(historyItems[startIndex..<endIndex])
    }
    
    func applyFilters() {
        currentPage = 1
        loadHistory()
    }
    
    func resetFilters() {
        startDate = Date()
        endDate = Date()
        selectedGroup = ""
        daysBack = 1
        applyFilters()
    }
    
    func updateDatesFromPeriod() {
        let calendar = Calendar.current
        endDate = Date()
        // Если выбрано 1 день, то это сегодня (0 дней назад от сегодня)
        // Но для логов обычно 1 день это и есть сегодня.
        // Если API ожидает количество дней, то для "сегодня" это 1.
        startDate = calendar.date(byAdding: .day, value: -(daysBack - 1), to: Date()) ?? Date()
        applyFilters()
    }
    
    func nextPage() {
        if currentPage < totalPages {
            currentPage += 1
            updatePaginatedItems()
        }
    }
    
    func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            updatePaginatedItems()
        }
    }
    
    func exportToExcel() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        let sDate = df.string(from: startDate)
        let eDate = df.string(from: endDate)
        let gName = selectedGroup.isEmpty ? nil : selectedGroup
        
        guard let url = apiService.getExportHistoryExcelURL(groupName: gName, startDate: sDate, endDate: eDate, daysBack: daysBack) else {
            self.errorMessage = "Не удалось сформировать ссылку для экспорта"
            return
        }
        
        var request = URLRequest(url: url)
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        isLoading = true
        apiService.downloadFile(request: request) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Не удалось загрузить файл"
                }
                return
            }
            
            // Копируем файл в постоянное временное хранилище с правильным расширением
            let fileName = "history_export.xlsx"
            let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = rootVC.view
                            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }
                        
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Ошибка при сохранении файла: \(error.localizedDescription)"
                }
            }
        }
    }
}
