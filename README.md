# Token.io WebView Integration for iOS

This guide shows you how to integrate Token.io's web-based payment flows into your existing iOS payment interface using a secure WebView implementation.

**Perfect for developers who already have a payment interface and just need to launch Token.io's web app securely.**

---

## 📋 Table of Contents

1. [Quick Overview](#quick-overview)
2. [What You Need](#what-you-need)
3. [WebView Components](#webview-components)
4. [Integration Steps](#integration-steps)
5. [Launching Token.io Web App](#launching-tokenio-web-app)
6. [Handling Payment Results](#handling-payment-results)
7. [Troubleshooting WebView Issues](#troubleshooting-webview-issues)

---

## 🎯 Quick Overview

If you already have a payment interface, you only need to:

1. **Add a secure WebView component** to launch Token.io's web app
2. **Handle payment callbacks** from the web app back to your app
3. **Process payment results** in your existing flow

**⚠️ Security First:**
> Use the provided WebView implementation - it handles security, SSL certificates, and proper callback routing that a basic WebView cannot.

---

## 🛠️ What You Need

Just **3 core files** and **2 simple steps**:

### Files to Copy:
1. **`PaymentService.swift`** - Handles Token.io API communication
2. **`PaymentWebView.swift`** - The secure WebView that launches Token.io
3. **`PaymentCompletionHandler.swift`** - Handles payment callbacks and results

### Steps:
1. **Add custom URL scheme to your Info.plist**
2. **Launch WebView from your existing payment flow**

That's it! 🎉

---

## 📱 WebView Components

### Core WebView Files You Need:

```
📁 From this demo project:
├── PaymentService.swift              # Token.io API Service
├── PaymentWebView.swift              # Main WebView Component
├── PaymentCompletionHandler.swift    # Callback Handler
└── Configuration.swift               # API Environment Config
```

**What each file does:**
- **`PaymentService`**: Communicates with Token.io API to create payment sessions
- **`PaymentWebView`**: Secure SwiftUI WebView that loads Token.io's web app
- **`PaymentCompletionHandler`**: Intercepts payment success/failure callbacks
- **`Configuration`**: Manages API environments (sandbox, beta, production)

---

## ⚡ Integration Steps

### Step 1: Add the WebView Files

Copy these 4 files to your Xcode project:
- `PaymentService.swift`
- `PaymentWebView.swift`
- `PaymentCompletionHandler.swift`
- `Configuration.swift`

### Step 2: Configure Custom URL Scheme

Add to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp.payment</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

### Step 3: Set Up Payment Handler in Your App

Update your main App struct:

```swift
@main
struct YourApp: App {
    @StateObject private var paymentHandler = PaymentCompletionHandler()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(paymentHandler)
                .onOpenURL { url in
                    paymentHandler.handleIncomingURL(url)
                }
        }
    }
}
```

### Step 4: Launch Token.io from Your Payment Flow

From your existing payment view:

```swift
struct PaymentView: View {
    @EnvironmentObject var paymentHandler: PaymentCompletionHandler
    @State private var paymentUrl: URL? = nil
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack {
                // Your existing payment UI

                Button("Pay with Bank") {
                    initiateTokenPayment()
                }
                .disabled(isLoading)

                if isLoading {
                    ProgressView("Initiating payment...")
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { paymentUrl != nil },
                set: { if !$0 { paymentUrl = nil } }
            )) {
                PaymentWebView(environment: .sandbox, initialUrl: paymentUrl)
            }
            .sheet(isPresented: Binding(
                get: { paymentHandler.paymentStatus != nil },
                set: { _ in }
            )) {
                PaymentResultView()
            }
        }
    }

    private func initiateTokenPayment() {
        isLoading = true
        paymentHandler.reset()

        PaymentService.shared.initiatePayment(
            environment: .sandbox,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "FASTER_PAYMENTS",
            creditorName: "Your Business",
            creditorIBAN: nil,
            creditorSortCode: "123456",
            creditorAccountNumber: "12345678"
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let (url, _)):
                    paymentUrl = url
                case .failure(let error):
                    print("Payment error: \(error)")
                }
            }
        }
    }
}
```

---

## 🚀 Launching Token.io Web App

### Option A: With Your Token.io Payment URL

If you already generate Token.io payment URLs:

```swift
private func launchTokenPayment(tokenPaymentUrl: URL) {
    paymentUrl = tokenPaymentUrl
}
```

### Option B: Create Payment Session and Launch WebView

To create a payment session and get the web app URL:

```swift
// 1. Create payment session
private func createPaymentSessionAndLaunch() {
    PaymentService.shared.initiatePayment(
        environment: .sandbox,
        currency: "GBP",           // or "EUR"
        amountValue: "100.50",     // Always use decimal format
        localInstrument: "FASTER_PAYMENTS", // or "SEPA_INSTANT"
        creditorName: "Your Business Name",
        creditorIBAN: nil,         // For EUR payments: "GB29NWBK60161331926819"
        creditorSortCode: "123456", // For UK payments
        creditorAccountNumber: "12345678" // For UK payments
    ) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let (url, state)):
                // Launch WebView with the payment URL
                self.paymentUrl = url
            case .failure(let error):
                // Handle error
                print("Failed to create payment: \(error)")
            }
        }
    }
}

// 2. Helper for amount formatting
private func formatAmount(_ amount: Double) -> String {
    return String(format: "%.2f", amount)
}
```

**API Key Configuration:**

Add to your `Info.plist`:
```xml
<key>API_KEY_SANDBOX</key>
<string>YOUR_SANDBOX_API_KEY</string>
<key>API_KEY_BETA</key>
<string>YOUR_BETA_API_KEY</string>
```

---

## 🔄 Handling Payment Results

The WebView will return results to your app in two ways:

### In-App Results (Most Common)
When payment completes within the WebView:

```swift
struct PaymentResultView: View {
    @EnvironmentObject var paymentHandler: PaymentCompletionHandler
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Status Icon
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 60))

            Text(statusTitle)
                .font(.title2)
                .fontWeight(.bold)

            // Payment Details
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Status", value: paymentHandler.statusString)
                DetailRow(label: "Amount", value: "\(paymentHandler.value) \(paymentHandler.currency)")
                DetailRow(label: "Reference", value: paymentHandler.refId)

                if let reason = paymentHandler.statusReasonInformation {
                    DetailRow(label: "Details", value: reason)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button("Done") {
                paymentHandler.reset()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            // Auto-poll for payment status
            if !paymentHandler.refId.isEmpty {
                paymentHandler.pollPaymentStatus(environment: .sandbox)
            }
        }
    }

    private var statusIcon: String {
        switch paymentHandler.paymentStatus {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .pending: return "clock.circle.fill"
        case .cancelled: return "xmark.circle"
        case nil: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch paymentHandler.paymentStatus {
        case .success: return .green
        case .failure, .cancelled: return .red
        case .pending: return .orange
        case nil: return .gray
        }
    }

    private var statusTitle: String {
        switch paymentHandler.paymentStatus {
        case .success: return "Payment Successful"
        case .failure: return "Payment Failed"
        case .cancelled: return "Payment Cancelled"
        case .pending: return "Payment Pending"
        case nil: return "Unknown Status"
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
```

### External Browser Results (For Some Banks)
Some banks redirect outside the app. These are handled automatically by the URL scheme you configured.

---

## 🎯 WebView Flow Summary

```
Your Payment Button
        ↓
PaymentService.initiatePayment()
        ↓
Launch PaymentWebView with URL
        ↓
Token.io Web App loads
        ↓
User completes bank payment
        ↓
Result returns to PaymentCompletionHandler
        ↓
Show PaymentResultView
        ↓
Continue your payment flow
```

**That's it! 🎉 Your existing payment interface can now launch Token.io's secure web app.**

---

## 🔍 Troubleshooting WebView Issues

### WebView Not Loading:
The `PaymentWebView` includes optimized settings:
```swift
// These are already configured in PaymentWebView.swift
preferences.allowsContentJavaScript = true
configuration.allowsInlineMediaPlayback = true
configuration.websiteDataStore = WKWebsiteDataStore.default()
```

### Payment Callbacks Not Working:
1. **Check your callback scheme** matches in:
   - Info.plist: `<string>yourapp</string>`
   - PaymentService: Uses `"yourapp://payment-complete"`

2. **Test callback manually:**
   ```bash
   xcrun simctl openurl booted "yourapp://payment-complete?payment-id=test123"
   ```

### WebView Security Issues:
- The provided `PaymentWebView` handles domain allowlisting
- Only Token.io domains load in WebView; others open in Safari
- All SSL certificates are properly validated

### Debug WebView Loading:
```swift
// Add to PaymentWebView for debugging
#if DEBUG
webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
```

---

## 🔐 Production Checklist

Before going live:

- [ ] **Update API keys** in Info.plist for production environment
- [ ] **Test on real devices** with actual bank accounts
- [ ] **Update callback URL scheme** to your production scheme
- [ ] **Test both in-app and external browser flows**
- [ ] **Verify domain allowlist** includes your production domains
- [ ] **Remove debug logging** from production builds
- [ ] **Test payment status polling** works correctly

---

## 💰 Currency and Payment Types

**Supported Configurations:**

### UK Payments (GBP):
```swift
PaymentService.shared.initiatePayment(
    environment: .sandbox,
    currency: "GBP",
    amountValue: "100.50",
    localInstrument: "FASTER_PAYMENTS",
    creditorName: "Your Business",
    creditorIBAN: nil,
    creditorSortCode: "123456",
    creditorAccountNumber: "12345678"
)
```

### EUR Payments (SEPA):
```swift
PaymentService.shared.initiatePayment(
    environment: .sandbox,
    currency: "EUR",
    amountValue: "100.50",
    localInstrument: "SEPA_INSTANT", // or "SEPA"
    creditorName: "Your Business",
    creditorIBAN: "DE89370400440532013000",
    creditorSortCode: nil,
    creditorAccountNumber: nil
)
```

**Amount Formatting:**
- Always use decimal format: `"100.50"` ✅
- Never use comma separators: `"100,50"` ❌
- Include currency code: `"GBP"`, `"EUR"` ✅

---

## 🌍 Environment Configuration

The SDK supports multiple environments via `Configuration.swift`:

```swift
enum ApiEnvironment: String, CaseIterable {
    case dev = "DEV"
    case sandbox = "SANDBOX"
    case beta = "BETA"

    var baseUrl: URL {
        switch self {
        case .dev: return URL(string: "https://api.dev.token.io")!
        case .sandbox: return URL(string: "https://api.sandbox.token.io")!
        case .beta: return URL(string: "https://api.beta.token.io")!
        }
    }
}
```

Add corresponding API keys to Info.plist:
- `API_KEY_DEV`
- `API_KEY_SANDBOX`
- `API_KEY_BETA`

---

**🚀 Ready to integrate?** Copy the 4 WebView files and you're set!

**📱 Questions?** Check the demo app to see the WebView in action.
