import Foundation
import SwiftUI
import UserNotifications
import ServiceManagement

@MainActor
class StatusManager: ObservableObject {
    static let shared = StatusManager()
    
    @Published var currentStatus: StatusIndicator = .unknown
    @Published var statusDescription: String = "Loading..."
    @Published var components: [Component] = []
    @Published var incidents: [Incident] = []
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var launchAtLogin: Bool = false
    
    private var timer: Timer?
    private var previousStatus: StatusIndicator = .unknown
    private let refreshInterval: TimeInterval = 60 // 1 minute
    
    private init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        requestNotificationPermission()
        startPolling()
    }
    
    // MARK: - Polling
    
    func startPolling() {
        // Fetch immediately
        Task {
            await refresh()
        }
        
        // Set up timer for periodic refresh
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let summary = try await GitHubStatusService.shared.fetchSummary()
            
            // Update state
            let newStatus = StatusIndicator(rawValue: summary.page.name == "GitHub" ? "none" : "unknown") ?? .unknown
            
            // Get status from the first component or use a separate status call
            let status = try await GitHubStatusService.shared.fetchStatus()
            
            previousStatus = currentStatus
            currentStatus = status.status.indicator
            statusDescription = status.status.description
            components = summary.components.filter { $0.isRealComponent }.sorted { $0.position < $1.position }
            incidents = summary.incidents
            lastUpdated = Date()
            
            // Send notification if status changed
            if previousStatus != .unknown && previousStatus != currentStatus {
                sendStatusChangeNotification()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            currentStatus = .unknown
            statusDescription = "Failed to fetch status"
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    var affectedComponents: [Component] {
        return components.filter { !$0.status.isHealthy }
    }
    
    var hasIssues: Bool {
        return currentStatus != .operational && currentStatus != .unknown
    }
    
    var lastUpdatedString: String {
        guard let lastUpdated = lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func sendStatusChangeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "GitHub Status Changed"
        content.body = statusDescription
        content.sound = .default
        
        // Add affected components if any
        if !affectedComponents.isEmpty {
            let componentNames = affectedComponents.map { $0.name }.joined(separator: ", ")
            content.body += "\nAffected: \(componentNames)"
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Launch at Login
    
    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchAtLogin.toggle()
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
    
    // MARK: - Actions
    
    func openGitHubStatus() {
        if let url = URL(string: "https://www.githubstatus.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
