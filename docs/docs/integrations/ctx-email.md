# Email API — Outbound Transactional Email via communicationservice

The backend runtime exposes `ctx.email` so handlers can send outbound emails.

Transport path:
- `ctx.email.send(...)` in isolate handler
- routed through clientisolates EmailIntegration
- forwarded to communicationservice `POST /api/email/send`
- communicationservice sends via configured Gmail OAuth credentials

## Methods

### 1) Send Email (object form)

```typescript
await ctx.email.send({
    to: 'customer@example.com',
    subject: 'Welcome to SiteMills',
    body: '<p>Your account is ready.</p>'
});
```

Required fields:
- `to` — recipient email string, comma-delimited string, or string array
- `subject` — non-empty string
- One of: `body`, `html`, or `text`

### 2) Send Email (positional form)

```typescript
await ctx.email.send(
    'customer@example.com',
    'Welcome to SiteMills',
    '<p>Your account is ready.</p>'
);
```

Positional args map to `{ to, subject, body }`.

## Return Shape

Typical success response:

```typescript
{
    sent: true,
    provider: 'communicationservice',
    to: 'customer@example.com',
    subject: 'Welcome to SiteMills',
    response: { status: 'Sent' }
}
```

## Example Handler

```typescript
export async function sendContactReceipt(ctx, { email, name, message }) {
    if (!email || !name || !message) {
        throw new Error('email, name, and message are required');
    }

    await ctx.email.send({
        to: email,
        subject: `Thanks for contacting us, ${name}`,
        body: `<p>We received your message:</p><blockquote>${message}</blockquote>`
    });

    return { sent: true };
}
```

## Additional Examples

### Multi-recipient notify + audit record

```typescript
export async function notifyOps(ctx, { subject, htmlBody }) {
    const recipients = ['ops@example.com', 'alerts@example.com'];

    const result = await ctx.email.send({
        to: recipients,
        subject,
        html: htmlBody
    });

    await ctx.db.collection('email_audit').insertOne({
        type: 'ops_notification',
        to: recipients,
        subject,
        sent: !!result?.sent,
        sentAt: new Date().toISOString()
    });

    return { sent: !!result?.sent };
}
```

### Plain-text fallback content

```typescript
await ctx.email.send({
    to: 'user@example.com',
    subject: 'Password reset requested',
    text: 'Use this link to reset your password: https://example.com/reset?token=...'
});
```

## Constraints and Notes

- Attachment support is not currently exposed via `ctx.email`.
- Content is sent as HTML-compatible body text to communicationservice.
- Recipient emails are validated at runtime; invalid emails throw before the request is sent.

## Recommended Usage

- Use for transactional flows: receipts, confirmations, invitations, resets, notifications.
- Keep email side effects in backend handlers, not frontend code.
- For scheduled or batched campaigns, trigger from jobs (`docs/ctx-jobs.md`) instead of request handlers.
- Avoid hardcoding sensitive recipient lists; use project configuration or data records.

## Failure Modes

- Missing required fields (`to`, `subject`, content) → handler throws validation error.
- Invalid recipient format → handler throws validation error.
- communicationservice auth/config mismatch → request fails and error propagates.
- communicationservice delivery failure → request fails with upstream error details.
