// SBRA PWA/Views/Main/WhiteListView.swift (исправляем toast)
import SwiftUI
import UniformTypeIdentifiers

struct WhiteListView: View {
    @StateObject private var viewModel = WhiteListViewModel()
    @State private var searchText = ""
    @State private var selectedGroup = "Все"
    @State private var showAddCardSheet = false
    @State private var showImportSheet = false
    
    @State private var newCardNum = ""
    @State private var newGroup = ""
    @State private var showingDeleteConfirmation = false
    @State private var cardToDelete: WhiteListCard?
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
                MeshBackground()
                
                VStack(spacing: 0) {
                    // Search and Filter
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.textSecondary)
                            TextField("Поиск по номеру карты", text: $searchText)
                                .keyboardType(.numberPad)
                                .onChange(of: searchText) { newValue in
                                    searchText = newValue.formattedCardNumber()
                                }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.cardBackground.opacity(0.8))
                        )
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(groups, id: \.self) { group in
                                    FilterButton(title: group, isSelected: selectedGroup == group) {
                                        withAnimation {
                                            selectedGroup = group
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    
                    if viewModel.isLoading && viewModel.cards.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(Theme.primary)
                        Spacer()
                    } else if filteredCards.isEmpty {
                        EmptyStateView(
                            icon: "creditcard.and.123",
                            title: "Карт не найдено",
                            message: "Добавьте карты в белый список",
                            buttonTitle: "Обновить",
                            action: { viewModel.loadCards() }
                        )
                    } else {
                        List {
                            ForEach(filteredCards) { card in
                                WhiteListCardRow(card: card) {
                                    cardToDelete = card
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        .refreshable {
                            viewModel.loadCards()
                        }
                    }
                }
            }
            .navigationTitle("Белый список")
            .navigationBarTitleDisplayMode(.large)
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
                            .foregroundColor(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddCardSheet) {
                AddCardSheet(viewModel: viewModel, isPresented: $showAddCardSheet)
            }
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
            .toast(toast: $viewModel.toast) // ИСПРАВЛЕНО
        }
    }
}

struct AddCardSheet: View {
    @ObservedObject var viewModel: WhiteListViewModel
    @Binding var isPresented: Bool
    @State private var newCardNum = ""
    @State private var newGroup = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                MeshBackground()
                
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Номер карты")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                TextField("Введите номер карты", text: $newCardNum)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: newCardNum) { newValue in
                                        newCardNum = newValue.formattedCardNumber()
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Группа")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                TextField("STREAM_%", text: $newGroup)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                        }
                        .padding()
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
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(newCardNum.isEmpty || newGroup.isEmpty || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("Новая карта")
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
        }
    }
}

struct WhiteListCardRow: View {
    let card: WhiteListCard
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Иконка
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.primary.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "creditcard")
                        .foregroundColor(Theme.primary)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardNum)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                
                Text(card.typeCon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary.opacity(0.1))
                    .foregroundColor(Theme.primary)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(Theme.danger)
                    .font(.headline)
            }
            .buttonStyle(PlainButtonStyle())
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
                .background(isSelected ? Theme.primary : Theme.cardBackground.opacity(0.8))
                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Theme.textTertiary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
