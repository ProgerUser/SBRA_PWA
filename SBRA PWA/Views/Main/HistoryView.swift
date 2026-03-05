import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Фильтры
                if showingFilters {
                    FiltersView(viewModel: viewModel)
                }
                
                // Статистика
                if let stats = viewModel.stats {
                    StatsView(stats: stats)
                }
                
                // Таблица истории
                HistoryTableView(viewModel: viewModel)
            }
            .navigationTitle("История обработок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            viewModel.exportToExcel()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(viewModel.historyItems.isEmpty)
                        
                        Button(action: {
                            viewModel.loadHistory()
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

struct FiltersView: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Группа", selection: $viewModel.selectedGroup) {
                Text("Все группы").tag("")
                ForEach(viewModel.availableGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .pickerStyle(.menu)
            
            HStack {
                DatePicker("С", selection: $viewModel.startDate, displayedComponents: .date)
                DatePicker("По", selection: $viewModel.endDate, displayedComponents: .date)
            }
            
            Picker("Период", selection: $viewModel.daysBack) {
                Text("1 день").tag(1)
                Text("3 дня").tag(3)
                Text("7 дней").tag(7)
                Text("14 дней").tag(14)
                Text("30 дней").tag(30)
                Text("90 дней").tag(90)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.daysBack) { _ in
                viewModel.updateDatesFromPeriod()
            }
            
            HStack {
                Button("Применить") {
                    viewModel.applyFilters()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Сбросить") {
                    viewModel.resetFilters()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5)
        .padding()
    }
}

struct StatsView: View {
    let stats: HistoryViewModel.Stats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Всего записей:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(stats.recordCount)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Общая сумма:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(stats.formattedTotal)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 5)
        .padding(.horizontal)
    }
}

struct HistoryTableView: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var body: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.historyItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Нет данных")
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.paginatedItems, id: \.id) { item in
                    HistoryRow(item: item)
                }
                
                // Пагинация
                HStack {
                    Button(action: { viewModel.previousPage() }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(viewModel.currentPage == 1)
                    
                    Text("\(viewModel.currentPage) из \(viewModel.totalPages)")
                        .font(.caption)
                    
                    Button(action: { viewModel.nextPage() }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(viewModel.currentPage == viewModel.totalPages)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .listStyle(.plain)
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(item.groupType)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Карта: \(item.cardNum)")
                        .font(.subheadline)
                    
                    if let account = item.accountNum {
                        Text("Счет: \(account)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(item.formattedSum)
                        .font(.headline)
                        .foregroundColor(item.paymentSum >= 0 ? .primary : .red)
                    
                    if let error = item.errorText {
                        Text("Ошибка")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    } else {
                        Text("Успешно")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
