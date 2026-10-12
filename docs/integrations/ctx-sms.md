# SMS API — Outbound SMS, Texting & Phone Verification

The backend runtime exposes `ctx.sms` so handlers (`server/handlers/*.ts`) can send outbound SMS text messages, customer texting notifications, phone verification codes (OTP / 2FA), and transactional mobile alerts.

Outbound messages are sent through the platform's toll-free business line (**`1-866-MILLS-02`** / `+1-866-645-5702`) by default, or an optional custom sender number configured for your project.

## Capabilities

- **Outbound Texting**: Send instant transactional SMS messages, order updates, customer notifications, and booking reminders.
- **Phone Verification (OTP / 2FA)**: Issue security verification codes and one-time passwords via SMS text.
- **Delivery & Response Callbacks**: Track message delivery receipts and receive status notifications via an optional `callbackUrl`.
- **Pre-Configured Toll-Free Sender**: Outbound messaging is backed by SiteMills's verified toll-free number (`1-866-MILLS-02`).

---

## Methods

### 1) Send SMS (object form)

```typescript
await ctx.sms.send({
    to: '+15551234567',
    body: 'Your verification code is 123456'
});
```

#### Options

| Option | Type | Required | Description |
|---|---|:---:|---|
| `to` | `string` | **Yes** | Recipient phone number in standard E.164 format (e.g. `+15551234567`) or standard 10-digit format. |
| `body` | `string` | **Yes** | Text message content (aliases: `message`, `text`). |
| `from` | `string` | No | Optional custom sender phone number or Alphanumeric Sender ID if configured. Defaults to the platform sender (`+1-866-645-5702`). |
| `callbackUrl` | `string` | No | Optional webhook URL to receive delivery status receipts (`delivered`, `undelivered`, `failed`) and responses. |

### 2) Send SMS (positional form)

```typescript
await ctx.sms.send(
    '+15551234567',
    'Your verification code is 123456'
);
```

Positional arguments map directly to `{ to, body }`.

---

## Return Shape

Typical success response:

```typescript
{
    sent: true,
    provider: 'sms',
    to: '+15551234567',
    sid: 'SM1234567890abcdef1234567890abcdef',
    response: {
        status: 'queued',
        sid: 'SM1234567890abcdef1234567890abcdef'
    }
}
```

---

## Example Handlers

### 1. One-Time Passcode (OTP / 2FA) Verification

```typescript
export async function sendOtp(ctx, { phoneNumber }) {
    if (!phoneNumber) {
        throw new Error('phoneNumber is required');
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();

    await ctx.sms.send({
        to: phoneNumber,
        body: `Your security code is ${code}. Valid for 10 minutes.`
    });

    await ctx.db.collection('otps').insertOne({
        phoneNumber,
        code,
        createdAt: new Date().toISOString()
    });

    return { success: true };
}
```

### 2. Transactional Notification with Delivery Callback

```typescript
export async function notifyOrderStatus(ctx, { phoneNumber, orderId, statusText }) {
    const result = await ctx.sms.send({
        to: phoneNumber,
        body: `Order #${orderId}: ${statusText}`,
        callbackUrl: 'https://my-app.sitemills.com/api/v1/sms-status'
    });

    await ctx.db.collection('sms_audit').insertOne({
        phoneNumber,
        orderId,
        sid: result?.sid,
        sentAt: new Date().toISOString()
    });

    return { sent: !!result?.sent };
}
```

---

## Best Practices & Constraints

- **Phone Number Normalization**: Always pass recipient phone numbers in standard E.164 format (`+1...`). Numbers are automatically validated and normalized before dispatch.
- **Message Length**: Keep SMS messages under 160 characters when possible to fit within a single message segment. Longer messages will be concatenated.
- **Background Dispatching**: For mass messaging or scheduled customer reminders, dispatch from background jobs (`server/jobs.ts`) to avoid blocking synchronous user HTTP requests.
- **Audit Logging**: Store outbound message SIDs in database collections (`ctx.db`) to correlate delivery status callbacks with application records.
- **Never Hardcode Secrets**: Access configuration or custom sender IDs via `ctx.env` rather than hardcoding in client code.
