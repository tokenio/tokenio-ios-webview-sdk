import XCTest

// MARK: - XCTestCase Helpers
extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
    
    func waitForExpectations(timeout: TimeInterval = 1.0) {
        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail("Asynchronous wait failed: \(error)")
            }
        }
    }
}

// MARK: - Equatable Helpers
func XCTAssertEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T?,
    _ expression2: @autoclosure () throws -> T?,
    file: StaticString = #filePath,
    line: UInt = #line
) rethrows {
    let value1 = try expression1()
    let value2 = try expression2()
    
    if value1 != value2 {
        XCTFail("\"\(String(describing: value1))\" is not equal to \"\(String(describing: value2))\"", file: file, line: line)
    }
}
