import Foundation

actor GitHubStatusService {
    static let shared = GitHubStatusService()
    
    private let statusURL = URL(string: "https://www.githubstatus.com/api/v2/status.json")!
    private let summaryURL = URL(string: "https://www.githubstatus.com/api/v2/summary.json")!
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private init() {}
    
    /// Fetches the current overall status
    func fetchStatus() async throws -> StatusResponse {
        let (data, response) = try await URLSession.shared.data(from: statusURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubStatusError.invalidResponse
        }
        
        return try decoder.decode(StatusResponse.self, from: data)
    }
    
    /// Fetches the full summary including components and incidents
    func fetchSummary() async throws -> SummaryResponse {
        let (data, response) = try await URLSession.shared.data(from: summaryURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubStatusError.invalidResponse
        }
        
        return try decoder.decode(SummaryResponse.self, from: data)
    }
}

enum GitHubStatusError: LocalizedError {
    case invalidResponse
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from GitHub Status API"
        case .decodingError:
            return "Failed to decode GitHub Status response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
