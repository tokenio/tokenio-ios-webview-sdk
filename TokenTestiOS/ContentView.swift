import SwiftUI

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
    
    var body: some View {
        // Computed property to bind sheet presentation to payment status
        let paymentStatusBinding = Binding<Bool>(
            get: { paymentCompletionHandler.paymentStatus != nil },
            set: { _ in /* This binding is read-only for presentation */ }
        )
        
        NavigationView {
            VStack(spacing: 20) { // Adjusted spacing
                // Move NavigationLink to the top of the VStack
                NavigationLink(
                    destination: PaymentWebView(environment: selectedEnvironment, initialUrl: paymentUrl),
                    isActive: Binding<Bool>(
                        get: { paymentUrl != nil },
                        set: { isActive in
                            print("[DEBUG] NavigationLink isActive set to", isActive)
                            if !isActive {
                                print("[DEBUG] Setting paymentUrl = nil from NavigationLink set closure")
                                paymentUrl = nil
                            }
                        }
                    )
                ) { EmptyView() }
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
                            print("Setting paymentUrl to: \(url)")
                            print("[DEBUG] Setting paymentUrl =", url)
                            paymentUrl = url     // Set the URL to trigger navigation
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
                
                // Background NavigationLink, triggered by paymentUrl change
                NavigationLink(
                    // Pass the URL obtained from the successful API call
                    // Note: We need PaymentWebView to accept the URL now.
                    destination: PaymentWebView(environment: selectedEnvironment, initialUrl: paymentUrl),
                    isActive: Binding<Bool>( // Drive navigation from paymentUrl state
                        get: { paymentUrl != nil },
                        set: { isActive in
                            if !isActive {
                                paymentUrl = nil
                            }
                        }
                                           )
                ) { EmptyView() } // Invisible link
            }
            .onReceive(NotificationCenter.default.publisher(for: .returnToHome)) { _ in
                print("[DEBUG] Received .returnToHome notification, setting paymentUrl = nil")
                paymentUrl = nil
            }
            .onChange(of: paymentCompletionHandler.paymentStatus) { newStatus in
                print("[DEBUG] paymentCompletionHandler.paymentStatus changed to", String(describing: newStatus))
            }
            
        }
    }
    
    // --- New View for Displaying Payment Result ---
    
    
    // --- Payment Result View ---
    struct PaymentResultView: View {
        @ObservedObject var paymentCompletionHandler: PaymentCompletionHandler
        @Environment(\.dismiss) var dismiss // To close the sheet
        
        var body: some View {
            VStack(spacing: 20) {
                Spacer()
                
                // Icon based on status
                Image(systemName: statusIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(statusColor)
                
                // Main status text
                Text(statusTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Optional details/reason
                if let reason = paymentCompletionHandler.statusReasonInformation, !reason.isEmpty {
                    Text(reason)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Display other details if available
                if paymentCompletionHandler.paymentStatus == .success {
                    Text("Ref ID: \(paymentCompletionHandler.refId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Amount: \(paymentCompletionHandler.value) \(paymentCompletionHandler.currency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Done button
                Button("Done") {
                    paymentCompletionHandler.reset() // Reset the state in the handler
                    dismiss() // Close the sheet
                    // Return to home by clearing navigation state
                    NotificationCenter.default.post(name: .returnToHome, object: nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom)
            }
            .padding()
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
