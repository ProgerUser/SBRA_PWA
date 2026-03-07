import SwiftUI

struct AccountGroupsView: View {
    @StateObject private var viewModel = AccountGroupsViewModel()
    @State private var showingAddModal = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Поиск
                SearchBar(text: $searchText, placeholder: "Поиск по счету или группе")
                    .padding(.horizontal)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.groups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Нет записей")
                            .foregroundColor(.gray)
                        Button("Добавить первую запись") {
                            showingAddModal = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Группы счетов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            viewModel.loadGroups()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            viewModel.selectedGroup = nil
                            viewModel.isEditing = false
                            showingAddModal = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddModal) {
                AccountGroupModal(viewModel: viewModel, isPresented: $showingAddModal)
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil && !showingAddModal },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .toast(message: $viewModel.toastMessage)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct AccountGroupRow: View {
    let group: AccountGroup
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.accNum)
                    .font(.headline)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text(group.grpName)
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
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
            VStack(spacing: 0) {
                Form {
                    Section(header: Text("Данные")) {
                        TextField("Номер счета", text: $accNum)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Группа (STREAM_%)", text: $grpName)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: grpName) { newValue in
                                grpName = newValue.uppercased()
                            }
                    }
                    
                    if let error = viewModel.formError {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        Text("Группа должна быть в формате STREAM_% и содержать только заглавные буквы, цифры и _")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if viewModel.isEditing {
                        Section {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "trash")
                                    Text("Удалить счет")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .disabled(accNum.isEmpty || grpName.isEmpty || !validateGroupName(grpName) || viewModel.isLoading)
            }
            .navigationTitle(viewModel.isEditing ? "Редактирование" : "Добавление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold)) // Жирная и стрелка
                        }
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
