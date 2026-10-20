import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration shared by every ChatBotKit client.
public struct ChatBotKitOptions: Sendable {
    /// The default API base URL.
    public static let defaultBaseURL = URL(string: "https://api.chatbotkit.com")!

    /// The token to authenticate with: an API secret on a server, or a
    /// short-lived session token in an app.
    public var token: String?

    /// The base URL of the API, e.g. `http://localhost:3000` for a self-hosted
    /// platform. A path prefix is preserved.
    public var baseURL: URL

    /// An optional host that replaces the host of `baseURL`.
    public var host: String?

    /// An optional user ID to run as.
    public var runAsUserId: String?

    /// An optional child user email to run as (experimental).
    public var runAsChildUserEmail: String?

    /// An optional timezone sent with every request, e.g. `Europe/London`.
    public var timezone: String?

    /// Extra headers sent with every request.
    public var headers: [String: String]

    /// An optional timeout in seconds for each request. When `nil` the
    /// `URLSession` default applies.
    public var timeout: TimeInterval?

    /// How many times a request is retried after a network error or a
    /// 429/5xx response.
    public var retries: Int

    /// The delay in seconds before the first retry; it doubles every attempt.
    public var retryDelay: TimeInterval

    /// Whether timed out requests are retried.
    public var retryTimeout: Bool

    /// The URL session used to perform requests.
    public var session: URLSession

    /// Creates the options.
    ///
    /// - Parameters:
    ///   - token: The API token or session token.
    ///   - secret: Former name of `token`; used when `token` is `nil`.
    public init(
        token: String? = nil,
        secret: String? = nil,
        baseURL: URL = ChatBotKitOptions.defaultBaseURL,
        host: String? = nil,
        runAsUserId: String? = nil,
        runAsChildUserEmail: String? = nil,
        timezone: String? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        retries: Int = 3,
        retryDelay: TimeInterval = 0.25,
        retryTimeout: Bool = true,
        session: URLSession = .shared
    ) {
        self.token = token ?? secret
        self.baseURL = baseURL
        self.host = host
        self.runAsUserId = runAsUserId
        self.runAsChildUserEmail = runAsChildUserEmail
        self.timezone = timezone
        self.headers = headers
        self.timeout = timeout
        self.retries = retries
        self.retryDelay = retryDelay
        self.retryTimeout = retryTimeout
        self.session = session
    }
}
