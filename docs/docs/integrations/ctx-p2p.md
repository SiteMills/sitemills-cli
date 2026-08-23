# ctx.p2p - Peer-to-Peer Session Setup API

`ctx.p2p` provides backend helpers for authenticated WebRTC setup.
Media and data flow directly between browsers, while SiteMills handles:
- TURN/STUN credential issuance
- signaling channel naming
- authentication gate enforcement

## Choose the correct surface first

Use `ctx.p2p` when your use case is direct browser-to-browser media/data.

Do not use `ctx.p2p` for:
- server-authoritative multiplayer state loops (`contracts/*.json` with `"type": "room"`, backend room lifecycle, `api/room-client.js`)
- generic server-routed notifications/live feeds (`ctx.realtime` with `sdk.onRealtime(...)` and `api/realtime-client.js`)

## Phase-1 guarantees

- Authenticated users only
- Mesh topology only
- Maximum 4 participants per session
- TURN credentials are managed by SiteMills and issued per request

## ctx.p2p methods

### getIceServers(options?)
Request TURN/STUN credentials and ICE server config.

```typescript
const ice = await ctx.p2p.getIceServers({ ttlSeconds: 900 });

// shape:
// {
//   iceServers: [{ urls: string[], username: string, credential: string }],
//   expiresAtEpochSeconds: number,
//   ttlSeconds: number,
//   topology: 'mesh',
//   maxParticipants: 4,
//   authenticatedOnly: true
// }
```

Options:
- `ttlSeconds` (optional): requested credential ttl in seconds

Behavior:
- Throws when called without an authenticated user context
- Throws if `ttlSeconds` exceeds configured limits

### getMeshConfig()
Return canonical mesh constraints for this runtime.

```typescript
const mesh = await ctx.p2p.getMeshConfig();
// { topology: 'mesh', maxParticipants: 4, authenticatedOnly: true }
```

### getSignalingChannel(sessionId)
Build canonical signaling channel name for a p2p session.

```typescript
const channel = await ctx.p2p.getSignalingChannel('room_abc123');
// '__p2p__:room_abc123'
```

## Backend integration pattern (distributed-safe)

Avoid in-memory session maps in handlers. Requests can land on different nodes.
Persist any shared session metadata in `ctx.db` by deterministic key.

```typescript
const SESSION_PREFIX = '__p2p_session_v1:';

function toSessionKey(sessionId: string) {
	return SESSION_PREFIX + sessionId;
}

export async function createSession(ctx, { sessionId, topic, ttlSeconds }) {
	if (!ctx.user?.id) {
		throw new Error('Authentication required for p2p session setup.');
	}

	const normalizedId = String(sessionId || '').trim();
	if (!normalizedId) {
		throw new Error('sessionId is required');
	}

	const existing = await ctx.db.collection('p2p_sessions').findOne({
		_id: toSessionKey(normalizedId)
	});

	const sessionRecord = existing || {
		_id: toSessionKey(normalizedId),
		sessionId: normalizedId,
		topic: String(topic || '').trim() || null,
		createdBy: ctx.user.id,
		createdAt: new Date().toISOString()
	};

	if (!existing) {
		await ctx.db.collection('p2p_sessions').insertOne(sessionRecord);
	}

	const [ice, mesh, channel] = await Promise.all([
		ctx.p2p.getIceServers(
			Number.isInteger(ttlSeconds) ? { ttlSeconds } : undefined
		),
		ctx.p2p.getMeshConfig(),
		ctx.p2p.getSignalingChannel(normalizedId)
	]);

	return {
		session: sessionRecord,
		bootstrap: {
			channel,
			topology: mesh,
			ice
		}
	};
}
```

Recommended backend routes for most apps:
- `createSession`
- `joinSession`
- `getSession`
- `renewIce`
- `getCurrentUser` (for frontend auth-state verification)

## Frontend pairing and lifecycle

Use `api/p2p-client.js` with `api/realtime-client.js`.

Recommended 1:1 call flow:
1. Ensure user is authenticated (login flow + refresh current user state)
2. Create/join session via backend route
3. `createP2PSession({ sessionId })`
4. `session.requestIceServers()` and build `RTCPeerConnection`
5. Attach local tracks on both peers (`attachLocalMedia`) before offer/answer
6. Exchange `offer`, `answer`, and `ice-candidate` via `session.sendSignal(...)`
7. Render remote tracks and handle autoplay policy (muted video or user gesture)
8. On cleanup, close peer connection, local tracks, and `session.close()`

## Signaling payload conventions

`api/p2p-client.js` sends this envelope over realtime:

```typescript
{
	payload: any,
	sentAt: string,
	targetUserId?: string
}
```

Common pattern:

```typescript
session.sendSignal('offer', { sdp: offer }, targetUserId);

session.onSignal(({ event, data }) => {
	const payload = data?.payload || {};
	if (event === 'offer') {
		// payload.sdp
	}
	if (event === 'answer') {
		// payload.sdp
	}
	if (event === 'ice-candidate') {
		// payload.candidate
	}
});
```

## Common failure modes

- Login appears successful but p2p setup still fails:
	backend route is missing auth-state visibility (`getCurrentUser`) or frontend did not refresh auth state after OAuth tab return.
- Remote video never appears:
	one side answered without local tracks; ensure both peers start local media.
- Remote element remains blank despite successful signaling:
	browser autoplay blocked audio/video playback; start muted or require user interaction before unmute.
- Behavior differs by node/request path:
	session metadata was kept in process memory; move all shared state to `ctx.db`.

## Security rules

- Never trust user-provided sender identity; use server-attached user context
- Never expose TURN shared secrets in client-managed config
- Do not bypass participant cap/authentication constraints

## Related docs

- `read_file("docs/ctx-realtime.md")`
- `read_file("api/p2p-client.js")`
- `read_file("public/api/p2p-client.js")`
- `read_file("api/realtime-client.js")`
