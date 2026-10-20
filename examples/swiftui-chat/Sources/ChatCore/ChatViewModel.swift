import ChatBotKit
import Foundation
import Observation

/// The state of one chat: its messages, the draft and the streaming reply.
///
/// It asks the backend for a session token and then talks to ChatBotKit
/// directly with that token, streaming the bot reply token by token.
@MainActor
@Observable
public final class ChatViewModel: Identifiable {
    public enum Role: Sendable, Equatable {
        case user
        case bot
    }

    public struct Message: Identifiable, Sendable, Equatable {
        public let id: String
        public let role: Role
        public var text: String
        public var attachments: [String]

        public init(id: String = UUID().uuidString, role: Role, text: String, attachments: [String] = []) {
            self.id = id
            self.role = role
            self.text = text
            self.attachments = attachments
        }
    }

    public struct Attachment: Identifiable, Sendable, Equatable {
        public let id = UUID()
        public let name: String
        public let type: String
        public let data: Data

        public init(name: String, type: String, data: Data) {
            self.name = name
            self.type = type
            self.data = data
        }
    }

    public let id = UUID()

    public private(set) var conversationId: String?
    public private(set) var messages: [Message] = []
    public private(set) var isStreaming = false
    public private(set) var errorMessage: String?

    public var draft = ""
    public var pendingAttachments: [Attachment] = []

    @ObservationIgnored private let backend: ChatBackend
    @ObservationIgnored private let options: ChatBotKitOptions
    @ObservationIgnored private var session: ChatSession?
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    /// Called with the conversation ID once a new chat has been created.
    @ObservationIgnored public var onConversationCreated: ((String) -> Void)?

    /// - Parameters:
    ///   - conversationId: An existing conversation, or `nil` for a new chat.
    ///   - backend: Your backend, which mints session tokens.
    ///   - options: ChatBotKit options such as `baseURL`; the token is
    ///     replaced by the session token.
    public init(conversationId: String?, backend: ChatBackend, options: ChatBotKitOptions = ChatBotKitOptions()) {
        self.conversationId = conversationId
        self.backend = backend
        self.options = options
    }

    public var canSend: Bool {
        !isStreaming && !(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty)
    }

    /// Loads the stored history of an existing conversation.
    public func load() async {
        guard let conversationId, messages.isEmpty else { return }

        do {
            let history = try await backend.listMessages(conversationId: conversationId)

            messages = history.compactMap { message in
                switch message.type {
                case "user":
                    return Message(id: message.id, role: .user, text: message.text)
                case "bot":
                    return Message(id: message.id, role: .bot, text: message.text)
                default:
                    return nil
                }
            }
        } catch {
            errorMessage = describe(error)
        }
    }

    /// Sends the draft and the pending attachments.
    public func send() {
        guard canSend else { return }

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = pendingAttachments

        draft = ""
        pendingAttachments = []

        streamTask = Task { await self.send(text, attachments: attachments) }
    }

    /// Stops the reply that is streaming.
    public func stop() {
        streamTask?.cancel()
    }

    /// Waits for the current reply to finish.
    public func waitForReply() async {
        await streamTask?.value
    }

    func send(_ text: String, attachments: [Attachment]) async {
        errorMessage = nil
        isStreaming = true

        defer { isStreaming = false }

        messages.append(Message(role: .user, text: text, attachments: attachments.map(\.name)))

        do {
            let (client, conversationId) = try await makeClient()

            for attachment in attachments {
                _ = try await client.conversation.attachment.upload(conversationId, data: attachment.data, name: attachment.name, type: attachment.type)
            }

            messages.append(Message(role: .bot, text: ""))

            let index = messages.count - 1

            let request = ConversationMessageCompleteRequest(text: text.isEmpty ? "See the attached files." : text)

            for try await item in client.conversation.complete(conversationId, request).stream() {
                switch item.type {
                case .token:
                    messages[index].text += item.data.token ?? ""
                case .result:
                    if let final = item.data.text {
                        messages[index].text = final
                    }
                case .error:
                    errorMessage = item.data.message ?? "The reply failed."
                default:
                    break
                }
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = describe(error)
        }

        if let last = messages.last, last.role == .bot, last.text.isEmpty {
            messages.removeLast()
        }
    }

    func makeClient() async throws -> (ChatBotKit, String) {
        if session == nil || session?.isExpiring() == true {
            let session = try await backend.createSession(conversationId: conversationId)

            self.session = session

            if conversationId == nil {
                conversationId = session.conversationId

                onConversationCreated?(session.conversationId)
            }
        }

        guard let session else {
            throw CancellationError()
        }

        var options = self.options

        options.token = session.token

        return (ChatBotKit(options: options), session.conversationId)
    }

    func describe(_ error: Error) -> String {
        switch error {
        case let error as FetchError:
            return error.message
        case let error as AuthorizationRequiredError:
            return error.message
        default:
            return error.localizedDescription
        }
    }
}
