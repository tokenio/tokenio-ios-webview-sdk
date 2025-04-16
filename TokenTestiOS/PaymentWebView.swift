//
//  PaymentWebView.swift
//  TokenTestiOS
//
//  Created by Josh Lister on 10/04/2025.
//

import SwiftUI
import WebKit
import UIKit

struct PaymentWebView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var paymentCompletionHandler: PaymentCompletionHandler
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    let environment: ApiEnvironment // Add property to receive environment
    let initialUrl: URL? // URL passed from ContentView after successful API call

    var body: some View {
        ZStack {
            // Main content area (initial loading or WebViewLoader)
            mainContent

            // Verifying overlay
            verifyingOverlay
            
            // Success/Failure overlay
            completionOverlay
        }
        // Apply modifiers directly to the ZStack
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Close") {
            presentationMode.wrappedValue.dismiss()
        })
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            print("PaymentWebView initialUrl: \(String(describing: initialUrl))")
            setupNotificationObservers()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .navigationBarBackButtonHidden(paymentCompletionHandler.paymentStatus != nil)
        .interactiveDismissDisabled(paymentCompletionHandler.paymentStatus != nil)
    }
    
    // MARK: - Subviews / Computed Properties
    
    @ViewBuilder
    private var mainContent: some View {
        VStack {
            // Initial loading indicator for initiating payment
            // Show only if initial loading is happening AND we are not verifying status
            if isLoading && !paymentCompletionHandler.isCheckingStatus {
                ProgressView("Initiating payment...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding()
            }
            
            // We'll load the actual payment web view in background
            // Only show the webview loader if not loading initial payment, not verifying, and no final status is set yet
            PaymentWebViewLoader(isLoading: $isLoading, showError: $showError, errorMessage: $errorMessage, environment: environment, urlToLoad: initialUrl)
                // Hide if initially loading, verifying, or final status is known
                .opacity(isLoading || paymentCompletionHandler.isCheckingStatus || paymentCompletionHandler.paymentStatus != nil ? 0 : 1)
                .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        }
    }
    
    @ViewBuilder
    private var verifyingOverlay: some View {
        if paymentCompletionHandler.isCheckingStatus {
            VStack(spacing: 15) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                Text("Verifying payment...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 10)
            )
            .transition(.opacity)
            .zIndex(101) // High zIndex to appear above everything
        }
    }
    
    @ViewBuilder
    private var completionOverlay: some View {
        // Show overlay if status is set and we are not checking
        if let status = paymentCompletionHandler.paymentStatus, !paymentCompletionHandler.isCheckingStatus {
            let (statusIcon, statusColor, statusText) = completionOverlayDetails(for: status)
            Group {
                VStack(spacing: 20) {
                    // Status Icon and Title
                    Image(systemName: statusIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(statusColor)

                    Text(statusText)
                        .font(.title2)
                        .fontWeight(.bold)
                    // Status Icon and Title
                    Image(systemName: statusIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(statusColor)

                    Text(statusText)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Display Detailed Status Info
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow(label: "Status", value: paymentCompletionHandler.statusString)
                        if let reason = paymentCompletionHandler.statusReasonInformation, !reason.isEmpty {
                            detailRow(label: "Details", value: reason)
                        }
                        detailRow(label: "Amount", value: "\(paymentCompletionHandler.currency) \(paymentCompletionHandler.value)")
                        detailRow(label: "Reference ID", value: paymentCompletionHandler.refId)
                    }
                    .padding(.vertical)

                    // Action Button (e.g., Done)
                    Button("Done") {
                        NotificationCenter.default.post(name: .returnToHome, object: nil)
                    }
                }
            }
            // Apply common container modifiers here
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground)) // Use system background color
                    .shadow(color: Color.black.opacity(0.2), radius: 10)
            )
            .transition(.scale.combined(with: .opacity))
            .zIndex(100) // Below verifying overlay
        }
    }
    
    // Helper function for detail rows
    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PaymentCompleted"),
            object: nil,
            queue: .main
        ) { notification in
            // Only update UI for result overlay here. Do NOT dismiss the view.
            // You may want to update a @State var or trigger a UI update if needed.
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DismissPaymentView"),
            object: nil,
            queue: .main
        ) { _ in
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    
    // MARK: - Overlay Details Helper
    private func completionOverlayDetails(for status: PaymentCompletionHandler.PaymentStatus) -> (String, Color, String) {
        switch status {
        case .success:
            return ("checkmark.circle.fill", .green, "Payment Successful")
        case .failure, .cancelled, .pending:
            return ("xmark.octagon.fill", .red, "Payment Failed")
        }
    }
}

// Separate component to handle the API call and WebView loading
struct PaymentWebViewLoader: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    let environment: ApiEnvironment // Add property to receive environment
    let urlToLoad: URL? // URL passed from PaymentWebView
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Set up the WebView with optimized configuration
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        configuration.allowsInlineMediaPlayback = true
        
        // Use default process pool for better performance
        configuration.processPool = WKProcessPool()
        
        // Optimize for speed
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Preload content in the background
        configuration.suppressesIncrementalRendering = false
        
        // Set up JavaScript message handler for payment completion
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "paymentComplete")
        contentController.add(context.coordinator, name: "paymentCancelled")
        
        // Add script to inject into the page to detect payment completion
        let script = WKUserScript(
            source: """
            function setupPaymentCallbacks() {
                // Watch for payment success indicators
                const checkForSuccess = () => {
                    // Look for success message elements
                    const successElements = [
                        document.querySelector('.payment-success'),
                        document.querySelector('.success-message'),
                        document.querySelector('[data-status="success"]'),
                        document.querySelector('.payment-complete'),
                        document.querySelector('.transaction-complete'),
                        // Look for text content that indicates success
                        ...Array.from(document.querySelectorAll('h1,h2,h3,p')).filter(el => {
                            const text = el.textContent.toLowerCase();
                            return text.includes('payment successful') || 
                                   text.includes('payment complete') || 
                                   text.includes('transaction complete') ||
                                   text.includes('thank you for your payment');
                        })
                    ];
                    
                    // Check if any success elements were found
                    if (successElements.some(el => el !== null)) {
                        window.webkit.messageHandlers.paymentComplete.postMessage('Payment completed successfully');
                        return true;
                    }
                    
                    // Check for cancel/back buttons that might indicate user wants to exit
                    const cancelElements = [
                        document.querySelector('.cancel-button'),
                        document.querySelector('.back-to-merchant'),
                        document.querySelector('[data-action="cancel"]'),
                        ...Array.from(document.querySelectorAll('button,a')).filter(el => {
                            const text = el.textContent.toLowerCase();
                            return text.includes('cancel') || 
                                   text.includes('back to merchant') || 
                                   text.includes('return to shop');
                        })
                    ];
                    
                    // Add click listeners to cancel elements
                    cancelElements.forEach(el => {
                        if (el && !el.hasAttribute('data-cancel-listener')) {
                            el.setAttribute('data-cancel-listener', 'true');
                            el.addEventListener('click', () => {
                                window.webkit.messageHandlers.paymentCancelled.postMessage('Payment cancelled by user');
                            });
                        }
                    });
                    
                    return false;
                };
                
                // Check immediately and then periodically
                if (!checkForSuccess()) {
                    setInterval(checkForSuccess, 1000);
                }
            }
            
            // Run when DOM is ready
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', setupPaymentCallbacks);
            } else {
                setupPaymentCallbacks();
            }
            
            // Also run when page changes via history API
            window.addEventListener('popstate', setupPaymentCallbacks);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        contentController.addUserScript(script)
        configuration.userContentController = contentController
        
        // Create the WKWebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Set navigation delegate
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator // If using UI delegate methods
        
        // Load the initial URL if provided
        if let url = urlToLoad {
            print("PaymentWebViewLoader: Loading initial URL: \(url.absoluteString)")
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            // Handle case where URL is nil (e.g., show an error or placeholder)
            print("PaymentWebViewLoader: Initial URL is nil.")
            // Optionally load a blank page or show an error message within the WebView
            // webView.loadHTMLString("<html><body>Error: Payment URL missing</body></html>", baseURL: nil)
        }
        
        // Start the payment process immediately
        context.coordinator.startPaymentProcess(webView: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        print("PaymentWebViewLoader.updateUIView: urlToLoad = \(String(describing: urlToLoad)), webView.url = \(String(describing: webView.url))")
        // Always load the payment URL if it is set and not already loaded
        if let url = urlToLoad {
            if webView.url != url {
                print("PaymentWebViewLoader: updateUIView loading URL: \(url.absoluteString)")
                let request = URLRequest(url: url)
                webView.load(request)
            }
        } else {
            print("PaymentWebViewLoader: updateUIView - urlToLoad is nil")
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    // Helper to get a Safari-compatible URL (for most non-http schemes, fallback is to try the same URL)
    private func safariUrl(for url: URL) -> URL? {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url
        }
        return url
    }

        var parent: PaymentWebViewLoader
        private var paymentSuccessful = false
        
        init(_ parent: PaymentWebViewLoader) {
            self.parent = parent
            super.init()
        }
        
        // Handle JavaScript messages from the webpage
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageBody = message.body as? String else { return }
            
            DispatchQueue.main.async {
                switch message.name {
                case "paymentComplete":
                    print("Payment completed: \(messageBody)")
                    self.paymentSuccessful = true
                    self.handlePaymentCompletion(success: true, message: messageBody)
                    
                case "paymentCancelled":
                    print("Payment cancelled: \(messageBody)")
                    self.handlePaymentCompletion(success: false, message: messageBody)
                    
                default:
                    break
                }
            }
        }
        
        private func handlePaymentCompletion(success: Bool, message: String) {
            // Hide loading indicator
            self.parent.isLoading = false
            
            // Show a brief success message before dismissing
            // Always notify the parent view to show the result
            NotificationCenter.default.post(
                name: NSNotification.Name("PaymentCompleted"),
                object: nil,
                userInfo: ["success": success, "message": message]
            )
            
            // Only auto-dismiss after a short delay for success
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NotificationCenter.default.post(name: NSNotification.Name("DismissPaymentView"), object: nil)
                }
            }

        }
        
        func startPaymentProcess(webView: WKWebView) {
            // Access environment via parent
            let environment = parent.environment
            
            print("Starting payment initiation in env: \(environment.rawValue)...")
            // This call now happens in ContentView, Loader just displays the webview
            // Initiate payment is now handled in ContentView
            // This view now just waits for the URL to be passed or loads it.
            // We need a mechanism to pass the URL from ContentView to here.
            // For now, we assume the URL is loaded via updateUIView if provided.
        }
        
        // WebView delegate methods
        // Track loading progress using KVO
        private var loadingObservation: NSKeyValueObservation?
        private var progressObservation: NSKeyValueObservation?
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("WebView started loading URL: \(webView.url?.absoluteString ?? "unknown")")
            
            // Set up KVO for loading state and progress
            if loadingObservation == nil {
                loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, change in
                    guard let self = self else { return }
                    
                    if let isLoading = change.newValue, !isLoading {
                        print("WebView isLoading changed to false")
                        DispatchQueue.main.async {
                            // Hide loading indicator when loading completes
                            self.parent.isLoading = false
                        }
                    }
                }
            }
            
            if progressObservation == nil {
                progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, change in
                    guard let self = self else { return }
                    
                    if let progress = change.newValue {
                        print("WebView loading progress: \(progress)")
                        
                        // If progress is high enough, consider the page loaded enough to show
                        if progress >= 0.8 {
                            DispatchQueue.main.async {
                                self.parent.isLoading = false
                            }
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("WebView committed navigation - DOM is starting to load")
            // This is called when the web view begins to receive web content
            // At this point, we can start showing the WebView as content is becoming visible
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading URL: \(webView.url?.absoluteString ?? "unknown")")
            DispatchQueue.main.async {
                // Once the page has loaded, show it
                self.parent.isLoading = false
                
                // Force a check for payment completion elements after the page loads
                let checkScript = """
                if (typeof setupPaymentCallbacks === 'function') {
                    setupPaymentCallbacks();
                    console.log('Payment callbacks setup triggered after page load');
                } else {
                    console.log('Payment callbacks function not found');
                }
                """
                
                webView.evaluateJavaScript(checkScript) { result, error in
                    if let error = error {
                        print("Error evaluating callback script: \(error)")
                    }
                }
            }
        }
        
        deinit {
            // Clean up KVO observers
            loadingObservation?.invalidate()
            progressObservation?.invalidate()
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleWebViewError(error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // Ignore error code -999 which is just a navigation cancellation
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                return
            }
            
            handleWebViewError(error)
        }
        
        private func handleWebViewError(_ error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.errorMessage = "Failed to load payment page: \(error.localizedDescription)"
                self.parent.showError = true
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            let urlString = url.absoluteString
            print("Navigating to URL: \(urlString)")
            
            // Check specifically for our app's custom scheme
            if url.scheme?.lowercased() == "paymentdemoapp" {
                print("Detected custom app scheme: paymentdemoapp. Cancelling WebView navigation.")
                decisionHandler(.cancel) // Cancel the WebView navigation
                
                // Explicitly ask the OS to handle the URL
                DispatchQueue.main.async { // Ensure UI operations are on the main thread
                    UIApplication.shared.open(url) { success in
                        print("[PaymentWebView] Attempted to open URL \(url.absoluteString) externally: \(success)")
                    }
                }
                return // Important: Don't proceed further in this delegate method
            }
            
            // Check for custom URL schemes that should be handled by external apps


            // --- BEGIN: Robust external browser fallback for bank and unknown domains ---
// Only allow navigation in WebView for allowed merchant/payment provider domains
let allowedDomains: Set<String> = [
    "https://app.token.io",
    "https://app.dev.token.io",
    "https://app.sandbox.token.io",
    "https://app.beta.token.io"
]
if (url.scheme == "http" || url.scheme == "https") {
    let urlString = url.absoluteString.lowercased()
    let isAllowed = allowedDomains.contains { urlString.hasPrefix($0) }
    if !isAllowed {
        print("Blocked URL: \(url.absoluteString)")
        decisionHandler(.cancel)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return
    }
}
// --- END: Robust external browser fallback ---

if let scheme = url.scheme?.lowercased(), !scheme.hasPrefix("http") {
                // List of schemes that should be handled by external apps
                let externalSchemes = [
                    "bankapp", // Generic example
                    "monzo",   // Monzo Bank
                    "starling", // Starling Bank
                    "hsbc",    // HSBC
                    "lloyds",  // Lloyds Bank
                    "barclays", // Barclays
                    "natwest", // NatWest
                    "halifax", // Halifax
                    "santander", // Santander
                    "tsb",     // TSB
                    "revolut", // Revolut
                    "nationwide" // Nationwide
                ]
                
                if externalSchemes.contains(scheme) || scheme.contains("bank") {

                    print("Detected external app URL scheme: \(scheme)")
                    
                    // Cancel the navigation in WebView
                    decisionHandler(.cancel)
                    
                    // Attempt to open the URL in the external app
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("Successfully opened URL in external app: \(urlString)")
                            } else {
                                // Fallback: try to open the same URL in Safari (device browser)
                                if let safariUrl = self.safariUrl(for: url) {
                                    UIApplication.shared.open(safariUrl, options: [:]) { safariSuccess in
                                        if safariSuccess {
                                            print("Opened fallback URL in Safari: \(safariUrl.absoluteString)")
                                        } else {
                                            // Show an alert if even Safari cannot open it
                                            DispatchQueue.main.async {
                                                let errorMessage = "Could not open the link externally. Please check your device settings."
                                                self.parent.errorMessage = errorMessage
                                                self.parent.showError = true
                                            }
                                        }
                                    }
                                } else {
                                    // Show an alert if unable to form a Safari URL
                                    DispatchQueue.main.async {
                                        let errorMessage = "Could not open the link externally. Please check your device settings."
                                        self.parent.errorMessage = errorMessage
                                        self.parent.showError = true
                                    }
                                }
                            }
                        }
                    }
                    return
                }
            }
            
            // For all other URLs (http, https, etc.), allow normal navigation in WebView
            print("Allowed navigation to: \(url.absoluteString)")
            decisionHandler(.allow)
        }
    }
}
