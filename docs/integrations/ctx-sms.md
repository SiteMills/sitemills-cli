# SMS API — Verification Codes, Appointment Reminders & Order Updates

The backend runtime exposes `ctx.sms` so handlers (`server/handlers/*.ts`) and jobs can text customers. Messages come from the platform's toll-free number (**`1-866-MILLS-02`** / `+1-866-645-5702`).

**SMS is template-based and one-way.** The platform writes every message, and handlers choose a template and pass in its values. Free-form text (`body`, `message`, `text`), custom senders (`from`) and callback URLs are rejected with an error. Recipients' replies are **not** delivered to your project, so never ask recipients to "reply YES" or to text back. The platform handles the standard STOP/HELP keywords.

## Capabilities

- **Verification codes (OTP / 2FA)**: phone sign-in and verification codes.
- **Appointment reminders**: date and time shown in the recipient's time zone.
- **Order updates**: confirmed, shipped, out for delivery, delivered, ready for pickup, cancelled.
- **Activity alerts**: a fixed "something happened, sign in to see it" notice (new match, result posted, schedule changed, action needed).
- **US and Canada only**: recipients must be `+1` numbers.

If a feature needs anything other than these four message types (marketing, custom wording, links, two-way chat), SMS cannot do it. Tell the user so, and suggest `ctx.email` for free-form messages.

---

## Method

```typescript
await ctx.sms.send({
    to: '+15551234567',
    template: 'verification_code',
    brand: 'Acme Dental',
    params: { code: '482913', expiresInMinutes: 10 }
});
```

| Option | Type | Required | Description |
|---|---|:---:|---|
| `to` | `string` | **Yes** | US/Canada number, E.164 (`+15551234567`) or 10/11 digits. |
| `template` | `string` | **Yes** | `verification_code`, `appointment_reminder`, `order_update` or `activity_alert`. |
| `brand` | `string` | **Yes** | Business name that starts the message. 2–30 characters: letters, digits, spaces and `& ' . -`. Web addresses are rejected. |
| `params` | `object` | **Yes** | Values for the template (below). Unknown keys are rejected. |

## Templates

### `verification_code`

| Param | Type | Required | Rule |
|---|---|:---:|---|
| `code` | `string` | **Yes** | 4–8 digits. Pass it as a string so leading zeros are kept. |
| `expiresInMinutes` | `number` | No | Whole number from 1 to 60. |

> `Acme Dental: Your verification code is 482913. It expires in 10 minutes. Do not share this code.`

### `appointment_reminder`

| Param | Type | Required | Rule |
|---|---|:---:|---|
| `startsAt` | `string` | **Yes** | ISO 8601 timestamp with an offset, e.g. `2026-10-14T19:30:00Z`. |
| `timeZone` | `string` | **Yes** | IANA time zone the time is shown in, e.g. `America/New_York`. |

> `Acme Dental: Reminder of your appointment on Wed, Oct 14 at 3:30 PM. Reply STOP to opt out.`

### `order_update`

| Param | Type | Required | Rule |
|---|---|:---:|---|
| `orderNumber` | `string` | **Yes** | 1–20 letters, digits or hyphens. |
| `status` | `string` | **Yes** | `confirmed`, `shipped`, `out_for_delivery`, `delivered`, `ready_for_pickup` or `cancelled`. |

> `Acme: Order #A-1001 is out for delivery. Reply STOP to opt out.`

### `activity_alert`

| Param | Type | Required | Rule |
|---|---|:---:|---|
| `type` | `string` | **Yes** | `match_scheduled`, `match_ready`, `result_posted`, `schedule_updated` or `action_required`. |

> `DH Pickleball: A new match has been scheduled for you. Sign in to see the details. Reply STOP to opt out.`

Alerts carry no details (names, times, links). Put the details in the app and use the alert to bring the user back.

Invalid values throw an `Error` that explains the rule, e.g. `SMS could not be sent: verification_code 'code' must be 4-8 digits.`

---

## Environments

Real texts are sent only from the **PROD** environment. In DEV, STAGING and on the Working Draft the send is simulated: it succeeds, nothing is delivered, and the result has `isSimulated: true` with the exact `body` that would have been sent.

## Return Shape

```typescript
{
    sent: true,
    provider: 'sms',
    to: '+15551234567',
    template: 'verification_code',
    body: 'Acme Dental: Your verification code is 482913. It expires in 10 minutes. Do not share this code.',
    sid: 'SM1234567890abcdef1234567890abcdef',
    isSimulated: false,
    response: { status: 'queued', sid: 'SM1234567890abcdef1234567890abcdef' }
}
```

Failures throw `Error('SMS could not be sent: <reason>')`, for example when the recipient has opted out (replied STOP), the number is invalid, or the service is rate limited.

---

## Example Handlers

### 1. Send and check a verification code

```typescript
export async function sendPhoneCode(ctx, { phoneNumber }) {
    if (!phoneNumber) throw new Error('phoneNumber is required');

    // Limit sends per number: public code endpoints are a target for SMS-pumping fraud.
    const since = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const recent = await ctx.db.collection('phone_codes').count({ phoneNumber, createdAt: { $gte: since } });
    if (recent >= 3) throw new Error('Too many codes requested. Try again in 10 minutes.');

    const code = Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
    await ctx.sms.send({
        to: phoneNumber,
        template: 'verification_code',
        brand: 'Acme Dental',
        params: { code, expiresInMinutes: 10 }
    });

    await ctx.db.collection('phone_codes').insertOne({ phoneNumber, code, createdAt: new Date().toISOString() });
    return { sent: true };
}
```

Store codes server-side and compare them in a separate handler. Never return the code to the browser.

### 2. Order status notification

```typescript
export async function notifyOrderShipped(ctx, { phoneNumber, orderNumber }) {
    const result = await ctx.sms.send({
        to: phoneNumber,
        template: 'order_update',
        brand: 'Acme Outfitters',
        params: { orderNumber, status: 'shipped' }
    });

    await ctx.db.collection('sms_audit').insertOne({
        phoneNumber,
        orderNumber,
        sid: result.sid,
        sentAt: new Date().toISOString()
    });

    return { sent: result.sent };
}
```

---

## Best Practices & Constraints

- **Consent**: only text people who gave your site their number for this purpose, e.g. a checkbox when they book or check out.
- **Rate limit public triggers**: any handler a visitor can call to send a text needs per-number and per-visitor limits, as in example 1.
- **Background sending**: send reminders from jobs (`server/jobs.ts`) rather than inside page requests.
- **Brand**: use the site's real business name consistently. Carriers filter messages whose brand changes or impersonates another business.
