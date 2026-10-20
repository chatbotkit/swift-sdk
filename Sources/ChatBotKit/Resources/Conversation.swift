import Foundation

/// Conversation client.
public struct ConversationClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// Conversation message client.
    public let message: ConversationMessageClient

    /// Conversation session client.
    public let session: ConversationSessionClient

    /// Conversation attachment client.
    public let attachment: ConversationAttachmentClient

    public init(client: ChatBotKitClient) {
        self.client = client

        message = ConversationMessageClient(client: client)
        session = ConversationSessionClient(client: client)
        attachment = ConversationAttachmentClient(client: client)
    }

    /// Retrieves a list of conversations.
    public func list(_ params: ConversationListParams? = nil) -> ResponsePromise<ConversationListResponse, ConversationListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/list", query: params))
    }

    /// Fetches a conversation.
    public func fetch(_ conversationId: String) async throws -> ConversationFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/fetch"))
    }

    /// Creates a new conversation.
    public func create(_ request: ConversationCreateRequest = ConversationCreateRequest()) async throws -> ConversationCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/create", body: .record(request)))
    }

    /// Updates a conversation.
    public func update(_ conversationId: String, _ request: ConversationUpdateRequest) async throws -> ConversationUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/update", body: .record(request)))
    }

    /// Deletes a conversation.
    public func delete(_ conversationId: String) async throws -> ConversationDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/delete", body: .record(EmptyRecord())))
    }

    /// Completes the next bot message of a stateless conversation: the full
    /// message history is sent with the request and nothing is stored.
    public func complete(_ request: ConversationCompleteRequest) -> ResponsePromise<ConversationCompleteResponse, ConversationCompleteStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/complete", body: .record(request)))
    }

    /// Sends a user message to a stored conversation and completes the next
    /// bot message.
    public func complete(_ conversationId: String, _ request: ConversationMessageCompleteRequest) -> ResponsePromise<ConversationMessageCompleteResponse, ConversationMessageCompleteStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/complete", body: .record(request)))
    }

    /// Dispatches a stateless conversation completion to run in the
    /// background. The response carries a channel ID for the events.
    public func dispatch(_ request: ConversationDispatchRequest) async throws -> ConversationDispatchResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/dispatch", body: .record(request)))
    }

    /// Dispatches the completion of a stored conversation to run in the
    /// background.
    public func dispatch(_ conversationId: String, _ request: StatefulConversationDispatchRequest) async throws -> StatefulConversationDispatchResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/dispatch", body: .record(request)))
    }

    /// Sends a user message to the conversation without completing it.
    public func send(_ conversationId: String, _ request: ConversationMessageSendRequest) -> ResponsePromise<ConversationMessageSendResponse, ConversationMessageSendStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/send", body: .record(request)))
    }

    /// Receives the next bot message of the conversation.
    public func receive(_ conversationId: String, _ request: ConversationMessageReceiveRequest = ConversationMessageReceiveRequest()) -> ResponsePromise<ConversationMessageReceiveResponse, ConversationMessageReceiveStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/receive", body: .record(request)))
    }

    /// Upvotes a conversation.
    public func upvote(_ conversationId: String, _ request: ConversationUpvoteRequest = ConversationUpvoteRequest()) async throws -> ConversationUpvoteResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/upvote", body: .record(request)))
    }

    /// Downvotes a conversation.
    public func downvote(_ conversationId: String, _ request: ConversationDownvoteRequest = ConversationDownvoteRequest()) async throws -> ConversationDownvoteResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/downvote", body: .record(request)))
    }
}

/// Conversation message client.
public struct ConversationMessageClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the messages of a conversation.
    public func list(_ conversationId: String, _ params: ListParams? = nil) -> ResponsePromise<ConversationMessageListResponse, ConversationMessageListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/list", query: params))
    }

    /// Fetches a message.
    public func fetch(_ conversationId: String, _ messageId: String) async throws -> ConversationMessageFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/\(Path.encode(messageId))/fetch"))
    }

    /// Creates a message.
    public func create(_ conversationId: String, _ request: ConversationMessageCreateRequest) async throws -> ConversationMessageCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/create", body: .record(request)))
    }

    /// Updates a message.
    public func update(_ conversationId: String, _ messageId: String, _ request: ConversationMessageUpdateRequest) async throws -> ConversationMessageUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/\(Path.encode(messageId))/update", body: .record(request)))
    }

    /// Deletes a message.
    public func delete(_ conversationId: String, _ messageId: String) async throws -> ConversationMessageDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/\(Path.encode(messageId))/delete", body: .record(EmptyRecord())))
    }

    /// Upvotes a message.
    public func upvote(_ conversationId: String, _ messageId: String, _ request: ConversationMessageUpvoteRequest = ConversationMessageUpvoteRequest()) async throws -> ConversationMessageUpvoteResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/\(Path.encode(messageId))/upvote", body: .record(request)))
    }

    /// Downvotes a message.
    public func downvote(_ conversationId: String, _ messageId: String, _ request: ConversationMessageDownvoteRequest = ConversationMessageDownvoteRequest()) async throws -> ConversationMessageDownvoteResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/message/\(Path.encode(messageId))/downvote", body: .record(request)))
    }
}

/// Conversation session client.
///
/// A conversation session token lets an app talk to one conversation
/// (`complete`, `send`, `receive`, attachment upload and message votes)
/// without holding the API secret. Create it on your server and hand only the
/// token to the app.
public struct ConversationSessionClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Creates a session token for the conversation.
    public func create(_ conversationId: String, _ request: ConversationSessionCreateRequest = ConversationSessionCreateRequest()) async throws -> ConversationSessionCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/session/create", body: .record(request)))
    }
}

/// Conversation attachment client.
public struct ConversationAttachmentClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the attachments of a conversation.
    public func list(_ conversationId: String, _ params: ListParams? = nil) -> ResponsePromise<ConversationAttachmentListResponse, StreamEvent> {
        clientFetch(ClientRequest(path: "/api/v1/conversation/\(Path.encode(conversationId))/attachment/list", query: params))
    }

    /// Uploads a file to the conversation so the bot can use it in the next
    /// completion.
    ///
    /// The API returns a pre-signed upload request and the bytes are then sent
    /// straight to storage.
    @discardableResult
    public func upload(_ conversationId: String, data: Data, name: String? = nil, type: String? = nil) async throws -> UploadResult {
        let response: ConversationAttachmentUploadResponse = try await fetch(
            ClientRequest(
                path: "/api/v1/conversation/\(Path.encode(conversationId))/attachment/upload",
                body: .record(UploadDescriptor(file: .init(size: data.count, type: type, name: name)))
            )
        )

        guard let uploadRequest = response.uploadRequest else {
            throw FetchError(message: "Missing upload request", code: "MISSING_UPLOAD_REQUEST")
        }

        try await upload(data, to: uploadRequest.url, method: uploadRequest.method, headers: uploadRequest.headers)

        return UploadResult(id: response.id, name: response.name)
    }
}

/// The result of an upload.
public struct UploadResult: Codable, Sendable, Hashable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

struct EmptyRecord: Codable, Sendable {}

struct UploadDescriptor: Encodable, Sendable {
    struct File: Encodable, Sendable {
        let size: Int
        let type: String?
        let name: String?
    }

    let file: File
}

extension ChatBotKitResourceClient {
    func upload(_ data: Data, to url: String, method: String, headers: [String: JSONValue]) async throws {
        var stringHeaders: [String: String] = [:]

        for (name, value) in headers {
            if let string = QueryEncoding.string(for: value) {
                stringHeaders[name] = string
            }
        }

        _ = try await perform(ClientRequest(path: url, method: method, body: .buffer(data), headers: stringHeaders, external: true))
    }
}
