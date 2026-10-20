import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ChatBotKit

final class ResourceTests: XCTestCase {
    func makeClient(token: String = "secret") -> ChatBotKit {
        ChatBotKit(options: ChatBotKitOptions(token: token, retryDelay: 0, session: MockURLProtocol.makeSession()))
    }

    func testFileUploadUsesThePresignedRequest() async throws {
        MockURLProtocol.reset { request in
            if request.url.host == "storage.example.com" {
                return MockResponse(status: 200, headers: [:], chunks: [])
            }

            return .json(#"{"id":"f1","uploadRequest":{"url":"https://storage.example.com/put?sig=1","method":"PUT","headers":{"Content-Type":"image/png","Content-Length":4}}}"#)
        }

        let bytes = Data([0x89, 0x50, 0x4E, 0x47])

        let result = try await makeClient().file.upload("f1", data: bytes, name: "logo.png", type: "image/png")

        XCTAssertEqual(result.id, "f1")

        let requests = MockURLProtocol.requests

        XCTAssertEqual(requests.count, 2)

        XCTAssertEqual(requests[0].url.path, "/v1/file/f1/upload")
        XCTAssertEqual(requests[0].json, ["file": ["size": 4, "type": "image/png", "name": "logo.png"]])
        XCTAssertEqual(requests[0].header("Authorization"), "Bearer secret")

        XCTAssertEqual(requests[1].url.absoluteString, "https://storage.example.com/put?sig=1")
        XCTAssertEqual(requests[1].method, "PUT")
        XCTAssertEqual(requests[1].header("Content-Type"), "image/png")
        XCTAssertNil(requests[1].header("Authorization"))
        XCTAssertEqual(requests[1].body, bytes)
    }

    func testAttachmentUpload() async throws {
        MockURLProtocol.reset { request in
            if request.url.host == "storage.example.com" {
                return MockResponse(status: 200, headers: [:], chunks: [])
            }

            return .json(#"{"id":"a1","name":"a1.pdf","uploadRequest":{"url":"https://storage.example.com/a1","method":"PUT","headers":{}}}"#)
        }

        let result = try await makeClient(token: "session").conversation.attachment.upload("c1", data: Data("pdf".utf8), name: "doc.pdf", type: "application/pdf")

        XCTAssertEqual(result, UploadResult(id: "a1", name: "a1.pdf"))
        XCTAssertEqual(MockURLProtocol.requests.first?.url.path, "/v1/conversation/c1/attachment/upload")
        XCTAssertEqual(MockURLProtocol.requests.last?.header("Content-Type"), "application/octet-stream")
    }

    func testUploadFailsWithoutUploadRequest() async {
        MockURLProtocol.reset { _ in .json(#"{"id":"f1"}"#) }

        do {
            _ = try await makeClient().file.upload("f1", data: Data([1]))

            XCTFail("expected an error")
        } catch let error as FetchError {
            XCTAssertEqual(error.code, "MISSING_UPLOAD_REQUEST")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testFileDownload() async throws {
        MockURLProtocol.reset { request in
            if request.header("Accept") == "application/json" {
                return .json(#"{"url":"https://cdn.example.com/f1"}"#)
            }

            return MockResponse(status: 200, headers: ["Content-Type": "application/octet-stream"], chunks: [Data("content".utf8)])
        }

        let client = makeClient()

        let link = try await client.file.download("f1")
        let data = try await client.file.downloadData("f1")

        XCTAssertEqual(link.url, "https://cdn.example.com/f1")
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "content")
        XCTAssertEqual(MockURLProtocol.requests.map(\.url.path), ["/v1/file/f1/download", "/v1/file/f1/download"])
        XCTAssertEqual(MockURLProtocol.requests.last?.header("Accept"), "application/octet-stream")
        XCTAssertEqual(MockURLProtocol.requests.last?.header("Authorization"), "Bearer secret")
    }

    func testSessionTokenFlow() async throws {
        MockURLProtocol.reset { request in
            switch request.url.path {
            case "/v1/conversation/c1/session/create":
                return .json(#"{"id":"c1","token":"short-lived","expiresAt":1700000000000}"#)
            default:
                return .json(#"{"id":"m1","text":"Hi there","usage":{"token":3},"end":{"reason":"stop"}}"#)
            }
        }

        let server = makeClient(token: "api-secret")

        let session = try await server.conversation.session.create("c1", ConversationSessionCreateRequest(durationInSeconds: 3600))

        XCTAssertEqual(session.token, "short-lived")
        XCTAssertEqual(MockURLProtocol.requests[0].json, ["durationInSeconds": 3600])

        let app = makeClient(token: session.token)

        let reply = try await app.conversation.complete("c1", ConversationMessageCompleteRequest(text: "Hello")).value

        XCTAssertEqual(reply.text, "Hi there")
        XCTAssertEqual(MockURLProtocol.requests[1].header("Authorization"), "Bearer short-lived")
    }

    func testBotSession() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"s1","conversationId":"c9","token":"tok","expiresAt":1}"#) }

        let session = try await makeClient().bot.session.create("b1")

        XCTAssertEqual(session.conversationID, "c9")
        XCTAssertEqual(MockURLProtocol.requests.first?.url.path, "/v1/bot/b1/session/create")
    }

    func testNestedListPaging() async throws {
        MockURLProtocol.reset { _ in .json(#"{"items":[{"id":"m1","createdAt":1,"updatedAt":2,"text":"Hi","type":"user"}],"cursor":"m1"}"#) }

        let list = try await makeClient().conversation.message.list("c1", ListParams(cursor: "m0", order: .asc, take: 20)).value

        XCTAssertEqual(list.items.first?.type, .user)

        let request = try XCTUnwrap(MockURLProtocol.requests.first)

        XCTAssertEqual(request.url.path, "/v1/conversation/c1/message/list")
        XCTAssertEqual(request.queryItems, ["cursor": "m0", "order": "asc", "take": "20"])
    }

    func testNestedResourcePaths() async throws {
        MockURLProtocol.reset { _ in .json(#"{"id":"x"}"#) }

        let client = makeClient()

        _ = try? await client.dataset.record.delete("d1", "r1")
        _ = try? await client.skillset.ability.delete("s1", "a1")
        _ = try? await client.conversation.message.delete("c1", "m1")
        _ = try? await client.contact.conversation.list("ct1").value
        _ = try? await client.dataset.file.sync("d1", "f1")
        _ = try? await client.user.session.create("u1")

        XCTAssertEqual(
            MockURLProtocol.requests.map(\.url.path),
            [
                "/v1/dataset/d1/record/r1/delete",
                "/v1/skillset/s1/ability/a1/delete",
                "/v1/conversation/c1/message/m1/delete",
                "/v1/contact/ct1/conversation/list",
                "/v1/dataset/d1/file/f1/sync",
                "/v1/user/u1/session/create",
            ]
        )
    }
}

final class JSONValueTests: XCTestCase {
    func testDecodesEveryKind() throws {
        let json = #"{"a":null,"b":true,"c":1.5,"d":"x","e":[1,false],"f":{"g":0}}"#

        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))

        XCTAssertEqual(value, ["a": nil, "b": true, "c": 1.5, "d": "x", "e": [1, false], "f": ["g": 0]])
        XCTAssertEqual(value["b"]?.boolValue, true)
        XCTAssertEqual(value["f"]?["g"]?.numberValue, 0)
        XCTAssertEqual(value["e"]?[1], false)
        XCTAssertNil(value["e"]?[5])
        XCTAssertTrue(value["a"]?.isNull ?? false)
    }

    func testRoundTrips() throws {
        let value: JSONValue = ["list": [1, "two", nil], "flag": false]

        let data = try JSONEncoder().encode(value)

        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
    }

    func testConvertsCodableValues() throws {
        struct Point: Codable, Equatable { let x: Int; let y: Int }

        let value = try JSONValue(encoding: Point(x: 1, y: 2))

        XCTAssertEqual(value, ["x": 1, "y": 2])
        XCTAssertEqual(try value.decode(as: Point.self), Point(x: 1, y: 2))
    }

    func testDecodesDates() throws {
        struct Stamp: Decodable { let at: Date }

        let decoder = ChatBotKitCoding.makeDecoder()

        let withFraction = try decoder.decode(Stamp.self, from: Data(#"{"at":"2024-05-01T10:00:00.250Z"}"#.utf8))
        let without = try decoder.decode(Stamp.self, from: Data(#"{"at":"2024-05-01T10:00:00Z"}"#.utf8))

        XCTAssertEqual(withFraction.at.timeIntervalSince1970, 1_714_557_600.25, accuracy: 0.001)
        XCTAssertEqual(without.at.timeIntervalSince1970, 1_714_557_600, accuracy: 0.001)
    }
}
