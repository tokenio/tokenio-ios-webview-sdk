import Foundation

// extension Bundle {
//     var apiKey: String? {
//         // 1. Prefer environment variable for local/test/dev
//         if let envKey = ProcessInfo.processInfo.environment["API_KEY"], !envKey.isEmpty {
//             return envKey
//         }
//         // 2. Fallback to Info.plist
//         return object(forInfoDictionaryKey: "API_KEY") as? String
//     }
// }
// Define the available API environments
enum ApiEnvironment: String, CaseIterable, Identifiable {
    case dev = "DEV"       // Example DEV environment
    case sandbox = "SANDBOX"
    case beta = "BETA"

    var id: String { self.rawValue }

    // Base URL for each environment
    var baseUrl: URL {
        switch self {
        case .dev:
            // Replace with your actual DEV URL if you have one
            return URL(string: "https://api.dev.token.io")!
        case .sandbox:
            return URL(string: "https://api.sandbox.token.io")!
        case .beta:
            return URL(string: "https://api.beta.token.io")!
        }
    }

   var apiKey: String {
        let key = "API_KEY_\(rawValue)" // e.g. "API_KEY_DEV"
        return Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
