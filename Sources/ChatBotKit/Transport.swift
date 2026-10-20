import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum HTTPTransport {
    static func data(for request: URLRequest, session: URLSession) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, response)
    }
}

enum StreamingEvent: Sendable {
    case response(URLResponse)
    case data(Data, URLResponse?)
    case complete(URLResponse?)
}

/// Forwards the callbacks of one streaming request into an async stream.
final class StreamingDelegate: NSObject, URLSessionDataDelegate, Sendable {
    let events: AsyncThrowingStream<StreamingEvent, Error>.Continuation

    init(events: AsyncThrowingStream<StreamingEvent, Error>.Continuation) {
        self.events = events
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        events.yield(.response(response))

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        events.yield(.data(data, dataTask.response))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            events.finish(throwing: error)
        } else {
            events.yield(.complete(task.response))

            events.finish()
        }

        session.finishTasksAndInvalidate()
    }
}

/// Streams the body of a single request chunk by chunk.
struct StreamingTask {
    private var events: AsyncThrowingStream<StreamingEvent, Error>.AsyncIterator
    private var pending: Data?
    private var complete = false
    private let task: URLSessionDataTask

    init(_ request: URLRequest, configuration: URLSessionConfiguration) {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: StreamingEvent.self)

        let session = URLSession(configuration: configuration, delegate: StreamingDelegate(events: continuation), delegateQueue: nil)
        let task = session.dataTask(with: request)

        continuation.onTermination = { _ in
            task.cancel()
        }

        self.events = stream.makeAsyncIterator()
        self.task = task
    }

    /// Sends the request and waits for the response head.
    mutating func start() async throws -> HTTPURLResponse {
        task.resume()

        while let event = try await events.next() {
            let response: URLResponse?

            switch event {
            case .response(let head):
                response = head
            case .data(let chunk, let head):
                pending = chunk
                response = head
            case .complete(let head):
                complete = true
                response = head
            }

            guard let response = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            return response
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        throw URLError(.badServerResponse)
    }

    /// Returns the next chunk of the body, or `nil` at its end.
    mutating func next() async throws -> Data? {
        if let chunk = pending {
            pending = nil

            return chunk
        }

        while !complete, let event = try await events.next() {
            switch event {
            case .response:
                continue
            case .data(let chunk, _):
                return chunk
            case .complete:
                complete = true
            }
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        return nil
    }

    func cancel() {
        task.cancel()
    }
}

/// Splits a byte stream into JSONL lines.
public struct JSONLLineBuffer: Sendable {
    private var buffer = Data()

    public init() {}

    /// Appends a chunk and returns every complete, non-empty line.
    public mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)

        var lines: [Data] = []

        while let index = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<index]

            buffer = Data(buffer[buffer.index(after: index)...])

            if let trimmed = Self.trim(Data(line)) {
                lines.append(trimmed)
            }
        }

        return lines
    }

    /// Returns the trailing line that was not terminated by a newline.
    public mutating func flush() -> Data? {
        defer { buffer = Data() }

        return Self.trim(buffer)
    }

    private static func trim(_ line: Data) -> Data? {
        var bytes = line[...]

        while let last = bytes.last, last == 0x0D || last == 0x20 || last == 0x09 {
            bytes = bytes.dropLast()
        }

        while let first = bytes.first, first == 0x20 || first == 0x09 {
            bytes = bytes.dropFirst()
        }

        return bytes.isEmpty ? nil : Data(bytes)
    }
}

enum QueryEncoding {
    static func items(for value: any Encodable) throws -> [URLQueryItem] {
        let json = try JSONValue(encoding: AnyEncodable(value))

        guard let object = json.objectValue else {
            return []
        }

        var items: [URLQueryItem] = []

        for key in object.keys.sorted() {
            guard let member = object[key] else { continue }

            switch member {
            case .null:
                continue
            case .object(let nested):
                for subKey in nested.keys.sorted() {
                    if let string = nested[subKey].flatMap(string(for:)) {
                        items.append(URLQueryItem(name: "\(key).\(subKey)", value: string))
                    }
                }
            case .array(let elements):
                for (index, element) in elements.enumerated() {
                    if let string = string(for: element) {
                        items.append(URLQueryItem(name: "\(key).\(index)", value: string))
                    }
                }
            default:
                if let string = string(for: member) {
                    items.append(URLQueryItem(name: key, value: string))
                }
            }
        }

        return items
    }

    static func string(for value: JSONValue) -> String? {
        switch value {
        case .null:
            return nil
        case .bool(let bool):
            return bool ? "true" : "false"
        case .number(let number):
            if number.rounded() == number && abs(number) < 1e15 {
                return String(Int64(number))
            }

            return String(number)
        case .string(let string):
            return string
        case .array, .object:
            guard let data = try? ChatBotKitCoding.makeEncoder().encode(value) else { return nil }

            return String(data: data, encoding: .utf8)
        }
    }
}

enum Path {
    static let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func encode(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: allowed) ?? component
    }
}
