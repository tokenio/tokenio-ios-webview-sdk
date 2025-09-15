import Foundation
import SwiftUI

// MARK: - API Response Structures
// REMOVED - These structs are already defined elsewhere

class PaymentCompletionHandler: ObservableObject {
    @Published var paymentStatus: PaymentStatus? = nil
    @Published var statusString: String = "" // Will hold the raw status from API
    @Published var statusReasonInformation: String? = nil
    @Published var currency: String = ""
    @Published var value: String = ""
    @Published var refId: String = ""
    @Published var isCheckingStatus: Bool = false // To indicate API call in progress

    // Keep the existing enum for initial status mapping from URL
    enum PaymentStatus {
        case success, failure, cancelled, pending
    }

    // Maps API status strings to the PaymentStatus enum
    private func mapApiStatus(_ apiStatus: String) -> PaymentStatus {
        // This mapping might need refinement based on all possible API statuses
        switch apiStatus.lowercased() {
        case "execution_successful", "settlement_completed": // Add other success cases
            return .success
        case "authorization_failure", "execution_rejected", "expired": // Add other failure cases
            return .failure
        case "cancelled": // Assuming API might use "cancelled"
             return .cancelled
        case "initiation_pending_redirect_hp", "pending", "processing": // Add other pending cases
            return .pending
        default:
            // Log unknown status for debugging
            print("Unknown API payment status received: \(apiStatus)")
            // Decide a default, maybe failure or pending?
            return .failure // Or perhaps keep the initial status? Consider UX.
        }
    }

    func handleIncomingURL(_ url: URL) {
        print("[DEBUG] Raw incoming URL: \(url.absoluteString)") // Log the full URL
        // Example: paymentdemoapp://payment-complete?state=XYZ&status=success&refId=123&amount=10.00&currency=GBP&reason=Approved
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let queryItems = components.queryItems ?? []
        
        func value(for key: String) -> String? {
            queryItems.first(where: { $0.name == key })?.value
        }

        // Extract payment-id and state
        let paymentId = value(for: "payment-id")
        let _ = value(for: "state") // Keep state for potential future CSRF check, silence warning
 
        // TODO: Optionally verify state matches expected (CSRF protection)

        if let pId = paymentId, !pId.isEmpty {
            self.refId = pId
            print("[DEBUG] handleIncomingURL extracted refId (from payment-id): \(self.refId)")
            // Set initial status to pending to trigger polling
            self.paymentStatus = .pending
            self.statusString = "Pending (Polling...)"
            print("[DEBUG] handleIncomingURL setting paymentStatus to .pending")
        } else {
            // If no payment-id found, it's an error state
            self.refId = ""
            self.paymentStatus = .failure
            self.statusString = "Payment ID Missing"
            self.statusReasonInformation = "Callback URL did not contain payment-id."
            print("[DEBUG] handleIncomingURL setting paymentStatus to .failure (payment-id missing in URL)")
        }

        // Polling will be triggered by .onAppear in the view now that refId should be set
    }
    
    // --- New Polling Function ---
    func pollPaymentStatus(environment: ApiEnvironment) {
        print("[POLL_DEBUG] pollPaymentStatus called. Checking refId...") // New Log
        guard !refId.isEmpty else {
            print("[POLL_DEBUG] Error: Missing refId for polling. Aborting poll.") // Updated Log
            // Optionally update status to indicate an error
            return
        }
        print("[POLL_DEBUG] refId found: \(refId). Checking environment baseURL...") // New Log
        
        // Access environment directly as it's non-optional
        let baseURL = environment.baseUrl
        print("[POLL_DEBUG] BaseURL: \(baseURL). Constructing full URL...") // New Log
        
        // Construct the full URL
        let fullURL = baseURL.appendingPathComponent("v2/payments").appendingPathComponent(refId)
        print("[POLL_DEBUG] Polling URL: \(fullURL). Starting URLSession task...") // New Log
 
        DispatchQueue.main.async {
            print("[POLL_DEBUG] Setting isCheckingStatus = true") // New Log
            self.isCheckingStatus = true // Indicate polling started
        }
 
        var request = URLRequest(url: fullURL)
        request.httpMethod = "GET"
        
        // Add Authorization header
        let apiKey = environment.apiKey
        if !apiKey.isEmpty {
            request.setValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization") // Use Basic Auth like initiatePayment
            print("[POLL_DEBUG] Added Authorization header (Basic).") // Updated log
        } else {
            print("[POLL_DEBUG] Warning: API Key is empty. Authorization header not added.")
        }
 
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Ensure UI updates happen on the main thread
            DispatchQueue.main.async {
                print("[POLL_DEBUG] URLSession completed. Setting isCheckingStatus = false") // New Log
                self?.isCheckingStatus = false // Indicate polling finished
                
                if let error = error {
                    print("[POLL_DEBUG] Polling Error (Network/Transport): \(error.localizedDescription)") // Updated Log
                    // Update UI to show polling error?
                    self?.statusString = "Polling Failed"
                    self?.statusReasonInformation = error.localizedDescription
                    // TODO: Decide if paymentStatus should change on polling failure
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    print("[POLL_DEBUG] Polling Error: Invalid HTTP status code \((response as? HTTPURLResponse)?.statusCode ?? 0)") // Updated Log
                    self?.statusString = "Polling Error"
                    self?.statusReasonInformation = "Server returned status \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    // TODO: Decide if paymentStatus should change on HTTP error
                    return
                }
                
                guard let data = data else {
                    print("[POLL_DEBUG] Polling Error: No data received.") // Updated Log
                    self?.statusString = "Polling Error"
                    self?.statusReasonInformation = "No data from server"
                    // Decide if paymentStatus should change
                    return
                }
                print("[POLL_DEBUG] Received data. Attempting JSON decoding...") // New Log
                
                do {
                    // Decode using the correct struct for the GET response
                    let decoder = JSONDecoder()
                    let paymentStatusResponse = try decoder.decode(PaymentStatusResponse.self, from: data)
                    
                    // Access the nested payment details object
                    let paymentDetails = paymentStatusResponse.payment 
 
                    // Log the decoded status
                    print("[POLL_DEBUG] Decoding successful. API Status: \(paymentDetails.status)") // New Log
                    
                    // Update published properties with polled data
                    self?.paymentStatus = self?.mapApiStatus(paymentDetails.status) // Update status based on API
                    self?.statusString = paymentDetails.status                              // Store raw API status
                    self?.statusReasonInformation = paymentDetails.statusReasonInformation // Update reason
                    self?.value = paymentDetails.initiation.amount.value                      // Update amount
                    self?.currency = paymentDetails.initiation.amount.currency                // Update currency
                    // self.refId should already be correct
                    
                    print("[POLL_DEBUG] Polling Success: Handler updated. Mapped Status: \(String(describing: self?.paymentStatus))")
                    
                } catch {
                    print("[POLL_DEBUG] Polling Error: Decoding failed - \(error)") // Updated Log
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[POLL_DEBUG] Received JSON string: \(jsonString)") // Log raw JSON on error
                    }
                    self?.statusString = "Polling Error"
                    self?.statusReasonInformation = "Could not process server response."
                    // TODO: Decide if paymentStatus should change on decoding error
                }
            }
        }.resume()
    }
    // --- End Polling Function ---

    func reset() {
        paymentStatus = nil
        statusString = ""
        statusReasonInformation = nil
        currency = ""
        value = ""
        refId = ""
        isCheckingStatus = false
        print("[DEBUG] PaymentCompletionHandler reset")
    }
}

// --- API Response Structures (Moved outside class) ---
