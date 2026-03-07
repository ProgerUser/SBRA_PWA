// SBRA PWA/Views/Main/CardActivationView.swift
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
                            .foregroundColor(Theme.textTertiary.opacity(0.3))
                        Text("ИЛИ")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Theme.textTertiary.opacity(0.3))
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
            .background(MeshBackground())
            .navigationTitle("Активация карт")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadHistory()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
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
                    withAnimation {
                        viewModel.processExcelFile(url: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError(error.localizedDescription)
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
            .toast(toast: $viewModel.toast)  // ИСПРАВЛЕНО: message: → toast:
        }
    }
}

struct SingleActivationSection: View {
    @Binding var cardNumber: String
    @ObservedObject var viewModel: CardActivationViewModel
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Активация одной карты", systemImage: "creditcard")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                
                VStack(spacing: 16) {
                    TextField("Введите номер карты", text: $cardNumber)
                        .textFieldStyle(ModernTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: cardNumber) { newValue in
                            cardNumber = newValue.formattedCardNumber()
                        }
                    
                    Button(action: {
                        let cleanNumber = cardNumber.replacingOccurrences(of: " ", with: "")
                        viewModel.activateSingleCard(cleanNumber)
                        cardNumber = ""
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Активировать карту")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(cardNumber.isEmpty || viewModel.isLoading)
                }
                
                Text("Номер карты будет автоматически очищен от пробелов")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

struct BatchActivationSection: View {
    @ObservedObject var viewModel: CardActivationViewModel
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Пакетная активация", systemImage: "doc.on.doc")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.info)
                    Text("Загрузите Excel файл с номерами карт в первом столбце")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding()
                .background(Theme.info.opacity(0.1))
                .cornerRadius(12)
                
                if let file = viewModel.selectedFile {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(Theme.primary)
                        Text(file.lastPathComponent)
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(viewModel.formatFileSize(file.fileSize))
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding()
                    .background(Theme.cardBackgroundSecondary)
                    .cornerRadius(12)
                    .transition(.slide.combined(with: .opacity))
                }
                
                HStack {
                    Button(action: { showingFilePicker = true }) {
                        Label("Выбрать файл", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    if viewModel.selectedFile != nil {
                        Button(action: {
                            withAnimation {
                                viewModel.processSelectedFile()
                            }
                        }) {
                            if viewModel.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Загрузить", systemImage: "arrow.up.doc")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(viewModel.isUploading)
                        
                        Button(action: {
                            withAnimation {
                                viewModel.clearSelectedFile()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Theme.cardBackground)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

struct ActivationResultView: View {
    let result: BatchActivationResult
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Результаты активации", systemImage: "chart.bar.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                
                HStack(spacing: 12) {
                    ResultCard(
                        title: "Всего",
                        value: result.total,
                        color: Theme.info
                    )
                    
                    ResultCard(
                        title: "Успешно",
                        value: result.success,
                        color: Theme.success
                    )
                    
                    ResultCard(
                        title: "Ошибки",
                        value: result.failed,
                        color: Theme.danger
                    )
                }
                
                if !result.results.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 12) {
                            ForEach(result.results.indices, id: \.self) { index in
                                let item = result.results[index]
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.cardNumber)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(item.success ? Theme.success : Theme.danger)
                                            .font(.title3)
                                    }
                                    
                                    if !item.message.isEmpty {
                                        Text(item.message)
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    if let details = item.details, let code = details.responseCode {
                                        Text("Код ответа: \(code)")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    
                                    if index < result.results.count - 1 {
                                        Divider()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } label: {
                        Text("Показать детали (\(result.results.count))")
                            .font(.subheadline)
                            .foregroundColor(Theme.primary)
                    }
                }
            }
        }
    }
}

struct ResultCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct ActivationHistoryView: View {
    @ObservedObject var viewModel: CardActivationViewModel
    @State private var showingFilters = false
    @State private var showingClearHistoryConfirmation = false
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("История активаций", systemImage: "clock.arrow.circlepath")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showingFilters.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(Theme.primary)
                    }
                    
                    Button(action: {
                        showingClearHistoryConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(Theme.danger)
                    }
                }
                
                if showingFilters {
                    HistoryFiltersView(viewModel: viewModel)
                }
                
                if viewModel.isLoadingHistory {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Theme.primary)
                        Spacer()
                    }
                    .padding()
                } else if viewModel.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.largeTitle)
                            .foregroundColor(Theme.textTertiary)
                        Text("Нет истории активаций")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Text("Найдено записей: \(viewModel.history.count)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.history) { item in
                            HistoryActivationRow(item: item)
                            
                            if item.id != viewModel.history.last?.id {
                                Divider()
                            }
                        }
                    }
                }
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
    }
}

struct HistoryFiltersView: View {
    @ObservedObject var viewModel: CardActivationViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            DatePicker("С", selection: $viewModel.filterStartDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundColor(Theme.textPrimary)
            
            DatePicker("По", selection: $viewModel.filterEndDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundColor(Theme.textPrimary)
            
            HStack {
                Button("Сегодня") {
                    withAnimation {
                        viewModel.setFilterToday()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("7 дней") {
                    withAnimation {
                        viewModel.setFilterWeek()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Очистить >30 дней") {
                    withAnimation {
                        viewModel.cleanupHistory(days: 30)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .foregroundColor(Theme.warning)
            }
            
            Button("Применить фильтры") {
                viewModel.loadHistory()
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding()
        .background(Theme.cardBackgroundSecondary.opacity(0.5))
        .cornerRadius(16)
    }
}

struct HistoryActivationRow: View {
    let item: ActivationHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.formattedDate)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text(item.success == 1 ? "Успех" : "Ошибка")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.success == 1 ? Theme.success.opacity(0.1) : Theme.danger.opacity(0.1))
                    .foregroundColor(item.success == 1 ? Theme.success : Theme.danger)
                    .cornerRadius(8)
            }
            
            Text(item.cardNumber ?? item.cleanCard ?? "—")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            
            if let message = item.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }
            
            if let details = item.details, let code = details.responseCode {
                Text("Код: \(code)")
                    .font(.caption2)
                    .foregroundColor(Theme.info)
            }
        }
        .padding(.vertical, 8)
    }
}
