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

## Secure API Key Storage
> **Important:** Never store API keys directly in your source code or commit them to version control.
>
> 1. Create a `.xcconfig` file for each environment (e.g., `Config/Sandbox.xcconfig`) and add your API key:
>    ```
>    API_KEY=your-sandbox-api-key-here
>    ```
> 2. Link each `.xcconfig` file to the appropriate build configuration in Xcode.
> 3. In your `Info.plist`, add a key named `API_KEY` with the value `$(API_KEY)`.
> 4. The SDK will read the API key from `Info.plist` at runtime.
>
> See `Configuration.swift` for details.

## Integration Steps

> **Note:**
> When a payment flow requires opening a bank app and the app is not installed, the SDK will automatically open the bank’s authentication page in the device’s default browser (Safari). This ensures compatibility with banks that do not allow authentication within in-app browsers.

> **Important:**
> The SDK only allows navigation within the in-app WebView for URLs belonging to a specific set of allowed merchant/payment provider domains.
> - All other http(s) URLs—including bank authentication and external pages—will be automatically opened in the device’s default browser (Safari).
> - **You must update the `allowedDomains` set in `PaymentWebView.swift` to include your merchant and payment provider domains.**
> - For example, to support all Token environments, your allow list should include:
>   - `https://app.token.io`
>   - `https://app.dev.token.io`
>   - `https://app.sandbox.token.io`
>   - `https://app.beta.token.io`
> - Any domain not in this list will be opened externally for security and compatibility.
>
> **App-to-App Redirects:**
> If a payment or bank app is installed on the user's device, the SDK will automatically open that app via its custom URL scheme for authentication or authorization. If the app is not installed, the SDK will fall back to opening the authentication page in the device's default browser (Safari). This ensures a seamless and secure user experience.

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
    @Published var refId: String = ""
    @Published var isCheckingStatus: Bool = false

    // Enum to represent final states for the UI
    enum PaymentStatus {
        case success, failure, cancelled, pending
    }

    func handleIncomingURL(_ url: URL) {
        print("Received URL: \(url.absoluteString)")
        guard url.scheme == "paymentdemoapp", url.host == "payment-complete" else { // Replace with YOUR scheme/host
            return
        }
        // TODO: Parse payment-id, state, etc. from URL
        // TODO: Verify the state parameter matches the expected value (see CSRF Protection)
        // TODO: Call PaymentService.getPaymentStatus and update published properties
    }

    func reset() {
        paymentStatus = nil
        statusString = ""
        statusReasonInformation = nil
        isCheckingStatus = false
    }
}
```

**3. Configure Custom URL Scheme:**

*   Choose a unique URL scheme (e.g., `myapp-payment`).
*   Register it in your target's `Info.plist` under `URL Types`:
    *   **Identifier:** `com.yourcompany.yourapp.payment` (or similar)
    *   **URL Schemes:** `paymentdemoapp` (or your chosen scheme)

**4. Add `.onOpenURL` Handler:**

Attach the `.onOpenURL` modifier to your main `WindowGroup` (or Scene) to receive the callback URL:

```swift
@main
struct YourApp: App {
    @StateObject var paymentCompletionHandler = PaymentCompletionHandler()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(paymentCompletionHandler)
                .onOpenURL { url in
                    paymentCompletionHandler.handleIncomingURL(url)
                }
        }
    }
}
```

**5. Initiate Payment and Present WebView:**

```swift
// 1. Prepare the payment request
let paymentRequest = PaymentRequest(
    initiation: Initiation(
        refId: "YOUR_REF_ID", // TODO: Replace with your unique reference
        flowType: "FULL_HOSTED_PAGES",
        remittanceInformationPrimary: "Invoice #123",
        remittanceInformationSecondary: "Payment for Goods",
        amount: Amount(value: "100.00", currency: "GBP"),
        localInstrument: "FASTER_PAYMENTS",
        creditor: Creditor(
            name: "Recipient Name",
            sortCode: "123456",
            accountNumber: "12345678"
        ),
        callbackUrl: "paymentdemoapp://payment-complete", // TODO: Replace with your scheme
        callbackState: "random-state-string" // TODO: Generate a secure random string
    ),
    pispConsentAccepted: true
)

// 2. Call PaymentService to initiate payment and get the payment URL
Task {
    do {
        let (url, _) = try await PaymentService.shared.initiatePayment(
            environment: .sandbox, // or .production
            paymentRequest: paymentRequest
        )
        // 3. Present the PaymentWebView
        // Option 1: NavigationLink
        NavigationLink(destination: PaymentWebView(initialUrl: url, environment: .sandbox)) {
            Text("Pay Now")
        }
        // Option 2: Sheet presentation
        // .sheet(isPresented: $showWebView) {
        //     PaymentWebView(initialUrl: url, environment: .sandbox)
        // }
    } catch {
        // TODO: Handle error (show alert, etc.)
    }
}
```

**6. Handle Payment Result:**

The SDK will update `PaymentCompletionHandler` with the result. You can observe its published properties to update your UI accordingly.

```swift
if let status = paymentCompletionHandler.paymentStatus {
    // Show result screen or message
}
```

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
