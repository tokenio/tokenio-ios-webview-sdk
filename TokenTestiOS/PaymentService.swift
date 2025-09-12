//
//  PaymentService.swift
//
//  Created by Josh Lister on 10/04/2025.
//

import Foundation

// MARK: - URLSessionProtocol
protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
    @available(iOS 15.0, *)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - Logging Extensions
private extension PaymentService {
    func logRequest(_ request: URLRequest) {
        print("\n==== TOKEN API REQUEST ====")
        print("🌎 URL: \(request.url?.absoluteString ?? "N/A")")
        print("🔑 Method: \(request.httpMethod ?? "N/A")")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("📋 Headers: \(headers)")
        }
        
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📝 Body: \(bodyString)")
        }
        
        print("==== END REQUEST ====\n")
    }
    
    func logResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        print("\n==== TOKEN API RESPONSE ====")
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🚦 Status Code: \(httpResponse.statusCode)")
            
            if let headers = httpResponse.allHeaderFields as? [String: Any], !headers.isEmpty {
                print("📋 Headers: \(headers)")
            }
        } else if let error = error {
            print("🚨 Error: \(error.localizedDescription)")
        }
        
        if let data = data {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print("📝 Body: \(prettyString)")
            } else if let string = String(data: data, encoding: .utf8) {
                print("📝 Body: \(string)")
            } else {
                print("📦 No response body data.")
            }
        } else {
            print("📦 No response data.")
        }
        
        print("==== END RESPONSE ====\n")
    }
}

// MARK: - Main Service

import Foundation
import CryptoKit
import UIKit // For UIApplication

struct PaymentResponse: Codable {
    let payment: Payment
    
    struct Payment: Codable {
        let id: String
        let memberId: String
        let initiation: Initiation
        let createdDateTime: String
        let updatedDateTime: String
        let status: String
        let statusReasonInformation: String
        let authentication: Authentication
        
        struct Initiation: Codable {
            let refId: String
            let remittanceInformationPrimary: String
            let remittanceInformationSecondary: String
            let amount: Amount
            let localInstrument: String
            let creditor: Creditor
            let callbackUrl: String
            let callbackState: String
            let flowType: String
            
            struct Amount: Codable {
                let currency: String
                let value: String
            }
            
            struct Creditor: Codable {
                let name: String
                let sortCode: String?
                let accountNumber: String?
            }
        }
        
        struct Authentication: Codable {
            let redirectUrl: String
        }
    }
}

// Separate struct for the response when GETting payment status
struct PaymentStatusResponse: Codable {
    let payment: PaymentDetails

    struct PaymentDetails: Codable {
        let id: String
        let memberId: String
        let initiation: InitiationDetails
        let createdDateTime: String
        let updatedDateTime: String
        let status: String
        let statusReasonInformation: String?

        // Note: 'authentication' field is intentionally omitted as it's not in the GET response

        // Define nested structs matching the GET response structure
        struct InitiationDetails: Codable {
            let bankId: String?
            let refId: String
            let remittanceInformationPrimary: String?
            let remittanceInformationSecondary: String?
            let amount: AmountDetails
            let localInstrument: String?
            let creditor: CreditorDetails
            let callbackUrl: String?
            let callbackState: String?
            let flowType: String?
        }

        struct AmountDetails: Codable {
            let currency: String
            let value: String
        }

        struct CreditorDetails: Codable {
            let name: String?
            let sortCode: String?
            let accountNumber: String?
        }
    }
}

struct PaymentRequest: Codable {
    let initiation: Initiation
    let pispConsentAccepted: Bool
    
    struct Initiation: Codable {
        let bankId: String?
        let refId: String
        let flowType: String
        let remittanceInformationPrimary: String
        let remittanceInformationSecondary: String
        let amount: Amount
        let localInstrument: String
        let creditor: Creditor
        let callbackUrl: String
        let callbackState: String
        
        struct Amount: Codable {
            let value: String
            let currency: String
        }
        
        struct Creditor: Codable {
            let name: String
            let iban: String?
            let sortCode: String?
            let accountNumber: String?
        }
    }
}

// Define a struct to hold the relevant status details we want to display
struct PaymentStatusDetails {
    let status: String
    let statusReasonInformation: String?
    let currency: String
    let value: String
    let refId: String
}

class PaymentService {
    // MARK: - Properties
    private let session: URLSessionProtocol
    private let keychainProvider: KeychainProvider
    
    // MARK: - Mock Mode Support
    private var isMockMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-useMockAPI")
    }
    
    // MARK: - Initialization
    init(session: URLSessionProtocol = URLSession.shared, 
         keychainProvider: KeychainProvider = DefaultKeychainProvider()) {
        self.session = session
        self.keychainProvider = keychainProvider
    }
    
    // Shared instance for singleton access
    static let shared = PaymentService()
    
    // Helper function to generate a secure random state string (URL-safe base64 encoded)
    private func generateRandomState() -> String {
        var randomBytes = Data(count: 32) // 32 bytes = 256 bits
        _ = randomBytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }
        return randomBytes.base64URLEncodedString()
    }

    // Modified to accept currency, localInstrument, and conditional creditor details
    private func createPaymentRequest(environment: ApiEnvironment, 
                                     currency: String, 
                                     amountValue: String, 
                                     localInstrument: String, 
                                     creditorName: String, 
                                     creditorIBAN: String?,
                                     creditorSortCode: String?,
                                     creditorAccountNumber: String?) -> (request: PaymentRequest, state: String) { // Return tuple
        // Generate a unique reference ID - exactly 8 characters
        let uuid = UUID().uuidString
        let refId = String(uuid.filter { $0.isLetter || $0.isNumber }.prefix(8))
        
        // Generate the secure random state
        let state = generateRandomState()
        print("=======remittanceInformationPrimary:=======: RP\(refId)");
        // Build the request using the generated state
        let request = PaymentRequest(
            initiation: PaymentRequest.Initiation(
                bankId: nil, // Let user select bank in the flow
                refId: refId, // Use the generated 8-char refId
                flowType: "FULL_HOSTED_PAGES", // Use FULL_HOSTED_PAGES as requested
                remittanceInformationPrimary: "RP\(refId)",
                remittanceInformationSecondary: "RS\(refId)",
                amount: PaymentRequest.Initiation.Amount(
                    value: amountValue,
                    currency: currency
                ),
                localInstrument: localInstrument,
                creditor: PaymentRequest.Initiation.Creditor(
                    name: creditorName,
                    iban: creditorIBAN, // Pass IBAN if provided
                    sortCode: creditorSortCode,
                    accountNumber: creditorAccountNumber
                ),
                callbackUrl: "paymentdemoapp://payment-complete", // Keep app's callback URL
                callbackState: state // Use the generated state here
            ),
            pispConsentAccepted: true // OK
        )
        return (request, state) // Return both request and state
    }
    
    // Modified to accept environment, currency, localInstrument, creditor details, and use completion handler
    func initiatePayment(environment: ApiEnvironment, 
                         currency: String, 
                         amountValue: String, 
                         localInstrument: String, 
                         creditorName: String, 
                         creditorIBAN: String?,
                         creditorSortCode: String?,
                         creditorAccountNumber: String?,
                         completion: @escaping (Result<(redirectUrl: URL, state: String), Error>) -> Void) { // Updated completion signature

        let endpointUrl = environment.baseUrl.appendingPathComponent("/v2/payments")

        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"

        let apiKey = environment.apiKey
        guard !apiKey.isEmpty else {
            print("❌ API key is empty — cannot initiate payment")
            completion(.failure(PaymentServiceError.missingApiKey))
            return
        }
        print("✅ Loaded API Key from environment: '\(apiKey)'")
        request.addValue("Basic \(apiKey)", forHTTPHeaderField: "Authorization")


        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (paymentRequestBody, generatedState) = createPaymentRequest(
            environment: environment,
            currency: currency,
            amountValue: amountValue,
            localInstrument: localInstrument,
            creditorName: creditorName,
            creditorIBAN: creditorIBAN,
            creditorSortCode: creditorSortCode,
            creditorAccountNumber: creditorAccountNumber
        )

        // --- MOCK MODE ---
        if isMockMode {
            // Simulate a successful payment initiation with a fake redirect URL and state
            let fakeUrl = URL(string: "https://app.sandbox.token.io/payment/redirect/mock-success")!
            let fakeState = "mocked-state-1234"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(.success((redirectUrl: fakeUrl, state: fakeState)))
            }
            return
        }
        // Encode Body
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(paymentRequestBody)
        } catch {
            print("Error encoding payment request: \(error)")
            completion(.failure(error))
            return
        }
        
        // Log Request
        print("\n==== TOKEN API REQUEST ====")
        print("🌎 URL: \(request.url?.absoluteString ?? "N/A")")
        print("🔑 Method: \(request.httpMethod ?? "N/A")")
        print("📋 Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let requestBody = request.httpBody, let requestBodyString = String(data: requestBody, encoding: .utf8) {
            print("📝 Body: \(requestBodyString)")
        }
        print("==== END REQUEST ====\n")

        // Execute Data Task
        let task = session.dataTask(with: request) { taskData, response, error in // Renamed data to taskData
            // Log Response
            self.logResponse(taskData, response, error) // Use taskData

            // Handle Errors
            if let error = error {
                print("Payment Network Error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let unknownError = NSError(domain: "PaymentService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response received"])
                completion(.failure(unknownError))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "Payment API Error: \(httpResponse.statusCode)"
                var errorDetails: [String: Any] = [NSLocalizedDescriptionKey: errorMessage]

                // Attempt to decode error response body if data exists
                if let errorData = taskData { // Use taskData here, renamed inner variable too
                    if let json = try? JSONSerialization.jsonObject(with: errorData, options: []) as? [String: Any] {
                        errorDetails["responseBody"] = json
                        if let specificMessage = json["message"] as? String {
                            errorMessage += " - \(specificMessage)"
                        }
                    } else if let errorString = String(data: errorData, encoding: .utf8) { // Use errorData
                        errorDetails["rawResponseBody"] = errorString
                    }
                    errorDetails[NSLocalizedDescriptionKey] = errorMessage // Update with detail if found
                }
                
                let responseError = NSError(domain: "PaymentService", code: httpResponse.statusCode, userInfo: errorDetails)
                // Print the full userInfo dictionary for debugging
                print("Payment API Error Details: \(responseError.userInfo)") 
                completion(.failure(responseError))
                return
            }
            
            // Check if data is actually present after ensuring status is 2xx
            // Use taskData here
            guard let responseData = taskData else { 
                let noDataError = NSError(domain: "PaymentService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received in response"])
                print("Payment API Error: No data received")
                completion(.failure(noDataError))
                return
            }
            // No need for force unwrap now

            // Decode Response and Extract URL
            do {
                let decoder = JSONDecoder()
                // Use the non-optional 'responseData' unwrapped above
                let paymentResponse = try decoder.decode(PaymentResponse.self, from: responseData) // Use new name

                guard let redirectUrl = URL(string: paymentResponse.payment.authentication.redirectUrl) else {
                    let urlError = NSError(domain: "PaymentService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URL received in response"])
                    print("Invalid redirect URL: \(paymentResponse.payment.authentication.redirectUrl)")
                    completion(.failure(urlError))
                    return
                }

                print("Payment API Redirect URL: \(redirectUrl)")
                // Pass the generated state along with the URL in the success case
                completion(.success((redirectUrl: redirectUrl, state: generatedState))) // Pass tuple

            } catch {
                print("Payment Decoding Error: \(error)")
                var userInfo: [String: Any] = [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"]
                if let responseString = String(data: responseData, encoding: .utf8) {
                     userInfo["rawResponse"] = responseString
                }
                let decodingError = NSError(domain: "PaymentService", code: 3, userInfo: userInfo)
                completion(.failure(decodingError))
            }
        }
        task.resume()
    }
    
    @available(iOS 15.0, *)
    func getPaymentStatus(paymentId: String, environment: ApiEnvironment) async throws -> PaymentStatusDetails {
        // --- MOCK MODE ---
        if isMockMode {
            // Return mock data for testing
            return PaymentStatusDetails(
                status: "execution_successful",
                statusReasonInformation: "Payment completed successfully",
                currency: "GBP",
                value: "10.00",
                refId: "MOCK_REF_123"
            )
        }
        
        // --- REAL API CALL ---
        // 1. Get API Key from Keychain
        let apiKey: String
        do {
            apiKey = try keychainProvider.getApiKey()
            print("Loaded API Key: '\(apiKey)'")
        } catch {
            print("Error loading API key: \(error)")
            throw PaymentServiceError.missingApiKey
        }
        
        // 2. Construct URL
        let baseUrl = environment.baseUrl
        let urlString = "\(baseUrl)/payments/\(paymentId)"
        
        guard let url = URL(string: urlString) else {
            throw PaymentServiceError.invalidUrl
        }
        
        // 3. Create Request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 4. Add Headers
        let authString = "\(apiKey):"
        let authData = authString.data(using: .utf8)!
        let base64AuthString = authData.base64EncodedString()
        
        request.setValue("Basic \(base64AuthString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Log the request
        logRequest(request)
        
        // 5. Make the API Call
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log the response
            logResponse(data, response, nil)
            
            // Check the HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaymentServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Payment Status Error: \(httpResponse.statusCode)")
                
                // Try to extract error details
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    print("Error details: \(errorMessage)")
                }
                
                throw PaymentServiceError.apiError("Failed to get payment status. Status code: \(httpResponse.statusCode)")
            }
            
            // 6. Parse the response
            let decoder = JSONDecoder()
            let paymentResponse = try decoder.decode(PaymentResponse.self, from: data)
            
            // 7. Map to our simplified model
            return PaymentStatusDetails(
                status: paymentResponse.payment.status,
                statusReasonInformation: paymentResponse.payment.statusReasonInformation,
                currency: paymentResponse.payment.initiation.amount.currency,
                value: paymentResponse.payment.initiation.amount.value,
                refId: paymentResponse.payment.initiation.refId
            )
            
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw PaymentServiceError.decodingError("Failed to decode payment status response: \(error.localizedDescription)")
        } catch {
            print("Error fetching or decoding payment status: \(error)")
            throw error
        }
    }
}

// Helper extension for URL-safe Base64 encoding
extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // Remove padding
    }
}
