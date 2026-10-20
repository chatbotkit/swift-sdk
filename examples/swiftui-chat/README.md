# SwiftUI Chat Example

A complete chat app for iOS and macOS built with the ChatBotKit Swift SDK:

- a conversation list with a "New chat" button
- a chat view that streams the bot reply token by token, with a stop button
- file attachments (images, PDFs, text) uploaded to the conversation
- session-token login: the app never sees the ChatBotKit API secret

## Layout

| Target     | What it contains                                                                 |
| ---------- | -------------------------------------------------------------------------------- |
| `ChatCore` | `ChatBackend`, `ChatViewModel`, `ChatStore` - platform-independent, unit tested. |
| `ChatUI`   | The SwiftUI views: `ChatRootView`, `ChatView`.                                   |
| `ChatApp`  | A minimal `@main` app that shows `ChatRootView`.                                 |

## How login works

The API secret stays on your backend. The app asks your backend for a
conversation session token and then talks to ChatBotKit directly with it:

```text
App ── POST /chat/session ──────────────▶ Your backend ── bot/{botId}/session/create ──▶ ChatBotKit
App ◀───── {conversationId, token, expiresAt} ─────┘
App ── conversation/{id}/complete (Bearer token, streaming) ─────────────────────────▶ ChatBotKit
```

Your backend authenticates the app user however you already do (the app sends
`CHAT_BACKEND_AUTHORIZATION` as the `Authorization` header) and exposes three
endpoints:

| Endpoint                                   | Response                                                    |
| ------------------------------------------ | ----------------------------------------------------------- |
| `POST /chat/session` `{"conversationId"?}` | `{"conversationId": "...", "token": "...", "expiresAt": 0}` |
| `GET /chat/conversations`                  | `{"items": [{"id": "...", "name": "...", "updatedAt": 0}]}` |
| `GET /chat/conversations/{id}/messages`    | `{"items": [{"id": "...", "type": "user", "text": "..."}]}` |

`expiresAt` and `updatedAt` are milliseconds since 1970, as ChatBotKit returns
them. The app asks for a new session shortly before the token expires.

A reference backend in Node.js with the ChatBotKit Node SDK. Replace
`getUser` with your own authentication, and check that the conversation
belongs to the user before you hand out a token for it:

```js
import { ChatBotKit } from '@chatbotkit/sdk'

import express from 'express'

const cbk = new ChatBotKit({ token: process.env.CHATBOTKIT_API_SECRET })
const botId = process.env.CHATBOTKIT_BOT_ID

const app = express()

app.use(express.json())

async function getUser(req) {
  // @todo authenticate the request and return { id, email }
  return { id: 'demo-user', email: 'demo@example.com' }
}

async function getContactId(user) {
  const contact = await cbk.contact.ensure({
    fingerprint: user.id,
    email: user.email,
  })

  return contact.id
}

app.post('/chat/session', async (req, res) => {
  const contactId = await getContactId(await getUser(req))

  let conversationId = req.body?.conversationId

  if (conversationId) {
    const conversation = await cbk.conversation.fetch(conversationId)

    if (conversation.contactId !== contactId) {
      return res.status(404).end()
    }
  } else {
    const conversation = await cbk.conversation.create({ botId, contactId })

    conversationId = conversation.id
  }

  const session = await cbk.conversation.session.create(conversationId, {
    durationInSeconds: 3600,
  })

  res.json({
    conversationId,
    token: session.token,
    expiresAt: session.expiresAt,
  })
})

app.get('/chat/conversations', async (req, res) => {
  const contactId = await getContactId(await getUser(req))

  const { items } = await cbk.contact.conversation.list(contactId, { take: 50 })

  res.json({
    items: items.map(({ id, name, updatedAt }) => ({ id, name, updatedAt })),
  })
})

app.get('/chat/conversations/:id/messages', async (req, res) => {
  const contactId = await getContactId(await getUser(req))

  const conversation = await cbk.conversation.fetch(req.params.id)

  if (conversation.contactId !== contactId) {
    return res.status(404).end()
  }

  const { items } = await cbk.conversation.message.list(req.params.id, {
    take: 100,
    order: 'asc',
  })

  res.json({ items: items.map(({ id, type, text }) => ({ id, type, text })) })
})

app.listen(8787)
```

## Run it

On macOS 14 or later:

```bash
CHAT_BACKEND_URL=http://localhost:8787 swift run --package-path examples/swiftui-chat ChatApp
```

For iOS, open `Package.swift` in Xcode, or create an iOS App project, add this
package as a local dependency and show `ChatRootView`:

```swift
import ChatCore
import ChatUI
import SwiftUI

@main
struct MyChatApp: App {
    @State private var store = ChatStore(
        backend: HTTPChatBackend(baseURL: URL(string: "https://your-backend.example.com")!, authorization: "Bearer <user token>")
    )

    var body: some Scene {
        WindowGroup {
            ChatRootView(store: store)
        }
    }
}
```

## Tests

`ChatCore` is tested without a network, also on Linux:

```bash
swift test --package-path examples/swiftui-chat
```
