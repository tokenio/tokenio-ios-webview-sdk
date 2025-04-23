# TokenTestiOS SDK Integration Guide
This guide will help you quickly integrate the TokenTestiOS payment SDK into your own iOS app using an **in-app WebView** flow.

## Quick Start
1. Add the SDK files (`PaymentService.swift`, `PaymentWebView.swift`, `PaymentCompletionHandler.swift`) to your project.
2. Register your custom callback URL scheme (e.g., `paymentdemoapp://`) in your app's Info.plist.
3. Implement `PaymentCompletionHandler` as a `@StateObject` in your main `App` struct and inject it into your view hierarchy using `.environmentObject()`.
4. Add `.onOpenURL` to your main app entry point (`WindowGroup` or `Scene`) to handle callbacks.
5. In your payment initiation view (e.g., `ContentView`), prepare payment details and call `PaymentService.shared.initiatePayment` within a `Task`.
6. Store the returned `redirectUrl` in a `@State` variable.
7. Use `.navigationDestination` (within a `NavigationStack`) tied to this `@State` variable to present the `PaymentWebView`.
8. Handle the final payment result in your callback handler (`PaymentCompletionHandler`), typically by observing its published properties to update the UI (e.g., show a result sheet).

## Overview
The SDK simplifies initiating payments, presenting the payment provider's interface within your app using a secure WebView, handling callbacks, and retrieving payment results.

## Core Components

These are the essential files and concepts you'll work with:

1.  **`PaymentService.swift`**: Manages communication with the payment provider's API (e.g., Token.io).
    *   `initiatePayment`: Starts the payment process, requiring details like amount, currency, creditor info, callback URL, and a CSRF state. Returns the redirect URL.
    *   `getPaymentStatus`: Checks the status of an existing payment using its ID.
    *   Includes the `ApiEnvironment` enum for selecting different API endpoints (dev, sandbox, beta). It also handles API key retrieval via a `Bundle` extension.
    *   Includes `PaymentRequest`, `PaymentResponse`, and `PaymentStatusResponse` structs for encoding/decoding API data.
2.  **`PaymentWebView.swift`**: A SwiftUI `View` that wraps a `WKWebView` (using the internal `PaymentWebViewLoader` which is a `UIViewRepresentable`).
    *   It's presented using SwiftUI's navigation system (e.g., `.navigationDestination` within a `NavigationStack`).
    *   Loads the payment URL provided by `PaymentService`.
    *   Handles WebView navigation, delegates actions, and manages loading/error/completion states shown to the user.
    *   Includes a `Coordinator` (`WKNavigationDelegate`, `WKUIDelegate`) to intercept navigation, handle callbacks (by detecting the custom scheme), and manage external app redirects (like bank apps).
3.  **`PaymentCompletionHandler.swift`**: An `ObservableObject` class responsible for:
    *   Receiving the callback URL via the app's `.onOpenURL`.
    *   Storing an `expectedState` for CSRF validation.
    *   Parsing the URL parameters (e.g., `payment-id`, `state`) from the callback.
    *   Validating the received state against the `expectedState`.
    *   Calling `pollPaymentStatus` to fetch the final payment outcome from the API.
    *   Publishing the final payment status (e.g., `.success`, `.failure`, `.pending`) and details for the UI to react to.
4.  **`Bundle+ApiKey.swift` (or similar extension, currently integrated in `PaymentService.swift`)**: Provides secure access to the API Key, first checking the `API_KEY` environment variable, then falling back to the app's `Info.plist`.
5.  **`YourAppApp.swift` (e.g., `TokenTestiOSApp.swift`)**: Your main SwiftUI `App` struct. This is where you'll:
    *   Initialize `PaymentCompletionHandler` as a `@StateObject`.
    *   Attach the `.onOpenURL` modifier to your main `WindowGroup` or `Scene`.
    *   Inject `PaymentCompletionHandler` into your view hierarchy using `.environmentObject()`.
6.  **Your UI View (e.g., `ContentView.swift`)**: The view where the user initiates the payment. It will typically:
    *   Wrap content in a `NavigationStack`.
    *   Have access to `PaymentCompletionHandler` via `@EnvironmentObject`.
    *   Contain UI elements (like a "Pay" button) and state variables (`@State`) to hold payment details (amount, currency, etc.) and the redirect URL obtained from `initiatePayment`.
    *   Call `PaymentService.shared.initiatePayment` within a `Task`.
    *   Update the `@State` variable holding the redirect URL upon success.
    *   Use `.navigationDestination(isPresented: ...)` bound to the redirect URL state variable to present `PaymentWebView`.
    *   Present a result view (like `PaymentResultView`) based on the status published by `PaymentCompletionHandler` (often via `.sheet` triggered by changes in the handler's status).
7.  **Custom URL Scheme**: Essential for the payment provider/bank to redirect the user back to your app after authentication.

## Prerequisites
- iOS app targeting iOS 15.0+ (due to `NavigationStack` usage, adjust if using older navigation like `NavigationView`)
- Add the required SDK source files (`PaymentService.swift`, `PaymentWebView.swift`, `PaymentCompletionHandler.swift`) to your project.
- Xcode: Latest stable version recommended.
- Valid payment provider API credentials (API Key).

## Secure API Key Storage
> **Important:** Never store API keys directly in your source code or commit them to version control.

This project uses a `Bundle` extension (found within `PaymentService.swift`) to retrieve the API Key:

1.  **Environment Variable (Recommended for Dev/CI):** Set an environment variable named `API_KEY` in your Xcode scheme's "Run" arguments (Edit Scheme > Run > Arguments > Environment Variables) or your CI environment. The code prioritizes this.
    ```
    API_KEY=your-api-key-here
    ```
2.  **Info.plist (Fallback):** Add a key named `API_KEY` to your target's `Info.plist` file with the API key as its string value. Use this for release builds, potentially managing different Plist files per configuration or using build scripts to populate the value.

```swift
// Example from PaymentService.swift
extension Bundle {
    var apiKey: String {
        // 1. Prefer environment variable
        if let envKey = ProcessInfo.processInfo.environment["API_KEY"], !envKey.isEmpty {
            return envKey
        }
        // 2. Fallback to Info.plist
        return object(forInfoDictionaryKey: "API_KEY") as? String ?? "" // Return empty string if not found
    }
}

// Usage within PaymentService for headers:
request.addValue("Basic \(environment.apiKey)", forHTTPHeaderField: "Authorization")
```

## WebView Domain Allowlist & App Redirects
### Domain Allowlist:

The PaymentWebView's Coordinator contains a set of allowedDomains. Only URLs matching these domains (and standard http/https) will load within the WebView. This prevents unexpected or malicious redirects.

- Ensure your payment provider's web flow domains (e.g., https://app.token.io, https://app.sandbox.token.io, etc.) are included.
- Other domains will attempt to open externally (Safari/other apps).

### App-to-App Redirects:

The Coordinator also checks for specific URL schemes known to belong to banking apps (e.g., monzo://, hsbc://). If detected:

- Navigation inside the WebView is cancelled.
- The app attempts to open the URL using UIApplication.shared.open.
- If the specific app isn't installed or the OS doesn't allow the redirect, it may fallback to Safari or show an error.

## Integration Steps
1. Add SDK Files:

Copy PaymentService.swift, PaymentWebView.swift, and PaymentCompletionHandler.swift into your Xcode project.

2. Implement PaymentCompletionHandler:

Ensure your PaymentCompletionHandler.swift matches the structure provided in the sample project, including:

- Published properties for status and details (paymentStatus, statusString, etc.).
- State properties (refId, expectedState, isCheckingStatus).
- handleIncomingURL method with URL parsing and state validation logic.
- pollPaymentStatus method with API call logic (using Basic Auth and PaymentStatusResponse decoding).
- reset method to clear state.

3. Configure Custom URL Scheme:

- Choose a unique URL scheme (e.g., myapp-payment).
- Register it in your target's Info.plist under URL Types:
    - Identifier: com.yourcompany.yourapp.payment (or similar unique identifier)
    - URL Schemes: paymentdemoapp (replace with your chosen scheme)

4. Add .onOpenURL Handler:

Attach the .onOpenURL modifier to your main WindowGroup (or Scene) to receive the callback URL:

```swift
@main
struct YourApp: App {
    @StateObject var paymentCompletionHandler = PaymentCompletionHandler()

    var body: some Scene {
        WindowGroup {
            ContentView() // Your main view
                .environmentObject(paymentCompletionHandler)
                .onOpenURL { url in
                    // Pass the URL to the handler
                    paymentCompletionHandler.handleIncomingURL(url)
                }
        }
    }
}
```

5. Initiate Payment and Present WebView:

In your view (e.g., ContentView), setup state variables and the payment initiation logic:

```swift
struct ContentView: View {
    @EnvironmentObject var paymentCompletionHandler: PaymentCompletionHandler
    @State private var selectedEnvironment: ApiEnvironment = .sandbox // Or your default
    @State private var paymentUrl: URL? = nil // Holds the redirect URL from API
    @State private var isLoading: Bool = false
    // ... other state vars for amount, currency etc.

    var body: some View {
        NavigationStack { // Essential for .navigationDestination
            VStack {
                // ... Your UI elements for amount, currency selection ...

                Button("Pay Now") {
                    initiatePaymentFlow()
                }
                .disabled(isLoading)

                if isLoading { ProgressView("Initiating...") }

                Spacer()
            }
            .navigationTitle("Checkout")
            // **** This presents the WebView when paymentUrl is set ****
            .navigationDestination(isPresented: Binding<Bool>(
                get: { paymentUrl != nil },
                set: { if !$0 { paymentUrl = nil } } // Reset on dismiss/back
            )) {
                // Pass the URL and environment to the WebView
                // Ensure PaymentCompletionHandler is also available via .environmentObject
                PaymentWebView(environment: selectedEnvironment, initialUrl: paymentUrl)
            }
            // Example: Show result sheet based on handler status
            .sheet(isPresented: Binding<Bool>( /* ... Binding logic based on paymentCompletionHandler.paymentStatus ... */ )) {
                PaymentResultView(environment: selectedEnvironment)
                    .environmentObject(paymentCompletionHandler) // Pass handler
            }
            // ... other modifiers ...
        }
    }

    // Helper function to generate a secure random string
    func generateRandomState() -> String {
        // Use a cryptographically secure random generator
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard status == errSecSuccess else {
            // Handle error appropriately, fallback to simpler method for non-critical cases if needed
            print("Error generating secure random bytes: \(status)")
            return UUID().uuidString // Fallback, less secure
        }
        return Data(randomBytes).base64URLEncodedString() // Use URL-safe Base64
    }


    func initiatePaymentFlow() {
        isLoading = true
        // 1. Generate Secure State (CSRF protection)
        let state = generateRandomState()
        paymentCompletionHandler.expectedState = state // Pass to handler for validation

        // 2. Prepare payment details from UI state
        let amountValue = "1.00" // Get from @State
        let currency = "GBP" // Get from @State
        let callbackUrl = "paymentdemoapp://payment-complete" // Use YOUR scheme
        // ... get other details like creditor info ...
        let creditorName = "Merchant Name"
        let creditorSortCode = "123456" // Example
        let creditorAccountNumber = "98765432" // Example
        let localInstrument = "FASTER_PAYMENTS" // Example

        // 3. Call PaymentService within a Task
        Task {
            do {
                let (redirectUrl, _) = try await PaymentService.shared.initiatePayment(
                    environment: selectedEnvironment,
                    currency: currency,
                    amountValue: amountValue,
                    localInstrument: localInstrument,
                    creditorName: creditorName,
                    creditorIBAN: nil, // Provide if needed
                    creditorSortCode: creditorSortCode,
                    creditorAccountNumber: creditorAccountNumber,
                    remittancePrimary: "Invoice 123",
                    remittanceSecondary: "",
                    callbackUrl: callbackUrl,
                    state: state // Pass the generated state
                )
                // 4. Update state to trigger navigation to PaymentWebView
                self.paymentUrl = redirectUrl
                self.isLoading = false // Stop loading indicator
            } catch {
                // TODO: Handle error (show alert, log, etc.)
                print("Error initiating payment: \(error)")
                self.isLoading = false // Stop loading indicator
                // Optionally show an error alert to the user
            }
        }
    }
}

// Helper extension for URL-safe Base64 encoding (can be placed globally or in PaymentService)
extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // Remove padding
    }
}
```

6. Handle Payment Result:

Observe changes in paymentCompletionHandler.paymentStatus in your UI (e.g., ContentView or a dedicated PaymentResultView) to display the final outcome (success, failure, details) to the user, often presented in a sheet or overlay.

## CSRF Protection (Crucial)
- Generate State: Before calling initiatePayment, generate a unique, cryptographically secure random string (see generateRandomState() example above).
- Pass State: Include this string in the state parameter of the initiatePayment call.
- Store State: Give the same generated state string to your PaymentCompletionHandler (e.g., paymentCompletionHandler.expectedState = state).
- Verify State: In PaymentCompletionHandler.handleIncomingURL, extract the state parameter from the incoming callback URL and strictly compare it to the expectedState. Abort the process if they do not match.

**Why?** This prevents attackers from tricking your app into processing a payment result that didn't originate from a flow initiated by the current user session.

## Final Integration Checklist
[ ] Added SDK files (PaymentService.swift, PaymentWebView.swift, PaymentCompletionHandler.swift) to project.
[ ] Registered custom callback URL scheme in Info.plist.
[ ] Implemented PaymentCompletionHandler as @StateObject and injected via .environmentObject.
[ ] Implemented .onOpenURL handler in main App struct.
[ ] Implemented secure state generation for CSRF protection.
[ ] Passed generated state to initiatePayment and PaymentCompletionHandler.
[ ] Verified state matching in handleIncomingURL.
[ ] Implemented payment initiation logic calling PaymentService.initiatePayment with correct parameters.
[ ] Used .navigationDestination (or similar SwiftUI presentation) bound to the redirect URL state to present PaymentWebView.
[ ] Handled final payment results by observing PaymentCompletionHandler.
[ ] Configured API Key storage securely (environment variable or Info.plist).
[ ] Tested the full in-app payment flow.
[ ] Reviewed WebView domain allowlist and external app redirect schemes.

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

**5. Initiate Payment and Launch External URL:**

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
        // 3. Open the returned payment URL externally via UIApplication
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
