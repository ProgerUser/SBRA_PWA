// SBRA PWA/Views/Main/BalanceReportView.swift
import SwiftUI
import Charts

struct BalanceReportView: View {
    @StateObject private var viewModel = BalanceReportViewModel()
    @State private var selectedChartType = 0
    @State private var showChart = true
    
    var body: some View {
        NavigationView {
            ZStack {
                MeshBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Переключатель вида
                        Picker("Вид", selection: $selectedChartType) {
                            Text("График").tag(0)
                            Text("Таблица").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if viewModel.isLoading {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .tint(Theme.primary)
                                    .scaleEffect(1.5)
                                Text("Загрузка отчета...")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        } else if viewModel.items.isEmpty {
                            EmptyStateView(
                                icon: "chart.pie",
                                title: "Нет данных",
                                message: "Загрузите отчет для просмотра остатков",
                                buttonTitle: "Загрузить",
                                action: { viewModel.loadReport() }
                            )
                        } else {
                            // Карточки с итогами
                            TotalsCards(viewModel: viewModel)
                                .padding(.horizontal)
                            
                            if selectedChartType == 0 {
                                // График
                                BalanceChartView(items: viewModel.items)
                                    .padding()
                            }
                            
                            // Детализация
                            if selectedChartType == 1 {
                                BalanceTableView(items: viewModel.items)
                                    .padding()
                            }
                            
                            if let summary = viewModel.summary {
                                SummaryView(summary: summary)
                                    .padding(.horizontal)
                            }
                            
                            if let lastUpdated = viewModel.lastUpdated {
                                Text("Обновлено: \(lastUpdated)")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textTertiary)
                                    .padding(.bottom)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Остатки")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            withAnimation {
                                viewModel.exportToExcel()
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                        }
                        .disabled(viewModel.items.isEmpty)
                        
                        Button(action: {
                            withAnimation {
                                viewModel.loadReport()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline)
                                .foregroundColor(Theme.primary)
                        }
                    }
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
        }
    }
}

struct TotalsCards: View {
    @ObservedObject var viewModel: BalanceReportViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                TotalCard(
                    title: "Общий итог",
                    value: viewModel.totalSum,
                    icon: "sum",
                    color: Theme.primary
                )
                
                TotalCard(
                    title: "Карты",
                    value: viewModel.cardsSum,
                    icon: "creditcard",
                    color: Theme.success
                )
                
                TotalCard(
                    title: "Счета",
                    value: viewModel.accountsSum,
                    icon: "banknote",
                    color: Theme.warning
                )
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TotalCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Text(formattedValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct BalanceChartView: View {
    let items: [BalanceReportItem]
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Распределение по группам", systemImage: "chart.pie")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(items.prefix(10)) { item in
                            BarMark(
                                x: .value("Сумма", item.rest),
                                y: .value("Группа", item.groupName)
                            )
                            .foregroundStyle(by: .value("Тип", item.type))
                            .annotation(position: .trailing) {
                                Text(item.formattedRest)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .frame(height: 300)
                    .chartForegroundStyleScale([
                        "Карта": Theme.success,
                        "Счет": Theme.warning
                    ])
                } else {
                    Text("График доступен в iOS 16+")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .padding()
        }
    }
}

struct BalanceTableView: View {
    let items: [BalanceReportItem]
    @State private var sortedItems: [BalanceReportItem] = []
    @State private var sortOrder = SortOrder.descending
    @State private var selectedType: String? = nil
    
    enum SortOrder {
        case ascending, descending
        
        mutating func toggle() {
            self = self == .ascending ? .descending : .ascending
        }
    }
    
    var filteredItems: [BalanceReportItem] {
        if let type = selectedType {
            return sortedItems.filter { $0.type == type }
        }
        return sortedItems
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Детализация", systemImage: "list.bullet")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Menu {
                        Button("Все") { selectedType = nil }
                        Button("Карты") { selectedType = "Карта" }
                        Button("Счета") { selectedType = "Счет" }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(Theme.primary)
                    }
                    
                    Button {
                        withAnimation {
                            sortOrder.toggle()
                            sortItems()
                        }
                    } label: {
                        Image(systemName: sortOrder == .descending ? "arrow.down.circle" : "arrow.up.circle")
                            .font(.title3)
                            .foregroundColor(Theme.primary)
                    }
                }
                
                if filteredItems.isEmpty {
                    Text("Нет данных для отображения")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            BalanceRow(item: item)
                            
                            if item.id != filteredItems.last?.id {
                                Divider()
                                    .background(Theme.textTertiary.opacity(0.2))
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            sortItems()
        }
        .onChange(of: items) { newItems in
            sortItems()
        }
    }
    
    private func sortItems() {
        sortedItems = items.sorted {
            sortOrder == .descending ? $0.rest > $1.rest : $0.rest < $1.rest
        }
    }
}

struct BalanceRow: View {
    let item: BalanceReportItem
    @State private var isHovered = false
    
    var typeColor: Color {
        item.type == "Карта" ? Theme.success : Theme.warning
    }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(typeColor.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.type == "Карта" ? "creditcard" : "banknote")
                        .foregroundColor(typeColor)
                        .font(.subheadline)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.groupName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                Text(item.type)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.1))
                    .foregroundColor(typeColor)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Text(item.formattedRest)
                .font(.headline)
                .foregroundColor(item.rest >= 0 ? Theme.textPrimary : Theme.danger)
                .scaleEffect(isHovered ? 1.05 : 1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Theme.cardBackgroundSecondary : Color.clear)
        )
        .onTapGesture {
            withAnimation(.spring()) {
                isHovered.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isHovered = false
                }
            }
        }
    }
}

struct SummaryView: View {
    let summary: BalanceReportSummary
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Сводка", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                HStack {
                    SummaryItem(
                        title: "Всего записей",
                        value: "\(summary.recordsCount)",
                        icon: "number",
                        color: Theme.info
                    )
                    
                    Spacer()
                    
                    SummaryItem(
                        title: "Средняя сумма",
                        value: (summary.totalSum / Double(max(1, summary.recordsCount))).formatted(),
                        icon: "equal",
                        color: Theme.secondary
                    )
                }
            }
            .padding()
        }
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
        )
    }
}
