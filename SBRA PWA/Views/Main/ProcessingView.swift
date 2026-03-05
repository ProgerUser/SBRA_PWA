import SwiftUI

struct ProcessingView: View {
    @StateObject private var viewModel = ProcessingViewModel()
    @State private var showingFilePicker = false
    @State private var showingProcessingModal = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Секция загрузки Excel файла
                    ExcelUploadSection(viewModel: viewModel)
                    
                    // Секция доступных обработок
                    ProcessingsSection(
                        viewModel: viewModel,
                        showingModal: $showingProcessingModal
                    )
                }
                .padding()
            }
            .navigationTitle("Обработки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadProcessings()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingProcessingModal) {
                if let selected = viewModel.selectedProcessing {
                    ProcessingDetailModal(
                        processing: selected,
                        viewModel: viewModel,
                        isPresented: $showingProcessingModal
                    )
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
                    viewModel.handleSelectedFile(url: url)
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil && !showingProcessingModal },
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

struct ExcelUploadSection: View {
    @ObservedObject var viewModel: ProcessingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.yellow)
                Text("Для группы STREAM_RUSLAN необходимо загрузить Excel файл")
                    .font(.subheadline)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
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
                Button(action: { viewModel.selectFile() }) {
                    Label("Выбрать файл", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if viewModel.selectedFile != nil {
                    Button(action: { viewModel.uploadFile() }) {
                        if viewModel.isUploading {
                            ProgressView()
                        } else {
                            Label("Загрузить", systemImage: "arrow.up.doc")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isUploading)
                }
            }
            
            if let result = viewModel.uploadResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.success ? .green : .red)
                        Text(result.message)
                            .font(.subheadline)
                    }
                    
                    if let cardCount = result.cardCount {
                        Text("В таблице карт: \(cardCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
        }
    }
}

struct ProcessingsSection: View {
    @ObservedObject var viewModel: ProcessingViewModel
    @Binding var showingModal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Доступные обработки")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.processings.count)")
                    .font(.caption)
                    .padding(5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if viewModel.processings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Нет доступных обработок")
                        .foregroundColor(.gray)
                    Button("Загрузить") {
                        viewModel.loadProcessings()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.processings) { processing in
                        ProcessingRow(
                            processing: processing,
                            onSelect: {
                                viewModel.selectedProcessing = processing
                                showingModal = true
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ProcessingRow: View {
    let processing: AvailableProcessing
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(processing.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = processing.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text(processing.code)
                            .font(.caption2)
                            .padding(4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        if processing.code == "STREAM_RUSLAN" {
                            Text("требуется файл")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.1), radius: 5)
        }
    }
}

struct ProcessingDetailModal: View {
    let processing: AvailableProcessing
    @ObservedObject var viewModel: ProcessingViewModel
    @Binding var isPresented: Bool
    @State private var parameters = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    if processing.code == "STREAM_RUSLAN" && (viewModel.uploadResult?.cardCount ?? 0) == 0 {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                                Text("Для обработки STREAM_RUSLAN необходимо сначала загрузить Excel файл")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Section(header: Text("Параметры")) {
                        TextField("Группа (например: STREAM_%)", text: $parameters)
                        
                        Picker("Выберите из истории", selection: $parameters) {
                            Text("").tag("")
                            ForEach(viewModel.availableGroups, id: \.self) { group in
                                Text(group).tag(group)
                            }
                        }
                    }
                    
                    Section {
                        Text("Выполняется процедура: \(processing.description ?? "")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {
                    viewModel.executeProcessing(parameters: parameters)
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Запустить обработку")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .disabled(processing.code == "STREAM_RUSLAN" && (viewModel.uploadResult?.cardCount ?? 0) == 0 || viewModel.isLoading)
            }
            .navigationTitle(processing.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
            }
            .onReceive(viewModel.successPublisher) { _ in
                isPresented = false
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
