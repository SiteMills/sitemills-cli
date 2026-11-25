# Subscriptions & Customer Billing Portal (`ctx.orders`)

Part of `docs/ctx-orders.md`. Covers recurring checkout sessions, free trials, subscription inspection, renewal cancellation, and Stripe Billing Portal creation.

## Starting a Subscription Checkout

Set `mode: 'subscription'` and supply `recurringInterval` (with optional `recurringIntervalCount` and checkout-level `trialPeriodDays` `1..730`):

```typescript
const subCheckout = await ctx.orders.checkout({
    mode: 'subscription',
    successUrl: '/billing/success?session_id={CHECKOUT_SESSION_ID}',
    cancelUrl: '/billing/cancel',
    customerEmail: ctx.user?.email,
    trialPeriodDays: 14, // optional: 1..730 days, subscription mode only
    allowPromotionCodes: true,
    metadata: { planId: 'pro-monthly', userId: ctx.user?.id ?? '' },
    lineItems: [
        {
            name: 'Pro Monthly',
            unitAmount: 29.00,
            currency: 'usd',
            quantity: 1,
            recurringInterval: 'month',
            recurringIntervalCount: 1
        }
    ]
});
```

Notes:
- `trialPeriodDays` is only permitted when `mode === 'subscription'` and must be an integer from `1` to `730`.
- Save `subCheckout.checkoutSessionId` against your authenticated user record after verifying `ctx.orders.getSession(sessionId)`.

## Managing an Active Subscription

Use only the saved scoped checkout `sessionId` for subscription management; `projectId`, `connectedAccountId`, `subscriptionId`, and `customerId` overrides are rejected because subscription identity is resolved strictly from the verified order and its original charged Stripe account.

```typescript
// Authenticate caller and verify they own savedCheckoutSessionId first!
const subscription = await ctx.orders.getSubscription({
    sessionId: savedCheckoutSessionId
});

const canceled = await ctx.orders.cancelSubscription({
    sessionId: savedCheckoutSessionId
});

const { portalUrl } = await ctx.orders.createBillingPortal({
    sessionId: savedCheckoutSessionId,
    returnUrl: '/#workspace?billing=managed'
});
```

### Important Behavior Rules

1. **Authenticate First**: Always authenticate `ctx.user` and verify they own the persisted billing record holding `savedCheckoutSessionId` before calling subscription or portal methods.
2. **End-of-Period Cancellation**: `cancelSubscription` sets Stripe `cancel_at_period_end = true` without proration and never immediately deletes the active subscription. Repeated calls are idempotent and safe. Cancellation does not refund the current period or automatically stop separately hosted resources.
3. **Return Shape & Minor Units**:
   - `getSubscription` and `cancelSubscription` return `{ subscriptionId, status, cancelAtPeriodEnd, currentPeriodEnd, paidThrough, serviceUntil, endedAt, keyMode, plans, invoices, receiptsAvailable }`.
   - `plans[].amountMinor` and `invoices[].amountPaidMinor` use **Stripe minor units** (for example USD cents), unlike `checkout()` `unitAmount` and `getSession()`/`getOrder()` monetary totals which use major units.
   - Rely on `paidThrough` (based on paid invoice lines) rather than subscription status alone when gating access; inspect `receiptsAvailable` and do not synthesize a paid date when Stripe cannot confirm payment.
4. **Billing Portal Scope**: `createBillingPortal` generates a short-lived Stripe portal for updating payment methods, viewing invoices, and canceling at period end (plan swaps are disabled). `returnUrl` must be relative or same-origin HTTPS matching the checkout origin.
5. **Periodic Refresh**: Initial checkout completion is not lifetime entitlement. Refresh subscription state periodically (for example via a scheduled backend job) and persist updated status and `serviceUntil`.
