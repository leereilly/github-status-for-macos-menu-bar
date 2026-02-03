import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var statusManager: StatusManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Current Status
            statusHeader
            
            Divider()
                .padding(.vertical, 8)
            
            // Active Incidents
            if !statusManager.incidents.isEmpty {
                incidentsSection
                
                Divider()
                    .padding(.vertical, 8)
            }
            
            // Affected Components (only show non-operational)
            if !statusManager.affectedComponents.isEmpty {
                affectedComponentsSection
                
                Divider()
                    .padding(.vertical, 8)
            }
            
            // All Components (collapsible or abbreviated)
            allComponentsSection
            
            Divider()
                .padding(.vertical, 8)
            
            // Footer actions
            footerSection
        }
        .padding(12)
        .frame(width: 320)
    }
    
    // MARK: - Header
    
    private var statusHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: statusManager.currentStatus.symbolName)
                .foregroundColor(statusManager.currentStatus.color)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusManager.statusDescription)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Updated \(statusManager.lastUpdatedString)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if statusManager.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
    
    // MARK: - Incidents Section
    
    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Incidents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            ForEach(statusManager.incidents) { incident in
                IncidentRowView(incident: incident)
            }
        }
    }
    
    // MARK: - Affected Components
    
    private var affectedComponentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Affected Services")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            ForEach(statusManager.affectedComponents) { component in
                ComponentRowView(component: component)
            }
        }
    }
    
    // MARK: - All Components
    
    private var allComponentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("All Services")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            ForEach(statusManager.components) { component in
                ComponentRowView(component: component)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    await statusManager.refresh()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            
            Button(action: statusManager.openGitHubStatus) {
                HStack {
                    Image(systemName: "globe")
                    Text("Open githubstatus.com")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            
            Divider()
                .padding(.vertical, 4)
            
            Toggle("Launch at Login", isOn: Binding(
                get: { statusManager.launchAtLogin },
                set: { _ in statusManager.toggleLaunchAtLogin() }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 12))
            
            Divider()
                .padding(.vertical, 4)
            
            Button(action: statusManager.quit) {
                HStack {
                    Text("Quit GitHub Status")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    StatusMenuView(statusManager: StatusManager.shared)
}
