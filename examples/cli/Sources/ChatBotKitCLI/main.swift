import ChatBotKit
import Foundation

let environment = ProcessInfo.processInfo.environment

guard let secret = environment["CHATBOTKIT_API_SECRET"], !secret.isEmpty else {
    FileHandle.standardError.write(Data("Set CHATBOTKIT_API_SECRET to your ChatBotKit API secret.\n".utf8))
    exit(1)
}

let client = ChatBotKit(
    options: ChatBotKitOptions(
        token: secret,
        baseURL: environment["CHATBOTKIT_BASE_URL"].flatMap(URL.init(string:)) ?? ChatBotKitOptions.defaultBaseURL
    )
)

let conversation = try await client.conversation.create(
    ConversationCreateRequest(
        botID: environment["CHATBOTKIT_BOT_ID"],
        backstory: environment["CHATBOTKIT_BOT_ID"] == nil ? "You are a friendly and concise assistant." : nil,
        model: environment["CHATBOTKIT_BOT_ID"] == nil ? (environment["CHATBOTKIT_MODEL"] ?? "gpt-4o") : nil
    )
)

func write(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
}

write("Conversation \(conversation.id). Type a message, or an empty line to quit.\n")

func reply(to text: String) async throws {
    let stream = client.conversation.complete(conversation.id, ConversationMessageCompleteRequest(text: text)).stream()

    for try await item in stream {
        switch item.type {
        case .token:
            write(item.data.token ?? "")
        case .result:
            write("\n")
        default:
            break
        }
    }
}

let arguments = CommandLine.arguments.dropFirst()

if !arguments.isEmpty {
    write("> \(arguments.joined(separator: " "))\n")

    try await reply(to: arguments.joined(separator: " "))
} else {
    while true {
        write("> ")

        guard let line = readLine(), !line.trimmingCharacters(in: .whitespaces).isEmpty else {
            break
        }

        do {
            try await reply(to: line)
        } catch let error as FetchError {
            write("\nError \(error.code): \(error.message)\n")
        }
    }
}
