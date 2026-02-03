import Foundation

// MARK: - Status Response
struct StatusResponse: Codable {
    let page: Page
    let status: Status
}

struct Page: Codable {
    let id: String
    let name: String
    let url: String
    let timeZone: String
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, url
        case timeZone = "time_zone"
        case updatedAt = "updated_at"
    }
}

struct Status: Codable {
    let indicator: StatusIndicator
    let description: String
}

// MARK: - Summary Response
struct SummaryResponse: Codable {
    let page: Page
    let components: [Component]
    let incidents: [Incident]
}

// MARK: - Component
struct Component: Codable, Identifiable {
    let id: String
    let name: String
    let status: ComponentStatus
    let description: String?
    let position: Int
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, description, position
        case updatedAt = "updated_at"
    }
    
    /// Filter out meta-components like "Visit www.githubstatus.com..."
    var isRealComponent: Bool {
        return !name.lowercased().contains("visit www.githubstatus.com")
    }
}

// MARK: - Incident
struct Incident: Codable, Identifiable {
    let id: String
    let name: String
    let status: IncidentStatus
    let impact: String
    let shortlink: String
    let createdAt: Date
    let updatedAt: Date
    let incidentUpdates: [IncidentUpdate]
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, impact, shortlink
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case incidentUpdates = "incident_updates"
    }
    
    var latestUpdate: IncidentUpdate? {
        return incidentUpdates.first
    }
}

enum IncidentStatus: String, Codable {
    case investigating = "investigating"
    case identified = "identified"
    case monitoring = "monitoring"
    case resolved = "resolved"
    case postmortem = "postmortem"
    case unknown = "unknown"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = IncidentStatus(rawValue: rawValue) ?? .unknown
    }
}

struct IncidentUpdate: Codable, Identifiable {
    let id: String
    let status: IncidentStatus
    let body: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, status, body
        case createdAt = "created_at"
    }
}
