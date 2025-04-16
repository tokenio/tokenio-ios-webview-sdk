//
//  PaymentService.swift
//
//  Created by Josh Lister on 10/04/2025.
//

import Foundation
import CryptoKit

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
    static let shared = PaymentService() // Add shared instance for singleton access

    init() {}
    
    private func logResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        print("\n==== TOKEN API RESPONSE ====")
        if let error = error {
            print("🚨 Error: \(error.localizedDescription)")
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🚦 Status Code: \(httpResponse.statusCode)")
            print("📋 Headers: \(httpResponse.allHeaderFields)")
        }
        
        if let data = data, let responseString = String(data: data, encoding: .utf8) {
            print("📝 Body: \(responseString)")
        } else if data != nil {
            print("⚠️ Could not decode response body as UTF-8")
        } else {
            print("📦 No response body data.")
        }
        
        print("==== END RESPONSE ====\n")
    }
    
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

        // Build the request using the generated state
        let request = PaymentRequest(
            initiation: PaymentRequest.Initiation(
                bankId: nil, // Let user select bank in the flow
                refId: refId, // Use the generated 8-char refId
                flowType: "FULL_HOSTED_PAGES", // Use FULL_HOSTED_PAGES as requested
                remittanceInformationPrimary: "RP/\(refId)",
                remittanceInformationSecondary: "RS/\(refId)",
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

        let credentials = environment.apiKey
        print("Loaded API Key: '\(credentials)'")
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")

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
        let task = URLSession.shared.dataTask(with: request) { taskData, response, error in // Renamed data to taskData
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
    
    // Modified to accept environment
    func getPaymentStatus(paymentId: String, environment: ApiEnvironment) async throws -> PaymentStatusDetails {
        let statusURL = environment.baseUrl.appendingPathComponent("/v2/payments/\(paymentId)")
        
        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        
        // Set Headers using environment
        request.addValue("Basic \(environment.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        print("\n==== TOKEN API REQUEST (Get Status) ====")
        print("Get Payment Status URL: \(request.url?.absoluteString ?? "N/A")")
        print("Get Payment Status Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("==== END REQUEST ====\n")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response
            logResponse(data, response, nil) 
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let error = NSError(domain: "PaymentService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get payment status. Status code: \(statusCode)"])
                print("Payment Status Error: \(error)")
                throw error
            }
            
            // Decode using the PaymentStatusResponse struct
            let decoder = JSONDecoder()
            let paymentStatusResponse = try decoder.decode(PaymentStatusResponse.self, from: data)
            
            print("Successfully retrieved payment status: \(paymentStatusResponse.payment.status)")
            
            // Create and return the detailed status struct
            let details = PaymentStatusDetails(
                status: paymentStatusResponse.payment.status,
                statusReasonInformation: paymentStatusResponse.payment.statusReasonInformation,
                currency: paymentStatusResponse.payment.initiation.amount.currency,
                value: paymentStatusResponse.payment.initiation.amount.value,
                refId: paymentStatusResponse.payment.initiation.refId
            )
            return details
            
        } catch {
            logResponse(nil, nil, error) // Log the error that occurred during the async call or decoding
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
