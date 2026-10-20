import ChatBotKit
import Foundation
import Observation

/// The conversation list and the chat that is open.
@MainActor
@Observable
public final class ChatStore {
    public private(set) var conversations: [ConversationSummary] = []
    public private(set) var current: ChatViewModel?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    @ObservationIgnored public let backend: ChatBackend
    @ObservationIgnored public let options: ChatBotKitOptions
    @ObservationIgnored private var chats: [String: ChatViewModel] = [:]

    public init(backend: ChatBackend, options: ChatBotKitOptions = ChatBotKitOptions()) {
        self.backend = backend
        self.options = options
    }

    /// The ID of the open conversation, if it has been created.
    public var selection: String? {
        current?.conversationId
    }

    /// Reloads the conversation list from the backend.
    public func refresh() async {
        isLoading = true

        defer { isLoading = false }

        do {
            conversations = try await backend.listConversations()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens an existing conversation.
    public func open(_ conversationId: String) {
        if let chat = chats[conversationId] {
            current = chat

            return
        }

        let chat = ChatViewModel(conversationId: conversationId, backend: backend, options: options)

        chats[conversationId] = chat
        current = chat
    }

    /// Starts a new chat. The conversation is created with the first message.
    public func newChat() {
        let chat = ChatViewModel(conversationId: nil, backend: backend, options: options)

        chat.onConversationCreated = { [weak self, weak chat] conversationId in
            guard let self, let chat else { return }

            self.chats[conversationId] = chat

            if !self.conversations.contains(where: { $0.id == conversationId }) {
                self.conversations.insert(ConversationSummary(id: conversationId, name: nil), at: 0)
            }
        }

        current = chat
    }
}
