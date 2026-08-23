# Message Queue API - ctx.queue

Use `ctx.queue` to offload work asynchronously from request handlers.

Platform behavior:
- `ctx.queue.enqueue(...)` stores the message, then publishes it to RabbitMQ.
- The runtime invokes your target handler route in the isolate.
- Handler output controls acknowledgement (`ack`) vs requeue (`nack`).
- Retry attempts are bounded by `maxRetries` and terminal failures move to dead-letter status.
- Queue operations emit analytics metrics under event type `queue_usage`.

## Methods

### 1) Enqueue Message

```typescript
const queued = await ctx.queue.enqueue({
  queueName: 'email.deliveries',
  handlerRoute: 'handlers/queue_handlers.processEmailDelivery',
  payload: {
    to: 'owner@example.com',
    subject: 'Welcome',
    body: 'Thanks for joining.'
  },
  metadata: {
    source: 'signup-flow'
  },
  maxRetries: 3,
  retryDelayMs: 5000
});
```

Required fields:
- `queueName`: logical queue name for grouping and analytics.
- `handlerRoute`: backend route to execute for this message.
- `payload`: JSON-serializable payload for the handler.

Optional fields:
- `metadata`: JSON-serializable metadata map.
- `maxRetries`: integer `0..10` (default `3`).
- `retryDelayMs`: integer `1000..900000` (default `5000`).

Response shape:

```typescript
{
  messageId: string,
  status: 'QUEUED',
  queuedAt: string
}
```

### 2) Alias

```typescript
const queued = await ctx.queue.send({
  queueName: 'media.transforms',
  handlerRoute: 'handlers/queue_handlers.processTransform',
  payload: { assetId: 'asset_123' }
});
```

`send(...)` is an alias of `enqueue(...)`.

### 3) Handler Disposition Helpers

Inside a queue handler, return `ctx.queue.ack(...)` or `ctx.queue.nack(...)` to control disposition.

```typescript
export async function processEmailDelivery(ctx: any, message: any): Promise<any> {
  const payload = message.payload || {};

  if (!payload.to) {
    // Retry not useful -> dead-letter now.
    return ctx.queue.nack({
      requeue: false,
      reason: 'missing_recipient'
    });
  }

  try {
    await ctx.email.send({
      to: payload.to,
      subject: payload.subject,
      body: payload.body
    });

    return ctx.queue.ack({
      delivered: true,
      provider: 'email'
    });
  } catch (error) {
    // Transient failure -> retry with delay.
    return ctx.queue.nack({
      requeue: true,
      reason: 'email_provider_error',
      retryDelayMs: 30000
    });
  }
}
```

`ctx.queue.ack(result?)`:
- Marks message successful.
- Optional `result` is recorded in logs and returned as handler result context.

`ctx.queue.nack(options?)`:
- Requests no-ack behavior.
- `requeue` (default `true`) controls retry vs terminal dead-letter.
- `retryDelayMs` optionally overrides next retry delay.
- `reason` is stored in message failure state.

## Queue Handler Message Shape

When your `handlerRoute` is invoked, the payload has this shape:

```typescript
{
  messageId: string,
  projectId: string,
  branchId: string,
  environment: string,
  dataScope: string,
  queueName: string,
  attempt: number,
  maxRetries: number,
  payload: any,
  metadata: Record<string, any>,
  enqueuedAt: string
}
```

## Dead-Letter Behavior

A message reaches dead-letter status when:
- handler returns `ctx.queue.nack({ requeue: false, ... })`, or
- retries exceed `maxRetries`, or
- queue publish/retry publish fails terminally.

Dead-lettered messages are persisted with status `DEAD_LETTER` and reason metadata.

## Analytics Events

Queue integration emits metrics with `eventType = queue_usage`:
- `queue_message_enqueued`
- `queue_message_acked`
- `queue_message_nacked`
- `queue_message_retried`
- `queue_message_dead_lettered`

Use the project Analytics tab and select event type `queue_usage` to chart queue usage by event name.
