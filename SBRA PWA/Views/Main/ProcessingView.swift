// SBRA PWA/Views/Main/ProcessingView.swift
import SwiftUI

struct ProcessingView: View {
    @StateObject private var viewModel = ProcessingViewModel()
    @State private var showingProcessingModal = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ExcelUploadSection(viewModel: viewModel)
                        .transition(.scale.combined(with: .opacity))
                    
                    ProcessingsSection(
                        viewModel: viewModel,
                        showingModal: $showingProcessingModal
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(MeshBackground())
            .navigationTitle("Обработки")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.loadProcessings()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
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
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [.excel],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    withAnimation {
                        viewModel.handleSelectedFile(url: url)
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
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .toast(toast: $viewModel.toast)
        }
    }
}

// MARK: - Excel Upload Section
struct ExcelUploadSection: View {
    @ObservedObject var viewModel: ProcessingViewModel
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Загрузка данных", systemImage: "externaldrive.badge.plus")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                
                // Информационный блок
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.info)
                    Text("Для группы STREAM_RUSLAN необходим Excel файл")
                        .font(.subheadline)
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
                    Button(action: { viewModel.selectFile() }) {
                        Label("Выбрать файл", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    if viewModel.selectedFile != nil {
                        Button(action: {
                            withAnimation {
                                viewModel.uploadFile()
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
                    }
                }
                
                if let result = viewModel.uploadResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(result.success ? Theme.success : Theme.danger)
                                .font(.title3)
                            Text(result.message)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                        if let cardCount = result.cardCount {
                            Text("\(cardCount) карт(ы) в файле")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(result.success ? Theme.success.opacity(0.1) : Theme.danger.opacity(0.1))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Processings Section
struct ProcessingsSection: View {
    @ObservedObject var viewModel: ProcessingViewModel
    @Binding var showingModal: Bool
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Доступные обработки", systemImage: "gearshape.2.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Text("\(viewModel.processings.count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Theme.primary)
                            .scaleEffect(1.2)
                        Spacer()
                    }
                    .padding()
                } else if viewModel.processings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(Theme.textTertiary)
                        Text("Нет доступных обработок")
                            .foregroundColor(Theme.textSecondary)
                        Button("Загрузить") {
                            withAnimation {
                                viewModel.loadProcessings()
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 200)
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.processings) { processing in
                            ProcessingRow(
                                processing: processing,
                                onSelect: {
                                    viewModel.selectedProcessing = processing
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showingModal = true
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Processing Row
struct ProcessingRow: View {
    let processing: AvailableProcessing
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Иконка слева
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: processing.code == "STREAM_RUSLAN" ? "externaldrive" : "doc.text.magnifyingglass")
                            .foregroundColor(Theme.primary)
                            .font(.title3)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(processing.name)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    if let description = processing.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    }
                    
                    HStack {
                        Text(processing.code)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.textTertiary.opacity(0.2))
                            .cornerRadius(4)
                        
                        if processing.code == "STREAM_RUSLAN" {
                            Text("требуется файл")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.warning.opacity(0.2))
                                .foregroundColor(Theme.warning)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
    }
}
