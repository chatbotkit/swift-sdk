import Foundation

/// Dataset client.
public struct DatasetClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// Dataset record client.
    public let record: DatasetRecordClient

    /// Dataset file client.
    public let file: DatasetFileClient

    public init(client: ChatBotKitClient) {
        self.client = client

        record = DatasetRecordClient(client: client)
        file = DatasetFileClient(client: client)
    }

    /// Retrieves a list of datasets.
    public func list(_ params: DatasetListParams? = nil) -> ResponsePromise<DatasetListResponse, DatasetListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/dataset/list", query: params))
    }

    /// Fetches a dataset.
    public func fetch(_ datasetId: String) async throws -> DatasetFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/fetch"))
    }

    /// Creates a new dataset.
    public func create(_ request: DatasetCreateRequest) async throws -> DatasetCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/create", body: .record(request)))
    }

    /// Updates a dataset.
    public func update(_ datasetId: String, _ request: DatasetUpdateRequest) async throws -> DatasetUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/update", body: .record(request)))
    }

    /// Deletes a dataset.
    public func delete(_ datasetId: String) async throws -> DatasetDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/delete", body: .record(EmptyRecord())))
    }

    /// Searches the records of a dataset.
    public func search(_ datasetId: String, _ request: DatasetSearchRequest) async throws -> DatasetSearchResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/search", body: .record(request)))
    }
}

/// Dataset record client.
public struct DatasetRecordClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the records of a dataset.
    public func list(_ datasetId: String, _ params: ListParams? = nil) -> ResponsePromise<DatasetRecordListResponse, DatasetRecordListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/record/list", query: params))
    }

    /// Exports the records of a dataset.
    public func export(_ datasetId: String, _ params: ListParams? = nil) -> ResponsePromise<DatasetRecordsExportResponse, DatasetRecordsExportStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/record/export", query: params))
    }

    /// Fetches a record.
    public func fetch(_ datasetId: String, _ recordId: String) async throws -> DatasetRecordFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/record/\(Path.encode(recordId))/fetch"))
    }

    /// Creates a record.
    public func create(_ datasetId: String, _ request: DatasetRecordCreateRequest) async throws -> DatasetRecordCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/record/create", body: .record(request)))
    }

    /// Updates a record.
    public func update(_ datasetId: String, _ recordId: String, _ request: DatasetRecordUpdateRequest) async throws -> DatasetRecordUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/record/\(Path.encode(recordId))/update", body: .record(request)))
    }

    /// Deletes a record.
    public func delete(_ datasetId: String, _ recordId: String) async throws -> DatasetRecordDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/record/\(Path.encode(recordId))/delete", body: .record(EmptyRecord())))
    }
}

/// Dataset file client.
public struct DatasetFileClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the files attached to a dataset.
    public func list(_ datasetId: String, _ params: ListParams? = nil) -> ResponsePromise<DatasetFileListResponse, DatasetFileListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/file/list", query: params))
    }

    /// Attaches a file to a dataset.
    public func attach(_ datasetId: String, _ fileId: String, _ request: DatasetFileAttachRequest) async throws -> DatasetFileAttachResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/file/\(Path.encode(fileId))/attach", body: .record(request)))
    }

    /// Detaches a file from a dataset.
    public func detach(_ datasetId: String, _ fileId: String, _ request: DatasetFileDetachRequest = DatasetFileDetachRequest()) async throws -> DatasetFileDetachResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/file/\(Path.encode(fileId))/detach", body: .record(request)))
    }

    /// Synchronises a file attached to a dataset.
    public func sync(_ datasetId: String, _ fileId: String) async throws -> DatasetFileSyncResponse {
        try await fetch(ClientRequest(path: "/api/v1/dataset/\(Path.encode(datasetId))/file/\(Path.encode(fileId))/sync", body: .record(EmptyRecord())))
    }
}
