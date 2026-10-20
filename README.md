[![CBK.AI](https://img.shields.io/badge/credits-CBK.AI-blue.svg)](https://cbk.ai)
[![Email](https://img.shields.io/badge/Email-Support-blue?logo=mail.ru)](mailto:support@cbk.ai)
[![Follow on Twitter](https://img.shields.io/twitter/follow/chatbotkit.svg?logo=twitter)](https://twitter.com/chatbotkit)

```text
 .d8888b.  888888b.   888    d8P
d88P  Y88b 888  "88b  888   d8P
888    888 888  .88P  888  d8P
888        8888888K.  888d88K
888        888  "Y88b 8888888b
888    888 888    888 888  Y88b
Y88b  d88P 888   d88P 888   Y88b
 "Y8888P"  8888888P"  888    Y88b .ai
```

# ChatBotKit Swift SDK

The official Swift SDK for [ChatBotKit](https://chatbotkit.com) - a platform
for building and deploying conversational AI applications. Use it to add
streaming AI chat to iOS, macOS, tvOS, watchOS and visionOS apps, or to call
the ChatBotKit API from Swift on the server and on Linux.

- `async`/`await` API built on `URLSession`, with no third-party dependencies
- Streaming replies token by token as an `AsyncThrowingStream`
- `Codable` and `Sendable` request and response types generated from the API
  specification
- Short-lived session tokens, so apps never ship the API secret
- Typed errors, retries with backoff and cancellation

## Requirements

- Swift 6.0 or later (Xcode 16 or later). The package builds in the Swift 6
  language mode with complete concurrency checking.
- iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, or Linux

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/chatbotkit/swift-sdk", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "ChatBotKit", package: "swift-sdk"),
    ]),
]
```

In Xcode, choose **File > Add Package Dependencies** and enter the same URL.

## Quick Start

```swift
import ChatBotKit

let client = ChatBotKit(token: "your-api-secret")

let conversation = try await client.conversation.create(
    ConversationCreateRequest(backstory: "You are a helpful assistant.", model: "gpt-4o")
)

let reply = try await client.conversation.complete(
    conversation.id,
    ConversationMessageCompleteRequest(text: "Hello!")
).value

print(reply.text)
```

## Streaming

Calls that can stream return a `ResponsePromise`. Await `.value` for the JSON
response, or iterate `.stream()` for the JSONL events as they arrive:

```swift
let stream = client.conversation.complete(
    conversation.id,
    ConversationMessageCompleteRequest(text: "Tell me a story")
).stream()

for try await item in stream {
    switch item.type {
    case .token:
        print(item.data.token ?? "", terminator: "")
    case .result:
        print("\n\(item.data.usage?.token ?? 0) tokens")
    default:
        break
    }
}
```

The same works for a stateless completion, where you send the whole history and
nothing is stored:

```swift
let stream = client.conversation.complete(
    ConversationCompleteRequest(
        messages: [ConversationCompleteRequestMessage(text: "Hi!", type: .user)],
        model: "gpt-4o"
    )
).stream()
```

Breaking out of the loop or cancelling the surrounding `Task` cancels the
request. To handle event types the typed stream item does not describe yet,
stream them as `StreamEvent`, which keeps the raw `type` and `data`:

```swift
for try await event in client.conversation.receive(conversation.id).stream(as: StreamEvent.self) {
    print(event.type, event.data)
}
```

`list` calls stream too, which is the easiest way to walk through every item:

```swift
for try await item in client.bot.list().stream() {
    print(item.data.id, item.data.name ?? "")
}
```

## Session Tokens for Apps

Never put your API secret in an app: anyone can extract it from the binary. Keep
it on your server and give the app a short-lived session token for one
conversation instead.

On your server (Swift, Node, Python or Go - any SDK works):

```swift
let server = ChatBotKit(token: ProcessInfo.processInfo.environment["CHATBOTKIT_API_SECRET"]!)

let session = try await server.bot.session.create("bot-id")

// return session.conversationID, session.token and session.expiresAt to the app
```

or, for a conversation that already exists:

```swift
let session = try await server.conversation.session.create(
    conversationId,
    ConversationSessionCreateRequest(durationInSeconds: 3600)
)
```

In the app, use only the token:

```swift
let client = ChatBotKit(token: sessionToken)

for try await item in client.conversation.complete(conversationId, ConversationMessageCompleteRequest(text: "Hi")).stream() {
    // ...
}
```

A conversation session token can call `complete`, `send` and `receive`,
upload attachments and vote on messages of that one conversation. Everything
else, such as listing conversations or reading the message history, goes
through your server. Tokens expire (one hour by default, up to a day), so ask
your server for a new one before `expiresAt`.

## Configuration

```swift
let client = ChatBotKit(
    options: ChatBotKitOptions(
        token: "your-api-secret",
        baseURL: URL(string: "https://api.chatbotkit.com")!,
        runAsUserId: "user-id",
        timezone: "Europe/London",
        headers: ["X-App-Version": "1.0"],
        timeout: 60,
        retries: 3,
        retryDelay: 0.25,
        session: .shared
    )
)
```

| Option                | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| `token`               | API secret (server) or session token (app). `secret` is an alias.      |
| `baseURL`             | API base URL, e.g. `http://localhost:3000` for a self-hosted platform. |
| `host`                | Replaces the host of `baseURL`.                                        |
| `runAsUserId`         | Run requests as a sub-user.                                            |
| `runAsChildUserEmail` | Run requests as a child user (experimental).                           |
| `timezone`            | Sent as `X-Timezone`.                                                  |
| `headers`             | Extra headers for every request.                                       |
| `timeout`             | Request timeout in seconds. Defaults to the `URLSession` setting.      |
| `retries`             | Retries after network errors and 429/5xx responses (default 3).        |
| `retryDelay`          | Delay before the first retry in seconds; doubles each time.            |
| `retryTimeout`        | Whether timed out requests are retried (default `true`).               |
| `session`             | The `URLSession` to use.                                               |

`client.extend { $0.runAsUserId = "other-user" }` returns a new client with
changed options and leaves the original alone.

## Concurrency

`ChatBotKit`, every resource client and `ChatBotKitOptions` are `Sendable`
and only hold immutable state, so one client can be created once and shared
between tasks, view models and actors of your app. The SDK itself uses no
actors and no global mutable state: each call is an `async` function on the
caller's task, and cancelling that task cancels the request.

## Resources

The client mirrors the structure of the Node SDK:

```swift
client.bot                      // list, fetch, create, update, delete, upvote, downvote
client.bot.session              // create (end-user session for a bot)
client.conversation             // list, fetch, create, update, delete, complete, dispatch,
                                // send, receive, upvote, downvote
client.conversation.message     // list, fetch, create, update, delete, upvote, downvote
client.conversation.session     // create (conversation session token)
client.conversation.attachment  // list, upload
client.dataset                  // list, fetch, create, update, delete, search
client.dataset.record           // list, export, fetch, create, update, delete
client.dataset.file             // list, attach, detach, sync
client.skillset                 // list, fetch, create, update, delete
client.skillset.ability         // list, export, fetch, create, update, delete, execute
client.file                     // list, fetch, create, update, delete, upload, download,
                                // downloadData, sync
client.contact                  // list, fetch, create, update, delete, ensure
client.contact.conversation     // list
client.user                     // list, fetch, create, update, delete
client.user.session             // create
client.platform.model           // list
```

Every resource client can also be used on its own, for example
`ConversationClient(options: options)`. Resource clients share one
`ChatBotKitClient` that holds the options and performs the requests
(`client.conversation.client`).

Any other endpoint can be called through the base client while it is not
wrapped yet:

```swift
let response: BlueprintListResponse = try await client.fetch(
    ClientRequest(path: "/api/v1/blueprint/list", query: BlueprintListParams(take: 10))
)
```

### Coverage compared with the Node SDK

| Node SDK client                                                                                                                                                      | Swift                        |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `bot`, `bot.session`                                                                                                                                                 | Yes                          |
| `conversation`, `.message`, `.session`, `.attachment`                                                                                                                | Yes                          |
| `dataset`, `.record`, `.file`                                                                                                                                        | Yes                          |
| `skillset`, `.ability`                                                                                                                                               | Yes                          |
| `file`                                                                                                                                                               | Yes                          |
| `contact`, `contact.conversation`                                                                                                                                    | Yes                          |
| `contact.secret`, `.space`, `.task`                                                                                                                                  | Not yet (use `client.fetch`) |
| `user`, `user.session`                                                                                                                                               | Yes                          |
| `user.context`, `.token`                                                                                                                                             | Not yet (use `client.fetch`) |
| `platform.model`                                                                                                                                                     | Yes                          |
| other `platform` catalogues                                                                                                                                          | Not yet (use `client.fetch`) |
| `blueprint`, `channel`, `computer`, `decision`, `event`, `graphql`, `integration`, `magic`, `memory`, `policy`, `portal`, `secret`, `space`, `task`, `team`, `usage` | Not yet (use `client.fetch`) |

## Uploading Files

```swift
let file = try await client.file.create(FileCreateRequest(name: "handbook.pdf"))

try await client.file.upload(file.id, data: pdfData, name: "handbook.pdf", type: "application/pdf")
```

Attachments for a conversation work the same way, with a session token too:

```swift
try await client.conversation.attachment.upload(conversationId, data: imageData, name: "photo.jpg", type: "image/jpeg")
```

The API returns a pre-signed upload request and the bytes go straight to
storage.

## Errors

| Error                        | When                                                                      |
| ---------------------------- | ------------------------------------------------------------------------- |
| `FetchError`                 | Non-2xx response. `code` (e.g. `NOT_FOUND`), `message`, `status`, `data`. |
| `AuthorizationRequiredError` | A secret or connection needs authorizing first; `url` is where to go.     |
| `TimeoutError`               | The request timed out.                                                    |
| `CancellationError`          | The task was cancelled.                                                   |
| `DecodingError`              | The response did not match the expected type.                             |

```swift
do {
    _ = try await client.conversation.fetch("missing")
} catch let error as FetchError where error.code == "NOT_FOUND" {
    print("No such conversation")
}
```

## Types

All request and response types in `Types.swift` are generated from the API
specification. Values the API may extend later, such as message and event
types, are open structs with static members (`.user`, `.token`), so a new value
from the server decodes instead of failing. Free-form JSON uses `JSONValue`.

Regenerate the types from the monorepo root after the API changes:

```bash
pnpm script:sync-types:swift
```

## Examples

- [`examples/cli`](examples/cli) - a terminal chat that creates a conversation
  and streams replies. Runs on macOS and Linux:
  `CHATBOTKIT_API_SECRET=... swift run --package-path examples/cli`
- [`examples/swiftui-chat`](examples/swiftui-chat) - a complete SwiftUI app for
  iOS and macOS with a conversation list, streaming chat, attachments and
  session-token login through a small backend.

## Development

```bash
swift build
swift test
```

The tests use a mocked `URLProtocol`, so they need no network or API key.

## Releasing

Versions are published as Git tags - for a Swift package, the tag _is_ the
release. The version is driven by the [`VERSION`](VERSION) file:

1. Bump `VERSION` (semver, no `v` prefix - e.g. `0.2.0`) and add a section to
   [`CHANGELOG.md`](CHANGELOG.md) in a pull request.
2. Merge to `main`. The `Tag Release` workflow reads `VERSION` and, if the
   matching `vX.Y.Z` tag does not yet exist, creates and pushes it, then
   triggers the `Release` workflow to publish GitHub release notes.

Consumers then pick up the new version through SwiftPM:

```swift
.package(url: "https://github.com/chatbotkit/swift-sdk", from: "0.2.0"),
```

While the API is still evolving the package stays on `0.x` (minor versions may
introduce breaking changes); it will move to `1.0.0` once the API is stable.

## License

ISC. See [LICENSE](LICENSE) for details.
