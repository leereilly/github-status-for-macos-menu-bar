import Foundation
import SwiftUI
import AppKit
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
    @Published var tintMenuBar: Bool = false {
        didSet {
            UserDefaults.standard.set(tintMenuBar, forKey: "tintMenuBar")
            updateMenuBarTint()
        }
    }
    
    enum AnimationPhase: Equatable {
        case idle, fadingOut, fadingIn, pulsing
    }
    @Published var animationPhase: AnimationPhase = .idle

    private var timer: Timer?
    private var tintWindow: NSWindow?
    private var previousStatus: StatusIndicator = .unknown
    private let refreshInterval: TimeInterval = 60 // 1 minute
    private var animationTask: Task<Void, Never>?
    private var tintPulseTimer: Timer?
    private var tintPulseStartTime: Date?
    
    private init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        tintMenuBar = UserDefaults.standard.bool(forKey: "tintMenuBar")
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
            
            // Update non-visual state immediately
            components = summary.components.filter { $0.isRealComponent }.sorted { $0.position < $1.position }
            incidents = summary.incidents
            
            // Send notification and trigger animation if status changed
            if previousStatus != .unknown && previousStatus != status.status.indicator {
                sendStatusChangeNotification()
                // triggerAnimation handles setting currentStatus after fade-out
                triggerAnimation(to: status.status.indicator, description: status.status.description)
            } else {
                currentStatus = status.status.indicator
                statusDescription = status.status.description
                lastUpdated = Date()
                updateMenuBarTint() // Static tint only when no animation
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
    
    // MARK: - Status Change Animation

    func triggerAnimation(to newStatus: StatusIndicator, description: String) {
        animationTask?.cancel()
        stopTintPulse()
        animationPhase = .idle // Reset so subsequent .onChange always fires
        
        let shouldFadeOut = currentStatus != .unknown
        
        animationTask = Task { @MainActor in
            // Phase 1: Fade out old color (skip on first load from .unknown)
            if shouldFadeOut {
                animationPhase = .fadingOut
                fadeOutTintWindow()
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
                guard !Task.isCancelled else { return }
            }
            
            // Phase 2: Switch status while icon is invisible
            previousStatus = currentStatus
            currentStatus = newStatus
            statusDescription = description
            lastUpdated = Date()
            
            tintWindow?.orderOut(nil)
            tintWindow = nil
            
            // Phase 3: Set up new tint and fade in with new color
            setupTintForAnimation()
            fadeInTintWindow()
            animationPhase = .fadingIn
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            guard !Task.isCancelled else { return }
            
            // Phase 4: Start pulsing
            animationPhase = .pulsing
            startTintPulse()
            
            // Pulse for ~10 seconds, then wait for the next trough (minimum opacity)
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            
            if let startTime = tintPulseStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                let period = 1.25
                let phaseInCycle = elapsed.truncatingRemainder(dividingBy: period) / period
                let troughPhase = 0.75 // sin = -1 at 3/4 of period
                let phasesToTrough = phaseInCycle <= troughPhase
                    ? troughPhase - phaseInCycle
                    : 1.0 - phaseInCycle + troughPhase
                let extraWait = phasesToTrough * period
                if extraWait > 0.01 {
                    try? await Task.sleep(nanoseconds: UInt64(extraWait * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                }
            }
            
            animationPhase = .idle
            stopTintPulse()
            updateMenuBarTint() // Reset to static tint state
        }
    }
    
    // MARK: - Menu Bar Tint Pulse
    
    /// Creates a tint window for animated pulsing (supports all status colors including green)
    private func setupTintForAnimation() {
        tintWindow?.orderOut(nil)
        tintWindow = nil
        
        guard tintMenuBar else { return }
        
        let tintColor: NSColor
        switch currentStatus {
        case .minor:
            tintColor = NSColor.systemYellow.withAlphaComponent(0.20)
        case .major, .critical:
            tintColor = NSColor.systemRed.withAlphaComponent(0.20)
        case .operational:
            tintColor = NSColor.systemGreen.withAlphaComponent(0.15)
        case .unknown:
            return
        }
        
        guard let screen = NSScreen.main else { return }
        
        let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let windowFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - menuBarHeight,
            width: screen.frame.width,
            height: menuBarHeight
        )
        
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.level = .statusBar
        window.backgroundColor = tintColor
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.alphaValue = 0.0 // Start transparent; fade-in will reveal it
        window.orderFrontRegardless()
        
        tintWindow = window
    }
    
    private func fadeOutTintWindow() {
        guard let window = tintWindow else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0.0
        }
    }
    
    private func fadeInTintWindow() {
        guard let window = tintWindow else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 1.0
        }
    }
    
    /// Smoothly pulses the tint window opacity using a sine wave (~1.25s period)
    private func startTintPulse() {
        guard tintWindow != nil else { return }
        tintPulseStartTime = Date()
        
        tintPulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, let window = self.tintWindow, let startTime = self.tintPulseStartTime else {
                    timer.invalidate()
                    return
                }
                let elapsed = Date().timeIntervalSince(startTime)
                // Sine wave: smooth fade between 0.1 and 1.0 with ~1.25s period
                let phase = sin(elapsed * 2.0 * .pi / 1.25)
                let alpha = 0.55 + 0.45 * phase
                window.alphaValue = CGFloat(alpha)
            }
        }
    }
    
    private func stopTintPulse() {
        tintPulseTimer?.invalidate()
        tintPulseTimer = nil
        tintPulseStartTime = nil
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
    
    // MARK: - Menu Bar Tint
    
    func updateMenuBarTint() {
        // Remove existing tint window
        tintWindow?.orderOut(nil)
        tintWindow = nil
        
        // Only show tint if enabled and status is minor/major/critical
        guard tintMenuBar else { return }
        
        let tintColor: NSColor?
        switch currentStatus {
        case .minor:
            tintColor = NSColor.yellow.withAlphaComponent(0.15)
        case .major, .critical:
            tintColor = NSColor.red.withAlphaComponent(0.15)
        default:
            tintColor = nil
        }
        
        guard let color = tintColor,
              let screen = NSScreen.main else { return }
        
        // Create a window that covers the menu bar
        let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let windowFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - menuBarHeight,
            width: screen.frame.width,
            height: menuBarHeight
        )
        
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.level = .statusBar
        window.backgroundColor = color
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.orderFrontRegardless()
        
        tintWindow = window
    }
}
