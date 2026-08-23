# Orders API — Stripe Connect + Hosted Checkout

The backend runtime exposes `ctx.orders` for project-level payment setup and checkout.

Use this when your app needs to:
- Enable Stripe Connect payouts for a project owner.
- Check whether payments are fully enabled.
- Create a hosted Stripe Checkout session.
- Look up a checkout session by `sessionId` to continue post-checkout fulfillment.
- Onboard third-party users/sub-merchants (like landlords or vendors) dynamically to their own Stripe accounts.
- Route payouts dynamically to different bank accounts per transaction using the custom `connectedAccountId` override.

## Single-Account vs. Multi-Tenant Routing Models

The platform supports two main routing architectures:

1. **Single-Account Model (Default)**
   - **When to use**: Typical e-commerce sites, subscription apps, or single-owner services.
   - **How it works**: The website owner connects one Stripe account via the Sitemills Builder settings. All checkout transactions are automatically processed through this account and paid out to the owner's default bank account. No custom database tracking of Stripe accounts is required.

2. **Multi-Tenant / Ad-Hoc Model**
   - **When to use**: Marketplaces, rental platforms (multi-landlord), or booking directories where different transactions must pay out to different bank accounts/parties.
   - **How it works**: Individual users/sub-merchants onboard via `ctx.orders.createAdHocOnboardingLink(...)`. You save their generated `connectedAccountId` in your application database. During checkout, you retrieve this ID and pass it as the `connectedAccountId` property in `ctx.orders.checkout(...)` to route that specific transaction directly to their bank account.

## Methods

### 1) Enable Payments

```typescript
const result = await ctx.orders.enablePayments({
    ownerEmail: 'owner@example.com',
    ownerName: 'Project Owner',      // optional
    country: 'US',                   // optional, default US server-side
    refreshUrl: '/billing?retry=1',  // relative path preferred
    returnUrl: '/billing?connected=1'
});
```

Required fields:
- `ownerEmail`
- `refreshUrl`
- `returnUrl`

URL safety rule:
- Use relative URLs (recommended), or absolute URLs on the same origin as the current request.
- Cross-origin redirect URLs are rejected.

Returns an object with:
- `onboardingUrl` — send the owner to this URL to complete Stripe onboarding.
- `connectedAccountId`
- `status` (capability flags)
- `keyMode` (`TEST` or `LIVE`)

### 1b) Create Ad-Hoc Onboarding Link (For Landlords / Sub-merchants)

For multi-tenant systems where individual users/landlords onboard separate bank accounts:
```typescript
const result = await ctx.orders.createAdHocOnboardingLink({
    email: 'landlord@example.com',
    businessName: 'Landlord Business',    // optional
    country: 'US',                       // optional, default US
    refreshUrl: '/stripe-onboard/refresh?landlordId=123',
    returnUrl: '/stripe-onboard/callback?landlordId=123'
});

// Alias also supported:
const result2 = await ctx.orders.createCustomAccountOnboardingLink({ ...samePayload });
```

Required fields:
- `email`
- `refreshUrl`
- `returnUrl`

Returns the same onboarding object (`onboardingUrl`, `connectedAccountId`, `status`, `keyMode`). Note that this account ID is **not** saved to the project-wide settings. Your custom application should save the `connectedAccountId` to its own database.


### 2) Get Payment Status

```typescript
const status = await ctx.orders.getStatus({
    connectedAccountId: 'acct_123...' // optional, checks status of a custom connected account
});

// Alias also supported:
const sameStatus = await ctx.orders.status({ connectedAccountId: 'acct_123...' });
```

Typical response fields:
- `accountConfigured`
- `connectedAccountId` (when configured)
- `status.paymentsEnabled`
- `status.payoutsEnabled`
- `status.detailsSubmitted`

### 3) Create Hosted Checkout Session

```typescript
const checkout = await ctx.orders.checkout({
    mode: 'payment', // or 'subscription'
    connectedAccountId: 'acct_123...', // optional, routes payouts dynamically to this account
    successUrl: '/checkout/success',
    cancelUrl: '/checkout/cancel',
    customerEmail: 'buyer@example.com',
    clientReferenceId: 'order-123',
    metadata: { source: 'pricing-page' },
    lineItems: [
        {
            name: 'Starter Plan',
            unitAmount: 19.99,
            currency: 'usd',
            quantity: 1
        }
    ]
});

// Alias also supported:
const checkout2 = await ctx.orders.createCheckoutSession({ ...samePayload });
```

Required fields:
- `lineItems` (non-empty)

URL safety rule:
- `successUrl` and `cancelUrl` may be relative paths (recommended) or same-origin absolute URLs.
- When omitted, runtime defaults are used (`/checkout/success`, `/checkout/cancel`).
- Cross-origin redirect URLs are rejected.

Line item fields:
- `name` (required)
- `unitAmount` (required; decimal in major units, e.g., `19.99` for $19.99)
- `currency` (optional, default `usd`)
- `quantity` (optional, default `1`)
- `recurringInterval` / `recurringIntervalCount` (optional, for subscriptions)

Also accepted (Stripe-style compatibility):
- `lineItems[].price_data.product_data.name`
- `lineItems[].price_data.unit_amount` (in cents)
- `lineItems[].price_data.currency`

Returns:
- `checkoutUrl` (redirect buyer here)
- `checkoutSessionId`
- `sessionMode`
- `expiresAt`

Fulfillment recommendation:
- Include business identifiers in `metadata` when creating checkout (for example `productId`, `quantity`, `orderType`).
- This makes post-checkout handlers deterministic when they load the session later.

### 4) Get Checkout Session Details

```typescript
const session = await ctx.orders.getSession('cs_test_123');

// Alias also supported:
const sameSession = await ctx.orders.getCheckoutSession('cs_test_123');
```

Supported call forms:
- `getSession(sessionId)`
- `getSession({ sessionId })`

Typical response fields:
- `checkoutSessionId`
- `sessionStatus`
- `paymentStatus`
- `paymentIntentId`
- `metadata`
- `orderId`
- `orderStatus`
- `lineItems`
- `order`

Notes:
- Session lookup is scoped to the current project/runtime context.
- If the session is unknown for the current project scope, the method throws.

### 5) Refund a Payment

```typescript
const refund = await ctx.orders.refund({
    paymentIntentId: 'pi_3PabcXYZ123',
    amount: 19.99,                        // decimal amount in major units
    connectedAccountId: 'acct_123...'    // optional, required if payment was connected
});

// Alias also supported:
const sameRefund = await ctx.orders.refundPayment({ ...samePayload });
```

Required fields:
- `paymentIntentId`
- `amount` (must be greater than zero)

Returns:
- `success` (boolean)
- `refundId`
- `status`

### 6) Create Terminal Connection Token

Generates a short-lived Connection Token required by the frontend Stripe Terminal JS SDK to establish communication with Wi-Fi/Ethernet readers.

```typescript
const tokenResponse = await ctx.orders.createTerminalConnectionToken({
    connectedAccountId: 'acct_123...'    // optional, required for connected accounts
});
```

Returns:
- `secret` (string) — The connection token secret to pass to the frontend SDK.

### 7) Register Terminal Reader

Registers a new physical Stripe Terminal reader device to the project or location.

```typescript
const reader = await ctx.orders.registerTerminalReader({
    registrationCode: 'simplicity-is-great',
    label: 'Counter 1',
    locationId: 'tmpl_123...',            // optional
    connectedAccountId: 'acct_123...'    // optional
});
```

Required fields:
- `registrationCode`
- `label`

Returns:
- `id` (string) — The registered reader ID.
- `deviceType` (string)
- `serialNumber` (string)
- `status` (string)

## Additional Examples

### Subscription checkout with monthly billing

```typescript
const subscriptionCheckout = await ctx.orders.checkout({
    mode: 'subscription',
    successUrl: '/billing/success',
    cancelUrl: '/billing/cancel',
    customerEmail: 'subscriber@example.com',
    metadata: { planId: 'pro-monthly', source: 'upgrade-modal' },
    lineItems: [
        {
            name: 'Pro Monthly',
            unitAmount: 29.0,
            currency: 'usd',
            quantity: 1,
            recurringInterval: 'month',
            recurringIntervalCount: 1
        }
    ]
});
```

### Post-checkout fulfillment using session metadata

```typescript
export async function finalizeOrder(ctx, { sessionId }) {
    if (!sessionId) {
        throw new Error('sessionId is required');
    }

    const session = await ctx.orders.getSession(sessionId);
    if (session.paymentStatus !== 'paid') {
        return { fulfilled: false, reason: 'payment_not_completed' };
    }

    const orderId = session.metadata?.orderId ?? session.orderId;
    if (!orderId) {
        throw new Error('Missing orderId metadata for fulfillment');
    }

    await ctx.db.collection('orders').updateOne(
        { id: orderId },
        {
            $set: {
                status: 'PAID',
                checkoutSessionId: session.checkoutSessionId,
                paidAt: new Date().toISOString()
            }
        },
        { upsert: false }
    );

    return { fulfilled: true, orderId };
}
```

## ACH and Asynchronous Payments

The platform supports both card payments and ACH (US Bank Account) transfers. 

Unlike credit cards, ACH payments are **asynchronous** and can take 3–5 business days to clear:
- During checkout, when the hosted checkout session completes, the payment intent status will be `processing` and `paymentStatus` will not yet be `paid`.
- You **must not** assume the order is paid or fulfill resources immediately upon session completion. Always verify that `session.paymentStatus === 'paid'` (as shown in the fulfillment example above).
- The platform automatically processes the `payment_intent.succeeded` webhook when the bank transfer clears, and updates the order status to `paid` in the database.
- If the payment fails (e.g., due to insufficient funds), the platform handles the `payment_intent.payment_failed` webhook and updates the order status to `failed`.

## Scope + Key Selection

`ctx.orders` runs in the active runtime scope for the current request.
The platform resolves the effective scope automatically.

Stripe key mode is selected server-side:
- Key mode is resolved by platform runtime context.

This allows one project to keep separate test/live connected account IDs across scopes.

## Failure Modes (important)

- If connected account is missing for the selected key mode, checkout returns a configuration error.
- If connected account is not fully enabled yet (`paymentsEnabled=false`), checkout is rejected.
- `ctx.orders.enablePayments(...)` and `ctx.orders.checkout(...)` require request context so runtime can determine the current site origin for safe redirects. Use them inside exported backend handlers that are invoked by frontend requests.
- If required fields are missing, methods throw with descriptive errors.

## Recommended Flow

1. Call `ctx.orders.enablePayments(...)` from owner settings.
2. Redirect owner to `onboardingUrl`.
3. Poll `ctx.orders.getStatus(...)` until `paymentsEnabled=true`.
4. Call `ctx.orders.checkout(...)` when buyer starts payment.
5. Redirect buyer to returned `checkoutUrl`.
6. In post-checkout backend handlers, call `ctx.orders.getSession(sessionId)` and use session metadata/order details to complete fulfillment.

