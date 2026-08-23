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
Browser ←→ WebSocket (chatservice) ←→ RabbitMQ ←→ Isolate handlers
```

- Browsers connect via a lightweight WebSocket client library
- Server handlers receive messages and can broadcast back
- Messages are scoped per channel (e.g. 'chat', 'game', 'dashboard')

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

## Frontend: Connecting to Realtime

The frontend uses the pre-built `api/realtime-client.js` framework file.
This file is automatically available in every project — do NOT create or overwrite it.
Just import from it:

```typescript
import { connect, subscribe, on, send, disconnect } from '../api/realtime-client.js';

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

For full API reference: `read_file("api/realtime-client.js")`

## Frontend Usage Example (Chat)

```typescript
// public/views/chat-view.tsx
import { render } from 'https://esm.sh/preact@10.23.1';
import { useState, useEffect, useRef } from 'https://esm.sh/preact@10.23.1/hooks';
import { connect, subscribe, on, send } from '../api/realtime-client.js';

function ChatView() {
    const [messages, setMessages] = useState([]);
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
        <div class="flex flex-col h-full">
            <div class="flex-1 overflow-y-auto p-4 space-y-2">
                {messages.map(m => (
                    <div class="bg-gray-100 rounded p-2">
                        <span class="font-bold">{m.userId}: </span>
                        <span>{m.text}</span>
                    </div>
                ))}
            </div>
            <div class="p-4 flex gap-2">
                <input
                    class="flex-1 border rounded px-3 py-2"
                    value={input}
                    onInput={e => setInput(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && sendMessage()}
                    placeholder="Type a message..."
                />
                <button class="bg-blue-500 text-white px-4 py-2 rounded" onClick={sendMessage}>
                    Send
                </button>
            </div>
        </div>
    );
}

render(<ChatView />, document.getElementById('app'));
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

    const resource = 'sitemills:projects:project-1:channels:ops-admin';

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
1. **Event-channel realtime:** `ctx.realtime` + `sdk.onRealtime(...)` + `api/realtime-client.js`.
2. **Browser peer-to-peer setup:** `ctx.p2p` + `api/p2p-client.js` + WebRTC offer/answer/ICE signaling on `__p2p__:<sessionId>` channels.
