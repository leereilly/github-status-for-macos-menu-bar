import SwiftUI

/// Represents the overall GitHub status indicator
enum StatusIndicator: String, Codable {
    case operational = "none"
    case minor = "minor"
    case major = "major"
    case critical = "critical"
    case unknown = "unknown"
    
    var color: Color {
        switch self {
        case .operational: return .green
        case .minor: return .yellow
        case .major, .critical: return .red
        case .unknown: return .gray
        }
    }
    
    var description: String {
        switch self {
        case .operational: return "All Systems Operational"
        case .minor: return "Minor Service Outage"
        case .major: return "Major Service Outage"
        case .critical: return "Critical Outage"
        case .unknown: return "Status Unknown"
        }
    }
    
    var symbolName: String {
        return "circle.fill"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = StatusIndicator(rawValue: rawValue) ?? .unknown
    }
}

/// Represents individual component status
enum ComponentStatus: String, Codable {
    case operational = "operational"
    case degradedPerformance = "degraded_performance"
    case partialOutage = "partial_outage"
    case majorOutage = "major_outage"
    case unknown = "unknown"
    
    var color: Color {
        switch self {
        case .operational: return .green
        case .degradedPerformance: return .yellow
        case .partialOutage: return .orange
        case .majorOutage: return .red
        case .unknown: return .gray
        }
    }
    
    var description: String {
        switch self {
        case .operational: return "Operational"
        case .degradedPerformance: return "Degraded Performance"
        case .partialOutage: return "Partial Outage"
        case .majorOutage: return "Major Outage"
        case .unknown: return "Unknown"
        }
    }
    
    var isHealthy: Bool {
        return self == .operational
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ComponentStatus(rawValue: rawValue) ?? .unknown
    }
}
