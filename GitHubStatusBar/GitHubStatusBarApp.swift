import SwiftUI

/// A dedicated view for the menu bar label that supports pulse animation on status change.
private struct MenuBarLabel: View {
    @ObservedObject var statusManager: StatusManager
    @State private var pulseOpacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: statusManager.currentStatus.symbolName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(statusManager.currentStatus.color)
            .opacity(pulseOpacity)
            .onChange(of: statusManager.animationPhase) { phase in
                switch phase {
                case .fadingOut:
                    withAnimation(.easeOut(duration: 0.4)) {
                        pulseOpacity = 0.0
                    }
                case .fadingIn:
                    withAnimation(.easeIn(duration: 0.4)) {
                        pulseOpacity = 1.0
                    }
                case .pulsing:
                    // Do not animate the menu bar icon label with repeatForever — doing so
                    // causes continuous SwiftUI re-renders that break MenuBarExtra hit-testing,
                    // making the icon unclickable. The tint window handles pulsing independently.
                    break
                case .idle:
                    withAnimation(.easeInOut(duration: 1.0)) {
                        pulseOpacity = 1.0
                    }
                }
            }
    }
}

@main
struct GitHubStatusBarApp: App {
    @StateObject private var statusManager = StatusManager.shared

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(statusManager: statusManager)
        } label: {
            MenuBarLabel(statusManager: statusManager)
        }
        .menuBarExtraStyle(.window)
    }
}
