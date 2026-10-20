import XCTest
import Foundation
import ChatBotKit

final class ReadmeExamplesTests: XCTestCase {
    func testReadmeExamplesCompile() {
        XCTAssertNotNil(readmeExamples as Any)
    }
}

private func readmeExamples() async throws {
    let client = ChatBotKit(token: "your-api-secret")

    let conversation = try await client.conversation.create(
        ConversationCreateRequest(backstory: "You are a helpful assistant.", model: "gpt-4o")
    )

    let reply = try await client.conversation.complete(
        conversation.id,
        ConversationMessageCompleteRequest(text: "Hello!")
    ).value

    print(reply.text)

    let stream = client.conversation.complete(
        conversation.id,
        ConversationMessageCompleteRequest(text: "Tell me a story")
    ).stream()

    for try await item in stream {
        switch item.type {
        case .token:
            print(item.data.token ?? "", terminator: "")
        case .result:
            print("\n\(item.data.usage?.token ?? 0) tokens")
        default:
            break
        }
    }

    let stateless = client.conversation.complete(
        ConversationCompleteRequest(
            messages: [ConversationCompleteRequestMessage(text: "Hi!", type: .user)],
            model: "gpt-4o"
        )
    ).stream()

    for try await item in stateless {
        print(item.data.token ?? "")
    }

    for try await event in client.conversation.receive(conversation.id).stream(as: StreamEvent.self) {
        print(event.type, event.data)
    }

    for try await item in client.bot.list().stream() {
        print(item.data.id, item.data.name ?? "")
    }

    let server = ChatBotKit(token: ProcessInfo.processInfo.environment["CHATBOTKIT_API_SECRET"] ?? "")

    let botSession = try await server.bot.session.create("bot-id")

    print(botSession.conversationID, botSession.token, botSession.expiresAt)

    let conversationSession = try await server.conversation.session.create(
        conversation.id,
        ConversationSessionCreateRequest(durationInSeconds: 3600)
    )

    let app = ChatBotKit(token: conversationSession.token)

    for try await item in app.conversation.complete(conversation.id, ConversationMessageCompleteRequest(text: "Hi")).stream() {
        print(item.type)
    }

    let configured = ChatBotKit(
        options: ChatBotKitOptions(
            token: "your-api-secret",
            baseURL: URL(string: "https://api.chatbotkit.com")!,
            runAsUserId: "user-id",
            timezone: "Europe/London",
            headers: ["X-App-Version": "1.0"],
            timeout: 60,
            retries: 3,
            retryDelay: 0.25,
            session: .shared
        )
    )

    _ = configured.extend { $0.runAsUserId = "other-user" }

    let response: BlueprintListResponse = try await client.fetch(
        ClientRequest(path: "/api/v1/blueprint/list", query: BlueprintListParams(take: 10))
    )

    print(response.items.count)

    let pdfData = Data()
    let imageData = Data()

    let file = try await client.file.create(FileCreateRequest(name: "handbook.pdf"))

    try await client.file.upload(file.id, data: pdfData, name: "handbook.pdf", type: "application/pdf")

    try await client.conversation.attachment.upload(conversation.id, data: imageData, name: "photo.jpg", type: "image/jpeg")

    do {
        _ = try await client.conversation.fetch("missing")
    } catch let error as FetchError where error.code == "NOT_FOUND" {
        print("No such conversation")
    }

    _ = ConversationClient(options: ChatBotKitOptions(token: "t"))
}
