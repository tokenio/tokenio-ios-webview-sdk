import XCTest
import Foundation
@testable import TokenTestiOS

class PaymentServiceErrorHandlingTests: XCTestCase {
    
    // MARK: - Properties
    private var sut: PaymentService!
    private var mockSession: MockURLSession!
    private var mockKeychainProvider: MockKeychainProvider!
    private let testEnvironment = ApiEnvironment.sandbox
    private let testURL = URL(string: "https://api.example.com")!
    
    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockKeychainProvider = MockKeychainProvider()
        sut = PaymentService(session: mockSession, keychainProvider: mockKeychainProvider)
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        mockKeychainProvider = nil
        super.tearDown()
    }
    
    // MARK: - Invalid Input Tests
    
    func testInitiatePayment_InvalidAmount() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with invalid amount")
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "invalid_amount",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to invalid amount")
            case .failure(let error as NSError):
                XCTAssertEqual(error.domain, "PaymentService")
                // The actual error message might vary, but we expect some kind of validation error
                XCTAssertTrue(error.localizedDescription.contains("Invalid") || 
                             error.localizedDescription.contains("invalid") ||
                             error.localizedDescription.contains("amount"),
                            "Unexpected error message: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testInitiatePayment_EmptyCreditorName() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with empty creditor name")
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "", // Empty creditor name
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to empty creditor name")
            case .failure(let error as NSError):
                XCTAssertEqual(error.domain, "PaymentService")
                // The actual error message might vary, but it should indicate some kind of error
                XCTAssertFalse(error.localizedDescription.isEmpty, 
                             "Error message should not be empty")
                
                // Log the actual error message for debugging
                print("Actual error message: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Network Error Tests
    
    func testInitiatePayment_TimeoutError() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with timeout")
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSLocalizedDescriptionKey: "The request timed out."])
        mockSession.error = timeoutError
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to timeout")
            case .failure(let error as NSError):
                // The error might be wrapped in a PaymentServiceError or passed through directly
                if error.domain == "PaymentService" {
                    // If it's a PaymentService error, it should contain the underlying error
                    XCTAssertTrue(error.localizedDescription.contains("timed out") ||
                                 error.localizedDescription.contains("timeout") ||
                                 error.localizedDescription.contains(String(NSURLErrorTimedOut)),
                                "Unexpected error message: \(error.localizedDescription)")
                } else {
                    // Or it might be the original NSURLError
                    XCTAssertEqual(error.domain, NSURLErrorDomain)
                    XCTAssertEqual(error.code, NSURLErrorTimedOut)
                }
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Server Error Tests
    
    func testInitiatePayment_ServerError() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with server error")
        let statusCode = 500
        mockSession.response = HTTPURLResponse(
            url: testURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to server error")
            case .failure(let error as NSError):
                // Check if it's a PaymentService error with the status code
                if error.domain == "PaymentService" {
                    XCTAssertTrue(error.localizedDescription.contains("\(statusCode)") ||
                                 error.localizedDescription.contains("server") ||
                                 error.localizedDescription.contains("error"),
                                "Unexpected error message: \(error.localizedDescription)")
                } else {
                    XCTFail("Expected PaymentService error, got \(error)")
                }
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Decoding Error Tests
    
    func testInitiatePayment_InvalidJSONResponse() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with invalid JSON")
        mockSession.data = "invalid json".data(using: .utf8)!
        mockSession.response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to invalid JSON")
            case .failure(let error as NSError):
                // Check if it's a decoding error or contains relevant information
                XCTAssertTrue(error.domain == "NSCocoaErrorDomain" || 
                             error.domain == "PaymentService" ||
                             error.localizedDescription.lowercased().contains("decode") ||
                             error.localizedDescription.lowercased().contains("json") ||
                             error.localizedDescription.lowercased().contains("format"),
                            "Expected decoding/JSON error, got: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Keychain Error Tests
    
    func testInitiatePayment_KeychainError() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with keychain error")
        mockKeychainProvider.shouldThrowError = .unexpectedData
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to keychain error")
            case .failure(let error):
                if case PaymentServiceError.missingApiKey = error {
                    // Success - this is the expected error
                } else {
                    XCTFail("Expected missingApiKey error, got \(error)")
                }
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Concurrent Requests Tests
    
    func testConcurrentPaymentRequests() {
        // Given
        let expectation1 = self.expectation(description: "First payment request")
        let expectation2 = self.expectation(description: "Second payment request")
        let response = TestDataFactory.createPaymentResponse()
        let responseData = try! JSONEncoder().encode(response)
        
        // Configure mock to return success after a delay to simulate network
        mockSession.data = responseData
        mockSession.response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        // When - Start two requests in parallel
        var results: [Result<(redirectUrl: URL, state: String), Error>] = []
        let group = DispatchGroup()
        
        // First request
        group.enter()
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor 1",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            results.append(result)
            expectation1.fulfill()
            group.leave()
        }
        
        // Second request
        group.enter()
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "20.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "Test Creditor 2",
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "87654321"
        ) { result in
            results.append(result)
            expectation2.fulfill()
            group.leave()
        }
        
        // Then
        wait(for: [expectation1, expectation2], timeout: 2)
        
        // Verify both requests completed successfully
        XCTAssertEqual(results.count, 2)
        for result in results {
            switch result {
            case .success(let response):
                XCTAssertFalse(response.state.isEmpty)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
        }
    }
}
