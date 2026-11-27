# Hosted Checkout & Order Reads (`ctx.orders`)

Part of `docs/ctx-orders.md`. Covers `ctx.orders.checkout`, `ctx.orders.expireCheckout`, `ctx.orders.getSession`, and `ctx.orders.getOrder`.

## Creating a Checkout Session

Start from this minimal call. Add the optional features below only when the store needs them: each one changes what the buyer sees or asks of the merchant's Stripe account.

```typescript
const checkout = await ctx.orders.checkout({
    mode: 'payment', // or 'subscription'
    successUrl: '/checkout/success?session_id={CHECKOUT_SESSION_ID}',
    cancelUrl: '/checkout/cancel',
    customerEmail: ctx.user?.email,
    metadata: { orderId: 'order-123' },
    lineItems: [
        {
            name: 'Weighted Blanket',
            unitAmount: 89.00, // major currency units (89.00 = $89.00)
            currency: 'usd',
            quantity: 1
        }
    ]
});

// Alias:
const checkout2 = await ctx.orders.createCheckoutSession({ ...samePayload });
```

Returns `{ checkoutSessionId, sessionId, checkoutUrl, orderId, sessionMode, expiresAt }` where `expiresAt` is an ISO-8601 UTC timestamp. Redirect the buyer to `checkoutUrl`.

## Checkout Options & Validation Rules

- **Redirect URLs**: `successUrl` and `cancelUrl` accept relative paths (recommended) or same-origin HTTPS URLs. Cross-origin URLs are rejected.
- **Line Items**:
  - `name` and positive `unitAmount` (in major currency units) are required; Stripe-style `price_data.product_data.name` and minor-unit `price_data.unit_amount` are also accepted using currency-aware minor unit scaling (e.g. zero-decimal `jpy`/`krw`, three-decimal `kwd`/`bhd`).
  - Optional item fields: `description`, `images` (up to 8; each an `http(s)://` URL of at most 2048 characters, or a path on this site such as `/images/mug.png`), `quantity` (default `1`), and `recurringInterval` / `recurringIntervalCount` for subscriptions. `taxCode` (a Stripe tax code such as `txcd_99999999`) and `taxBehavior` only matter with `automaticTax` (see below).
- **Session Expiration (`expiresInMinutes`)**:
  - Optional. Must be an integer from `30` to `1440` (24 hours, the default). Values outside this range fail immediately before calling Stripe.
- **Metadata**:
  - Up to 43 custom keys (leaving 7 reserved platform routing keys); key length max 40 chars, value max 500 chars. Include your own identifiers (`orderId`, `cartId`, `planId`) so the success page can find the site's order record.
- **Platform Fees**:
  - Site code can't set platform fees. Never pass `applicationFeeAmount` or `applicationFeePercent`: a request containing either is rejected.

## Optional Checkout Features

Turn these on one at a time, for stores that need them.

- **Shipping (physical goods only)**:
  - `allowedShippingCountries: ['US', 'CA']` (or `shippingAddressCollection.allowedCountries`) asks for a shipping address in those 2-letter ISO countries. Ask the merchant which countries they ship to.
  - `shippingOptions: [{ displayName, amount, currency, minDeliveryDays, maxDeliveryDays }]` offers up to 5 rates; `amount` is in major currency units (`0` for free shipping). If line items use multiple currencies, `currency` is required on each option.
- **Buyer details**: `phoneNumberCollection: true`, `billingAddressCollection: 'auto' | 'required'`, `taxIdCollection: true` (business buyers' VAT/tax IDs).
- **Custom fields**: up to 3 `customFields: [{ key, label, type: 'text' | 'numeric' | 'dropdown', optional }]`. Each `key` must be unique and alphanumeric (`/^[A-Za-z0-9]+$/`), and each `label` at most 50 characters. A `dropdown` needs 1 to 200 `dropdownOptions: [{ label, value }]` (labels up to 100 characters) with unique alphanumeric `value` strings. Answers come back in `customFields` on the order.
- **Discounts**: `allowPromotionCodes: true` shows a promotion-code box; `promotionCodeId` or `couponId` applies one directly. Use at most one of the three. They only work with promotion codes or coupons that already exist on the merchant's Stripe account; SiteMills can't create them yet, so don't add a code box the merchant can't use.
- **Automatic tax**: `automaticTax: true`, with `taxCode` / `taxBehavior` on line items.
  - It needs Stripe Tax set up on the merchant's connected Stripe account: a head-office address, a default tax code, and tax registrations for the places it collects tax.
  - SiteMills can't set that up for merchants yet. Without it, checkout fails with `stripe_tax_inactive`, or charges no tax where the merchant has no registration.
  - So leave it off and include tax in prices, unless the merchant confirms Stripe Tax is set up.
- **Abandoned-cart recovery (limited for now)**: `enableAbandonedCartRecovery: true` keeps a recovery link for 30 days after the session expires, and asks US buyers for promotional consent. Until connected-account webhook events reach SiteMills, a purchase through the link is recorded only for a card payment completed through the success page: a bank transfer through the link, or a buyer who closes the tab first, stays unrecorded. Once connected-account webhooks are enabled, Stripe's events record those too. See "Abandoned-Cart Recovery" below. Nothing emails the link for you. Only checkouts on the project's own Stripe account, not marketplace sellers' accounts.

## Expiring an Open Checkout Session

```typescript
const expired = await ctx.orders.expireCheckout('cs_test_123');
// Or with options object:
const expired2 = await ctx.orders.expireCheckout({ sessionId: 'cs_test_123' });
```

Returns `{ checkoutSessionId, sessionId, orderId, orderStatus: 'expired', sessionStatus: 'expired', recoveryUrl }` (check `sessionStatus === 'expired'` or `orderStatus === 'expired'`). Use it to release held stock when the buyer empties their cart. Calling it again is safe. If the buyer already paid, it fails with "This checkout was already completed" and the order is recorded as paid: fulfil it instead.

## Reading Checkout Session & Order Receipt Fields

### Post-Checkout Verification (`getSession`)

```typescript
const session = await ctx.orders.getSession('cs_test_123');
// Or getCheckoutSession({ sessionId: 'cs_test_123' })
```

`getSession` reads the session from Stripe and records what it finds on the order: once the buyer has paid, `orderStatus` becomes `'paid'` and the receipt fields are saved. It returns:
- `checkoutSessionId`, `sessionId`, `sessionMode`, `sessionStatus` (`'open' | 'complete' | 'expired'`), `paymentStatus` (`'paid' | 'unpaid' | 'no_payment_required'`), `orderStatus`, `orderId`, `paymentIntentId`
- Monetary breakdown: `amountSubtotal`, `amountTax`, `amountShipping`, `amountDiscount`, `amountTotal`, `currency`, `promoCode`
- Buyer & receipt data: `customerEmail`, `customerName`, `customerPhone`, `shippingDetails`, `customFields` (`Record<string, string> | null`), `marketingConsent` (`'opt_in' | 'opt_out' | null`), `recoveryUrl`, `expiresAt`
- `metadata`, `lineItems`, and nested `order`

### Order Lookup (`getOrder`)

```typescript
const order = await ctx.orders.getOrder('ord_abc123');
// Or:
const sameOrder = await ctx.orders.getOrder({ orderId: 'ord_abc123' });
```

`getOrder` returns the order, scoped to the current project, environment (`DEV` | `STAGING` | `PROD`) and data scope. While the order is still unpaid, it checks the checkout session with Stripe first. So after the buyer pays it reports `status: 'paid'` with the receipt fields filled in, and after the session expires it reports `'expired'`. It returns:
- `orderId`, `projectId`, `branchId`, `scopeId`, `siteEnvironment`, `orderType`, `status`
- `amountSubtotal`, `amountTax`, `amountShipping`, `amountDiscount`, `amountTotal`, `amountRefunded`, `currency`, `promoCode`
- `customerEmail`, `customerName`, `customerPhone`, `shippingDetails` (`{ name, phone, shippingRateId, amountShipping, address: { line1, line2, city, state, postalCode, country } }`)
- `customFields` (`Record<string, string> | null`, e.g. `order.customFields?.giftMessage`), `marketingConsent` (`'opt_in' | 'opt_out' | null`), `recoveryUrl`, `stripeCheckoutSessionId`, `stripePaymentIntentId`, `stripeSubscriptionId`, `items[]`, `createdAt`, `updatedAt`

## Fulfilling Orders (Including Bank Payments and Free Trials)

Fulfil only when the order is paid, and make fulfilment safe to run twice (the buyer can reload the success page). When creating the checkout, save the site's own record first, for example `{ checkoutSessionId: checkout.checkoutSessionId, orderId: checkout.orderId, status: 'PENDING', createdAt, ... }` in `ctx.db`. Find that record by `orderId`, not by session id: a purchase made through an abandoned-cart recovery link has a new `checkoutSessionId` but the same `orderId`.

```typescript
// Does the fulfilment work once per order, however many times it's called.
async function fulfilOnce(ctx, orderId, amountTotal) {
    const result = await ctx.db.collection('orders').updateOne(
        // RECOVERY_SENT: see "Abandoned-Cart Recovery" below.
        { orderId, status: { $in: ['PENDING', 'RECOVERY_SENT'] } },
        { $set: { status: 'PAID', amountTotal, paidAt: new Date().toISOString() } }
    );
    if (result.matchedCount === 1) {
        // send the receipt, grant access, reduce stock...
    }
}

export async function finalizeOrder(ctx, { sessionId }) {
    if (!sessionId) throw new Error('sessionId is required');

    const session = await ctx.orders.getSession(sessionId);
    // 'paid' once Stripe reports the payment, including free trials and 100%-off orders
    // (paymentStatus 'no_payment_required').
    if (session.orderStatus !== 'paid') {
        return { fulfilled: false, reason: session.paymentStatus || 'pending' };
    }

    await fulfilOnce(ctx, session.orderId, session.amountTotal);
    return { fulfilled: true, orderId: session.orderId };
}
```

Bank payments such as US ACH settle days later: right after checkout `sessionStatus` is `'complete'` while `paymentStatus` stays `'unpaid'` and `orderStatus` stays `'pending'`. Don't fulfil until a later `getSession` or `getOrder` reports `'paid'` (a scheduled job that reads pending orders works). Once connected-account webhooks are enabled, the order also becomes `'paid'` on its own when the payment settles, without anything reading it.

## Abandoned-Cart Recovery

With `enableAbandonedCartRecovery: true`, Stripe keeps a recovery link for 30 days after a checkout expires. Once the session has expired, `getOrder` reports `status: 'expired'` with `recoveryUrl`.

**Limited for now.** Until connected-account webhook events reach SiteMills, a purchase made through a recovery link is recorded only for a card payment completed through the success page. A bank transfer through the link, or a buyer who pays and closes the tab before the success page, leaves the original order `'expired'` although the merchant was paid, so the site can't fulfil it. Don't add recovery emails unless the merchant asks for them and accepts this. Once connected-account webhooks are enabled, those purchases are recorded on the original order when Stripe reports them, and the job below then finds them `'paid'`.

Nothing emails the link. If the merchant wants recovery emails, send them yourself, and only to buyers who opted in (`marketingConsent === 'opt_in'`). For example, a daily job (see `docs/ctx-jobs.md`) can go through the site's own pending checkout records:

```typescript
export const jobs = {
    emailAbandonedCheckouts: async (ctx) => {
        const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        const records = await ctx.db.collection('orders').find({ status: 'PENDING', createdAt: { $lt: dayAgo } });
        for (const record of records) {
            const order = await ctx.orders.getOrder(record.orderId);
            if (order.status === 'paid') {
                // Paid after all, but the buyer never came back to the success page.
                await fulfilOnce(ctx, order.orderId, order.amountTotal);
                continue;
            }
            if (order.status !== 'expired') {
                continue; // still open: look again tomorrow
            }
            if (!order.recoveryUrl || order.marketingConsent !== 'opt_in') {
                // Nothing to send, so stop looking at it every day.
                await ctx.db.collection('orders').updateOne(
                    { orderId: record.orderId, status: 'PENDING' },
                    { $set: { status: 'EXPIRED' } }
                );
                continue;
            }
            const result = await ctx.db.collection('orders').updateOne(
                { orderId: record.orderId, status: 'PENDING' },
                { $set: { status: 'RECOVERY_SENT' } }
            );
            if (result.matchedCount === 1) {
                await ctx.email.send({
                    to: order.customerEmail,
                    subject: 'You left something in your cart',
                    html: `<p>Your cart is saved. <a href="${order.recoveryUrl}">Finish checking out</a>.</p>`
                });
            }
        }
    }
};
```

The recovery link opens a new checkout with its own session id, and it returns to the same `successUrl`. On the success page, `getSession` with that new `session_id` finds the original order and records the payment there, so `orderId` and `orderStatus: 'paid'` work as for any other checkout; `checkoutSessionId` is the new session's id, which is why `fulfilOnce` looks the record up by `orderId`. For now only the success page records it, and only for a card payment: a bank transfer through the link settles days later, and nothing reads its session again, so until connected-account webhook events reach SiteMills, `getOrder` keeps reporting that order, like one whose buyer closed the tab, as `'expired'`. Once connected-account webhooks are enabled, Stripe's events record both cases on the original order. This works for checkouts on the project's own Stripe account; a recovery of a marketplace seller's checkout isn't linked back yet.
