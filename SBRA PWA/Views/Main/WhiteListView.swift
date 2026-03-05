import SwiftUI
import UniformTypeIdentifiers

struct WhiteListView: View {
    @StateObject private var viewModel = WhiteListViewModel()
    @State private var searchText = ""
    @State private var selectedGroup = "Все"
    @State private var showAddCardSheet = false
    @State private var showImportSheet = false
    
    // For adding single card
    @State private var newCardNum = ""
    @State private var newGroup = ""
    
    // Deletion confirmation
    @State private var showingDeleteConfirmation = false
    @State private var cardToDelete: WhiteListCard?
    
    // For file import
    @State private var showFilePicker = false
    
    var filteredCards: [WhiteListCard] {
        viewModel.cards.filter { card in
            let matchesSearch = searchText.isEmpty || card.cardNum.contains(searchText)
            let matchesGroup = selectedGroup == "Все" || card.typeCon == selectedGroup
            return matchesSearch && matchesGroup
        }
    }
    
    var groups: [String] {
        let allGroups = Set(viewModel.cards.map { $0.typeCon })
        return ["Все"] + allGroups.sorted()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search and Filter
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Поиск по номеру карты", text: $searchText)
                                .keyboardType(.numberPad)
                                .onChange(of: searchText) { newValue in
                                    searchText = newValue.formattedCardNumber()
                                }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(groups, id: \.self) { group in
                                    FilterButton(title: group, isSelected: selectedGroup == group) {
                                        selectedGroup = group
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    if viewModel.isLoading && viewModel.cards.isEmpty {
                        Spacer()
                        ProgressView("Загрузка...")
                        Spacer()
                    } else if filteredCards.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "creditcard.and.123")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Карт не найдено")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Button(action: { viewModel.loadCards() }) {
                                Label("Обновить", systemImage: "arrow.clockwise")
                            }
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filteredCards) { card in
                                WhiteListCardRow(card: card) {
                                    cardToDelete = card
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        .refreshable {
                            viewModel.loadCards()
                        }
                    }
                }
            }
            .navigationTitle("Белый список")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showAddCardSheet = true }) {
                            Label("Добавить карту", systemImage: "plus")
                        }
                        Button(action: { showFilePicker = true }) {
                            Label("Импорт из Excel", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            // Add Single Card Sheet
            .sheet(isPresented: $showAddCardSheet) {
                NavigationView {
                    VStack(spacing: 0) {
                        Form {
                            Section(header: Text("Данные карты")) {
                                TextField("Номер карты", text: $newCardNum)
                                    .keyboardType(.numberPad)
                                    .onChange(of: newCardNum) { newValue in
                                        newCardNum = newValue.formattedCardNumber()
                                    }
                                TextField("Тип/Группа", text: $newGroup)
                            }
                        }
                        
                        Button(action: {
                            let cleanNumber = newCardNum.replacingOccurrences(of: " ", with: "")
                            viewModel.addSingleCard(cardNum: cleanNumber, typeCon: newGroup)
                            newCardNum = ""
                            newGroup = ""
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Добавить в белый список")
                                    .frame(maxWidth: .infinity)
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding()
                        .disabled(newCardNum.isEmpty || newGroup.isEmpty || viewModel.isLoading)
                    }
                    .navigationTitle("Новая карта")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { showAddCardSheet = false }
                        }
                    }
                    .onReceive(viewModel.successPublisher) { _ in
                        showAddCardSheet = false
                    }
                    .alert("Ошибка", isPresented: Binding(
                        get: { viewModel.errorMessage != nil },
                        set: { if !$0 { viewModel.errorMessage = nil } }
                    )) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(viewModel.errorMessage ?? "")
                    }
                }
            }
            // File Picker
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.spreadsheet, .commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.uploadWhiteListFile(fileURL: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            // Error Alert
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil && !showAddCardSheet },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Удаление карты", isPresented: $showingDeleteConfirmation) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    if let card = cardToDelete {
                        viewModel.deleteCard(cardNum: card.cardNum)
                    }
                }
            } message: {
                Text("Вы уверены, что хотите удалить карту \(cardToDelete?.cardNum ?? "") из белого списка?")
            }
            .toast(message: $viewModel.toastMessage)
        }
    }
}

struct WhiteListCardRow: View {
    let card: WhiteListCard
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardNum)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(card.typeCon)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// Reuse FilterButton or define here if not global
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct WhiteListView_Previews: PreviewProvider {
    static var previews: some View {
        WhiteListView()
    }
}
