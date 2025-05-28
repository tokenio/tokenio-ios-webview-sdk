import Foundation
@testable import TokenTestiOS

// MARK: - MockURLProtocol
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (Data?, HTTPURLResponse, Error?))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }
        
        do {
            let (data, response, error) = try handler(request)
            
            if let error = error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        // Required method, implement as a no-op.
    }
}

// MARK: - MockURLSession
class MockURLSession: URLSessionProtocol {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    var lastRequest: URLRequest?
    
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        self.lastRequest = request
        self.completionHandler = completionHandler
        
        let task = MockURLSessionDataTask { [weak self] in
            guard let self = self else { return }
            completionHandler(self.data, self.response, self.error)
            self.completionHandler = nil
        }
        return task
    }
    
    @available(iOS 15.0, *)
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.lastRequest = request
        
        if let error = error {
            throw error
        }
        
        guard let data = data, let response = response else {
            throw NSError(domain: "MockURLSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock data or response provided"])
        }
        
        return (data, response)
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    private let closure: () -> Void
    
    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
    
    override func resume() {
        closure()
    }
}
