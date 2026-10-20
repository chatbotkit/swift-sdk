import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A short-lived ChatBotKit session for one conversation, minted by your
/// backend with the API secret.
public struct ChatSession: Codable, Sendable, Equatable {
    public let conversationId: String
    public let token: String

    /// Expiry in milliseconds since 1970, as returned by ChatBotKit.
    public let expiresAt: Double

    public init(conversationId: String, token: String, expiresAt: Double) {
        self.conversationId = conversationId
        self.token = token
        self.expiresAt = expiresAt
    }

    /// Whether the token expires within `margin` seconds.
    public func isExpiring(within margin: TimeInterval = 60, now: Date = Date()) -> Bool {
        Date(timeIntervalSince1970: expiresAt / 1000) <= now.addingTimeInterval(margin)
    }
}

/// A conversation shown in the list.
public struct ConversationSummary: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String?
    public let updatedAt: Double?

    public init(id: String, name: String? = nil, updatedAt: Double? = nil) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
    }
}

/// A message from the stored history of a conversation.
public struct HistoryMessage: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let text: String

    public init(id: String, type: String, text: String) {
        self.id = id
        self.type = type
        self.text = text
    }
}

/// The calls the app makes to your own backend. The backend holds the
/// ChatBotKit API secret; the app never sees it.
public protocol ChatBackend: Sendable {
    /// Returns a session for an existing conversation, or creates a new
    /// conversation when `conversationId` is `nil`.
    func createSession(conversationId: String?) async throws -> ChatSession

    /// Lists the conversations of the signed-in user.
    func listConversations() async throws -> [ConversationSummary]

    /// Lists the stored messages of a conversation.
    func listMessages(conversationId: String) async throws -> [HistoryMessage]
}

/// A ``ChatBackend`` that talks to the endpoints described in the README:
///
/// - `POST /chat/session` with `{"conversationId": "..."}` (optional)
/// - `GET /chat/conversations`
/// - `GET /chat/conversations/{conversationId}/messages`
public struct HTTPChatBackend: ChatBackend {
    public let baseURL: URL
    public let authorization: String?
    public let session: URLSession

    /// - Parameters:
    ///   - baseURL: The URL of your backend.
    ///   - authorization: The `Authorization` header that identifies the
    ///     signed-in user to your backend, e.g. `Bearer <your app token>`.
    public init(baseURL: URL, authorization: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authorization = authorization
        self.session = session
    }

    struct Items<T: Decodable>: Decodable {
        let items: [T]
    }

    struct SessionRequest: Encodable {
        let conversationId: String?
    }

    public func createSession(conversationId: String?) async throws -> ChatSession {
        try await send("chat/session", method: "POST", body: try JSONEncoder().encode(SessionRequest(conversationId: conversationId)))
    }

    public func listConversations() async throws -> [ConversationSummary] {
        let response: Items<ConversationSummary> = try await send("chat/conversations")

        return response.items
    }

    public func listMessages(conversationId: String) async throws -> [HistoryMessage] {
        let id = conversationId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? conversationId

        let response: Items<HistoryMessage> = try await send("chat/conversations/\(id)/messages")

        return response.items
    }

    func send<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))

        request.httpMethod = method
        request.httpBody = body

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            throw BackendError.badStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum BackendError: Error, Equatable {
    case badStatus(Int)
}
