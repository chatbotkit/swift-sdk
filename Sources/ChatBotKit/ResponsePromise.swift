import Foundation

/// A pending API call that can be awaited for its JSON response or consumed
/// as a stream of JSONL items.
///
/// ```swift
/// let reply = try await client.conversation.complete(request).value
///
/// for try await item in client.conversation.complete(request).stream() {
///     if item.type == .token, let token = item.data.token {
///         print(token, terminator: "")
///     }
/// }
/// ```
///
/// Nothing is sent until `value` or `stream()` is used, and every use sends a
/// new request.
public struct ResponsePromise<T: Decodable & Sendable, U: Decodable & Sendable>: Sendable {
    public let client: ChatBotKitClient
    public let request: ClientRequest

    public init(client: ChatBotKitClient, request: ClientRequest) {
        self.client = client
        self.request = request
    }

    /// Sends the request and decodes the JSON response.
    public var value: T {
        get async throws {
            try await client.fetch(request, as: T.self)
        }
    }

    /// Sends the request with `Accept: application/jsonl` and yields each item.
    public func stream() -> AsyncThrowingStream<U, Error> {
        client.stream(request, as: U.self)
    }

    /// Streams the items decoded as any other type, e.g. ``StreamEvent``.
    public func stream<V: Decodable & Sendable>(as type: V.Type) -> AsyncThrowingStream<V, Error> {
        client.stream(request, as: type)
    }
}

/// A loosely typed JSONL stream item: the event `type` and its raw `data`.
///
/// Use it when you want to handle event types that the typed stream item does
/// not describe yet.
public struct StreamEvent: Codable, Sendable, Hashable {
    public let type: String
    public let data: JSONValue

    public init(type: String, data: JSONValue = .null) {
        self.type = type
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        type = try container.decode(String.self, forKey: .type)
        data = try container.decodeIfPresent(JSONValue.self, forKey: .data) ?? .null
    }

    /// Decodes `data` into a concrete type.
    public func decode<T: Decodable>(_ type: T.Type = T.self) throws -> T {
        try data.decode(as: type)
    }
}
