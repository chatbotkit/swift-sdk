#if canImport(SwiftUI)
import ChatCore
import SwiftUI

/// The whole chat app: the conversation list and the open chat.
public struct ChatRootView: View {
    @State private var store: ChatStore

    public init(store: ChatStore) {
        _store = State(initialValue: store)
    }

    public var body: some View {
        NavigationSplitView {
            ConversationListView(store: store)
        } detail: {
            if let chat = store.current {
                ChatView(model: chat)
                    .id(chat.id)
            } else {
                ContentUnavailableView("No chat selected", systemImage: "bubble.left.and.bubble.right", description: Text("Pick a conversation or start a new one."))
            }
        }
        .task {
            await store.refresh()
        }
    }
}

struct ConversationListView: View {
    @Bindable var store: ChatStore

    var body: some View {
        List(selection: Binding(get: { store.selection }, set: { id in
            if let id {
                store.open(id)
            }
        })) {
            ForEach(store.conversations) { conversation in
                VStack(alignment: .leading) {
                    Text(conversation.name ?? "Conversation")
                        .font(.headline)

                    if let updatedAt = conversation.updatedAt {
                        Text(Date(timeIntervalSince1970: updatedAt / 1000), style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(conversation.id as String?)
            }
        }
        .overlay {
            if store.conversations.isEmpty && !store.isLoading {
                ContentUnavailableView("No conversations yet", systemImage: "text.bubble")
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem {
                Button {
                    store.newChat()
                } label: {
                    Label("New chat", systemImage: "square.and.pencil")
                }
            }
        }
        .refreshable {
            await store.refresh()
        }
    }
}
#endif
