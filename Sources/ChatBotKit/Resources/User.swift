import Foundation

/// User client.
public struct UserClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// User session client.
    public let session: UserSessionClient

    public init(client: ChatBotKitClient) {
        self.client = client

        session = UserSessionClient(client: client)
    }

    /// Retrieves a list of sub-users.
    public func list(_ params: UserListParams? = nil) -> ResponsePromise<UserListResponse, UserListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/user/list", query: params))
    }

    /// Fetches a sub-user.
    public func fetch(_ userId: String) async throws -> UserFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/user/\(Path.encode(userId))/fetch"))
    }

    /// Creates a new sub-user.
    public func create(_ request: UserCreateRequest) async throws -> UserCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/user/create", body: .record(request)))
    }

    /// Updates a sub-user.
    public func update(_ userId: String, _ request: UserUpdateRequest) async throws -> UserUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/user/\(Path.encode(userId))/update", body: .record(request)))
    }

    /// Deletes a sub-user.
    public func delete(_ userId: String) async throws -> UserDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/user/\(Path.encode(userId))/delete", body: .record(EmptyRecord())))
    }
}

/// User session client.
public struct UserSessionClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Creates a session token for a user.
    public func create(_ userId: String, _ request: UserSessionCreateRequest = UserSessionCreateRequest()) async throws -> UserSessionCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/user/\(Path.encode(userId))/session/create", body: .record(request)))
    }
}
