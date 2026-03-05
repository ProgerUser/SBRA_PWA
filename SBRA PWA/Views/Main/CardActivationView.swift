import SwiftUI
import UniformTypeIdentifiers

struct CardActivationView: View {
    @StateObject private var viewModel = CardActivationViewModel()
    @State private var showingFilePicker = false
    @State private var cardNumber = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Активация одной карты
                    SingleActivationSection(
                        cardNumber: $cardNumber,
                        viewModel: viewModel
                    )
                    
                    // Разделитель
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("ИЛИ")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal)
                    
                    // Пакетная активация
                    BatchActivationSection(
                        viewModel: viewModel,
                        showingFilePicker: $showingFilePicker
                    )
                    
                    // Результаты
                    if let result = viewModel.activationResult {
                        ActivationResultView(result: result)
                    }
                    
                    // История активаций
                    ActivationHistoryView(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Активация карт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadHistory()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.excel],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.processExcelFile(url: url)
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
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
            .toast(message: $viewModel.toastMessage)
        }
    }
}

struct SingleActivationSection: View {
    @Binding var cardNumber: String
    @ObservedObject var viewModel: CardActivationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Активация одной карты")
                .font(.headline)
            
            VStack(spacing: 16) {
                TextField("Введите номер карты", text: $cardNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                
                Button(action: {
                    let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
                    viewModel.activateSingleCard(cleanNumber)
                    cardNumber = ""
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Активировать карту")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(cardNumber.isEmpty || viewModel.isLoading)
            }
            .onChange(of: cardNumber) { newValue in
                cardNumber = newValue.formattedCardNumber()
            }
            
            Text("Номер карты будет автоматически очищен от пробелов")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

struct BatchActivationSection: View {
    @ObservedObject var viewModel: CardActivationViewModel
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Пакетная активация из Excel")
                .font(.headline)
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Загрузите Excel файл с номерами карт в первом столбце")
                    .font(.caption)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            if let file = viewModel.selectedFile {
                HStack {
                    Image(systemName: "doc")
                    Text(file.lastPathComponent)
                    Spacer()
                    Text(viewModel.formatFileSize(file.fileSize))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack {
                Button(action: { showingFilePicker = true }) {
                    Label("Выбрать файл", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if viewModel.selectedFile != nil {
                    Button(action: {
                        viewModel.processSelectedFile()
                    }) {
                        if viewModel.isUploading {
                            ProgressView()
                        } else {
                            Label("Загрузить", systemImage: "arrow.up.doc")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isUploading)
                    
                    Button(action: {
                        viewModel.clearSelectedFile()
                    }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

struct ActivationResultView: View {
    let result: BatchActivationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результаты активации")
                .font(.headline)
            
            HStack {
                ResultCard(title: "Всего", value: result.total, color: .blue)
                ResultCard(title: "Успешно", value: result.success, color: .green)
                ResultCard(title: "Ошибки", value: result.failed, color: .red)
            }
            
            if !result.results.isEmpty {
                DisclosureGroup("Детали") {
                    ForEach(result.results.indices, id: \.self) { index in
                        let item = result.results[index]
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.cardNumber)
                                    .font(.caption)
                                    .font(.system(.caption, design: .monospaced))
                                
                                Spacer()
                                
                                Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(item.success ? .green : .red)
                            }
                            
                            Text(item.message)
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            if let details = item.details, let code = details.responseCode {
                                Text("Код: \(code)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            if index < result.results.count - 1 {
                                Divider()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

struct ResultCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ActivationHistoryView: View {
    @ObservedObject var viewModel: CardActivationViewModel
    @State private var showingFilters = false
    @State private var showingClearHistoryConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("История активаций")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingFilters.toggle() }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                
                Button(action: {
                    showingClearHistoryConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .alert("Очистка истории", isPresented: $showingClearHistoryConfirmation) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    viewModel.clearHistory()
                }
            } message: {
                Text("Вы уверены, что хотите полностью очистить историю активаций?")
            }
            
            if showingFilters {
                HistoryFiltersView(viewModel: viewModel)
            }
            
            if viewModel.isLoadingHistory {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if viewModel.history.isEmpty {
                Text("Нет истории активаций")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("Найдено записей: \(viewModel.history.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                ForEach(viewModel.history) { item in
                    HistoryActivationRow(item: item)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
}

struct HistoryFiltersView: View {
    @ObservedObject var viewModel: CardActivationViewModel
    
    var body: some View {
        VStack {
            DatePicker("С", selection: $viewModel.filterStartDate, displayedComponents: .date)
            DatePicker("По", selection: $viewModel.filterEndDate, displayedComponents: .date)
            
            HStack {
                Button("Сегодня") {
                    viewModel.setFilterToday()
                }
                .buttonStyle(.bordered)
                
                Button("7 дней") {
                    viewModel.setFilterWeek()
                }
                .buttonStyle(.bordered)
                
                Button("Очистить старше 30 дней") {
                    viewModel.cleanupHistory(days: 30)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
            
            Button("Применить") {
                viewModel.loadHistory()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HistoryActivationRow: View {
    let item: ActivationHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(item.success == 1 ? "Успех" : "Ошибка")
                    .font(.caption2)
                    .padding(4)
                    .background(item.success == 1 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(item.success == 1 ? .green : .red)
                    .cornerRadius(4)
            }
            
            Text(item.cardNumber ?? item.cleanCard ?? "")
                .font(.subheadline)
                .font(.system(.subheadline, design: .monospaced))
            
            if let message = item.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if let details = item.details, let code = details.responseCode {
                Text("Код: \(code)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}
