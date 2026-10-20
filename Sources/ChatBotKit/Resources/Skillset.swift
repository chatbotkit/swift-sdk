import Foundation

/// Skillset client.
public struct SkillsetClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// Skillset ability client.
    public let ability: SkillsetAbilityClient

    public init(client: ChatBotKitClient) {
        self.client = client

        ability = SkillsetAbilityClient(client: client)
    }

    /// Retrieves a list of skillsets.
    public func list(_ params: SkillsetListParams? = nil) -> ResponsePromise<SkillsetListResponse, SkillsetListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/skillset/list", query: params))
    }

    /// Fetches a skillset.
    public func fetch(_ skillsetId: String) async throws -> SkillsetFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/fetch"))
    }

    /// Creates a new skillset.
    public func create(_ request: SkillsetCreateRequest) async throws -> SkillsetCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/create", body: .record(request)))
    }

    /// Updates a skillset.
    public func update(_ skillsetId: String, _ request: SkillsetUpdateRequest) async throws -> SkillsetUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/update", body: .record(request)))
    }

    /// Deletes a skillset.
    public func delete(_ skillsetId: String) async throws -> SkillsetDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/delete", body: .record(EmptyRecord())))
    }
}

/// Skillset ability client.
public struct SkillsetAbilityClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the abilities of a skillset.
    public func list(_ skillsetId: String, _ params: ListParams? = nil) -> ResponsePromise<SkillsetAbilityListResponse, SkillsetAbilityListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/list", query: params))
    }

    /// Exports the abilities of a skillset.
    public func export(_ skillsetId: String, _ params: ListParams? = nil) -> ResponsePromise<SkillsetAbilitiesExportResponse, SkillsetAbilitiesExportStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/export", query: params))
    }

    /// Fetches an ability.
    public func fetch(_ skillsetId: String, _ abilityId: String) async throws -> SkillsetAbilityFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/\(Path.encode(abilityId))/fetch"))
    }

    /// Creates an ability.
    public func create(_ skillsetId: String, _ request: SkillsetAbilityCreateRequest) async throws -> SkillsetAbilityCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/create", body: .record(request)))
    }

    /// Updates an ability.
    public func update(_ skillsetId: String, _ abilityId: String, _ request: SkillsetAbilityUpdateRequest) async throws -> SkillsetAbilityUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/\(Path.encode(abilityId))/update", body: .record(request)))
    }

    /// Deletes an ability.
    public func delete(_ skillsetId: String, _ abilityId: String) async throws -> SkillsetAbilityDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/\(Path.encode(abilityId))/delete", body: .record(EmptyRecord())))
    }

    /// Executes an ability.
    public func execute(_ skillsetId: String, _ abilityId: String, _ request: SkillsetAbilityExecuteRequest) -> ResponsePromise<SkillsetAbilityExecuteResponse, SkillsetAbilityExecuteStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/skillset/\(Path.encode(skillsetId))/ability/\(Path.encode(abilityId))/execute", body: .record(request)))
    }
}
