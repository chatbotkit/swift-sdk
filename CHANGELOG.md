# Changelog

All notable changes to the ChatBotKit Swift SDK are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-20

### Added

- First release of the Swift package `ChatBotKit` for iOS 15, macOS 12,
  tvOS 15, watchOS 8, visionOS 1 and Linux, with no third-party dependencies.
- `ChatBotKit` client with `async`/`await` methods for `bot`, `conversation`,
  `dataset`, `skillset`, `file`, `contact`, `user` and `platform.model`, plus
  `client.fetch` for any other endpoint.
- Streaming of JSONL responses as an `AsyncThrowingStream` of typed items
  through `ResponsePromise.stream()`, with cancellation when the consuming task
  is cancelled.
- `Codable` and `Sendable` request and response types generated from the API
  specification.
- Session tokens, retries with backoff, timeouts and typed errors
  (`FetchError`, `AuthorizationRequiredError`, `TimeoutError`).
- `ChatBotKit`, its resource clients and `ChatBotKitOptions` are `Sendable`
  value types and immutable classes, checked by the Swift 6 language mode.
- Readable generated type names derived from the parent type and property,
  e.g. `ConversationCompleteRequestMessageType`.
- `examples/cli` and `examples/swiftui-chat`.
