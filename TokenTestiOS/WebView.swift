//
//  WebView.swift
//  TokenTestiOS
//
//  Created by Josh Lister on 10/04/2025.
//

import SwiftUI
import WebKit

// Class to observe WebView loading progress
class ProgressObserver: NSObject {
    @objc dynamic var estimatedProgress: Double = 0
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    private let progressObserver = ProgressObserver()
    
    func makeUIView(context: Context) -> WKWebView {
        // Store the coordinator for later reference
        let coordinator = context.coordinator
        // Configure WebView with enhanced settings for payment processing
        let configuration = WKWebViewConfiguration()
        
        // Enable JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Allow cross-site tracking for payment flows
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            configuration.websiteDataStore = WKWebsiteDataStore.default()
        }
        
        // Configure process pool for shared cookies and security
        configuration.processPool = WKProcessPool()
        
        // Add security exceptions for development environments
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // Allow auto-play for potential animations
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 15.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            // Fallback for earlier versions
            configuration.mediaTypesRequiringUserActionForPlayback = .audio
        }
        
        // Create and configure the WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Add KVO for progress tracking
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        
        // Additional settings
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        
        // Enable debugging for development
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create a more robust request with appropriate headers
        var request = URLRequest(url: url)
        
        // Add headers that are typically needed for web views
        request.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        // Use appropriate cache policy for payment pages
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Load the request
        print("Loading URL in WebView: \(url.absoluteString)")
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        // Remove KVO observers when the WebView is dismantled
        webView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.isLoading))
        print("WebView observers removed")
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        private var progressObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        
        init(_ parent: WebView) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            // Remove observers when coordinator is deallocated
            progressObservation?.invalidate()
            loadingObservation?.invalidate()
        }
        
        // Handle KVO observations
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            
            if keyPath == #keyPath(WKWebView.estimatedProgress) {
                let progress = webView.estimatedProgress
                print("WebView loading progress: \(Int(progress * 100))%")
                
                // When progress is 100%, we consider the page loaded
                if progress >= 1.0 {
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
                    }
                }
            } else if keyPath == #keyPath(WKWebView.isLoading) {
                if !webView.isLoading {
                    print("WebView isLoading changed to false")
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
                    }
                }
            }
        }
        
        // Navigation started
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        // Navigation finished
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView didFinish navigation - marking as loaded")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        // Handle the completion of all resources (images, scripts, etc.)
        // This is called after didFinish in many cases
        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            print("WebView received redirect - this may indicate a page change")
        }
        
        // Document is ready - this happens when the DOM is fully loaded
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("WebView didCommit - DOM is ready, marking as 50% loaded")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("WebView deciding policy for URL: \(url.absoluteString)")
                
                // Log request details for debugging
                if let headers = navigationAction.request.allHTTPHeaderFields {
                    print("Request headers: \(headers)")
                }
                
                // Check for bank app URL scheme
                if url.scheme == "bankapp" {
                    print("Detected bank app URL scheme, attempting to open")
                    // Try to open the URL - this will work if the app is installed
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        decisionHandler(.cancel)
                        return
                    }
                }
                
                // For all other URLs, allow navigation
                print("Allowing navigation to: \(url.absoluteString)")
                decisionHandler(.allow)
            } else {
                print("Navigation action has no URL, allowing by default")
                decisionHandler(.allow)
            }
        }
        
        // Handle navigation errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Error code -999 is a cancellation error that happens during redirects
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                // This is a cancelled request, which is normal during redirects
                return
            }
            
            print("WebView navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Error code -999 is a cancellation error that happens during redirects
            // It's not a real error and should be ignored
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                // This is a cancelled request, which is normal during redirects
                // Don't log it or change loading state
                return
            }
            
            print("WebView provisional navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
