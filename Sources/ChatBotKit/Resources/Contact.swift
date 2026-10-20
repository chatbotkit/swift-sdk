import Foundation

/// Contact client.
public struct ContactClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// Contact conversation client.
    public let conversation: ContactConversationClient

    public init(client: ChatBotKitClient) {
        self.client = client

        conversation = ContactConversationClient(client: client)
    }

    /// Retrieves a list of contacts.
    public func list(_ params: ContactListParams? = nil) -> ResponsePromise<ContactListResponse, ContactListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/contact/list", query: params))
    }

    /// Fetches a contact.
    public func fetch(_ contactId: String) async throws -> ContactFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/contact/\(Path.encode(contactId))/fetch"))
    }

    /// Creates a new contact.
    public func create(_ request: ContactCreateRequest) async throws -> ContactCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/contact/create", body: .record(request)))
    }

    /// Updates a contact.
    public func update(_ contactId: String, _ request: ContactUpdateRequest) async throws -> ContactUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/contact/\(Path.encode(contactId))/update", body: .record(request)))
    }

    /// Deletes a contact.
    public func delete(_ contactId: String) async throws -> ContactDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/contact/\(Path.encode(contactId))/delete", body: .record(EmptyRecord())))
    }

    /// Returns the contact matching the fingerprint, email or phone in the
    /// request, creating it when it does not exist.
    public func ensure(_ request: ContactEnsureRequest) async throws -> ContactEnsureResponse {
        try await fetch(ClientRequest(path: "/api/v1/contact/ensure", body: .record(request)))
    }
}

/// Contact conversation client.
public struct ContactConversationClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the conversations of a contact.
    public func list(_ contactId: String, _ params: ListParams? = nil) -> ResponsePromise<ContactConversationListResponse, ContactConversationListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/contact/\(Path.encode(contactId))/conversation/list", query: params))
    }
}
