import Foundation

enum PaymentServiceError: LocalizedError {
    case missingApiKey
    case invalidUrl
    case invalidResponse
    case apiError(String)
    case decodingError(String)
    case networkError(Error)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "API key is missing"
        case .invalidUrl:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
