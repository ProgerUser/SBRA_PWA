import Foundation
import Combine
import UIKit
import UniformTypeIdentifiers

class ProcessingViewModel: ObservableObject {
    @Published var processings: [AvailableProcessing] = []
    @Published var selectedProcessing: AvailableProcessing?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFile: URL?
    @Published var isUploading = false
    @Published var uploadResult: UploadResult?
    @Published var availableGroups: [String] = []
    @Published var cardCount: Int?
    @Published var toastMessage: String?
    
    let successPublisher = PassthroughSubject<Void, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    struct UploadResult {
        let success: Bool
        let message: String
        let cardCount: Int?
    }
    
    init() {
        loadProcessings()
        loadAvailableGroups()
    }
    
    func loadProcessings() {
        errorMessage = nil
        isLoading = true
        apiService.getAvailableProcessings()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] processings in
                self?.processings = processings
            }
            .store(in: &cancellables)
    }
    
    func loadAvailableGroups() {
        apiService.getAvailableGroups()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] groups in
                self?.availableGroups = groups
            }
            .store(in: &cancellables)
    }
    
    func selectFile() {
        // Функция будет вызываться из UIKit
    }
    
    func handleSelectedFile(url: URL) {
        self.selectedFile = url
    }
    
    func uploadFile() {
        guard let fileURL = selectedFile else { return }
        
        errorMessage = nil
        isUploading = true
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            
            apiService.uploadRuslanFile(fileData: fileData, fileName: fileURL.lastPathComponent)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    self?.isUploading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.uploadResult = UploadResult(
                            success: false,
                            message: error.localizedDescription,
                            cardCount: nil
                        )
                    }
                } receiveValue: { [weak self] result in
                    self?.uploadResult = UploadResult(
                        success: true,
                        message: result.message,
                        cardCount: result.count
                    )
                    self?.selectedFile = nil
                    self?.checkCardCount()
                }
                .store(in: &cancellables)
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
        }
    }
    
    func checkCardCount() {
        apiService.getRuslanCardCount()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] count in
                self?.cardCount = count
            }
            .store(in: &cancellables)
    }
    
    func executeProcessing(parameters: String) {
        errorMessage = nil
        guard let processing = selectedProcessing else { return }
        
        let request = ProcessingRequest(
            processingType: processing.code,
            parameters: parameters.isEmpty ? nil : parameters
        )
        
        apiService.executeProcessing(request)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] _ in
                // Задача запущена
                self?.triggerToast("Задача успешно запущена")
                self?.successPublisher.send()
            }
            .store(in: &cancellables)
    }
    
    func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func triggerToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}
