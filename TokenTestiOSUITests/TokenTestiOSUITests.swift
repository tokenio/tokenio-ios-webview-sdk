//
//  TokenTestiOSUITests.swift
//  TokenTestiOSUITests
//
//  Created by Josh Lister on 10/04/2025.
//

import XCTest

final class TokenTestiOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testPaymentSuccessFlow_withMockAPI() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-useMockAPI")
        app.launch()

        // Fill out payment form (assuming default values are present, adjust selectors as needed)
        let amountField = app.textFields["Amount"]
        if amountField.exists {
            amountField.tap()
            amountField.clearAndEnterText(text: "10.00")
        }

        // Tap 'Pay by bank' button
        let payButton = app.buttons["Pay by bank"]
        XCTAssertTrue(payButton.waitForExistence(timeout: 2), "Pay by bank button should exist")
        payButton.tap()

        // Wait for mock redirect and status polling to complete
        let successLabel = app.staticTexts["Payment Successful"]
        let exists = successLabel.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "Payment Successful UI should appear after mock payment flow")
    }

    // Helper for clearing and entering text
    // Add this as an extension for XCUIElement
    // (You may want to move this to a shared test utility file)
    // Usage: element.clearAndEnterText(text: "new text")
    // If not allowed, you can inline this logic in the test
    


    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
