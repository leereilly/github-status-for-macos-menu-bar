import SwiftUI
import AppKit

/// Creates a tinted copy of the MenuBarIcon asset.
/// macOS forces template rendering on menu bar images, ignoring SwiftUI
/// foregroundStyle, so we tint the bitmap ourselves and mark it non-template.
private func tintedMenuBarIcon(color: NSColor) -> NSImage {
    guard let base = NSImage(named: "MenuBarIcon") else {
        return NSImage()
    }
    let size = NSSize(width: 18, height: 18)
    let tinted = NSImage(size: size, flipped: false) { rect in
        base.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    tinted.isTemplate = false
    return tinted
}

/// A dedicated view for the menu bar label that supports pulse animation on status change.
private struct MenuBarLabel: View {
    @ObservedObject var statusManager: StatusManager
    @State private var pulseOpacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(nsImage: tintedMenuBarIcon(color: NSColor(statusManager.currentStatus.color)))
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
