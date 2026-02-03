import SwiftUI

struct ComponentRowView: View {
    let component: Component
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .foregroundColor(component.status.color)
                .font(.system(size: 8))
            
            Text(component.name)
                .font(.system(size: 13))
            
            Spacer()
            
            Text(component.status.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct IncidentRowView: View {
    let incident: Incident
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                
                Text(incident.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }
            
            if let latestUpdate = incident.latestUpdate {
                Text(latestUpdate.body)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        ComponentRowView(component: Component(
            id: "1",
            name: "GitHub Actions",
            status: .partialOutage,
            description: "Test",
            position: 1,
            updatedAt: Date()
        ))
        
        ComponentRowView(component: Component(
            id: "2",
            name: "Git Operations",
            status: .operational,
            description: "Test",
            position: 2,
            updatedAt: Date()
        ))
    }
    .padding()
    .frame(width: 280)
}
