# TokenTestiOS SDK Integration Guide
This guide will help you quickly integrate the TokenTestiOS payment SDK into your own iOS app with minimal effort and maximum clarity.

## Quick Start
1. Add the SDK files (`PaymentService.swift`, `PaymentWebView.swift`, `Configuration.swift`) to your project.
2. Register your custom callback URL scheme (e.g. `paymentdemoapp://`) in your app's Info.plist.
3. Implement a `PaymentCompletionHandler` as shown below.
4. Add `.onOpenURL` to your main app entry point to handle callbacks.
5. Prepare a `PaymentRequest` with a secure `callbackState` (see CSRF Protection below).
6. Present the payment WebView using the URL from `PaymentService.initiatePayment`.
7. Always handle the payment result in your callback handler.

## Overview
The SDK simplifies the process of initiating payments, handling redirects and callbacks, and retrieving payment results. Integration requires only a few lines of code—no need to manage networking, WebView logic, or result parsing yourself.

**Important:**
> Do **NOT** implement your own WebView for payment flows. Always use the provided `PaymentWebView` for all payment operations. This ensures security, compatibility, and a seamless user experience.

## Core Components

These are the essential files and concepts you'll work with:

1.  **`PaymentService.swift`**: Manages communication with the payment provider's API (e.g., Token.io) to initiate payments (`initiatePayment`) and check their status (`getPaymentStatus`). Requires configuration (see `Configuration.swift`).
2.  **`PaymentWebView.swift`**: A SwiftUI `UIViewRepresentable` view that wraps a `WKWebView`. It loads the payment URL provided by `PaymentService`, handles navigation (including detecting your custom URL scheme), and delegates actions to its `Coordinator`.
    *   **`Coordinator` (within `PaymentWebView.swift`)**: Acts as the `WKNavigationDelegate` and `WKUIDelegate`. It intercepts navigation attempts, specifically looking for your custom URL scheme to hand off the redirect back to the OS.
3.  **`PaymentCompletionHandler.swift` (Create this file)**: An `ObservableObject` class responsible for:
    *   Receiving the callback URL via the app's `.onOpenURL`.
    *   Parsing the URL parameters (e.g., `payment-id`, `state`).
    *   Calling `PaymentService.getPaymentStatus` to verify the payment outcome.
    *   Publishing the final payment status (e.g., `.success`, `.failure`, `.pending`) for the UI to react to.
4.  **`Configuration.swift`**: Defines API environments (`ApiEnvironment` enum) and holds base URLs and potentially API keys (use secure storage for production keys!).
5.  **`YourAppApp.swift` (e.g., `TokenTestiOSApp.swift`)**: Your main SwiftUI `App` struct. This is where you'll:
    *   Initialize `PaymentCompletionHandler` as a `@StateObject`.
    *   Attach the `.onOpenURL` modifier to your main `WindowGroup` to receive the callback URL.
    *   Inject `PaymentCompletionHandler` into your view hierarchy using `.environmentObject()`.
6.  **Your UI View (e.g., `ContentView.swift`)**: The view where the user initiates the payment. It will typically:
    *   Have access to `PaymentCompletionHandler` via `@EnvironmentObject`.
    *   Contain UI elements (like a "Pay" button).
    *   Call `PaymentService.initiatePayment`.
    *   Use the resulting URL to present the `PaymentWebView` (e.g., via `NavigationLink` or `.sheet`).
    *   Present a result view (like `PaymentResultView`) based on the status published by `PaymentCompletionHandler`.
7.  **Custom URL Scheme**: Essential for the payment provider/bank to redirect the user back to your app after authentication.

## Prerequisites
- iOS app targeting iOS 14.0+
- Add the SDK module or source files to your project
- Add required dependencies (see below)
- Xcode: Latest stable version recommended
- Valid payment provider API credentials

## Integration Steps

**1. Add SDK Files:**

*   Copy `PaymentService.swift`, `PaymentWebView.swift`, and `Configuration.swift` into your Xcode project.

**2. Create `PaymentCompletionHandler.swift`:**

*   Create a new Swift file named `PaymentCompletionHandler.swift`.
*   Define a class conforming to `ObservableObject` similar to the one currently in `TokenTestiOSApp.swift`. Include:
    *   `@Published` properties for `paymentStatus`, `statusString`, `statusReasonInformation`, etc.
    *   The `PaymentStatus` enum (`.success`, `.failure`, `.pending`, `.cancelled`).
    *   The `handleIncomingURL(_:)` function to parse the URL, call `PaymentService.getPaymentStatus`, and update the published properties.
    *   A `reset()` function.

```swift
// Example: PaymentCompletionHandler.swift
import Foundation
import Combine

class PaymentCompletionHandler: ObservableObject {
    // Published properties for UI updates
    @Published var paymentStatus: PaymentStatus? = nil
    @Published var statusString: String = ""
    @Published var statusReasonInformation: String? = nil
    @Published var currency: String = ""
    @Published var value: String = ""
    @Published var refId: String = ""
    @Published var isCheckingStatus: Bool = false

    // Enum to represent final states for the UI
    enum PaymentStatus {
        case success, failure, cancelled, pending
    }

    func handleIncomingURL(_ url: URL) {
        print("Received URL: \(url.absoluteString)")
        guard url.scheme == "paymentdemoapp", url.host == "payment-complete" else { // Replace with YOUR scheme/host
            print("URL is not the expected payment completion URL.")
            return
        }

        // TODO: Implement CSRF state verification here if needed

        // --- Extract payment ID and environment --- 
        // (Adapt query parameter names: 'payment-id', 'state', 'env' as needed)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let paymentId = queryItems.first(where: { $0.name == "payment-id" })?.value else {
            print("Could not parse URL or extract payment-id.")
            DispatchQueue.main.async {
                 self.paymentStatus = .failure
                 self.statusString = "Error"
                 self.statusReasonInformation = "Could not read payment result identifier."
                 self.postCompletionNotification() // Notify UI
            }
            return
        }
        
        // Example: Extract environment from state (adjust parsing as needed)
        var environment: ApiEnvironment = .sandbox // Default
        if let stateParam = queryItems.first(where: { $0.name == "state" })?.value,
           let stateComponents = URLComponents(string: "?" + stateParam),
           let envValue = stateComponents.queryItems?.first(where: { $0.name == "env" })?.value,
           let parsedEnv = ApiEnvironment(rawValue: envValue) {
            environment = parsedEnv
        } else {
             print("⚠️ Could not parse environment from state. Using default: \(environment.rawValue)")
        }

        // --- Call PaymentService to get final status --- 
        Task {
            await MainActor.run { isCheckingStatus = true }
            do {
                let statusDetails = try await PaymentService.shared.getPaymentStatus(paymentId: paymentId, environment: environment)
                await MainActor.run {
                    self.statusString = statusDetails.status
                    self.statusReasonInformation = statusDetails.statusReasonInformation
                    self.currency = statusDetails.currency
                    self.value = statusDetails.value
                    self.refId = statusDetails.refId

                    // Map API status string to PaymentStatus enum
                    switch statusDetails.status.uppercased() {
                        // Add your specific success/pending/failure cases here
                        case "INITIATION_COMPLETED", "SETTLEMENT_IN_PROGRESS", "SETTLEMENT_COMPLETED", "SUCCESS", "EXECUTED":
                             self.paymentStatus = .success
                        case "INITIATION_PENDING", /* ... other pending statuses ... */ "INITIATION_PROCESSING":
                             self.paymentStatus = .pending
                        default:
                             self.paymentStatus = .failure
                    }
                    self.isCheckingStatus = false
                    postCompletionNotification() // Notify UI
                }
            } catch {
                print("Error checking payment status: \(error)")
                await MainActor.run {
                    self.paymentStatus = .failure
                    self.statusString = "Error"
                    self.statusReasonInformation = "Could not verify payment status."
                    self.isCheckingStatus = false
                    postCompletionNotification() // Notify UI
                }
            }
        }
    }

    // Helper to notify UI (if using NotificationCenter)
    func postCompletionNotification() {
         // Consider using Combine publishers directly instead of NotificationCenter
         NotificationCenter.default.post(name: NSNotification.Name("PaymentCompleted"), object: nil, userInfo: [/* ... */])
    }

    func reset() {
        paymentStatus = nil
        statusString = ""
        statusReasonInformation = nil
        // Reset other properties
        isCheckingStatus = false
    }
}
```

**3. Configure Custom URL Scheme:**

*   Choose a unique URL scheme (e.g., `myapp-payment`).
*   Register it in your target's `Info.plist` under `URL Types`:
    *   **Identifier:** `com.yourcompany.yourapp.payment` (or similar)
    *   **URL Schemes:** `myapp-payment` (your chosen scheme)
    *   **Role:** `Editor`

**4. Update `PaymentService.swift`:**

*   Ensure the `callbackUrl` parameter in `PaymentRequest` (within `initiatePayment`) uses **your** custom URL scheme and a defined host/path (e.g., `"myapp-payment://payment-complete"`).
*   Configure API keys and base URLs in `Configuration.swift`.

**5. Update `PaymentWebView.swift`:**

*   Change the hardcoded scheme check (`if url.scheme?.lowercased() == "paymentdemoapp"`) to use **your** custom scheme.

**6. Set up your App Struct (`YourAppApp.swift`):**

```swift
import SwiftUI

@main
struct YourAppApp: App {
    // Create and own the handler instance
    @StateObject private var paymentCompletionHandler = PaymentCompletionHandler()

    var body: some Scene {
        WindowGroup {
            ContentView() // Your root view
                .environmentObject(paymentCompletionHandler) // Inject handler
                .onOpenURL { url in
                    // Pass the incoming URL to the handler
                    paymentCompletionHandler.handleIncomingURL(url)
                }
        }
    }
}
```

**7. Implement Payment Initiation in Your UI (`ContentView.swift`):**

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var paymentCompletionHandler: PaymentCompletionHandler
    @State private var paymentUrl: URL? = nil // To trigger webview presentation
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                // ... your checkout UI ...

                Button("Pay Now") {
                    isLoading = true
                    paymentCompletionHandler.reset() // Reset state before initiating
                    Task {
                        do {
                            // TODO: Add parameters (amount, currency, destination, CSRF state)
                            let (url, _) = try await PaymentService.shared.initiatePayment(
                                environment: .sandbox, // Or .production
                                currency: "GBP", 
                                amountValue: "10.00", 
                                remittanceInformationPrimary: "REF123", 
                                destinationSortCode: "040004", // If applicable
                                destinationAccountNumber: "12345678", // If applicable
                                destinationIban: nil, // If applicable
                                callbackUrl: "myapp-payment://payment-complete", // YOUR scheme
                                callbackState: "YOUR_CSRF_STATE_HERE" // Optional CSRF
                            )
                            await MainActor.run {
                                self.paymentUrl = url // Set URL to present PaymentWebView
                                self.isLoading = false
                            }
                        } catch {
                             await MainActor.run {
                                 print("Error initiating payment: \(error)")
                                 self.isLoading = false
                                 // TODO: Show error alert to user
                             }
                        }
                    }
                }
                .disabled(isLoading)

                // --- Present PaymentWebView --- 
                // Option 1: NavigationLink (like TokenTestiOS example)
                // Requires paymentUrl to be non-nil
                 NavigationLink(
                     destination: paymentUrl.map { PaymentWebView(url: $0, customScheme: "myapp-payment") }, // Pass YOUR scheme
                     isActive: Binding<Bool>( 
                         get: { paymentUrl != nil }, 
                         set: { isActive in if !isActive { paymentUrl = nil } } 
                     ),
                     label: { EmptyView() }
                 )
                 
                 // Option 2: Sheet presentation
                 // .sheet(item: $paymentUrl) { url in 
                 //     PaymentWebView(url: url, customScheme: "myapp-payment")
                 // }
            }
            // --- Present Result Sheet --- 
            .sheet(isPresented: Binding<Bool>( 
                get: { paymentCompletionHandler.paymentStatus != nil }, 
                set: { _ in } 
            )) {
                 PaymentResultView(paymentCompletionHandler: paymentCompletionHandler)
            }
        }
    }
}

// --- PaymentResultView (Example - Adapt as needed) ---
struct PaymentResultView: View { 
    @ObservedObject var paymentCompletionHandler: PaymentCompletionHandler
    @Environment(\.dismiss) var dismiss
    // ... (Implementation similar to TokenTestiOS example) ...
    var body: some View { Text("Payment Result: \(paymentCompletionHandler.statusTitle)") /* ... Add icon, details, button ... */ }
    // ... computed properties for icon, color, title ...
}

## CSRF Protection (Recommended)
- **Generate State:** Before starting a payment, generate a unique, cryptographically random string for the `callbackState` parameter.
- **Include State:** Pass this state in the `callbackState` parameter of the `PaymentRequest`.
- **Store State:** Store the expected state value in a variable accessible when the callback URL arrives (e.g. a SwiftUI `@State` or `@StateObject`).
- **Verify State:** In `PaymentCompletionHandler.handleIncomingURL`, extract the `state` parameter from the callback URL and compare it to the expected value. Abort if they don't match.

**Why?**
This prevents attackers from forging payment callbacks to your app.

```swift
// TODO: Generate a secure random string for callbackState
let callbackState = UUID().uuidString // Example only; use a cryptographically secure generator for production
```

## Final Integration Checklist
- [ ] Added SDK files to my project
- [ ] Registered my custom callback URL scheme in Info.plist
- [ ] Implemented `.onOpenURL` handler
- [ ] Generate and store a secure state value for each payment
- [ ] Pass the state to the backend and verify it on callback
- [ ] Use only PaymentWebView for payment flows
- [ ] Handle payment results in the callback handler
- [ ] Tested the flow with both in-app and browser redirects
- [ ] Never hard-code production API keys in my app