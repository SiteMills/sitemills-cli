# Orders API (`ctx.orders`)

The backend runtime exposes `ctx.orders` for project-level Stripe Connect setup, hosted checkout, live order inspection, refunds, subscription portals, and hardware reader onboarding.

Read the focused topic page that matches your task before implementing a specific workflow:
- Checkout sessions, taxes, shipping, discounts, custom fields, expiration, and receipt fields: `docs/ctx-orders-checkout.md`
- Recurring billing, free trials, cancellations, and Stripe billing portals: `docs/ctx-orders-subscriptions.md`
- Multi-tenant marketplace / landlord payouts and sub-merchant onboarding: `docs/ctx-orders-marketplace.md`

## Single-Account vs. Multi-Tenant Routing

1. **Single-Account Model (Default)**
   - **When to use**: E-commerce storefronts, SaaS subscriptions, or single-owner booking sites.
   - **How it works**: Connect one Stripe account in SiteMills Dashboard settings (or call `ctx.orders.enablePayments(...)`). All checkout payments route to that account automatically.
2. **Multi-Tenant / Ad-Hoc Model**
   - **When to use**: Marketplaces or multi-vendor platforms where separate sellers receive payouts directly.
   - **How it works**: Onboard each seller with `ctx.orders.createAdHocOnboardingLink(...)`, store their `connectedAccountId`, and pass `connectedAccountId` into `ctx.orders.checkout(...)`. See `docs/ctx-orders-marketplace.md` for full code examples.

## Method Quick Reference

| Area | Methods | Guide |
| :--- | :--- | :--- |
| Merchant Onboarding & Status | `enablePayments`, `createAdHocOnboardingLink` (`createCustomAccountOnboardingLink`), `getStatus` (`status`) | This doc & `docs/ctx-orders-marketplace.md` |
| Hosted Checkout & Session Read | `checkout` (`createCheckoutSession`), `expireCheckout`, `getSession` (`getCheckoutSession`) | `docs/ctx-orders-checkout.md` |
| Live Order Reads & History | `getOrder`, `getOrderHistory` (`listOrders`, `history`) | This doc & `docs/ctx-orders-checkout.md` |
| Subscriptions & Portal | `getSubscription`, `cancelSubscription`, `createBillingPortal` | `docs/ctx-orders-subscriptions.md` |
| Refunds | `refund` (`refundPayment`) | This doc |
| POS Reader Setup | `createTerminalConnectionToken`, `registerTerminalReader`, `listTerminalReaders` | This doc |

## Core Methods

### 1) Enable Payments

```typescript
const result = await ctx.orders.enablePayments({
    ownerEmail: ctx.user.email,      // signed-in site owner or billing contact
    ownerName: 'Project Owner',      // optional
    country: 'US',                   // optional, default US
    refreshUrl: '/billing?retry=1',  // relative path or same-origin HTTPS URL
    returnUrl: '/billing?connected=1'
});
```

Returns `{ onboardingUrl, connectedAccountId, status, keyMode }`.

### 2) Get Payment Status

```typescript
const status = await ctx.orders.getStatus({
    connectedAccountId: 'acct_123...' // optional: check one of this site's seller accounts
});

// Alias:
const sameStatus = await ctx.orders.status({ connectedAccountId: 'acct_123...' });
```

Returns `{ accountConfigured, connectedAccountId, status: { paymentsEnabled, chargesEnabled, payoutsEnabled, detailsSubmitted } }`.

### 3) Create Hosted Checkout Session

```typescript
const checkout = await ctx.orders.checkout({
    successUrl: '/checkout/success?session_id={CHECKOUT_SESSION_ID}',
    cancelUrl: '/checkout/cancel',
    customerEmail: ctx.user?.email,
    expiresInMinutes: 60, // optional: 30..1440 minutes (defaults to 1440)
    lineItems: [
        { name: 'Starter Plan', unitAmount: 19.99, currency: 'usd', quantity: 1 }
    ]
});
```

See `docs/ctx-orders-checkout.md` for the optional features (shipping, custom fields, discounts, automatic tax and what each needs), dynamic wallets, `expireCheckout(sessionId)`, `getSession(sessionId)`, and fulfilling paid orders.

### 4) Read an Order (`getOrder`)

Look up one order within the current project and runtime environment (`DEV`, `STAGING`, or `PROD`). While the order is still unpaid, `getOrder` checks its checkout session with Stripe first, so it reports `paid` once the buyer has paid:

```typescript
const order = await ctx.orders.getOrder('ord_abc123');
// Or with options object:
const order2 = await ctx.orders.getOrder({ orderId: 'ord_abc123' });
```

Returns the order:
- `orderId`, `orderType`, `status`, `stripeCheckoutSessionId`, `stripePaymentIntentId`, `stripeSubscriptionId`
- Monetary breakdown in major units: `amountSubtotal`, `amountTax`, `amountShipping`, `amountDiscount`, `amountTotal`, `amountRefunded`, `currency`, `promoCode`
- Line items (`items[]`), buyer details (`customerEmail`, `customerName`, `customerPhone`, `shippingDetails`), `customFields` (key-value map `Record<string, string> | null`), `marketingConsent` (`'opt_in' | 'opt_out' | null`), `recoveryUrl` (set once an expired session with abandoned-cart recovery has a recovery link), `createdAt`, and `updatedAt`
- Never pass `projectId` to `getOrder`; project and scope are derived automatically from the active runtime context.

### 5) Customer Order History (`getOrderHistory`)

```typescript
const history = await ctx.orders.getOrderHistory({
    customerEmail: ctx.user.email, // inferred from ctx.user.email when omitted
    limit: 25
});

// Aliases:
const ordersList = await ctx.orders.listOrders({ customerEmail: ctx.user.email });
const sameHistory = await ctx.orders.history({ customerEmail: ctx.user.email });
```

### 6) Refund a Payment

```typescript
const refund = await ctx.orders.refund({
    paymentIntentId: 'pi_3PabcXYZ123',
    amount: 19.99 // decimal amount in major units
});

// Alias:
const sameRefund = await ctx.orders.refundPayment({ paymentIntentId: 'pi_3PabcXYZ123', amount: 19.99 });
```

Notes:
- Only payments captured through this project's `ctx.orders.checkout` can be refunded, and funds automatically return through the charged connected account.
- If `connectedAccountId` is passed, it must match the account that originally processed the payment.

### 7) Hardware POS Reader Setup

- `ctx.orders.createTerminalConnectionToken({ connectedAccountId?, locationId? })` -> returns `{ secret }` for frontend `@stripe/terminal-js`.
- `ctx.orders.registerTerminalReader({ registrationCode, label, locationId?, connectedAccountId? })` -> returns `{ id, deviceType, serialNumber, status }`.
- `ctx.orders.listTerminalReaders({ connectedAccountId?, locationId? })` -> returns registered readers for the project/account.

#### Web App (Browser POS) Hardware Rules

| Scenario | Recommended Reader | Connectivity | Key Notes |
| :--- | :--- | :--- | :--- |
| Countertop / Register POS | **BBPOS WisePOS E** | Wi-Fi / Ethernet | 5" touchscreen, cloud API over web browsers |
| High-Volume Countertop | **Stripe Reader T600** | Wi-Fi / Ethernet | Vibrant countertop smart reader |
| Table-side Handheld | **Stripe Reader S700 / S710** | Wi-Fi / 4G Cellular | Handheld smart readers for floor or mobile POS |
| Built-in Paper Receipts | **Verifone V660p** | Wi-Fi / Cellular | Integrated thermal receipt printer |
| Kiosk / Drive-Thru | **Verifone UX700** | Ethernet / Wi-Fi | Unattended weatherproof smart reader |
| Native Mobile Only | **Stripe Reader M2 / Tap to Pay** | Bluetooth / NFC | Unsupported in browser web apps |

## Scope + Key Selection

`ctx.orders` always runs in the active runtime scope (`DEV`, `STAGING`, or `PROD`, plus preview branch scope). Key mode (`TEST` or `LIVE`) is resolved automatically server-side so test transactions never hit live Stripe accounts.

## Failure Modes & Recommended Flow

- Missing connected account or `paymentsEnabled = false` rejects `checkout` with a setup error.
- Passing a `connectedAccountId` that does not belong to this project in the active mode throws `This project has no Stripe account with that ID in TEST mode.` (or `LIVE`).
- Cross-origin redirect URLs (`successUrl`, `cancelUrl`, `returnUrl`, `refreshUrl`) are rejected; prefer relative paths.
- Recommended flow: `enablePayments` -> redirect owner to `onboardingUrl` -> poll `getStatus` -> `checkout` -> redirect buyer to `checkoutUrl` -> verify via `getSession` / `getOrder`.
