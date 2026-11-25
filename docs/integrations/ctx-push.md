# Website-scoped Web Push

Backend handlers use `ctx.push` to send notifications to the browsers and installed web apps of a project's verified users and guests. It is separate from the notifications SiteMills itself sends, and subscriptions are stored per project and environment.

Deploy handlers through the normal SiteMills project/CLI flow; no custom CLI command or SDK installation is needed. Push works only in projects SiteMills has enabled it for: elsewhere `ctx.push.status()` returns `enabled: false`, and the user needs to ask SiteMills support to enable it. Realtime WebSocket updates work independently of push permission; use `ctx.realtime.notify` for private invalidations and push for optional background notifications.

```ts
await ctx.push.status(); // { enabled, publicKey }
await ctx.push.subscribe({ endpoint, keys: { p256dh, auth }, categories: ['messages'] });
await ctx.push.unsubscribe(endpoint);
await ctx.push.send({ recipient: 'user:' + verifiedUserId, category: 'messages', path: '/#workspace' });
```

Recipients are `user:<verified runtime id>` or `guest:<verified visitor id>`. Subscription ownership comes from runtime identity, never payload fields. Application handlers must authorize who can send a notification; never expose unrestricted `push.send` forwarding to browser payloads. Account switching requires unsubscribing the former browser subscription before registering under another identity.

Supported categories: `messages`, `stages`, `proposals`, `payments`. Categories opt in per subscription. The application must wire each advertised event type to delivery. In a project that is enabled but not yet fully set up by SiteMills, `ctx.push` calls throw a configuration error.

Subscriptions are scoped by project and runtime data scope, with up to ten devices per identity. Endpoints are limited to the supported Google, Mozilla and Apple push hosts to prevent arbitrary outbound requests. Delivery has a five-second timeout and five-minute TTL. Expired (404/410) subscriptions are removed. Delivery results report delivered/failed counts; provider errors never log endpoint credentials. Notifications use a generic lock-screen message, not the customer's chat text.

The frontend must ask browser permission only following a user action, register a service worker, submit its subscription, offer unsubscribe, and open only same-origin notification destinations. Background delivery depends on browser/OS support, installation requirements and permissions; it is not guaranteed.
