import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ChatBotKit

func withTimeout<T: Sendable>(_ seconds: Double = 5, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await body() }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

            throw TimeoutError()
        }

        defer { group.cancelAll() }

        return try await group.next()!
    }
}

final class StreamTests: XCTestCase {
    func makeClient() -> ChatBotKit {
        ChatBotKit(options: ChatBotKitOptions(token: "session-token", retryDelay: 0, session: MockURLProtocol.makeSession()))
    }

    func testStreamsTypedItemsAcrossChunkBoundaries() async throws {
        MockURLProtocol.reset { _ in
            .jsonl([
                #"{"type":"token","data":{"token":"Hel"}}"# + "\n" + #"{"type":"tok"#,
                #"en","data":{"token":"lo"}}"# + "\r\n\n",
                #"{"type":"result","data":{"id":"m1","text":"Hello","end":{"reason":"stop"},"usage":{"token":2}}}"#,
            ])
        }

        var tokens: [String] = []
        var result: String?

        for try await item in makeClient().conversation.complete("c1", ConversationMessageCompleteRequest(text: "Hi")).stream() {
            switch item.type {
            case .token:
                tokens.append(item.data.token ?? "")
            case .result:
                result = item.data.text
            default:
                break
            }
        }

        XCTAssertEqual(tokens, ["Hel", "lo"])
        XCTAssertEqual(result, "Hello")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)

        XCTAssertEqual(request.header("Accept"), "application/jsonl")
        XCTAssertEqual(request.header("Authorization"), "Bearer session-token")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.path, "/v1/conversation/c1/complete")
        XCTAssertEqual(request.json, ["text": "Hi"])
    }

    func testUnknownEventTypesStillDecode() async throws {
        MockURLProtocol.reset { _ in
            .jsonl([#"{"type":"somethingNew","data":{"token":"x"}}"# + "\n"])
        }

        var types: [String] = []

        for try await item in makeClient().conversation.complete("c1", ConversationMessageCompleteRequest(text: "Hi")).stream() {
            types.append(item.type.rawValue)
        }

        XCTAssertEqual(types, ["somethingNew"])
    }

    func testRawStreamEvents() async throws {
        MockURLProtocol.reset { _ in
            .jsonl([#"{"type":"token","data":{"token":"A"}}"# + "\n" + #"{"type":"custom","data":{"value":[1,2]}}"# + "\n"])
        }

        var events: [StreamEvent] = []

        for try await event in makeClient().conversation.send("c1", ConversationMessageSendRequest(text: "Hi")).stream(as: StreamEvent.self) {
            events.append(event)
        }

        XCTAssertEqual(events.map(\.type), ["token", "custom"])
        XCTAssertEqual(events[1].data["value"], [1, 2])

        struct Token: Decodable { let token: String }

        XCTAssertEqual(try events[0].decode(Token.self).token, "A")
    }

    func testStreamErrorStatusThrowsFetchError() async {
        MockURLProtocol.reset { _ in .json(#"{"message":"Not authorized","code":"NOT_AUTHORIZED"}"#, status: 403) }

        do {
            for try await _ in makeClient().conversation.receive("c1").stream() {}

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.code, "NOT_AUTHORIZED")
            XCTAssertEqual(error.status, 403)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testStreamRetriesBeforeTheBodyStarts() async throws {
        let counter = Counter()

        MockURLProtocol.reset { _ in
            counter.increment() == 1
                ? .json(#"{"message":"busy"}"#, status: 502)
                : .jsonl([#"{"type":"token","data":{"token":"ok"}}"# + "\n"])
        }

        var tokens: [String] = []

        for try await item in makeClient().conversation.complete("c1", ConversationMessageCompleteRequest(text: "Hi")).stream() {
            tokens.append(item.data.token ?? "")
        }

        XCTAssertEqual(tokens, ["ok"])
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
    }

    func testInvalidLineThrows() async {
        MockURLProtocol.reset { _ in .jsonl(["not json\n"]) }

        do {
            for try await _ in makeClient().conversation.receive("c1").stream(as: StreamEvent.self) {}

            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testBreakingOutCancelsTheRequest() async throws {
        MockURLProtocol.reset { _ in
            .jsonl([#"{"type":"token","data":{"token":"first"}}"# + "\n"], holdOpen: true)
        }

        let client = makeClient()

        let first = try await withTimeout {
            for try await item in client.conversation.complete("c1", ConversationMessageCompleteRequest(text: "Hi")).stream() {
                return item.data.token
            }

            return nil
        }

        XCTAssertEqual(first, "first")

        let deadline = Date().addingTimeInterval(5)

        while MockURLProtocol.stopCount == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertGreaterThan(MockURLProtocol.stopCount, 0)
    }

    func testCancellingTheTaskEndsTheStream() async throws {
        MockURLProtocol.reset { _ in
            .jsonl([#"{"type":"token","data":{"token":"first"}}"# + "\n"], holdOpen: true)
        }

        let client = makeClient()
        let received = Counter()

        let task = Task {
            for try await _ in client.conversation.complete("c1", ConversationMessageCompleteRequest(text: "Hi")).stream() {
                _ = received.increment()
            }
        }

        let deadline = Date().addingTimeInterval(5)

        while MockURLProtocol.requests.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        task.cancel()

        _ = try? await withTimeout { try await task.value }

        while MockURLProtocol.stopCount == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertGreaterThan(MockURLProtocol.stopCount, 0)
    }

    func testJSONLLineBuffer() {
        var buffer = JSONLLineBuffer()

        XCTAssertEqual(buffer.append(Data("{\"a\":1}\n\n  \r\n{\"b\"".utf8)).map { String(decoding: $0, as: UTF8.self) }, ["{\"a\":1}"])
        XCTAssertEqual(buffer.append(Data(":2}\r\n{\"c\":3}".utf8)).map { String(decoding: $0, as: UTF8.self) }, ["{\"b\":2}"])
        XCTAssertEqual(buffer.flush().map { String(decoding: $0, as: UTF8.self) }, "{\"c\":3}")
        XCTAssertNil(buffer.flush())
    }

    func testListStreamsItems() async throws {
        MockURLProtocol.reset { _ in
            .jsonl([
                #"{"type":"item","data":{"id":"b1","createdAt":1,"updatedAt":2}}"# + "\n",
                #"{"type":"item","data":{"id":"b2","createdAt":1,"updatedAt":2}}"# + "\n",
            ])
        }

        var ids: [String] = []

        for try await item in makeClient().bot.list().stream() {
            ids.append(item.data.id)
        }

        XCTAssertEqual(ids, ["b1", "b2"])
        XCTAssertEqual(MockURLProtocol.requests.first?.method, "GET")
    }
}
