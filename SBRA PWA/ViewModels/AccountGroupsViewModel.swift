// SBRA PWA/ViewModels/AccountGroupsViewModel.swift
import Foundation
import Combine
import SwiftUI

class AccountGroupsViewModel: ObservableObject, ToastCapable {
    @Published var groups: [AccountGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published var formError: String?
    @Published var selectedGroup: AccountGroup?
    @Published var isEditing = false
    
    let successPublisher = PassthroughSubject<Void, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    init() {
        loadGroups()
    }
    
    func loadGroups() {
        errorMessage = nil
        isLoading = true
        apiService.getAccountGroups()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] groups in
                self?.groups = groups
            }
            .store(in: &cancellables)
    }
    
    func createGroup(accNum: String, grpName: String) {
        errorMessage = nil
        isLoading = true
        apiService.createAccountGroup(accNum: accNum, grpName: grpName)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.showError(error.localizedDescription)
                }
            } receiveValue: { [weak self] _ in
                self?.showSuccess("Группа успешно создана")
                self?.successPublisher.send()
                self?.loadGroups()
            }
            .store(in: &cancellables)
    }
    
    func updateGroup(oldAccNum: String, newAccNum: String, grpName: String) {
        errorMessage = nil
        isLoading = true
        apiService.updateAccountGroup(accNum: oldAccNum, newAccNum: newAccNum, grpName: grpName)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.showError(error.localizedDescription)
                }
            } receiveValue: { [weak self] _ in
                self?.showSuccess("Группа успешно обновлена")
                self?.successPublisher.send()
                self?.loadGroups()
            }
            .store(in: &cancellables)
    }
    
    func deleteGroup(_ group: AccountGroup) {
        errorMessage = nil
        isLoading = true
        apiService.deleteAccountGroup(accNum: group.accNum)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.showError(error.localizedDescription)
                }
            } receiveValue: { [weak self] _ in
                self?.showSuccess("Группа успешно удалена")
                self?.successPublisher.send()
                self?.loadGroups()
            }
            .store(in: &cancellables)
    }
    
    func filteredGroups(_ searchText: String) -> [AccountGroup] {
        if searchText.isEmpty {
            return groups
        }
        return groups.filter {
            $0.accNum.localizedCaseInsensitiveContains(searchText) ||
            $0.grpName.localizedCaseInsensitiveContains(searchText)
        }
    }
}
