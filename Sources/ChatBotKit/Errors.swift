import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thrown when the API responds with a non-2xx status.
///
/// `code` is the machine readable error code returned by the API (for example
/// `NOT_FOUND` or `BAD_REQUEST`), `status` is the HTTP status and `data` holds
/// the parsed response body when it was JSON.
public struct FetchError: Error, Sendable, LocalizedError, CustomStringConvertible {
    public let message: String
    public let code: String
    public let status: Int?
    public let url: URL?
    public let data: JSONValue?

    public init(message: String, code: String, status: Int? = nil, url: URL? = nil, data: JSONValue? = nil) {
        self.message = message
        self.code = code
        self.status = status
        self.url = url
        self.data = data
    }

    public var errorDescription: String? { message }

    public var description: String { "FetchError(\(code)): \(message)" }
}

/// Thrown when the API responds with `authorization_required`: the linked
/// secret or connection has not been authenticated yet. `url` is the address
/// the user must visit to authorize; `data` carries the full response body.
public struct AuthorizationRequiredError: Error, Sendable, LocalizedError, CustomStringConvertible {
    public let message: String
    public let code: String = "AUTHORIZATION_REQUIRED"
    public let url: String?
    public let status: Int?
    public let data: JSONValue?

    public init(message: String, url: String? = nil, status: Int? = nil, data: JSONValue? = nil) {
        self.message = message
        self.url = url
        self.status = status
        self.data = data
    }

    public var errorDescription: String? { message }

    public var description: String { "AuthorizationRequiredError: \(message)" }
}

/// Thrown when a request does not complete within the configured timeout.
public struct TimeoutError: Error, Sendable, LocalizedError {
    public let code: String = "TimeoutError"

    public init() {}

    public var errorDescription: String? { "TimeoutError" }
}

enum ErrorMapping {
    static let standardErrors: [Int: (message: String, code: String)] = [
        413: ("Client request is too large to be processed by the web server.", "CONTENT_TOO_LARGE"),
    ]

    static let defaultError = (message: "There was a generic error", code: "GENERIC_ERROR")

    static func error(status: Int, body: Data, url: URL?) -> Error {
        let data = try? ChatBotKitCoding.makeDecoder().decode(JSONValue.self, from: body)

        guard let data, data.objectValue != nil else {
            let fallback = standardErrors[status] ?? defaultError

            return FetchError(message: fallback.message, code: fallback.code, status: status, url: url)
        }

        let statusText = HTTPURLResponse.localizedString(forStatusCode: status)

        let message = data["message"]?.stringValue ?? "HTTP Error: \(statusText)"

        if data["error"]?.stringValue == "authorization_required" {
            return AuthorizationRequiredError(message: message, url: data["url"]?.stringValue, status: status, data: data)
        }

        let code = data["code"]?.stringValue ?? "ERROR_\(status)"

        return FetchError(message: message, code: code, status: status, url: url, data: data)
    }
}
