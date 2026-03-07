// SBRA PWA/Views/Main/ProcessingDetailModal.swift
import SwiftUI

struct ProcessingDetailModal: View {
    let processing: AvailableProcessing
    @ObservedObject var viewModel: ProcessingViewModel
    @Binding var isPresented: Bool
    @State private var parameters = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                MeshBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Информация о processing
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(processing.name, systemImage: "gearshape.2")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                if let description = processing.description {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                HStack {
                                    Text("Код:")
                                        .font(.caption)
                                        .foregroundColor(Theme.textTertiary)
                                    Text(processing.code)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.primary.opacity(0.1))
                                        .foregroundColor(Theme.primary)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                        
                        // Проверка для STREAM_RUSLAN
                        if processing.code == "STREAM_RUSLAN" && (viewModel.uploadResult?.cardCount ?? 0) == 0 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Theme.warning)
                                Text("Для обработки STREAM_RUSLAN необходимо сначала загрузить Excel файл")
                                    .font(.caption)
                                    .foregroundColor(Theme.warning)
                            }
                            .padding()
                            .background(Theme.warning.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Параметры
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Параметры", systemImage: "slider.horizontal.3")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Группа")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    TextField("Например: STREAM_%", text: $parameters)
                                        .textFieldStyle(ModernTextFieldStyle())
                                    
                                    if !viewModel.availableGroups.isEmpty {
                                        Text("Или выберите из списка:")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.top, 8)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack {
                                                ForEach(viewModel.availableGroups, id: \.self) { group in
                                                    Button(action: {
                                                        parameters = group
                                                    }) {
                                                        Text(group)
                                                            .font(.caption)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(parameters == group ? Theme.primary : Theme.primary.opacity(0.1))
                                                            .foregroundColor(parameters == group ? .white : Theme.primary)
                                                            .cornerRadius(20)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Кнопка запуска
                        Button(action: {
                            viewModel.executeProcessing(parameters: parameters)
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Запустить обработку")
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(
                            (processing.code == "STREAM_RUSLAN" && (viewModel.uploadResult?.cardCount ?? 0) == 0) ||
                            viewModel.isLoading
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle(processing.name)
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
