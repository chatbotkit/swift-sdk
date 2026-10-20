import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ChatBotKit

func requireSendable<T: Sendable>(_ value: T) -> T {
    value
}

final class ConcurrencyTests: XCTestCase {
    func makeClient() -> ChatBotKit {
        ChatBotKit(options: ChatBotKitOptions(token: "t", retryDelay: 0, session: MockURLProtocol.makeSession()))
    }

    func testClientsAreSendable() {
        let client = makeClient()

        _ = requireSendable(client)
        _ = requireSendable(client.client)
        _ = requireSendable(client.options)
        _ = requireSendable(client.conversation)
        _ = requireSendable(client.conversation.message)
        _ = requireSendable(client.conversation.session)
        _ = requireSendable(client.conversation.attachment)
        _ = requireSendable(client.bot.session)
        _ = requireSendable(client.dataset.record)
        _ = requireSendable(client.dataset.file)
        _ = requireSendable(client.skillset.ability)
        _ = requireSendable(client.file)
        _ = requireSendable(client.contact.conversation)
        _ = requireSendable(client.user.session)
        _ = requireSendable(client.platform.model)
        _ = requireSendable(client.conversation.list())
    }

    func testResourceClientsShareOneClient() {
        let client = makeClient()

        XCTAssertTrue(client.conversation.client === client.client)
        XCTAssertTrue(client.conversation.message.client === client.client)
        XCTAssertTrue(client.dataset.record.client === client.client)
        XCTAssertTrue(client.platform.model.client === client.client)
    }

    func testExtendGivesResourceClientsTheNewOptions() {
        let client = makeClient()

        let scoped = client.extend { $0.runAsUserId = "user-2" }

        XCTAssertFalse(scoped.client === client.client)
        XCTAssertEqual(scoped.conversation.message.options.runAsUserId, "user-2")
        XCTAssertNil(client.conversation.message.options.runAsUserId)

        let conversations = ConversationClient(options: client.options).extend { $0.timezone = "Europe/London" }

        XCTAssertEqual(conversations.options.timezone, "Europe/London")
        XCTAssertEqual(conversations.message.options.timezone, "Europe/London")
    }

    func testOneClientServesConcurrentTasks() async throws {
        MockURLProtocol.reset { request in
            .json(#"{"id":"\#(request.url.pathComponents[3])","createdAt":1,"updatedAt":2}"#)
        }

        let client = makeClient()

        let ids = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<20 {
                group.addTask {
                    try await client.bot.fetch("b\(index)").id
                }
            }

            var ids: [String] = []

            for try await id in group {
                ids.append(id)
            }

            return ids
        }

        XCTAssertEqual(Set(ids), Set((0..<20).map { "b\($0)" }))
        XCTAssertEqual(MockURLProtocol.requests.count, 20)
    }

    func testCancellingAFetchThrowsCancellationError() async throws {
        MockURLProtocol.reset { _ in MockResponse(chunks: [], holdOpen: true) }

        let client = makeClient()

        let task = Task {
            try await client.bot.fetch("b1")
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        task.cancel()

        do {
            _ = try await withTimeout { try await task.value }

            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
    }

    func testStreamWithAnEmptyBodyFinishes() async throws {
        MockURLProtocol.reset { _ in .jsonl([]) }

        let client = makeClient()

        let items = try await withTimeout {
            var items: [StreamEvent] = []

            for try await item in client.conversation.list().stream(as: StreamEvent.self) {
                items.append(item)
            }

            return items
        }

        XCTAssertTrue(items.isEmpty)
    }
}
