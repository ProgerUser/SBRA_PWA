import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if viewModel.tasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Нет задач")
                            .foregroundColor(.gray)
                        Button("Обновить") {
                            viewModel.loadTasks()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(viewModel.tasks) { task in
                        TaskRow(task: task, viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Мои задачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadTasks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                viewModel.loadTasks()
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

struct TaskRow: View {
    let task: ProcessingTask
    let viewModel: TasksViewModel
    @State private var showingError = false
    
    var statusColor: Color {
        switch task.status {
        case .pending: return .orange
        case .running: return .blue
        case .completed: return .green
        case .error: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(task.taskId.prefix(8)) + "...")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(task.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text(task.processingType)
                .font(.headline)
            
            if let parameters = task.parameters {
                Text("Параметры: \(parameters)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text(viewModel.formatDate(task.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if task.status == .completed, let filename = task.filename {
                    Button(action: {
                        viewModel.downloadReport(filename: filename)
                    }) {
                        Label("Скачать", systemImage: "arrow.down.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                
                if task.status == .error, let error = task.errorMessage {
                    Button(action: {
                        showingError = true
                    }) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                    .alert("Ошибка", isPresented: $showingError) {
                        Button("OK") {}
                    } message: {
                        Text(error)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
