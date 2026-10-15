# ctx.realtime - Real-Time WebSocket API

The realtime API enables bidirectional communication between the browser
and server handlers via WebSockets.

Use ctx.realtime for event-channel realtime such as chat, notifications,
presence, live dashboards, and lightweight collaborative events.

## Choosing the Correct Surface

Use ctx.realtime (`sdk.onRealtime`) when:
- You need channel/event message fanout.
- State authority is not tied to a Room lifecycle.
- Examples: chat, notifications, presence heartbeats, live counters.

## Architecture

```
Browser ←→ Realtime WebSocket Gateway ←→ Platform Message Bus ←→ Server Handlers
```

- Browsers connect via a lightweight WebSocket client library
- Server handlers receive messages and can broadcast back
- Messages are scoped per channel (e.g. 'chat', 'game', 'dashboard')

### Private account and guest updates

`await ctx.realtime.notify(recipient, event, data?)` delivers only to WebSocket
sessions subscribed to `__private__` with a matching verified identity, project,
code branch and data scope, and an unexpired token. Recipients are
`user:<runtime user ID>` or `guest:<ctx.visitor.id>`. Guest identity remains
distinct from login. Resolve the recipient from authorized server records, never
from an unchecked browser payload.

```typescript
// Backend: persist first, then send a small invalidation signal
await ctx.db.collection('workspaces').updateOne({ id: workspaceId }, { $set: changes });
await ctx.realtime.notify('user:' + ownerUserId, 'workspaceChanged', {});
```

```typescript
// Frontend: re-fetch the authorized snapshot on invalidation and after (re)subscribing
import { connect, subscribe, on, onStatus } from '../api/realtime-client.js';

await connect();
subscribe('__private__');
on('__private__', 'workspaceChanged', () => refreshWorkspace());
onStatus(({ state, channel }) => {
    if (state === 'subscribed' && channel === '__private__') refreshWorkspace();
});
```

Use this for private inbox/workspace updates. Ordinary channel names such as
`admin:inbox` or `account:alice` are **not access controls**; never broadcast private
messages on those channels. `notify` rejects missing or invalid recipients
instead of falling back to a broadcast. Private notifications are delivered over
WebSockets only (not over the SSE client). No backlog is kept: reconnecting
clients should re-fetch their authorized state.

Persist first, then send a small invalidation (for example `workspaceChanged`, `{}`).
The frontend re-fetches its authorized snapshot. The browser client retains
subscriptions across reconnects and exposes `onStatus` (`connected`,
`disconnected`, `subscribed`); fetch after a `subscribed` acknowledgment and on
returning to the tab. Keep a manual refresh action and preserve unsaved drafts.
Delivery is best-effort, not a substitute for database persistence. Guest HTTP
mutations still use cookie verification; this does not authorize guest WebSocket
writes or let a channel subscription grant project membership.

Web Push (`ctx.push`) is separate: optional, permission-based delivery for suspended
or closed apps. A live WebSocket cannot replace that browser/OS facility.

## Backend: Registering a Realtime Handler

Use `sdk.onRealtime(channel, handler)` to register a handler for incoming
realtime messages on a named channel.

```typescript
// server/handlers/chat_realtime.ts

/**
 * Handle incoming chat messages in real-time.
 * Triggered when any connected browser sends a message to the 'chat' channel.
 */
sdk.onRealtime('chat', async (ctx, message) => {
    // message shape:
    // {
    //   channel: 'chat',
    //   event: 'sendMessage',        // the event name the browser sent
    //   data: { text: 'Hello!' },     // the payload the browser sent
    //   user: { id: 'user@email.com', sessionId: '...' }
    // }

    const { event, data, user } = message;

    if (event === 'sendMessage') {
        // Save to database
        const { id } = await ctx.db.collection('messages').insertOne({
            text: data.text,
            userId: user.id,
            channel: 'chat',
            timestamp: new Date().toISOString()
        });

        // Broadcast to ALL connected clients on the 'chat' channel
        await ctx.realtime.broadcast('chat', 'newMessage', {
            id,
            text: data.text,
            userId: user.id,
            timestamp: new Date().toISOString()
        });
    }
});
```

## ctx.realtime Methods

### broadcast(channel, event, data)
Send a message to ALL connected clients subscribed to the channel.

```typescript
await ctx.realtime.broadcast('chat', 'newMessage', {
    text: 'hello',
    userId: 'user-123'
});
```

### send(channel, event, data)
Alias for `broadcast`. Sends to all subscribers.

```typescript
await ctx.realtime.send('dashboard', 'statsUpdate', { visitors: 42 });
```

### sendToUser(channel, userId, event, data)
Send a message to a SPECIFIC user on a channel.

IMPORTANT: `sendToUser` still sends on the exact `channel` argument. It does NOT automatically
route to `user:<id>` or any other implicit user channel. The target browser must be subscribed
to the same channel string.

The signature is always `sendToUser(channel, targetUserId, event, data)`. Do not call
`sendToUser(channel, event, data)`; that treats the event name as the target user id.

```typescript
// Send a private notification to one user
await ctx.realtime.sendToUser('game', 'user@email.com', 'yourTurn', {
    message: 'It is your turn to play!'
});

// Per-user channel pattern: frontend subscribes to 'user:' + user.id
await ctx.realtime.sendToUser('user:' + targetUserId, targetUserId, 'matchFound', { roomId });
```

### notify(recipient, event, data?)
Private delivery to a verified `user:<id>` or `guest:<visitorId>` recipient whose
browser is subscribed to `__private__`. See
[Private account and guest updates](#private-account-and-guest-updates).

```typescript
await ctx.realtime.notify('user:' + ownerUserId, 'inboxChanged', {});
```

## Frontend: Connecting to Realtime

The frontend uses either the pre-built `api/realtime-client.js` (WebSockets) or `api/sse-client.js` (Server-Sent Events) framework file.
These files are automatically available in every project — do NOT create or overwrite them.
Just import from them.

### WebSockets (`api/realtime-client.js`)

```typescript
import { connect, subscribe, unsubscribe, on, send, disconnect } from '../api/realtime-client.js';

// Connect once on app startup
await connect();

// Subscribe to a channel
subscribe('chat');

// For per-user messages, the backend must send to this exact channel string
subscribe('user:' + user.id);

// Listen for events
on('chat', 'newMessage', (data) => { /* handle */ });

// Send messages
send('chat', 'sendMessage', { text: 'Hello!' });

// Optional: unsubscribe or disconnect
unsubscribe('chat');
disconnect();
```

The client also exports `off(channel, event, callback)` and `onStatus(callback)`.
For the full API, see `api/realtime-client.js` in your project.

### Server-Sent Events (SSE) (`api/sse-client.js`)

Provides a drop-in replacement that uses EventSource for unidirectional server-to-client streaming, and HTTP POST requests for client-to-server messaging. Useful when WebSockets are blocked or unnecessary:

```typescript
import { connect, subscribe, unsubscribe, on, send, disconnect } from '../api/sse-client.js';

// Connect once on app startup
await connect();

// Subscribe to a channel
subscribe('chat');

// Listen for events
on('chat', 'newMessage', (data) => { /* handle */ });

// Send messages
send('chat', 'sendMessage', { text: 'Hello!' });

// Optional: unsubscribe or disconnect
unsubscribe('chat');
disconnect();
```

For the full API, see `api/sse-client.js` in your project.

## Frontend Usage Example (Chat)

```typescript
// src/components/ChatView.tsx
import { useState, useEffect, useRef } from 'react';
import { connect, subscribe, on, send } from '@/api/realtime-client.js';

export function ChatView() {
    const [messages, setMessages] = useState<Array<{ userId: string; text: string }>>([]);
    const [input, setInput] = useState('');
    const initialized = useRef(false);

    useEffect(() => {
        if (initialized.current) return;
        initialized.current = true;

        // Connect and subscribe
        connect().then(() => {
            subscribe('chat');
            on('chat', 'newMessage', (data) => {
                setMessages(prev => [...prev, data]);
            });
        });
    }, []);

    const sendMessage = () => {
        if (!input.trim()) return;
        send('chat', 'sendMessage', { text: input });
        setInput('');
    };

    return (
        <div className="flex flex-col h-full">
            <div className="flex-1 overflow-y-auto p-4 space-y-2">
                {messages.map((m, idx) => (
                    <div key={idx} className="bg-gray-100 rounded p-2">
                        <span className="font-bold">{m.userId}: </span>
                        <span>{m.text}</span>
                    </div>
                ))}
            </div>
            <div className="p-4 flex gap-2">
                <input
                    className="flex-1 border rounded px-3 py-2"
                    value={input}
                    onChange={e => setInput(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && sendMessage()}
                    placeholder="Type a message..."
                />
                <button className="bg-blue-500 text-white px-4 py-2 rounded" onClick={sendMessage}>
                    Send
                </button>
            </div>
        </div>
    );
}
```

## Handler Signature

```typescript
sdk.onRealtime(channelName, async (ctx, message) => { ... });
```

- **ctx** — Same context object as regular handlers: `ctx.db`, `ctx.user`,
    `ctx.session`, `ctx.metrics`, `ctx.logs`, `ctx.realtime`
- **message** — `{ channel, event, data, user }`
  - `channel`: the channel name (matches what you registered)
  - `event`: the event name sent by the browser
  - `data`: the payload object sent by the browser
  - `user`: `{ id, sessionId }` — the authenticated sender

## Additional Examples

### Presence heartbeat channel

```typescript
sdk.onRealtime('presence', async (ctx, message) => {
    const { event, user } = message;
    if (event !== 'heartbeat') {
        return;
    }

    await ctx.db.collection('presence').updateOne(
        { userId: user.id },
        { $set: { lastSeenAt: new Date().toISOString() } },
        { upsert: true }
    );

    await ctx.realtime.sendToUser('presence', user.id, 'heartbeatAck', {
        receivedAt: new Date().toISOString()
    });
});
```

### Selective fanout to per-entity subscribers

```typescript
export async function publishRoomUpdate(ctx, { roomId, patch }) {
    const channel = `entity:${roomId}`;
    await ctx.realtime.broadcast(channel, 'roomUpdated', {
        roomId,
        patch,
        emittedAt: Date.now()
    });

    return { published: true, channel };
}
```

### RBAC-gated channel publish with metrics

```typescript
sdk.onRealtime('ops-admin', async (ctx, message) => {
    const { event, user, data } = message;
    if (event !== 'publishOpsNotice') {
        return;
    }

    const resource = 'channels:ops-admin'; // project-relative; the platform scopes it automatically

    await ctx.permissions.require({
        subjectId: user.id,
        action: 'write:ops_notice',
        resource,
        message: 'You do not have permission to publish ops notices.'
    });

    await ctx.metrics.track('realtime_ops_notice_received', {
        channel: 'ops-admin',
        senderUserId: user.id
    });

    await ctx.realtime.broadcast('ops-admin', 'opsNotice', {
        text: typeof data?.text === 'string' ? data.text : '',
        senderUserId: user.id,
        sentAt: new Date().toISOString()
    });

    await ctx.metrics.track('realtime_ops_notice_broadcast', {
        channel: 'ops-admin',
        senderUserId: user.id
    });
});
```

## Best Practices

1. **One handler per channel** — Register one `sdk.onRealtime` per channel,
   use `event` to distinguish message types within the handler.
2. **Validate input** — Always validate `message.data` before processing.
3. **Keep broadcasts small** — Send only what changed, not the entire state.
4. **Auth check** — Use `message.user.id` to verify the sender. The user
   context is injected by the system and cannot be spoofed by the client.

## Realtime Implementation Classification

When addressing realtime/multiplayer/WebSocket design or queries, explicitly classify the implementation surface:
1. **Event-channel realtime:** `ctx.realtime` + `sdk.onRealtime(...)` + `api/realtime-client.js` (WebSockets) or `api/sse-client.js` (Server-Sent Events).
2. **Browser peer-to-peer setup:** `ctx.p2p` + `api/p2p-client.js` + WebRTC offer/answer/ICE signaling on `__p2p__:<sessionId>` channels.
