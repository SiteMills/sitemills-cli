# Multi-Tenant Marketplace & Sub-Merchant Payouts (`ctx.orders`)

Part of `docs/ctx-orders.md`. Covers seller onboarding (`createAdHocOnboardingLink`), dynamic payout routing (`connectedAccountId`), local mock testing, and post-checkout deduplication.

## Ownership & Payout Rules

- Any signed-in user (`ctx.user.email`) can onboard as a seller or landlord via `ctx.orders.createAdHocOnboardingLink`. The resulting connected account belongs to your site **and** strictly to that signed-in user.
- Only the seller who owns an account can resume its onboarding by passing their existing `connectedAccountId`. Passing another seller's account ID rejects the request even for the site owner.
- A user can create up to 20 new seller accounts per day per mode (`TEST` and `LIVE`), with no lifetime cap; resuming an existing account does not count toward the daily limit.
- Seller payouts are held for 7 days after each payment so refunds or disputes during that window settle out of the seller's held balance.
- Any visitor can check out against any seller account belonging to the current site. Passing a `connectedAccountId` from another site or wrong key mode is rejected.

## 1. Sub-Merchant / Landlord Onboarding

Track seller accounts in a collection such as `bank_accounts`:

```typescript
interface BankAccount {
    userId: string;
    label: string;
    accountId: string;
    pendingOnboardingUrl: string | null;
    status: 'active' | 'pending';
}
```

Generate or resume an onboarding link for the signed-in user:

```typescript
const result = await ctx.orders.createAdHocOnboardingLink({
    email: ctx.user.email,               // must match ctx.user.email
    businessName: 'Northside Rentals',   // optional
    country: 'US',                       // optional, default US
    connectedAccountId: 'acct_123...',   // optional: pass to resume existing onboarding
    refreshUrl: '/payouts?onboarding=refresh',
    returnUrl: '/payouts?onboarding=success'
});

// Alias:
const same = await ctx.orders.createCustomAccountOnboardingLink({ ...samePayload });
```

Store `result.connectedAccountId` in your database; ad-hoc accounts are not stored as the site owner's default payout account. Check readiness later using `ctx.orders.getStatus({ connectedAccountId })`.

## 2. Offline & Local Development Mock Prefix Pattern

To support local tests without live Stripe credentials, check for an explicit mock prefix such as `acct_mock_` before calling `ctx.orders.getStatus` or passing `connectedAccountId` to `ctx.orders.checkout`:

```typescript
export async function getSellerPayoutStatus(ctx: any, acc: { id: string; accountId: string; pendingOnboardingUrl: string | null }) {
    if (!acc.accountId || acc.accountId.startsWith('acct_mock_')) {
        return { paymentsEnabled: true, onboardingUrl: null };
    }

    const statusRes = await ctx.orders.getStatus({ connectedAccountId: acc.accountId });
    const paymentsEnabled = statusRes?.status?.paymentsEnabled ?? false;

    if (paymentsEnabled && acc.pendingOnboardingUrl) {
        await ctx.db.collection('bank_accounts').updateOne(
            { id: acc.id },
            { $set: { pendingOnboardingUrl: null } }
        );
        return { paymentsEnabled: true, onboardingUrl: null };
    }

    if (!paymentsEnabled && !acc.pendingOnboardingUrl) {
        const linkRes = await ctx.orders.createAdHocOnboardingLink({
            email: ctx.user.email,
            connectedAccountId: acc.accountId,
            refreshUrl: '/payouts?onboarding=refresh',
            returnUrl: '/payouts?onboarding=success'
        });
        const onboardingUrl = linkRes?.onboardingUrl ?? null;
        if (onboardingUrl) {
            await ctx.db.collection('bank_accounts').updateOne(
                { id: acc.id },
                { $set: { pendingOnboardingUrl: onboardingUrl } }
            );
        }
        return { paymentsEnabled: false, onboardingUrl };
    }

    return { paymentsEnabled, onboardingUrl: acc.pendingOnboardingUrl };
}
```

## 3. Routing Checkout to a Seller Account

```typescript
const checkoutParams: any = {
    mode: 'payment',
    successUrl: '/booking/success?session_id={CHECKOUT_SESSION_ID}',
    cancelUrl: '/booking/cancel',
    customerEmail: ctx.user?.email,
    metadata: { bookingId: booking.id, sellerUserId: seller.userId },
    lineItems: [
        { name: `Stay Booking - ${listing.title}`, unitAmount: booking.totalAmount, currency: 'usd', quantity: 1 }
    ]
};

if (seller.accountId && !seller.accountId.startsWith('acct_mock_')) {
    checkoutParams.connectedAccountId = seller.accountId;
}

const checkout = await ctx.orders.checkout(checkoutParams);
return { checkoutUrl: checkout.checkoutUrl, sessionId: checkout.checkoutSessionId };
```

Site code can't set platform fees. Never pass `applicationFeeAmount` or `applicationFeePercent` to `ctx.orders.checkout`: a request containing either is rejected.

## 4. Deduplicated Post-Checkout Settlement Verification

```typescript
export async function finalizeSellerPayment(ctx: any, { sessionId }: { sessionId: string }) {
    if (!sessionId) throw new Error('sessionId is required');

    const existing = await ctx.db.collection('transactions').findOne({ stripeCheckoutSessionId: sessionId });
    if (existing) {
        return { success: true, alreadyProcessed: true, status: existing.status };
    }

    const session = await ctx.orders.getSession(sessionId);
    // 'paid' once Stripe reports the payment. A bank payment stays 'pending' for days: record nothing yet, so a
    // later call (after it settles) records it as paid.
    if (session.orderStatus !== 'paid') {
        return { success: false, reason: 'payment_not_completed', paymentStatus: session.paymentStatus };
    }
    const status = 'paid';

    await ctx.db.collection('transactions').insertOne({
        bookingId: session.metadata?.bookingId,
        sellerUserId: session.metadata?.sellerUserId,
        amount: Number(session.amountTotal),
        stripeCheckoutSessionId: sessionId,
        status,
        createdAt: new Date().toISOString()
    });

    return { success: true, status };
}
```
