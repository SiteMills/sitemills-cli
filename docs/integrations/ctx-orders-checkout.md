# Hosted Checkout & Order Reads (`ctx.orders`)

Part of `docs/ctx-orders.md`. Covers `ctx.orders.checkout`, `ctx.orders.expireCheckout`, `ctx.orders.getSession`, and `ctx.orders.getOrder`.

## Creating a Checkout Session

```typescript
const checkout = await ctx.orders.checkout({
    mode: 'payment', // or 'subscription'
    successUrl: '/checkout/success?session_id={CHECKOUT_SESSION_ID}',
    cancelUrl: '/checkout/cancel',
    customerEmail: ctx.user?.email,
    clientReferenceId: 'order-123',
    expiresInMinutes: 60, // optional: strictly 30..1440 minutes (defaults to 1440)
    automaticTax: true,
    taxIdCollection: true,
    billingAddressCollection: 'auto', // 'auto' | 'required'
    allowedShippingCountries: ['US', 'CA'],
    shippingOptions: [
        {
            displayName: 'Standard Ground',
            amount: 7.50, // major currency units
            currency: 'usd',
            minDeliveryDays: 3,
            maxDeliveryDays: 5,
            taxBehavior: 'exclusive' // 'exclusive' | 'inclusive' | 'unspecified'
        }
    ],
    phoneNumberCollection: true,
    allowPromotionCodes: true,
    enableAbandonedCartRecovery: true,
    customFields: [
        {
            key: 'giftMessage',
            label: 'Gift Message',
            type: 'text', // 'text' | 'numeric' | 'dropdown'
            optional: true
        }
    ],
    metadata: { orderId: 'order-123', source: 'storefront' },
    lineItems: [
        {
            name: 'Weighted Blanket',
            description: 'Organic cotton cooling throw',
            images: ['https://example.com/images/blanket.jpg'],
            unitAmount: 89.00, // decimal major currency units (e.g. 89.00 for $89.00)
            currency: 'usd',
            quantity: 1,
            taxCode: 'txcd_99999999',
            taxBehavior: 'exclusive'
        }
    ]
});

// Alias:
const checkout2 = await ctx.orders.createCheckoutSession({ ...samePayload });
```

Returns `{ checkoutSessionId, sessionId, checkoutUrl, orderId, sessionMode, expiresAt }` where `expiresAt` is an ISO-8601 UTC timestamp.

## Checkout Options & Validation Rules

- **Redirect URLs**: `successUrl` and `cancelUrl` accept relative paths (recommended) or same-origin HTTPS URLs. Cross-origin URLs are rejected.
- **Line Items**:
  - `name` and positive `unitAmount` (in major currency units) are required; Stripe-style `price_data.product_data.name` and minor-unit `price_data.unit_amount` are also accepted using currency-aware minor unit scaling (e.g. zero-decimal `jpy`/`krw`, three-decimal `kwd`/`bhd`).
  - Optional item fields: `description`, `images` (up to 8 non-empty URLs), `taxCode`, `taxBehavior` (`exclusive`, `inclusive`, `unspecified`), `quantity` (default `1`), and `recurringInterval` / `recurringIntervalCount` for subscriptions.
- **Session Expiration (`expiresInMinutes`)**:
  - Must be an integer strictly between `30` and `1440` (24 hours). Values outside this range fail immediately before calling Stripe.
- **Discounts**:
  - `allowPromotionCodes`, `promotionCodeId`, and `couponId` are mutually exclusive — configure at most one per checkout session.
- **Custom Fields**:
  - Up to 3 entries in `customFields`. Each `key` must be unique and strictly alphanumeric (`/^[A-Za-z0-9]+$/`).
  - When `type: 'dropdown'`, provide non-empty `dropdownOptions: [{ label, value }]` with unique alphanumeric `value` strings.
- **Shipping**:
  - `allowedShippingCountries` (or `shippingAddressCollection.allowedCountries`) expects an array of 2-letter ISO country codes (for example `['US', 'CA']`).
  - `shippingOptions[].amount` is specified in major currency units (`0` allowed for free shipping). If line items use multiple currencies, `currency` is required on each shipping option.
- **Wallets & Payment Methods (`paymentMethodTypes`)**:
  - Omit `paymentMethodTypes` (recommended) or pass `['card']` so Apple Pay, Google Pay, and wallets render dynamically via Stripe Dynamic Payment Methods when eligible.
  - Passing `'apple_pay'`, `'google_pay'`, or `'samsung_pay'` as standalone entries in `paymentMethodTypes` fails validation.
- **Platform Fees**:
  - Application fees are calculated and managed automatically by SiteMills. Never pass `applicationFeeAmount` or `applicationFeePercent` — any request containing fee overrides is rejected immediately.
- **Abandoned Cart Recovery & Promotional Consent**:
  - Set `enableAbandonedCartRecovery: true` to persist recovery URLs when sessions expire and enable US Stripe promotional consent collection (`auto`) when applicable.
- **Metadata**:
  - Up to 44 custom keys (leaving 6 reserved platform routing keys); key length max 40 chars, value max 500 chars. Include domain identifiers (`orderId`, `cartId`, `planId`) for deterministic post-checkout reconciliation.

## Expiring an Open Checkout Session

```typescript
const expired = await ctx.orders.expireCheckout('cs_test_123');
// Or with options object:
const expired2 = await ctx.orders.expireCheckout({ sessionId: 'cs_test_123' });
```

Returns `{ checkoutSessionId, sessionId, orderId, orderStatus: 'expired', sessionStatus: 'expired', recoveryUrl }` (check `sessionStatus === 'expired'` or `orderStatus === 'expired'`).

## Reading Checkout Session & Live Order Receipt Fields

### Post-Checkout Verification (`getSession`)

```typescript
const session = await ctx.orders.getSession('cs_test_123');
// Or getCheckoutSession({ sessionId: 'cs_test_123' })
```

Returns checkout & order summary fields:
- `checkoutSessionId`, `sessionId`, `sessionMode`, `sessionStatus`, `paymentStatus`, `orderStatus`, `orderId`, `paymentIntentId`
- Monetary breakdown: `amountSubtotal`, `amountTax`, `amountShipping`, `amountDiscount`, `amountTotal`, `currency`, `promoCode`
- Buyer & receipt data: `customerEmail`, `customerName`, `customerPhone`, `shippingDetails`, `customFields` (`Record<string, string> | null`), `marketingConsent` (`'opt_in' | 'opt_out' | null`), `recoveryUrl`, `expiresAt`
- `metadata`, `lineItems`, and nested `order`

### Live Scoped Order Lookup (`getOrder`)

```typescript
const order = await ctx.orders.getOrder('ord_abc123');
// Or:
const sameOrder = await ctx.orders.getOrder({ orderId: 'ord_abc123' });
```

`getOrder` queries the live order record scoped strictly to the current project, environment (`DEV` | `STAGING` | `PROD`), and branch scope, returning:
- `orderId`, `projectId`, `branchId`, `scopeId`, `siteEnvironment`, `orderType`, `status`
- `amountSubtotal`, `amountTax`, `amountShipping`, `amountDiscount`, `amountTotal`, `amountRefunded`, `currency`, `promoCode`
- `customerEmail`, `customerName`, `customerPhone`, `shippingDetails` (`{ name, phone, shippingRateId, amountShipping, address: { line1, line2, city, state, postalCode, country } }`)
- `customFields` (`Record<string, string> | null`, e.g. `order.customFields?.giftMessage`), `marketingConsent` (`'opt_in' | 'opt_out' | null`), `recoveryUrl`, `stripeCheckoutSessionId`, `stripePaymentIntentId`, `stripeSubscriptionId`, `items[]`, `createdAt`, `updatedAt`

## ACH / Asynchronous Payments & Fulfillment

Always verify paid status before granting goods or entitlements:

```typescript
export async function finalizeOrder(ctx, { sessionId }) {
    if (!sessionId) throw new Error('sessionId is required');

    const session = await ctx.orders.getSession(sessionId);
    if (session.paymentStatus !== 'paid' && session.orderStatus !== 'paid') {
        return { fulfilled: false, reason: session.paymentStatus || 'pending' };
    }

    const order = session.orderId ? await ctx.orders.getOrder(session.orderId) : null;
    await ctx.db.collection('orders').updateOne(
        { checkoutSessionId: session.checkoutSessionId },
        {
            $set: {
                status: 'PAID',
                orderId: session.orderId,
                amountTotal: order?.amountTotal ?? session.amountTotal,
                paidAt: new Date().toISOString()
            }
        },
        { upsert: true }
    );

    return { fulfilled: true, orderId: session.orderId };
}
```

US ACH transfers settle asynchronously (3-5 business days): immediately after checkout completes, `paymentStatus` may remain `'processing'` until settlement finishes, so never treat incomplete `processing` status as settled payment.
