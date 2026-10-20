import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ChatBotKit

final class ErrorTests: XCTestCase {
    func makeClient(retries: Int = 3) -> ChatBotKit {
        ChatBotKit(options: ChatBotKitOptions(token: "t", retries: retries, retryDelay: 0, session: MockURLProtocol.makeSession()))
    }

    func testJSONErrorBecomesFetchError() async {
        MockURLProtocol.reset { _ in .json(#"{"message":"Conversation not found","code":"NOT_FOUND"}"#, status: 404) }

        do {
            _ = try await makeClient().conversation.fetch("missing")

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.message, "Conversation not found")
            XCTAssertEqual(error.code, "NOT_FOUND")
            XCTAssertEqual(error.status, 404)
            XCTAssertEqual(error.data?["code"], "NOT_FOUND")
            XCTAssertEqual(error.url?.path, "/v1/conversation/missing/fetch")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testJSONErrorWithoutCodeUsesStatus() async {
        MockURLProtocol.reset { _ in .json(#"{"message":"Nope"}"#, status: 422) }

        do {
            _ = try await makeClient().bot.fetch("b1")

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.message, "Nope")
            XCTAssertEqual(error.code, "ERROR_422")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testNonJSONErrorsUseStandardMessages() async {
        MockURLProtocol.reset { _ in .text("<html>too big</html>", status: 413, contentType: "text/html") }

        do {
            _ = try await makeClient().bot.fetch("b1")

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.code, "CONTENT_TOO_LARGE")
            XCTAssertEqual(error.status, 413)
            XCTAssertNil(error.data)
        } catch {
            XCTFail("unexpected error \(error)")
        }

        MockURLProtocol.reset { _ in .text("bad", status: 400) }

        do {
            _ = try await makeClient().bot.fetch("b1")

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.code, "GENERIC_ERROR")
            XCTAssertEqual(error.message, "There was a generic error")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testAuthorizationRequired() async {
        MockURLProtocol.reset { _ in
            .json(#"{"error":"authorization_required","message":"Connect your account","url":"https://example.com/authorize"}"#, status: 409)
        }

        do {
            _ = try await makeClient().bot.fetch("b1")

            XCTFail("expected an error")
        } catch let error as AuthorizationRequiredError {
            XCTAssertEqual(error.message, "Connect your account")
            XCTAssertEqual(error.url, "https://example.com/authorize")
            XCTAssertEqual(error.status, 409)
            XCTAssertEqual(error.code, "AUTHORIZATION_REQUIRED")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRetriesOnServerErrors() async throws {
        let counter = Counter()

        MockURLProtocol.reset { _ in
            counter.increment() < 3
                ? .json(#"{"message":"busy"}"#, status: 503)
                : .json(#"{"id":"b1","createdAt":1,"updatedAt":2}"#)
        }

        let bot = try await makeClient().bot.fetch("b1")

        XCTAssertEqual(bot.id, "b1")
        XCTAssertEqual(MockURLProtocol.requests.count, 3)
    }

    func testGivesUpAfterRetries() async {
        MockURLProtocol.reset { _ in .json(#"{"message":"slow down","code":"TOO_MANY_REQUESTS"}"#, status: 429) }

        do {
            _ = try await makeClient(retries: 2).bot.fetch("b1")

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.code, "TOO_MANY_REQUESTS")
            XCTAssertEqual(MockURLProtocol.requests.count, 3)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testDoesNotRetryClientErrors() async {
        MockURLProtocol.reset { _ in .json(#"{"message":"bad","code":"BAD_REQUEST"}"#, status: 400) }

        _ = try? await makeClient().bot.fetch("b1")

        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }

        value += 1

        return value
    }
}
