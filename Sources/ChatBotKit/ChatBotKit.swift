import Foundation

/// ChatBotKit SDK - the main client for the ChatBotKit API.
///
/// It gives access to every API resource through a specialised client.
///
/// ```swift
/// import ChatBotKit
///
/// let client = ChatBotKit(token: "your-api-token")
///
/// let bots = try await client.bot.list().value
/// ```
///
/// The client and every resource client only hold immutable state, so they
/// are `Sendable` and can be shared freely between tasks.
public final class ChatBotKit: ChatBotKitResourceClient {
    public let client: ChatBotKitClient

    public let platform: PlatformClient
    public let bot: BotClient
    public let file: FileClient
    public let user: UserClient
    public let dataset: DatasetClient
    public let skillset: SkillsetClient
    public let contact: ContactClient
    public let conversation: ConversationClient

    public init(client: ChatBotKitClient) {
        self.client = client

        platform = PlatformClient(client: client)
        bot = BotClient(client: client)
        file = FileClient(client: client)
        user = UserClient(client: client)
        dataset = DatasetClient(client: client)
        skillset = SkillsetClient(client: client)
        contact = ContactClient(client: client)
        conversation = ConversationClient(client: client)
    }
}
