import Foundation

/// Platform client.
public struct PlatformClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    /// Platform model client.
    public let model: PlatformModelClient

    public init(client: ChatBotKitClient) {
        self.client = client

        model = PlatformModelClient(client: client)
    }
}

/// Platform model client.
public struct PlatformModelClient: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public init(client: ChatBotKitClient) {
        self.client = client
    }

    /// Retrieves the models available on the platform.
    public func list(_ params: PlatformModelListParams? = nil) -> ResponsePromise<PlatformModelListResponse, PlatformModelListStreamItem> {
        clientFetch(ClientRequest(path: "/api/v1/platform/model/list", query: params))
    }
}
