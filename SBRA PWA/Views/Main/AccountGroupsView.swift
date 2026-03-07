// SBRA PWA/Views/Main/AccountGroupsView.swift
import SwiftUI

struct AccountGroupsView: View {
    @StateObject private var viewModel = AccountGroupsViewModel()
    @State private var showingAddModal = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                MeshBackground()
                
                VStack(spacing: 0) {
                    // Поиск
                    SearchBar(text: $searchText, placeholder: "Поиск по счету или группе")
                        .padding()
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Theme.primary)
                            .scaleEffect(1.2)
                        Spacer()
                    } else if viewModel.groups.isEmpty {
                        EmptyStateView(
                            icon: "folder",
                            title: "Нет записей",
                            message: "Добавьте первую группу счетов",
                            buttonTitle: "Добавить",
                            action: {
                                viewModel.selectedGroup = nil
                                viewModel.isEditing = false
                                showingAddModal = true
                            }
                        )
                    } else {
                        List {
                            ForEach(viewModel.filteredGroups(searchText)) { group in
                                Button(action: {
                                    viewModel.selectedGroup = group
                                    viewModel.isEditing = true
                                    showingAddModal = true
                                }) {
                                    AccountGroupRow(group: group)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        .refreshable {
                            await withAnimation {
                                viewModel.loadGroups()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Группы счетов")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            withAnimation {
                                viewModel.loadGroups()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                        }
                        
                        Button(action: {
                            viewModel.selectedGroup = nil
                            viewModel.isEditing = false
                            showingAddModal = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(Theme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddModal) {
                AccountGroupModal(viewModel: viewModel, isPresented: $showingAddModal)
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .toast(toast: $viewModel.toast)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
                .font(.subheadline)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.subheadline)
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                        .font(.subheadline)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct AccountGroupRow: View {
    let group: AccountGroup
    
    var body: some View {
        HStack {
            // Иконка
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.primary.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "folder")
                        .foregroundColor(Theme.primary)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.accNum)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Text(group.grpName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary.opacity(0.1))
                    .foregroundColor(Theme.primary)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct AccountGroupModal: View {
    @ObservedObject var viewModel: AccountGroupsViewModel
    @Binding var isPresented: Bool
    @State private var accNum = ""
    @State private var grpName = ""
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                MeshBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Поля ввода
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Номер счета")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("Введите номер счета", text: $accNum)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Группа (STREAM_%)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("STREAM_...", text: $grpName)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .autocapitalization(.allCharacters)
                                    .disableAutocorrection(true)
                                    .onChange(of: grpName) { newValue in
                                        grpName = newValue.uppercased()
                                    }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Theme.cardBackground.opacity(0.8))
                        )
                        
                        // Подсказка
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.info)
                            Text("Группа должна быть в формате STREAM_% и содержать только заглавные буквы, цифры и _")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding()
                        .background(Theme.info.opacity(0.1))
                        .cornerRadius(12)
                        
                        if viewModel.isEditing {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Удалить счет")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.red.opacity(0.1))
                                )
                                .foregroundColor(.red)
                            }
                        }
                        
                        Button(action: {
                            if viewModel.isEditing, let group = viewModel.selectedGroup {
                                viewModel.updateGroup(oldAccNum: group.accNum, newAccNum: accNum, grpName: grpName)
                            } else {
                                viewModel.createGroup(accNum: accNum, grpName: grpName)
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(viewModel.isEditing ? "Сохранить изменения" : "Создать группу")
                                    .frame(maxWidth: .infinity)
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(accNum.isEmpty || grpName.isEmpty || !validateGroupName(grpName) || viewModel.isLoading)
                    }
                    .padding()
                }
            }
            .navigationTitle(viewModel.isEditing ? "Редактирование" : "Добавление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .onReceive(viewModel.successPublisher) { _ in
                isPresented = false
            }
            .onAppear {
                if let group = viewModel.selectedGroup {
                    accNum = group.accNum
                    grpName = group.grpName
                }
            }
            .alert("Удаление счета", isPresented: $showingDeleteConfirmation) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    if let group = viewModel.selectedGroup {
                        viewModel.deleteGroup(group)
                    }
                }
            } message: {
                Text("Вы уверены, что хотите удалить этот счет из группы?")
            }
        }
    }
    
    private func validateGroupName(_ name: String) -> Bool {
        let pattern = "^STREAM_[A-Z0-9_]+$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: name)
    }
}
