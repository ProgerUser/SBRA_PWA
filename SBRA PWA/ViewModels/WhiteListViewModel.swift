import Foundation
import Combine
import UIKit

class WhiteListViewModel: ObservableObject {
    @Published var cards: [WhiteListCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var successMessage: String?
    @Published var toastMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    let successPublisher = PassthroughSubject<Void, Never>()
    
    init() {
        loadCards()
    }
    
    func loadCards() {
        errorMessage = nil
        isLoading = true
        apiService.getWhiteListCards()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] cards in
                self?.cards = cards
            }
            .store(in: &cancellables)
    }
    
    func addSingleCard(cardNum: String, typeCon: String) {
        errorMessage = nil
        isLoading = true
        apiService.addSingleCardToWhiteList(cardNum: cardNum, typeCon: typeCon)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.triggerToast("Карта успешно добавлена")
                self?.successPublisher.send()
                self?.loadCards()
            }
            .store(in: &cancellables)
    }
    
    func uploadWhiteListFile(fileURL: URL) {
        guard let data = try? Data(contentsOf: fileURL) else {
            self.errorMessage = "Не удалось прочитать файл"
            return
        }
        
        errorMessage = nil
        isLoading = true
        apiService.addCardsToWhiteList(fileData: data, fileName: fileURL.lastPathComponent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.triggerToast("Файл успешно загружен. Обработано \(response.count ?? 0) карт")
                self?.successPublisher.send()
                self?.loadCards()
            }
            .store(in: &cancellables)
    }
    
    func deleteCard(cardNum: String) {
        errorMessage = nil
        isLoading = true
        apiService.deleteWhiteListCard(cardNum: cardNum)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] _ in
                self?.triggerToast("Карта успешно удалена")
                self?.loadCards()
            }
            .store(in: &cancellables)
    }
    
    func clearGroup(groupName: String) {
        errorMessage = nil
        isLoading = true
        apiService.clearWhiteListByGroup(groupName: groupName)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] _ in
                self?.triggerToast("Группа успешно очищена")
                self?.loadCards()
            }
            .store(in: &cancellables)
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
