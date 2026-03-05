import Foundation
import Combine
import UIKit

class BalanceReportViewModel: ObservableObject {
    @Published var items: [BalanceReportItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: String?
    
    @Published var summary: BalanceReportSummary?
    
    var totalSum: Double {
        summary?.totalSum ?? items.reduce(0) { $0 + $1.rest }
    }
    
    var cardsSum: Double {
        summary?.totalCards ?? items.filter { $0.type == "Карта" }.reduce(0) { $0 + $1.rest }
    }
    
    var accountsSum: Double {
        summary?.totalAccounts ?? items.filter { $0.type == "Счет" }.reduce(0) { $0 + $1.rest }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        loadReport()
    }
    
    func loadReport() {
        isLoading = true
        apiService.getDetailedBalanceReport()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.items = response.data
                self?.summary = response.summary
                self?.lastUpdated = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
            }
            .store(in: &cancellables)
    }
    
    func exportToExcel() {
        guard let url = apiService.getExportBalanceReportExcelURL() else {
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
            
            let fileName = "balance_report.xlsx"
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
