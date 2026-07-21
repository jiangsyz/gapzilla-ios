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

    func testDeleteWithBodySendsAppleCredential() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIClientStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = APIClient(
            baseURL: try XCTUnwrap(URL(string: "https://gapzilla.test")),
            session: session
        )
        APIClientStubURLProtocol.responseData = Data(
            #"{"code":0,"message":"ok","data":{"deleted":true}}"#.utf8
        )
        APIClientStubURLProtocol.lastRequest = nil
        APIClientStubURLProtocol.lastRequestBody = nil
        let credential = AppleCredential(
            identityToken: "identity-token",
            authorizationCode: "authorization-code",
            nonce: "nonce",
            fullName: ""
        )

        let data: DeleteAccountData = try await api.delete(
            "/api/v1/users/me",
            body: DeleteAccountPayload(credential: credential)
        )

        XCTAssertTrue(data.deleted)
        let request = try XCTUnwrap(APIClientStubURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(APIClientStubURLProtocol.lastRequestBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let encodedCredential = try XCTUnwrap(json["credential"] as? [String: Any])
        XCTAssertEqual(encodedCredential["authorization_code"] as? String, "authorization-code")
    }
}

private final class APIClientStubURLProtocol: URLProtocol {
    static var responseData = Data()
    static var lastRequest: URLRequest?
    static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = readBody(from: request)
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

    private func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
