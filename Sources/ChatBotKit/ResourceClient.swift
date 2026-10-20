import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A client for one part of the API, such as ``ConversationClient``.
///
/// Resource clients share a ``ChatBotKitClient`` that holds the configuration
/// and performs the requests, so any of them can also be used on its own:
///
/// ```swift
/// let conversations = ConversationClient(options: options)
/// ```
public protocol ChatBotKitResourceClient: Sendable {
    /// The client that performs the requests.
    var client: ChatBotKitClient { get }

    /// Creates the resource client on top of a shared client.
    init(client: ChatBotKitClient)
}

extension ChatBotKitResourceClient {
    /// Creates the resource client with its own configuration.
    public init(options: ChatBotKitOptions) {
        self.init(client: ChatBotKitClient(options: options))
    }

    /// Creates the resource client from individual options.
    public init(
        token: String? = nil,
        secret: String? = nil,
        baseURL: URL = ChatBotKitOptions.defaultBaseURL,
        runAsUserId: String? = nil,
        timezone: String? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        session: URLSession = .shared
    ) {
        self.init(
            options: ChatBotKitOptions(
                token: token,
                secret: secret,
                baseURL: baseURL,
                runAsUserId: runAsUserId,
                timezone: timezone,
                headers: headers,
                timeout: timeout,
                session: session
            )
        )
    }

    /// The configuration of this client.
    public var options: ChatBotKitOptions {
        client.options
    }

    /// Creates a new client with modified options, leaving this one as is.
    ///
    /// ```swift
    /// let scoped = client.extend { $0.runAsUserId = "user-id" }
    /// ```
    public func extend(_ update: (inout ChatBotKitOptions) -> Void) -> Self {
        var options = self.options

        update(&options)

        return Self(options: options)
    }

    /// Creates a request that can be awaited for its JSON response or
    /// consumed as a JSONL stream.
    public func clientFetch<T: Decodable & Sendable, U: Decodable & Sendable>(
        _ request: ClientRequest,
        response: T.Type = T.self,
        streamItem: U.Type = U.self
    ) -> ResponsePromise<T, U> {
        client.clientFetch(request, response: response, streamItem: streamItem)
    }

    /// Performs a request and decodes its JSON response.
    public func fetch<T: Decodable>(_ request: ClientRequest, as type: T.Type = T.self) async throws -> T {
        try await client.fetch(request, as: type)
    }

    /// Performs a request and returns the raw body and response.
    public func perform(_ request: ClientRequest) async throws -> (Data, HTTPURLResponse) {
        try await client.perform(request)
    }

    /// Performs a request and yields every JSONL line decoded as `U`.
    public func stream<U: Decodable & Sendable>(_ request: ClientRequest, as type: U.Type = U.self) -> AsyncThrowingStream<U, Error> {
        client.stream(request, as: type)
    }
}
