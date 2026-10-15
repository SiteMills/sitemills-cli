# Web Push API — ctx.push

The backend runtime exposes `ctx.push` so your website can send optional,
permission-based browser notifications to its own users and guests — including
when the site is in the background or closed.

Web Push is separate from realtime updates. Live WebSocket updates work
independently of notification permission; use `ctx.realtime.notify` for private
in-page invalidations and `ctx.push` for optional background notifications.

> Web Push must be enabled for your project before use. Until it is enabled,
> `ctx.push.status()` returns `{ enabled: false, publicKey: null }`,
> `subscribe` throws, and `send` returns `{ delivered: 0, enabled: false }`.
> Deploy handlers through the normal SiteMills project/CLI flow; no extra SDK
> installation is needed.

## Methods

```typescript
await ctx.push.status();                 // { enabled, publicKey }
await ctx.push.subscribe({ endpoint, keys: { p256dh, auth }, categories: ['messages'] }); // { subscribed: true }
await ctx.push.unsubscribe(endpoint);    // { subscribed: false }
await ctx.push.send({ recipient: 'user:' + verifiedUserId, category: 'messages', path: '/#workspace' });
// { delivered, failed, enabled }
```

### status()
Returns whether push is enabled for the project and the VAPID `publicKey` the
browser needs for `pushManager.subscribe(...)`.

### subscribe({ endpoint, keys, categories })
Registers the current browser subscription for the **calling** identity.
- Subscription ownership comes from the runtime identity (`ctx.userId` for
  signed-in users, otherwise the verified guest `ctx.visitor.id`), never from
  payload fields. A verified visitor or signed-in user is required.
- `categories` must include at least one supported category. Categories opt in
  per subscription.
- Each identity can register up to ten devices.
- A browser subscription already registered to another identity must be
  unsubscribed before registering it under a different account.
- Only standard browser push services (Google, Mozilla and Apple) are accepted
  as endpoints.

### unsubscribe(endpoint)
Removes the calling identity's subscription for that endpoint.

### send({ recipient, category, path? })
Delivers a notification to every subscribed device of the recipient that opted
in to `category`.
- `recipient` is `user:<verified runtime user id>` or `guest:<verified visitor id>`.
  Resolve it from your own authorized server records.
- `path` is an optional same-site relative path (must start with a single `/`,
  max 1000 characters). Defaults to `/#workspace`.
- Notifications use a generic lock-screen message (title "New website update",
  body "Open your workspace to view it.") plus your `path` and `category`; your
  message content is never placed on the lock screen.
- Delivery has a five-second timeout and a five-minute TTL. Expired
  subscriptions (404/410 from the push service) are removed automatically.

## Supported categories

`messages`, `stages`, `proposals`, `payments`.

Your application must wire each category it advertises to an actual `send`
call for that event type.

## Frontend flow

The frontend must ask for browser permission only after a user action, register
a service worker, submit its subscription through your own backend handler,
offer an unsubscribe option, and open only same-origin notification destinations.

```typescript
// Run from a click handler, e.g. "Enable notifications"
const { enabled, publicKey } = await getPushStatus();  // your handler returning ctx.push.status()
if (!enabled) return;

const permission = await Notification.requestPermission();
if (permission !== 'granted') return;

const registration = await navigator.serviceWorker.register('/sw.js');
const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(publicKey)
});
const { endpoint, keys } = subscription.toJSON();
await savePushSubscription({ endpoint, keys, categories: ['messages'] }); // your handler calling ctx.push.subscribe
```

```javascript
// Service worker: show the notification and open the in-site path on click
self.addEventListener('push', (event) => {
    const data = event.data ? event.data.json() : {};
    event.waitUntil(self.registration.showNotification(data.title, {
        body: data.body,
        data: { path: data.path }
    }));
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const target = new URL(event.notification.data?.path || '/', self.location.origin);
    event.waitUntil(clients.openWindow(target.href));
});
```

Background delivery depends on browser/OS support, installation requirements
(for example, installed web apps on some mobile platforms) and user permission;
it is not guaranteed.

## Security rules

- Application handlers must authorize who can trigger a notification. Never
  expose a handler that forwards arbitrary browser payloads to `ctx.push.send`.
- Always derive `recipient` from authorized server-side records.
- When a user signs out or switches accounts, unsubscribe the browser
  subscription before registering it under another identity.

## Testing

Test on a non-production environment first. Verify that two different browsers
or a guest and a signed-in user receive only their own notifications, that
opt-out works, and that real phone/browser delivery succeeds before advertising
the feature to your users.

Reference: [web-push library API](https://github.com/web-push-libs/web-push).
