import XCTest

extension XCUIElement {
    func clearAndEnterText(text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }
        tap()
        // Select all and delete
        let deleteString = stringValue.map { _ in XCUIKeyboardKey.delete.rawValue }.joined(separator: "")
        typeText(deleteString)
        typeText(text)
    }
}
