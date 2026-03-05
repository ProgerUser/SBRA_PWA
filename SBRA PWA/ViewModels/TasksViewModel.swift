import Foundation
import Combine
import UIKit
import UserNotifications

class TasksViewModel: ObservableObject {
    @Published var tasks: [ProcessingTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private var timer: Timer?
    
    init() {
        requestNotificationPermissions()
        loadTasks()
        startPolling()
    }
    
    deinit {
        stopPolling()
    }
    
    func loadTasks() {
        isLoading = true
        apiService.getUserTasks()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] newTasks in
                self?.checkTaskStatusChanges(oldTasks: self?.tasks ?? [], newTasks: newTasks)
                self?.tasks = newTasks
            }
            .store(in: &cancellables)
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    private func checkTaskStatusChanges(oldTasks: [ProcessingTask], newTasks: [ProcessingTask]) {
        for newTask in newTasks {
            // Ищем эту же задачу в старом списке
            if let oldTask = oldTasks.first(where: { $0.taskId == newTask.taskId }) {
                // Если статус изменился на завершенный или ошибку
                if oldTask.status == .running || oldTask.status == .pending {
                    if newTask.status == .completed {
                        sendLocalNotification(for: newTask, title: "Задача завершена", message: "Обработка «\(newTask.processingType)» успешно выполнена")
                    } else if newTask.status == .error {
                        sendLocalNotification(for: newTask, title: "Ошибка в задаче", message: "Обработка «\(newTask.processingType)» завершилась с ошибкой: \(newTask.errorMessage ?? "Неизвестная ошибка")")
                    }
                }
            }
        }
    }
    
    private func sendLocalNotification(for task: ProcessingTask, title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "TaskFinished-\(task.taskId)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.loadTasks()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func downloadReport(filename: String) {
        guard let url = URL(string: "https://10.111.170.74:5500/download-report/\(filename)") else { return }
        
        var request = URLRequest(url: url)
        if let token = TokenManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        APIService.shared.downloadFile(request: request) { localURL, response, error in
            guard let localURL = localURL, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = error?.localizedDescription ?? "Ошибка скачивания"
                }
                return
            }
            
            DispatchQueue.main.async {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsURL.appendingPathComponent(filename)
                
                try? FileManager.default.removeItem(at: destinationURL)
                try? FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                // Показываем диалог сохранения
                let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .short
        outputFormatter.timeStyle = .short
        outputFormatter.locale = Locale(identifier: "ru_RU")
        return outputFormatter.string(from: date)
    }
}
