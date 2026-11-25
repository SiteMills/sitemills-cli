# Runtime logging

Logging is available to backend handlers without a separate provider account.
Use Project → Logging to inspect runtime messages for the intended environment.

```ts
ctx.logs.info('Order accepted', { orderId });
ctx.logs.error('Order failed', { orderId, reason: 'Payment declined' });
```

`console.log`, `console.warn` and `console.error` also produce runtime logs.
Logging is fire-and-forget and has no credit cost. Retention is up to one hour;
logs are not a durable audit trail. Never log credentials, payment details, raw
request bodies or unnecessary personal data. Use short messages and safe IDs.

To test, invoke a handler with a harmless test message and find it in Logging.
If it is missing, confirm the environment, publication and time window before
retrying. Do not repeat real payments or other side effects merely to create a log.
