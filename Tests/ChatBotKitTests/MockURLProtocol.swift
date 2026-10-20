import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ChatBotKit

struct MockResponse {
    var status: Int = 200
    var headers: [String: String] = ["Content-Type": "application/json"]
    var chunks: [Data] = []
    var holdOpen = false

    static func json(_ string: String, status: Int = 200) -> MockResponse {
        MockResponse(status: status, chunks: [Data(string.utf8)])
    }

    static func text(_ string: String, status: Int, contentType: String = "text/plain") -> MockResponse {
        MockResponse(status: status, headers: ["Content-Type": contentType], chunks: [Data(string.utf8)])
    }

    static func jsonl(_ chunks: [String], status: Int = 200, holdOpen: Bool = false) -> MockResponse {
        MockResponse(status: status, headers: ["Content-Type": "application/jsonl"], chunks: chunks.map { Data($0.utf8) }, holdOpen: holdOpen)
    }
}

struct RecordedRequest {
    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?

    func header(_ name: String) -> String? {
        headers.first { $0.key.lowercased() == name.lowercased() }?.value
    }

    var json: JSONValue? {
        body.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
    }

    var queryItems: [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
    }
}

final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((RecordedRequest) -> MockResponse)?
    nonisolated(unsafe) private static var recorded: [RecordedRequest] = []
    nonisolated(unsafe) private static var stopped = 0

    static func reset(_ handler: @escaping (RecordedRequest) -> MockResponse) {
        lock.lock()
        self.handler = handler
        recorded = []
        stopped = 0
        lock.unlock()
    }

    static var requests: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static var stopCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral

        configuration.protocolClasses = [MockURLProtocol.self]

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let recordedRequest = RecordedRequest(
            url: request.url!,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.readBody(of: request)
        )

        Self.lock.lock()
        Self.recorded.append(recordedRequest)
        let handler = Self.handler
        Self.lock.unlock()

        let mock = handler?(recordedRequest) ?? MockResponse(status: 500)

        let response = HTTPURLResponse(url: request.url!, statusCode: mock.status, httpVersion: "HTTP/1.1", headerFields: mock.headers)!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        for chunk in mock.chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }

        if !mock.holdOpen {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        Self.lock.lock()
        Self.stopped += 1
        Self.lock.unlock()
    }

    private static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)

            if count <= 0 { break }

            data.append(buffer, count: count)
        }

        return data
    }
}
