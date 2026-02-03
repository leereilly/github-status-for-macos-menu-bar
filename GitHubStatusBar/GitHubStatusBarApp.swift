import SwiftUI

@main
struct GitHubStatusBarApp: App {
    @StateObject private var statusManager = StatusManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(statusManager: statusManager)
        } label: {
            Image(systemName: statusManager.currentStatus.symbolName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(statusManager.currentStatus.color)
        }
        .menuBarExtraStyle(.window)
    }
}
