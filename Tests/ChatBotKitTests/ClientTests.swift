import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ChatBotKit

final class ClientTests: XCTestCase {
    func makeClient(
        token: String? = "test-token",
        baseURL: URL = ChatBotKitOptions.defaultBaseURL,
        configure: (inout ChatBotKitOptions) -> Void = { _ in }
    ) -> ChatBotKit {
        var options = ChatBotKitOptions(token: token, baseURL: baseURL, retryDelay: 0, session: MockURLProtocol.makeSession())

        configure(&options)

        return ChatBotKit(options: options)
    }

    func testFetchSendsAuthAndDecodesResponse() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"c1","createdAt":1,"updatedAt":2,"name":"Hello","meta":{"a":1}}"#) }

        let client = makeClient()

        let conversation = try await client.conversation.fetch("c1")

        XCTAssertEqual(conversation.id, "c1")
        XCTAssertEqual(conversation.name, "Hello")
        XCTAssertEqual(conversation.meta?["a"], .number(1))

        let request = try XCTUnwrap(MockURLProtocol.requests.first)

        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url.absoluteString, "https://api.chatbotkit.com/v1/conversation/c1/fetch")
        XCTAssertEqual(request.header("Authorization"), "Bearer test-token")
        XCTAssertNil(request.header("Content-Type"))
    }

    func testSecretIsAnAliasForToken() {
        XCTAssertEqual(ChatBotKitOptions(secret: "s").token, "s")
        XCTAssertEqual(ChatBotKitOptions(token: "t", secret: "s").token, "t")
    }

    func testOptionalHeaders() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"b1","createdAt":1,"updatedAt":2}"#) }

        let client = makeClient { options in
            options.runAsUserId = "user-1"
            options.runAsChildUserEmail = "child@example.com"
            options.timezone = "Europe/London"
            options.headers = ["X-App": "demo"]
        }

        _ = try await client.bot.fetch("b1")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)

        XCTAssertEqual(request.header("X-RunAs-User-ID"), "user-1")
        XCTAssertEqual(request.header("X-RunAs-Child-User-Email"), "child@example.com")
        XCTAssertEqual(request.header("X-Timezone"), "Europe/London")
        XCTAssertEqual(request.header("X-App"), "demo")
    }

    func testCustomBaseURLKeepsPrefixAndApiPath() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"b1","createdAt":1,"updatedAt":2}"#) }

        let client = makeClient(baseURL: URL(string: "http://localhost:3000/cbk/")!)

        _ = try await client.bot.fetch("b1")

        XCTAssertEqual(MockURLProtocol.requests.first?.url.absoluteString, "http://localhost:3000/cbk/api/v1/bot/b1/fetch")
    }

    func testHostOverride() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"b1","createdAt":1,"updatedAt":2}"#) }

        let client = makeClient { $0.host = "staging.example.com:8443" }

        _ = try await client.bot.fetch("b1")

        XCTAssertEqual(MockURLProtocol.requests.first?.url.absoluteString, "https://staging.example.com:8443/api/v1/bot/b1/fetch")
    }

    func testPathComponentsAreEncoded() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"x","createdAt":1,"updatedAt":2}"#) }

        _ = try await makeClient().bot.fetch("a/b c")

        XCTAssertEqual(MockURLProtocol.requests.first?.url.absoluteString, "https://api.chatbotkit.com/v1/bot/a%2Fb%20c/fetch")
    }

    func testListEncodesQuery() async throws {
        MockURLProtocol.reset { _ in .json(#"{"items":[{"id":"c1","createdAt":1,"updatedAt":2}],"cursor":"next"}"#) }

        let client = makeClient()

        let list = try await client.conversation.list(ConversationListParams(cursor: "abc", meta: ["source": "ios"], order: .desc, take: 10)).value

        XCTAssertEqual(list.items.map(\.id), ["c1"])
        XCTAssertEqual(list.cursor, "next")

        let query = try XCTUnwrap(MockURLProtocol.requests.first).queryItems

        XCTAssertEqual(query, ["cursor": "abc", "meta.source": "ios", "order": "desc", "take": "10"])
    }

    func testCreateEncodesBody() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"c1"}"#) }

        let client = makeClient()

        let created = try await client.conversation.create(
            ConversationCreateRequest(
                contactID: "contact-1",
                messages: [ConversationCreateRequestMessage(text: "Hi", type: .user)],
                meta: ["plan": "pro", "seats": 3],
                botID: "bot-1"
            )
        )

        XCTAssertEqual(created.id, "c1")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)

        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.header("Content-Type"), "application/json")
        XCTAssertEqual(
            request.json,
            [
                "contactId": "contact-1",
                "botId": "bot-1",
                "messages": [["text": "Hi", "type": "user"]],
                "meta": ["plan": "pro", "seats": 3],
            ]
        )
    }

    func testDeleteSendsEmptyRecord() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"c1"}"#) }

        _ = try await makeClient().conversation.delete("c1")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)

        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.json, [:])
    }

    func testStatelessComplete() async throws {
        MockURLProtocol.reset { _ in .json(#"{"text":"Hello!","end":{"reason":"stop"},"usage":{"token":12}}"#) }

        let client = makeClient()

        let reply = try await client.conversation.complete(
            ConversationCompleteRequest(messages: [ConversationCompleteRequestMessage(text: "Hi", type: .user)], model: "gpt-4o")
        ).value

        XCTAssertEqual(reply.text, "Hello!")
        XCTAssertEqual(reply.usage.token, 12)
        XCTAssertEqual(MockURLProtocol.requests.first?.url.path, "/v1/conversation/complete")
    }

    func testExtendLeavesOriginalUntouched() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"b1","createdAt":1,"updatedAt":2}"#) }

        let client = makeClient()
        let scoped = client.extend { $0.runAsUserId = "user-2" }

        _ = try await scoped.bot.fetch("b1")
        _ = try await client.bot.fetch("b1")

        XCTAssertEqual(MockURLProtocol.requests[0].header("X-RunAs-User-ID"), "user-2")
        XCTAssertNil(MockURLProtocol.requests[1].header("X-RunAs-User-ID"))
        XCTAssertNil(client.options.runAsUserId)
    }

    func testResourceClientsWorkOnTheirOwn() async throws {
        MockURLProtocol.reset { _ in .json(#"{"items":[],"cursor":""}"#) }

        let models = PlatformModelClient(options: ChatBotKitOptions(token: "t", session: MockURLProtocol.makeSession()))

        let list = try await models.list(PlatformModelListParams(type: .language)).value

        XCTAssertTrue(list.items.isEmpty)
        XCTAssertEqual(MockURLProtocol.requests.first?.url.absoluteString, "https://api.chatbotkit.com/v1/platform/model/list?type=language")
    }

    func testDecodesUnknownEnumValues() throws {
        let json = #"{"items":[{"id":"m1","createdAt":1,"updatedAt":2,"text":"Hi","type":"brand-new-type"}],"cursor":""}"#

        let list = try ChatBotKitCoding.makeDecoder().decode(ConversationMessageListResponse.self, from: Data(json.utf8))

        XCTAssertEqual(list.items.first?.type.rawValue, "brand-new-type")
    }
}
