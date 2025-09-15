import XCTest
@testable import TokenTestiOS

// MARK: - MockKeychainProvider
class MockKeychainProvider: NSObject, KeychainProvider {
    var shouldSucceed = true
    var mockApiKey = "test_api_key_123"
    var shouldThrowError: KeychainError? = nil
    
    func getApiKey() throws -> String {
        if let error = shouldThrowError {
            throw error
        }
        return mockApiKey
    }
}

// MARK: - PaymentServiceTests
class PaymentServiceTests: XCTestCase {
    
    // MARK: - Properties
    private var sut: PaymentService!
    private var mockSession: MockURLSession!
    private var mockKeychainProvider: MockKeychainProvider!
    private let testURL = URL(string: "https://api.example.com")!
    private let testEnvironment = ApiEnvironment.sandbox
    
    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockKeychainProvider = MockKeychainProvider()
        
        // Initialize PaymentService with our mock session and keychain provider
        sut = PaymentService(session: mockSession, keychainProvider: mockKeychainProvider)
        
        // Configure the mock keychain provider
        mockKeychainProvider.shouldSucceed = true
        mockKeychainProvider.mockApiKey = "test_api_key_123"
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        mockKeychainProvider = nil
        super.tearDown()
    }
    
    // MARK: - Init Tests
    func test_init_createsObject() {
        XCTAssertNotNil(sut)
    }
    
    func testInitiatePayment_Success() {
        // Given
        let expectation = self.expectation(description: "Initiate payment")
        let mockResponse = TestDataFactory.createPaymentResponse()
        let responseData = try! JSONEncoder().encode(mockResponse)
        
        mockSession.data = responseData
        mockSession.response = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                             statusCode: 200,
                                             httpVersion: nil,
                                             headerFields: nil)!
        
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
            case .success(let response):
                XCTAssertEqual(response.redirectUrl.absoluteString, mockResponse.payment.authentication.redirectUrl)
                // Can't directly compare state as it's randomly generated
                XCTAssertFalse(response.state.isEmpty)
            case .failure(let error):
                XCTFail("Expected success, got \(error) instead")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testInitiatePayment_NetworkError() {
        // Given
        let expectation = self.expectation(description: "Network error")
        let expectedError = NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."])
        
        mockSession.error = expectedError
        
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
                XCTFail("Expected failure, got success instead")
            case .failure(let error as NSError):
                XCTAssertEqual(error.domain, expectedError.domain)
                XCTAssertEqual(error.code, expectedError.code)
            }
            expectation.fulfill()
        }
        
        // Simulate the URLSession completion
        mockSession.completionHandler?(nil, nil, expectedError)
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testGetPaymentStatus_Success() async {
        // Given
        let paymentResponse = TestDataFactory.createPaymentResponse()
        let responseData = try! JSONEncoder().encode(paymentResponse)
        
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/payments/\(paymentResponse.payment.id)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        
        mockSession.data = responseData
        mockSession.response = urlResponse
        
        do {
            // When
            let status = try await sut.getPaymentStatus(
                paymentId: paymentResponse.payment.id,
                environment: testEnvironment
            )
            
            // Then
            XCTAssertEqual(status.status, paymentResponse.payment.status)
            XCTAssertEqual(status.statusReasonInformation, paymentResponse.payment.statusReasonInformation)
            XCTAssertEqual(status.currency, paymentResponse.payment.initiation.amount.currency)
            XCTAssertEqual(status.value, paymentResponse.payment.initiation.amount.value)
            XCTAssertEqual(status.refId, paymentResponse.payment.initiation.refId)
        } catch {
            XCTFail("Expected success, got \(error) instead")
        }
    }
    
    func testGetPaymentStatus_InvalidResponse() async {
        // Given
        let mockResponse = ["invalid": "response"]
        let responseData = try! JSONEncoder().encode(mockResponse)
        
        mockSession.data = responseData
        mockSession.response = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                             statusCode: 200,
                                             httpVersion: nil,
                                             headerFields: nil)!
        
        do {
            // When
            _ = try await sut.getPaymentStatus(
                paymentId: "test_payment_123",
                environment: testEnvironment
            )
            
            // Then
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Keychain Failure Tests
    
    func testInitiatePayment_KeychainFailure() {
        // Given
        mockKeychainProvider.shouldThrowError = .noData
        let expectation = self.expectation(description: "Initiate payment with keychain failure")
        
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
                XCTFail("Expected failure but got success")
            case .failure(let error):
                if case PaymentServiceError.missingApiKey = error {
                    // Success - this is the expected error
                } else {
                    XCTFail("Expected PaymentServiceError.missingApiKey but got \(error)")
                }
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testGetPaymentStatus_KeychainFailure() async {
        // Given
        mockKeychainProvider.shouldThrowError = .noData
        
        do {
            // When
            _ = try await sut.getPaymentStatus(
                paymentId: "test_payment_123",
                environment: testEnvironment
            )
            
            // Then
            XCTFail("Expected error to be thrown")
        } catch PaymentServiceError.missingApiKey {
            // Success - this is the expected error
        } catch {
            XCTFail("Expected PaymentServiceError.missingApiKey but got \(error)")
        }
    }
    
    // MARK: - HTTP Status Code Tests
    
    func testInitiatePayment_Unauthorized() {
        // Given
        let expectation = self.expectation(description: "Initiate payment unauthorized")
        let statusCode = 401
        
        mockSession.response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        
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
                XCTFail("Expected failure but got success")
            case .failure(let error as NSError):
                // Should be a payment service error with the status code
                XCTAssertEqual(error.domain, "PaymentService")
                XCTAssertEqual(error.code, statusCode)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Input Validation Tests
    
    func testInitiatePayment_InvalidAmount() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with invalid amount")
        
        // When
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "not_a_number",
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
            case .failure(let error):
                // Should be a validation error
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testInitiatePayment_MissingRequiredParameters() {
        // Given
        let expectation = self.expectation(description: "Initiate payment with missing parameters")
        
        // When - Missing creditor name
        sut.initiatePayment(
            environment: testEnvironment,
            currency: "GBP",
            amountValue: "10.00",
            localInstrument: "UK.OBIE.FPS",
            creditorName: "", // Empty name
            creditorIBAN: nil,
            creditorSortCode: "040004",
            creditorAccountNumber: "12345678"
        ) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure due to missing creditor name")
            case .failure(let error):
                // Should be a validation error
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentPaymentRequests() {
        // Given
        let count = 5
        let expectation = self.expectation(description: "All concurrent requests completed")
        expectation.expectedFulfillmentCount = count
        
        let mockResponse = TestDataFactory.createPaymentResponse()
        let responseData = try! JSONEncoder().encode(mockResponse)
        
        mockSession.data = responseData
        mockSession.response = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                             statusCode: 200,
                                             httpVersion: nil,
                                             headerFields: nil)!
        
        // When
        for _ in 0..<count {
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
                    break // Success
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5)
    }
}
