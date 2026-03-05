import SwiftUI

struct BalanceReportView: View {
    @StateObject private var viewModel = BalanceReportViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Карточки с итогами
                    TotalsCards(viewModel: viewModel)
                    
                    // Таблица
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if viewModel.items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Нет данных")
                                .foregroundColor(.gray)
                            Button("Загрузить отчет") {
                                viewModel.loadReport()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        BalanceTableView(items: viewModel.items)
                        
                        if let lastUpdated = viewModel.lastUpdated {
                            Text("Обновлено: \(lastUpdated)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Остатки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            viewModel.exportToExcel()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(viewModel.items.isEmpty)
                        
                        Button(action: {
                            viewModel.loadReport()
                        }) {
                            Image(systemName: "arrow.clockwise")
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
        HStack(spacing: 12) {
            TotalCard(
                title: "Общий итог",
                value: viewModel.totalSum,
                color: .blue
            )
            
            TotalCard(
                title: "Карты",
                value: viewModel.cardsSum,
                color: .green
            )
            
            TotalCard(
                title: "Счета",
                value: viewModel.accountsSum,
                color: .orange
            )
        }
    }
}

struct TotalCard: View {
    let title: String
    let value: Double
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Text(formattedValue)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color)
        .cornerRadius(10)
    }
}

struct BalanceTableView: View {
    let items: [BalanceReportItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Детализация")
                .font(.headline)
            
            ForEach(items) { item in
                BalanceRow(item: item)
            }
            
            HStack {
                Text("ОБЩИЙ ИТОГ:")
                    .font(.headline)
                
                Spacer()
                
                Text(items.reduce(0) { $0 + $1.rest }.formatted())
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.top)
        }
    }
}

struct BalanceRow: View {
    let item: BalanceReportItem
    
    var body: some View {
        HStack {
            Text(item.type)
                .font(.caption)
                .padding(4)
                .background(item.type == "Карта" ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(item.type == "Карта" ? .blue : .orange)
                .cornerRadius(4)
            
            Text(item.groupName)
                .font(.system(.body, design: .monospaced))
            
            Spacer()
            
            Text(item.formattedRest)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(item.rest >= 0 ? .primary : .red)
        }
        .padding(.vertical, 4)
    }
}
