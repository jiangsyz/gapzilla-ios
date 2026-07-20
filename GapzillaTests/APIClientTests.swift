import Foundation
import XCTest
@testable import Gapzilla

final class APIClientTests: XCTestCase {
    func testServerErrorWithoutDataPreservesBusinessMessage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIClientStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = APIClient(
            baseURL: try XCTUnwrap(URL(string: "https://gapzilla.test")),
            session: session
        )
        APIClientStubURLProtocol.responseData = Data(
            #"{"code":40001,"message":"apple account choice has expired"}"#.utf8
        )

        do {
            let _: EmptyData = try await api.get("/api/v1/test")
            XCTFail("Expected the server error to be thrown")
        } catch let APIClientError.server(code, message) {
            XCTAssertEqual(code, 40001)
            XCTAssertEqual(message, "apple account choice has expired")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class APIClientStubURLProtocol: URLProtocol {
    static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
