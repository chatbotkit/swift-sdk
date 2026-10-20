import ChatBotKit
import ChatCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class StubURLProtocol: URLProtocol {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var paths: [String] = []
    nonisolated(unsafe) static var authorizations: [String?] = []

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral

        configuration.protocolClasses = [StubURLProtocol.self]

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.paths.append(request.url?.path ?? "")
        Self.authorizations.append(request.value(forHTTPHeaderField: "Authorization"))
        let handler = Self.handler
        Self.lock.unlock()

        let (status, body) = handler?(request) ?? (500, "")

        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class FakeBackend: ChatBackend, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var sessionRequests: [String?] = []
    var expiresAt: Double = Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000

    private func record(_ conversationId: String?) -> Int {
        lock.lock()
        defer { lock.unlock() }

        sessionRequests.append(conversationId)

        return sessionRequests.count
    }

    func createSession(conversationId: String?) async throws -> ChatSession {
        let count = record(conversationId)

        return ChatSession(conversationId: conversationId ?? "new-conversation", token: "token-\(count)", expiresAt: expiresAt)
    }

    func listConversations() async throws -> [ConversationSummary] {
        [ConversationSummary(id: "c1", name: "First")]
    }

    func listMessages(conversationId: String) async throws -> [HistoryMessage] {
        [
            HistoryMessage(id: "m1", type: "user", text: "Hi"),
            HistoryMessage(id: "m2", type: "activity", text: "ignored"),
            HistoryMessage(id: "m3", type: "bot", text: "Hello"),
        ]
    }
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    override func setUp() {
        StubURLProtocol.lock.lock()
        StubURLProtocol.paths = []
        StubURLProtocol.authorizations = []
        StubURLProtocol.lock.unlock()
    }

    func makeOptions() -> ChatBotKitOptions {
        ChatBotKitOptions(baseURL: URL(string: "https://api.example.com")!, retries: 0, session: StubURLProtocol.makeSession())
    }

    func testNewChatCreatesSessionUploadsAndStreams() async {
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/v1/conversation/new-conversation/attachment/upload":
                return (200, #"{"id":"a1","name":"a1.txt","uploadRequest":{"url":"https://storage.example.com/a1","method":"PUT","headers":{}}}"#)
            case "/a1":
                return (200, "")
            default:
                return (200, [
                    #"{"type":"token","data":{"token":"Hel"}}"#,
                    #"{"type":"token","data":{"token":"lo"}}"#,
                    #"{"type":"result","data":{"text":"Hello!"}}"#,
                ].joined(separator: "\n"))
            }
        }

        let backend = FakeBackend()
        let model = ChatViewModel(conversationId: nil, backend: backend, options: makeOptions())

        var created: String?

        model.onConversationCreated = { created = $0 }

        model.draft = "Hi"
        model.pendingAttachments = [.init(name: "notes.txt", type: "text/plain", data: Data("x".utf8))]

        XCTAssertTrue(model.canSend)

        model.send()

        await model.waitForReply()

        XCTAssertEqual(created, "new-conversation")
        XCTAssertEqual(model.conversationId, "new-conversation")
        XCTAssertEqual(backend.sessionRequests, [nil])
        XCTAssertEqual(model.messages.map(\.text), ["Hi", "Hello!"])
        XCTAssertEqual(model.messages.first?.attachments, ["notes.txt"])
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isStreaming)
        XCTAssertEqual(model.draft, "")

        XCTAssertEqual(
            StubURLProtocol.paths,
            ["/api/v1/conversation/new-conversation/attachment/upload", "/a1", "/api/v1/conversation/new-conversation/complete"]
        )
        XCTAssertEqual(StubURLProtocol.authorizations, ["Bearer token-1", nil, "Bearer token-1"])
    }

    func testLoadsHistory() async {
        let model = ChatViewModel(conversationId: "c1", backend: FakeBackend(), options: makeOptions())

        await model.load()

        XCTAssertEqual(model.messages.map(\.role), [.user, .bot])
        XCTAssertEqual(model.messages.map(\.text), ["Hi", "Hello"])
    }

    func testShowsApiErrors() async {
        StubURLProtocol.handler = { _ in (403, #"{"message":"Session expired","code":"NOT_AUTHORIZED"}"#) }

        let model = ChatViewModel(conversationId: "c1", backend: FakeBackend(), options: makeOptions())

        model.draft = "Hi"
        model.send()

        await model.waitForReply()

        XCTAssertEqual(model.errorMessage, "Session expired")
        XCTAssertEqual(model.messages.map(\.role), [.user])
    }

    func testRefreshesExpiringSessions() async {
        StubURLProtocol.handler = { _ in (200, #"{"type":"result","data":{"text":"ok"}}"#) }

        let backend = FakeBackend()

        backend.expiresAt = Date().timeIntervalSince1970 * 1000

        let model = ChatViewModel(conversationId: "c1", backend: backend, options: makeOptions())

        model.draft = "one"
        model.send()
        await model.waitForReply()

        model.draft = "two"
        model.send()
        await model.waitForReply()

        XCTAssertEqual(backend.sessionRequests, ["c1", "c1"])
        XCTAssertEqual(StubURLProtocol.authorizations, ["Bearer token-1", "Bearer token-2"])
    }

    func testStoreOpensAndCreatesChats() async {
        let store = ChatStore(backend: FakeBackend(), options: makeOptions())

        await store.refresh()

        XCTAssertEqual(store.conversations.map(\.id), ["c1"])

        store.open("c1")

        let first = store.current

        store.open("c1")

        XCTAssertTrue(first === store.current)
        XCTAssertEqual(store.selection, "c1")

        store.newChat()

        XCTAssertNil(store.selection)
    }
}
