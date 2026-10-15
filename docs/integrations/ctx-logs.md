# Runtime Logging — ctx.logs

Logging is available to backend handlers without a separate provider account.
Use **Project → Logging** in the SiteMills dashboard to inspect runtime messages
for the intended environment.

## Methods

```typescript
ctx.logs.log('Handler started');
ctx.logs.info('Order accepted', { orderId });
ctx.logs.warn('Inventory low', { sku, remaining });
ctx.logs.error('Order failed', { orderId, reason: 'Payment declined' });
```

`console.log`, `console.warn` and `console.error` also produce runtime logs.

## Behavior

- Logging is fire-and-forget: the methods return immediately and never throw,
  so a logging problem cannot fail your handler.
- Logging has no credit cost.
- Retention is up to one hour; logs are not a durable audit trail. Persist
  anything you need long-term in your own database.

## Recommended usage

- Use short messages and safe identifiers (order IDs, record IDs).
- Never log credentials, payment details, raw request bodies or unnecessary
  personal data.

## Testing

Invoke a handler with a harmless test message and find it in Logging. If it is
missing, confirm the environment, that the latest code is published, and the
time window before retrying. Do not repeat real payments or other side effects
merely to create a log entry.
