import Foundation

/// Bot client.
public struct BotClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// Bot session client.
    public let session: BotSessionClient

    public init(client: ChatBotKitClient) {
        self.client = client

        session = BotSessionClient(client: client)
    }

    /// Retrieves a list of bots.
    public func list(_ params: BotListParams? = nil) -> ResponsePromise<BotListResponse, BotListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/bot/list", query: params))
    }

    /// Fetches a bot.
    public func fetch(_ botId: String) async throws -> BotFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/\(Path.encode(botId))/fetch"))
    }

    /// Creates a new bot.
    public func create(_ request: BotCreateRequest) async throws -> BotCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/create", body: .record(request)))
    }

    /// Updates a bot.
    public func update(_ botId: String, _ request: BotUpdateRequest) async throws -> BotUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/\(Path.encode(botId))/update", body: .record(request)))
    }

    /// Deletes a bot.
    public func delete(_ botId: String) async throws -> BotDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/\(Path.encode(botId))/delete", body: .record(EmptyRecord())))
    }

    /// Upvotes a bot.
    public func upvote(_ botId: String, _ request: BotUpvoteRequest = BotUpvoteRequest()) async throws -> BotUpvoteResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/\(Path.encode(botId))/upvote", body: .record(request)))
    }

    /// Downvotes a bot.
    public func downvote(_ botId: String, _ request: BotDownvoteRequest = BotDownvoteRequest()) async throws -> BotDownvoteResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/\(Path.encode(botId))/downvote", body: .record(request)))
    }
}

/// Bot session client.
///
/// A bot session creates a new conversation with the bot and returns a
/// conversation session token for it, so an app can chat without the API
/// secret. Create it on your server and hand only the token to the app.
public struct BotSessionClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Creates a conversation with the bot and a session token for it.
    public func create(_ botId: String, _ request: BotSessionCreateRequest = BotSessionCreateRequest()) async throws -> BotSessionCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/bot/\(Path.encode(botId))/session/create", body: .record(request)))
    }
}
