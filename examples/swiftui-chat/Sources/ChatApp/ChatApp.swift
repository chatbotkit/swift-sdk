import ChatCore
import Foundation

#if canImport(SwiftUI)
import ChatUI
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct ChatApp: App {
    @State private var store = ChatStore(
        backend: HTTPChatBackend(
            baseURL: URL(string: ProcessInfo.processInfo.environment["CHAT_BACKEND_URL"] ?? "http://localhost:8787")!,
            authorization: ProcessInfo.processInfo.environment["CHAT_BACKEND_AUTHORIZATION"]
        )
    )

    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ChatRootView(store: store)
        }
    }
}
#else
@main
enum ChatApp {
    static func main() {
        print("The SwiftUI app needs iOS 17 or macOS 14. On this platform only ChatCore is available.")
    }
}
#endif
