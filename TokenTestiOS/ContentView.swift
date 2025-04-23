import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var paymentCompletionHandler: PaymentCompletionHandler // Access the shared handler
    @State private var paymentUrl: URL? = nil // Initialize to nil
    @State private var isLoading = false
    @State private var selectedEnvironment: ApiEnvironment = .sandbox // Use ApiEnvironment from Configuration.swift
    
    // Editable amount
    @State private var amountString: String = "1"
    
    // Currency and Account Details
    @State private var selectedCurrency: String = "GBP"
    private let currencies = ["GBP", "EUR"]
    
    // Destination Account Details
    @State private var sortCode: String = "042900"
    @State private var accountNumber: String = "00981656"
    @State private var iban: String = "DE36310108330000009006" // Default EUR IBAN
    
    let paymentService = PaymentService() // Keep instance if needed across views, or create in button action
    
    // SEPA Instrument selection
    @State private var selectedSepaInstrument: String = "SEPA_INSTANT"
    private let sepaInstruments = ["SEPA_INSTANT", "SEPA"]
    
    private var externalResultBinding: Binding<Bool> {
        Binding<Bool>(
            get: { paymentCompletionHandler.paymentStatus != nil && paymentUrl == nil },
            set: { _ in
                // If we need to dismiss programmatically by setting this to false,
                // we might need to reset the paymentStatus here.
                // For now, the onDismiss handles the reset.
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) { // Adjusted spacing
                Spacer() // Push content to center vertically
                
                // --- Checkout Details Section --- NEW Simplified Version
                VStack(alignment: .leading, spacing: 10) {
                    Text("Payment Amount")
                        .font(.headline)
                    
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            HStack {
                                Spacer()
                                Text(selectedCurrency) // Show selected currency symbol
                                    .padding(.trailing, 10)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal) // Add horizontal padding to the section
                // --- End Checkout Details ---
                
                // --- Currency Selection ---
                VStack(alignment: .leading) {
                    Text("Currency")
                        .font(.headline)
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                // --- End Currency Selection ---
                
                // --- SEPA Instrument Selection (Conditional) ---
                if selectedCurrency == "EUR" {
                    VStack(alignment: .leading) {
                        Text("SEPA Instrument")
                            .font(.headline)
                        Picker("SEPA Instrument", selection: $selectedSepaInstrument) {
                            ForEach(sepaInstruments, id: \.self) { instrument in
                                Text(instrument.replacingOccurrences(of: "_", with: " ")) // User-friendly display
                                    .tag(instrument)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale)) // Add animation
                }
                // --- End SEPA Instrument Selection ---
                
                // --- Destination Account Input ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("Destination Account")
                        .font(.headline)
                    
                    if selectedCurrency == "GBP" {
                        TextField("Sort Code (e.g., 042900)", text: $sortCode)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        
                        TextField("Account Number (e.g., 00981656)", text: $accountNumber)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                    } else if selectedCurrency == "EUR" {
                        TextField("IBAN (e.g., DE36...)", text: $iban)
                            .keyboardType(.asciiCapable) // Allow letters and numbers
                            .autocapitalization(.allCharacters)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal) // Add horizontal padding to the section
                // --- End Destination Account Input ---
                
                // --- Environment Selection ---
                VStack(spacing: 8) {
                    Text("Select API Environment:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Environment", selection: $selectedEnvironment) {
                        // Use the environment defined in Configuration.swift
                        ForEach(ApiEnvironment.allCases) { environment in
                            Text(environment.rawValue).tag(environment)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40) // Keep horizontal padding for picker
                // --- End Environment Selection ---
                
                Button {
                    isLoading = true
                    paymentCompletionHandler.reset() // Reset state before initiating
                    // Ensure PaymentService is correctly initialized if needed here
                    
                    // Determine parameters based on currency AND SEPA selection
                    let localInstrument: String
                    if selectedCurrency == "GBP" {
                        localInstrument = "FASTER_PAYMENTS"
                    } else { // EUR
                        localInstrument = selectedSepaInstrument // Use the selected SEPA instrument
                    }
                    let creditorName = "Clara Creditor" // Keep consistent for now
                    
                    // Conditionally provide account details
                    let sc = selectedCurrency == "GBP" ? sortCode : nil
                    let an = selectedCurrency == "GBP" ? accountNumber : nil
                    let ibanParam = selectedCurrency == "EUR" ? iban : nil
                    
                    paymentService.initiatePayment(environment: selectedEnvironment,
                                                   currency: selectedCurrency,
                                                   amountValue: amountString, // Use the state variable directly
                                                   localInstrument: localInstrument,
                                                   creditorName: creditorName,
                                                   creditorIBAN: ibanParam,
                                                   creditorSortCode: sc,
                                                   creditorAccountNumber: an) { result in
                        isLoading = false
                        switch result {
                        case .success(let (url, state)): // Destructure the tuple
                            print("Payment initiated, URL: \(url), State: \(state)")
                            // Only load token.io domains in-app; open all others externally
                            let urlString = url.absoluteString.lowercased()
                            let tokenDomains: [String] = [
                                "https://app.token.io",
                                "https://app.beta.token.io",
                                "https://app.sandbox.token.io",
                                "https://app.dev.token.io"
                            ]
                            if tokenDomains.contains(where: { urlString.hasPrefix($0) }) {
                                print("Loading in-app WebView: \(url)")
                                paymentUrl = url
                            } else {
                                print("Opening external URL: \(url)")
                                DispatchQueue.main.async {
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                }
                            }
                        case .failure(let error):
                            // Basic error handling, consider showing an alert
                            print("Error initiating payment: \(error.localizedDescription)")
                            print("[DEBUG] Setting paymentUrl = nil due to payment initiation failure")
                            paymentUrl = nil    // Ensure no navigation on error
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "creditcard.fill") // Keep icon or change if desired
                        Text("Pay by bank") // Updated button text
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .padding(.horizontal, 40) // Add horizontal padding
                
                if isLoading {
                    ProgressView("Initiating...")
                        .padding(.top)
                }
                
                Spacer() // Push content to center vertically
            }
            // Register in-app WebView navigation inside the NavigationStack context
            .navigationDestination(isPresented: Binding<Bool>( // Restore correct binding for webview
                get: { paymentUrl != nil },
                set: { if !$0 { paymentUrl = nil } } // Reset paymentUrl if dismissed
            )) {
                PaymentWebView(environment: selectedEnvironment, initialUrl: paymentUrl)
            }
            // Fallback result sheet for external flows
            .sheet(isPresented: Binding<Bool>( // Inline binding for the sheet
                get: { paymentCompletionHandler.paymentStatus != nil },
                set: { show in
                    if !show {
                        // If sheet is dismissed, ensure status is cleared
                        // only if it's not nil already (avoid infinite loop)
                        if paymentCompletionHandler.paymentStatus != nil {
                            paymentCompletionHandler.paymentStatus = nil
                            print("[DEBUG][ContentView] Sheet dismissed by user (isPresented=false), setting paymentStatus = nil")
                        }
                    }
                }
            ), onDismiss: {
                print("[DEBUG][ContentView] onDismiss called. Resetting handler.")
                // Call reset within a closure
                paymentCompletionHandler.reset()
            }) {
                // Content of the sheet
                PaymentResultView(environment: selectedEnvironment)
            }
            // Reset state on returnToHome notification
            .onReceive(NotificationCenter.default.publisher(for: .returnToHome)) { _ in
                paymentUrl = nil
            }
            // Debug payment status changes
            .onChange(of: paymentCompletionHandler.paymentStatus) { oldStatus, newStatus in
                print("[DEBUG] paymentCompletionHandler.paymentStatus changed from \(String(describing: oldStatus)) to \(String(describing: newStatus))")
            }
        } // End NavigationStack
        
    }
    
    // --- New View for Displaying Payment Result ---
    
    // --- Payment Result View ---
    struct PaymentResultView: View {
        @EnvironmentObject var paymentCompletionHandler: PaymentCompletionHandler
        @Environment(\.dismiss) var dismiss // To close the sheet
        let environment: ApiEnvironment // Receive the environment
        
        var body: some View {
            VStack {
                // --- Loading Indicator ---
                if paymentCompletionHandler.isCheckingStatus {
                    ProgressView("Checking Status...")
                        .padding(.vertical)
                }
                // --- End Loading Indicator ---
                
                Spacer(minLength: 40)
                VStack(spacing: 20) {
                    Image(systemName: statusIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundColor(statusColor)
                    Text(statusTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 16)
                
                // --- Details Section ---
                // Show details only when not checking status OR if already loaded
                if !paymentCompletionHandler.isCheckingStatus || !paymentCompletionHandler.statusString.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Status:").fontWeight(.medium)
                            Spacer()
                            // Use the raw status string from API if available, otherwise use title
                            Text(paymentCompletionHandler.statusString.isEmpty ? statusTitle : paymentCompletionHandler.statusString)
                                .foregroundColor(.secondary)
                        }
                        if let reason = paymentCompletionHandler.statusReasonInformation, !reason.isEmpty {
                            HStack {
                                Text("Reason:").fontWeight(.medium)
                                Spacer()
                                Text(reason).foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text("Amount:").fontWeight(.medium)
                            Spacer()
                            // Use updated amount/currency from handler
                            Text("\(paymentCompletionHandler.value) \(paymentCompletionHandler.currency)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Reference ID:").fontWeight(.medium)
                            Spacer()
                            // Use refId from handler
                            Text(paymentCompletionHandler.refId)
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.body)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .padding(.bottom, 24)
                } else {
                    // Optional: Add a placeholder or leave empty while loading initial details
                }
                // --- End Details Section ---
                
                Spacer()
                Button("Done") {
                    paymentCompletionHandler.reset()
                    dismiss()
                    NotificationCenter.default.post(name: .returnToHome, object: nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: 420)
            .background(Color.clear)
            // --- Add .onAppear to trigger polling ---
            .onAppear {
                // Ensure refId is populated before attempting to poll
                if !paymentCompletionHandler.refId.isEmpty {
                    print("[DEBUG] PaymentResultView appeared. Polling status for refId: \(paymentCompletionHandler.refId)")
                    paymentCompletionHandler.pollPaymentStatus(environment: environment)
                } else {
                    print("[DEBUG] PaymentResultView appeared, but refId is empty. Polling skipped.")
                    // Optionally, set a status indicating polling couldn't happen yet?
                    // Or rely on handleIncomingURL's initial status.
                }
            }
            // --- End .onAppear ---
        }
        
        // Helper computed properties for UI elements based on status
        private var statusIcon: String {
            switch paymentCompletionHandler.paymentStatus {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.octagon.fill"
            case .cancelled: return "xmark.circle.fill"
            case .pending: return "hourglass.circle.fill"
            case nil: return "questionmark.circle.fill"
            }
        }
        
        private var statusColor: Color {
            switch paymentCompletionHandler.paymentStatus {
            case .success: return .green
            case .failure: return .red
            case .cancelled: return .red
            case .pending: return .orange
            case nil: return .gray
            }
        }
        
        private var statusTitle: String {
            switch paymentCompletionHandler.paymentStatus {
            case .success: return "Payment Successful"
            case .failure: return "Payment Failed"
            case .cancelled: return "Payment Cancelled"
            case .pending: return "Payment Pending"
            case nil: return "Unknown Status"
            }
        }
    }
    
    // --- Preview ---
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
