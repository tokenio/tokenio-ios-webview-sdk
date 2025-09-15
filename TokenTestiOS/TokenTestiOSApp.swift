
import SwiftUI

@main
struct TokenTestiOSApp: App {
    @StateObject private var paymentCompletionHandler = PaymentCompletionHandler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(paymentCompletionHandler)
                .onOpenURL { url in
                    print("--- TokenTestiOSApp.onOpenURL triggered ---")
                    paymentCompletionHandler.handleIncomingURL(url)
                }
        }
    }
}
