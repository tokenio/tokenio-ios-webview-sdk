import Foundation
@testable import TokenTestiOS

enum TestDataFactory {
    // MARK: - Payment Response
    static func createPaymentResponse() -> PaymentResponse {
        return PaymentResponse(
            payment: PaymentResponse.Payment(
                id: "test_payment_123",
                memberId: "test_member_123",
                initiation: PaymentResponse.Payment.Initiation(
                    refId: "test_ref_123",
                    remittanceInformationPrimary: "Test Payment",
                    remittanceInformationSecondary: "Test Payment Secondary",
                    amount: PaymentResponse.Payment.Initiation.Amount(
                        currency: "GBP",
                        value: "10.00"
                    ),
                    localInstrument: "UK.OBIE.FPS",
                    creditor: PaymentResponse.Payment.Initiation.Creditor(
                        name: "Test Creditor",
                        sortCode: "040004",
                        accountNumber: "12345678"
                    ),
                    callbackUrl: "paymentdemoapp://payment-complete",
                    callbackState: "test_state_123",
                    flowType: "OBIE_SINGLE"
                ),
                createdDateTime: "2025-01-01T00:00:00Z",
                updatedDateTime: "2025-01-01T00:00:00Z",
                status: "PENDING",
                statusReasonInformation: "Processing",
                authentication: PaymentResponse.Payment.Authentication(
                    redirectUrl: "https://example.com/redirect"
                )
            )
        )
    }
    
    static func createPaymentStatusResponse() -> PaymentStatusDetails {
        return PaymentStatusDetails(
            status: "execution_successful",
            statusReasonInformation: "Payment completed successfully",
            currency: "GBP",
            value: "10.00",
            refId: "test_ref_123"
        )
    }
    
    // MARK: - Error Response
    static func createErrorResponse() -> Data {
        let json = """
        {
            "error": "invalid_request",
            "error_description": "The request is missing a required parameter"
        }
        """
        return json.data(using: .utf8)!
    }
    
    // MARK: - HTTP Response
    static func createHTTPURLResponse(url: URL, statusCode: Int) -> HTTPURLResponse? {
        return HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
    }
    
    // MARK: - Test Models
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
                    let sortCode: String
                    let accountNumber: String
                }
            }
            
            struct Authentication: Codable {
                let redirectUrl: String
            }
        }
    }
}
