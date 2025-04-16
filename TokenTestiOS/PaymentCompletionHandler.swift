import Foundation
import SwiftUI

class PaymentCompletionHandler: ObservableObject {
    @Published var paymentStatus: PaymentStatus? = nil
    @Published var statusString: String = ""
    @Published var statusReasonInformation: String? = nil
    @Published var currency: String = ""
    @Published var value: String = ""
    @Published var refId: String = ""
    @Published var isCheckingStatus: Bool = false // To indicate API call in progress

    enum PaymentStatus {
        case success, failure, cancelled, pending
    }

    func handleIncomingURL(_ url: URL) {
        // Example: paymentdemoapp://payment-complete?state=XYZ&status=success&refId=123&amount=10.00&currency=GBP&reason=Approved
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let queryItems = components.queryItems ?? []
        
        func value(for key: String) -> String? {
            queryItems.first(where: { $0.name == key })?.value
        }

        // Extract state and status
        let state = value(for: "state")
        let status = value(for: "status")
        let refId = value(for: "refId")
        let amount = value(for: "amount")
        let currency = value(for: "currency")
        let reason = value(for: "reason")

        // TODO: Optionally verify state matches expected (CSRF protection)
        // For now, we always show result if present

        // Set payment status and details
        if let status = status {
            switch status.lowercased() {
            case "success":
                paymentStatus = .success
            case "failure":
                paymentStatus = .failure
            case "cancelled":
                paymentStatus = .cancelled
            case "pending":
                paymentStatus = .pending
            default:
                paymentStatus = .failure
            }
        } else {
            paymentStatus = .failure
        }
        self.refId = refId ?? ""
        self.value = amount ?? ""
        self.currency = currency ?? ""
        self.statusReasonInformation = reason
    }

    func reset() {
        paymentStatus = nil
        statusString = ""
        statusReasonInformation = nil
        currency = ""
        value = ""
        refId = ""
        isCheckingStatus = false
    }
}
