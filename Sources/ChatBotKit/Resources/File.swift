import Foundation

/// File client.
public struct FileClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves a list of files.
    public func list(_ params: FileListParams? = nil) -> ResponsePromise<FileListResponse, FileListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/file/list", query: params))
    }

    /// Fetches a file.
    public func fetch(_ fileId: String) async throws -> FileFetchResponse {
        try await fetch(ClientRequest(path: "/api/v1/file/\(Path.encode(fileId))/fetch"))
    }

    /// Creates a new file. Upload its content with ``upload(_:data:name:type:)``.
    public func create(_ request: FileCreateRequest = FileCreateRequest()) async throws -> FileCreateResponse {
        try await fetch(ClientRequest(path: "/api/v1/file/create", body: .record(request)))
    }

    /// Updates a file.
    public func update(_ fileId: String, _ request: FileUpdateRequest) async throws -> FileUpdateResponse {
        try await fetch(ClientRequest(path: "/api/v1/file/\(Path.encode(fileId))/update", body: .record(request)))
    }

    /// Deletes a file.
    public func delete(_ fileId: String) async throws -> FileDeleteResponse {
        try await fetch(ClientRequest(path: "/api/v1/file/\(Path.encode(fileId))/delete", body: .record(EmptyRecord())))
    }

    /// Uploads the content of a file.
    ///
    /// The API returns a pre-signed upload request and the bytes are then sent
    /// straight to storage.
    @discardableResult
    public func upload(_ fileId: String, data: Data, name: String? = nil, type: String? = nil) async throws -> UploadResult {
        let response: FileUploadResponse = try await fetch(
            ClientRequest(
                path: "/api/v1/file/\(Path.encode(fileId))/upload",
                body: .record(UploadDescriptor(file: .init(size: data.count, type: type, name: name)))
            )
        )

        guard let uploadRequest = response.uploadRequest else {
            throw FetchError(message: "Missing upload request", code: "MISSING_UPLOAD_REQUEST")
        }

        try await upload(data, to: uploadRequest.url, method: uploadRequest.method, headers: uploadRequest.headers)

        return UploadResult(id: response.id)
    }

    /// Returns a short-lived URL from which the content of the file can be
    /// downloaded.
    public func download(_ fileId: String) async throws -> FileDownloadResponse {
        try await fetch(ClientRequest(path: "/api/v1/file/\(Path.encode(fileId))/download", headers: ["accept": "application/json"]))
    }

    /// Downloads the content of a file. A file without content yet returns
    /// empty data.
    public func downloadData(_ fileId: String) async throws -> Data {
        let (data, _) = try await perform(ClientRequest(path: "/api/v1/file/\(Path.encode(fileId))/download", headers: ["accept": "application/octet-stream"]))

        return data
    }

    /// Synchronises a file with its source.
    public func sync(_ fileId: String) async throws -> FileSyncResponse {
        try await fetch(ClientRequest(path: "/api/v1/file/\(Path.encode(fileId))/sync", body: .record(EmptyRecord())))
    }
}
