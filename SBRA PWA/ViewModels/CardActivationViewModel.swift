// SBRA PWA/ViewModels/CardActivationViewModel.swift
import Foundation
import Combine
import UniformTypeIdentifiers

class CardActivationViewModel: ObservableObject, ToastCapable {
    @Published var activationResult: BatchActivationResult?
    @Published var history: [ActivationHistory] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var isLoadingHistory = false
    @Published var errorMessage: String?
    @Published var selectedFile: URL?
    @Published var toast: Toast?  // Изменено с toastMessage
    
    // Фильтры
    @Published var filterStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var filterEndDate = Date()
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    let successPublisher = PassthroughSubject<Void, Never>()
    
    init() {
        loadHistory()
    }
    
    func activateSingleCard(_ cardNumber: String) {
        errorMessage = nil
        isLoading = true
        
        apiService.activateSingleCard(cardNumber: cardNumber)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.showError(error.localizedDescription)
                }
            } receiveValue: { [weak self] result in
                let batchResult = BatchActivationResult(
                    total: 1,
                    success: result.success ? 1 : 0,
                    failed: result.success ? 0 : 1,
                    results: [result]
                )
                self?.activationResult = batchResult
                let displayMessage = result.success ? "Карта успешно активирована" : (result.message.isEmpty ? "Ошибка активации" : result.message)
                
                if result.success {
                    self?.showSuccess(displayMessage)
                    HapticManager.shared.success()
                } else {
                    self?.showError(displayMessage)
                    HapticManager.shared.warning()
                }
                
                self?.successPublisher.send()
                self?.loadHistory()
            }
            .store(in: &cancellables)
    }
    
    func processExcelFile(url: URL) {
        self.selectedFile = url
    }
    
    func processSelectedFile() {
        guard let fileURL = selectedFile else { return }
        
        errorMessage = nil
        isUploading = true
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            
            apiService.uploadActivationFile(fileData: fileData, fileName: fileURL.lastPathComponent)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    self?.isUploading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.showError(error.localizedDescription)
                    }
                } receiveValue: { [weak self] result in
                    self?.activationResult = result
                    self?.selectedFile = nil
                    self?.showSuccess("Файл обработан. Успешно: \(result.success)")
                    self?.successPublisher.send()
                    self?.loadHistory()
                }
                .store(in: &cancellables)
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            showError(error.localizedDescription)
        }
    }
    
    func clearSelectedFile() {
        selectedFile = nil
    }
    
    func loadHistory() {
        errorMessage = nil
        isLoadingHistory = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateStr = dateFormatter.string(from: filterStartDate)
        let endDateStr = dateFormatter.string(from: filterEndDate)
        
        apiService.getActivationHistory(startDate: startDateStr, endDate: endDateStr)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingHistory = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.showError(error.localizedDescription)
                }
            } receiveValue: { [weak self] history in
                self?.history = history
            }
            .store(in: &cancellables)
    }
    
    func clearHistory() {
        errorMessage = nil
        apiService.clearActivationHistory()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.showError(error.localizedDescription)
                }
            } receiveValue: { [weak self] _ in
                self?.showSuccess("История очищена")
                self?.loadHistory()
            }
            .store(in: &cancellables)
    }
    
    func cleanupHistory(days: Int) {
        // Реализация очистки старше N дней
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Фильтруем историю, оставляя только записи новее cutoffDate
        history = history.filter { item in
            let dateFormatter = ISO8601DateFormatter()
            guard let itemDate = dateFormatter.date(from: item.createdAt) else { return true }
            return itemDate > cutoffDate
        }
        
        showSuccess("История очищена от записей старше \(days) дней")
    }
    
    func setFilterToday() {
        filterStartDate = Date()
        filterEndDate = Date()
        loadHistory()
    }
    
    func setFilterWeek() {
        filterStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        filterEndDate = Date()
        loadHistory()
    }
    
    func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
