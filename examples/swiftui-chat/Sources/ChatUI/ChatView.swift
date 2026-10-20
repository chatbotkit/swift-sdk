#if canImport(SwiftUI)
import ChatCore
import SwiftUI
import UniformTypeIdentifiers

/// A chat with streaming replies, a composer and file attachments.
public struct ChatView: View {
    @Bindable var model: ChatViewModel

    @State private var isImporting = false

    public init(model: ChatViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.messages) { message in
                            MessageBubble(message: message, isStreaming: model.isStreaming && message.id == model.messages.last?.id && message.role == .bot)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.messages.last?.text) {
                    if let id = model.messages.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if !model.pendingAttachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.pendingAttachments) { attachment in
                            Label(attachment.name, systemImage: "paperclip")
                                .font(.caption)
                                .padding(6)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            composer
        }
        .navigationTitle("Chat")
        .task {
            await model.load()
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.image, .pdf, .plainText], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }

            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()

                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                guard let data = try? Data(contentsOf: url) else { continue }

                let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

                model.pendingAttachments.append(.init(name: url.lastPathComponent, type: type, data: data))
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                isImporting = true
            } label: {
                Image(systemName: "paperclip")
            }
            .disabled(model.isStreaming)

            TextField("Message", text: $model.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit { model.send() }

            if model.isStreaming {
                Button {
                    model.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                }
            } else {
                Button {
                    model.send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .disabled(!model.canSend)
            }
        }
        .font(.title3)
        .padding()
    }
}

struct MessageBubble: View {
    let message: ChatViewModel.Message
    let isStreaming: Bool

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                ForEach(message.attachments, id: \.self) { name in
                    Label(name, systemImage: "paperclip")
                        .font(.caption)
                }

                if message.text.isEmpty && isStreaming {
                    ProgressView()
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .background(message.role == .user ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

            if message.role == .bot {
                Spacer(minLength: 40)
            }
        }
    }
}
#endif
