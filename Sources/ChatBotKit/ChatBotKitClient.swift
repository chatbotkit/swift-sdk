import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A single API request, before it is sent.
public struct ClientRequest: Sendable {
    /// The body of a request.
    public enum Body: Sendable {
        case none
        case record(any Encodable & Sendable)
        case buffer(Data)
    }

    public var path: String
    public var method: String?
    public var query: (any Encodable & Sendable)?
    public var body: Body
    public var headers: [String: String]
    public var external: Bool

    /// Creates a request.
    ///
    /// - Parameters:
    ///   - path: An API path such as `/api/v1/bot/list`, or an absolute URL.
    ///   - method: The HTTP method; defaults to `POST` with a body and `GET`
    ///     without one.
    ///   - query: A value encoded into query parameters.
    ///   - body: The request body.
    ///   - headers: Headers for this request only.
    ///   - external: Whether the request goes to a URL outside the API, in
    ///     which case no credentials are attached.
    public init(
        path: String,
        method: String? = nil,
        query: (any Encodable & Sendable)? = nil,
        body: Body = .none,
        headers: [String: String] = [:],
        external: Bool = false
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.headers = headers
        self.external = external
    }
}

/// Holds the configuration and performs requests.
///
/// Every resource client, such as ``ConversationClient`` and ``BotClient``,
/// shares one instance. It only holds immutable state, so it is `Sendable`.
public final class ChatBotKitClient: Sendable {
    public static let retryStatuses: Set<Int> = [429, 500, 502, 503, 504]

    /// The configuration of this client.
    public let options: ChatBotKitOptions

    public init(options: ChatBotKitOptions) {
        self.options = options
    }

    /// Creates a client from individual options.
    public convenience init(
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

    /// Creates a request that can be awaited for its JSON response or
    /// consumed as a JSONL stream.
    public func clientFetch<T: Decodable & Sendable, U: Decodable & Sendable>(
        _ request: ClientRequest,
        response: T.Type = T.self,
        streamItem: U.Type = U.self
    ) -> ResponsePromise<T, U> {
        ResponsePromise(client: self, request: request)
    }

    /// Performs a request and decodes its JSON response.
    public func fetch<T: Decodable>(_ request: ClientRequest, as type: T.Type = T.self) async throws -> T {
        let (data, _) = try await perform(request)

        return try ChatBotKitCoding.makeDecoder().decode(type, from: data.isEmpty ? Data("{}".utf8) : data)
    }

    /// Performs a request and returns the raw body and response.
    public func perform(_ request: ClientRequest) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try makeURLRequest(request, accept: nil)

        var attempt = 0
        var delay = options.retryDelay

        while true {
            do {
                let (data, response) = try await HTTPTransport.data(for: urlRequest, session: options.session)

                if !(200..<300).contains(response.statusCode) {
                    if Self.retryStatuses.contains(response.statusCode) && attempt < options.retries {
                        attempt += 1

                        try await Self.sleep(seconds: delay)

                        delay *= 2

                        continue
                    }

                    throw ErrorMapping.error(status: response.statusCode, body: data, url: urlRequest.url)
                }

                return (data, response)
            } catch let error as URLError {
                let mapped = Self.map(error)

                guard Self.isRetryable(error, retryTimeout: options.retryTimeout), attempt < options.retries else {
                    throw mapped
                }

                attempt += 1

                try await Self.sleep(seconds: delay)

                delay *= 2
            }
        }
    }

    /// Performs a request and yields every JSONL line decoded as `U`.
    public func stream<U: Decodable & Sendable>(_ request: ClientRequest, as type: U.Type = U.self) -> AsyncThrowingStream<U, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeURLRequest(request, accept: "application/jsonl")

                    let decoder = ChatBotKitCoding.makeDecoder()

                    var attempt = 0
                    var delay = options.retryDelay

                    while true {
                        var streaming = StreamingTask(urlRequest, configuration: options.session.configuration)

                        let response: HTTPURLResponse

                        do {
                            response = try await streaming.start()
                        } catch let error as URLError {
                            guard Self.isRetryable(error, retryTimeout: options.retryTimeout), attempt < options.retries else {
                                throw Self.map(error)
                            }

                            attempt += 1

                            try await Self.sleep(seconds: delay)

                            delay *= 2

                            continue
                        }

                        if !(200..<300).contains(response.statusCode) {
                            if Self.retryStatuses.contains(response.statusCode) && attempt < options.retries {
                                streaming.cancel()

                                attempt += 1

                                try await Self.sleep(seconds: delay)

                                delay *= 2

                                continue
                            }

                            var body = Data()

                            while let chunk = try await streaming.next() {
                                body.append(chunk)
                            }

                            throw ErrorMapping.error(status: response.statusCode, body: body, url: urlRequest.url)
                        }

                        var lines = JSONLLineBuffer()

                        do {
                            while let chunk = try await streaming.next() {
                                for line in lines.append(chunk) {
                                    continuation.yield(try decoder.decode(type, from: line))
                                }
                            }
                        } catch let error as URLError {
                            throw Self.map(error)
                        }

                        if let line = lines.flush() {
                            continuation.yield(try decoder.decode(type, from: line))
                        }

                        continuation.finish()

                        return
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Builds the `URLRequest` for a request.
    public func makeURLRequest(_ request: ClientRequest, accept: String?) throws -> URLRequest {
        var url = try resolveURL(request.path)

        if let query = request.query {
            let items = try QueryEncoding.items(for: query)

            if !items.isEmpty {
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    throw URLError(.badURL)
                }

                components.queryItems = (components.queryItems ?? []) + items
                components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")

                guard let withQuery = components.url else {
                    throw URLError(.badURL)
                }

                url = withQuery
            }
        }

        var urlRequest = URLRequest(url: url)

        var headers = options.headers

        if !request.external {
            if let token = options.token, !token.isEmpty {
                headers["authorization"] = "Bearer \(token)"
            }

            if let runAsUserId = options.runAsUserId {
                headers["x-runas-user-id"] = runAsUserId
            }

            if let runAsChildUserEmail = options.runAsChildUserEmail {
                headers["x-runas-child-user-email"] = runAsChildUserEmail
            }
        }

        if let timezone = options.timezone {
            headers["x-timezone"] = timezone
        }

        var method = request.method

        switch request.body {
        case .none:
            method = method ?? "GET"
        case .record(let record):
            method = method ?? "POST"

            urlRequest.httpBody = try ChatBotKitCoding.makeEncoder().encode(AnyEncodable(record))

            headers["content-type"] = "application/json"
        case .buffer(let data):
            method = method ?? "POST"

            urlRequest.httpBody = data

            headers["content-type"] = "application/octet-stream"
        }

        if let accept {
            headers["accept"] = accept
        }

        for (name, value) in request.headers {
            headers = headers.filter { $0.key.lowercased() != name.lowercased() }

            headers[name] = value
        }

        urlRequest.httpMethod = method

        for (name, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        if let timeout = options.timeout {
            urlRequest.timeoutInterval = timeout
        }

        return urlRequest
    }

    /// Resolves an API path against the base URL.
    public func resolveURL(_ path: String) throws -> URL {
        if let absolute = URL(string: path), let scheme = absolute.scheme, !scheme.isEmpty, absolute.host != nil {
            return absolute
        }

        guard var components = URLComponents(url: options.baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        if let host = options.host {
            let parts = host.split(separator: ":", maxSplits: 1)

            components.host = String(parts[0])
            components.port = parts.count > 1 ? Int(parts[1]) : nil
        }

        let prefix = components.percentEncodedPath.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let suffix = path.replacingOccurrences(of: "^/+", with: "", options: .regularExpression)

        var fullPath = prefix + "/" + suffix

        if components.host == "api.chatbotkit.com" && fullPath.hasPrefix("/api/") {
            fullPath = String(fullPath.dropFirst(4))
        }

        components.percentEncodedPath = ""
        components.percentEncodedQuery = nil
        components.fragment = nil

        guard let root = components.url, let url = URL(string: root.absoluteString + fullPath) else {
            throw URLError(.badURL)
        }

        return url
    }

    static func isRetryable(_ error: URLError, retryTimeout: Bool) -> Bool {
        switch error.code {
        case .cancelled:
            return false
        case .timedOut:
            return retryTimeout
        default:
            return true
        }
    }

    static func map(_ error: URLError) -> Error {
        switch error.code {
        case .cancelled:
            return CancellationError()
        case .timedOut:
            return TimeoutError()
        default:
            return error
        }
    }

    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

struct AnyEncodable: Encodable {
    let value: any Encodable

    init(_ value: any Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
