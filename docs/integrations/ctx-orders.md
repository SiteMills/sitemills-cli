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
    connectedAccountId: 'acct_123...',   // optional, pass to resume onboarding on an existing account
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

Returns the same onboarding object (`onboardingUrl`, `connectedAccountId`, `status`, `keyMode`). Note that this account ID is **not** saved to the project-wide settings. Your custom application should save the `connectedAccountId` to its own database. Pass `connectedAccountId` on subsequent calls to resume onboarding for the same account without creating duplicates.

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

## In-Person Payments & Hardware Selection (Stripe Terminal)

*(Official Stripe Terminal Hardware & API Guidance as of August 2026)*

When users build restaurant POS, cafes, or retail applications requiring in-person card and contactless payments, recommend the appropriate [Stripe Terminal](https://stripe.com/terminal) smart reader:

### Device Recommendation Matrix

| Scenario / Workflow | Recommended Reader | Connectivity | Why / Key Features |
| :--- | :--- | :--- | :--- |
| **Standard Countertop / Register POS** | **[BBPOS WisePOS E](https://stripe.com/terminal/wisepose)** | Wi-Fi / Ethernet dock | Most popular for restaurant & retail counters. 5" touchscreen, customer tipping & line-item display. Connects directly to web browser apps over cloud. |
| **High-Volume Countertop** | **[Stripe Reader T600](https://stripe.com/terminal/t600)** | Wi-Fi / Ethernet | Countertop smart reader with vibrant display and PIN pad for fast register checkout. |
| **Table-side / Floor Checkout** | **[Stripe Reader S700](https://stripe.com/terminal/s700)** | Wi-Fi | Handheld Android smart reader with 5.5" screen. Waitstaff can bring device to tables for ordering and payment. Supports running custom POS apps directly. |
| **Mobile / Outdoor / Anywhere** | **[Stripe Reader S710](https://stripe.com/terminal/s710)** | Cellular + Wi-Fi | Smart handheld reader with cellular 4G connectivity for food trucks, patios, or markets. |
| **Physical Receipt Printing** | **[Verifone V660p](https://stripe.com/terminal/v660p)** | Wi-Fi / Cellular | Handheld smart reader with a **built-in thermal printer** for paper dining receipts. |
| **Self-Service Kiosk / Drive-Thru** | **[Verifone UX700](https://stripe.com/terminal/ux700)** | Ethernet / Wi-Fi | Weatherproof unattended smart reader for outdoor kiosks and self-ordering stations. |
| **Low-Cost Bluetooth** *(Mobile App Only)* | **[Stripe Reader M2](https://stripe.com/terminal/m2)** | Bluetooth | Budget reader (~$59). *Requires a native iOS/Android mobile app; cannot be controlled directly from a web browser.* |
| **Contactless Phone-to-Phone** *(Mobile App Only)* | **[Tap to Pay](https://stripe.com/terminal/tap-to-pay)** | Phone NFC | Turn iPhone or Android into a reader without extra hardware. *Requires native mobile app.* |

Full directory: [Stripe Terminal Devices](https://stripe.com/terminal/devices) | Setup Guide: [Stripe Terminal Documentation](https://stripe.com/docs/terminal)

### Web App (Browser POS) Compatibility Rule
- **Web applications (Preact/browser) MUST use Internet-connected Smart Readers** (WisePOS E, S700/S710, T600, V660p). Web browsers communicate with readers via the Stripe Cloud API / `@stripe/terminal-js` SDK without needing Bluetooth pairing.
- **Bluetooth readers (Stripe Reader M2) and Tap to Pay are unsupported in web browsers** and require native mobile apps.

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

## Multi-Tenant / Marketplace Patterns (Stripe Connect)

For platforms like marketplaces or rental portals where transactions must be routed dynamically to different sub-merchant or landlord bank accounts, you should implement the following multi-tenant architecture pattern.

### 1. Landlord / Sub-Merchant Onboarding
Store the onboarding information in a collection like `bank_accounts`:
```typescript
interface BankAccount {
    userId: string;
    label: string;
    accountId: string;               // Stripe Connect account ID
    pendingOnboardingUrl: string | null;
    status: 'active' | 'pending';
}
```

#### A. Generating/Resuming the Onboarding Link
When a user begins bank onboarding, check if they already have an active onboarding session URL. If they do not, call `ctx.orders.createAdHocOnboardingLink` and persist the URL. This allows them to resume their onboarding session instead of creating duplicate accounts.
```typescript
export async function getBankAccounts(ctx: any) {
    const landlordAccounts = await ctx.db.collection('bank_accounts').find({ userId: ctx.user.id });
    const enrichedAccounts = [];

    for (const acc of landlordAccounts) {
        let paymentsEnabled = true;
        let onboardingUrl = acc.pendingOnboardingUrl;

        // Skip querying Stripe if it is a mock/local testing account
        if (acc.accountId && !acc.accountId.startsWith('acct_mock_')) {
            try {
                const statusRes = await ctx.orders.getStatus({ connectedAccountId: acc.accountId });
                paymentsEnabled = statusRes?.status?.paymentsEnabled ?? false;

                if (!paymentsEnabled) {
                    // Generate and cache a new onboarding link if not already cached
                    if (!onboardingUrl) {
                        const linkRes = await ctx.orders.createAdHocOnboardingLink({
                            email: ctx.user.email,
                            connectedAccountId: acc.accountId, // Pass existing ID to resume instead of creating duplicate accounts
                            returnUrl: `/properties?onboarding=success`,
                            refreshUrl: `/properties?onboarding=refresh`,
                            businessName: acc.label
                        });
                        onboardingUrl = linkRes?.onboardingUrl || null;
                        if (onboardingUrl) {
                            await ctx.db.collection('bank_accounts').update(acc.id, {
                                ...acc,
                                pendingOnboardingUrl: onboardingUrl
                            });
                        }
                    }
                } else {
                    // Account is active - clear any stale pending URL
                    if (acc.pendingOnboardingUrl) {
                        await ctx.db.collection('bank_accounts').update(acc.id, {
                            ...acc,
                            pendingOnboardingUrl: null
                        });
                    }
                    onboardingUrl = null;
                }
            } catch (err) {
                console.error('Failed to get Stripe Connect status:', err);
            }
        }

        enrichedAccounts.push({ ...acc, paymentsEnabled, onboardingUrl });
    }
    return enrichedAccounts;
}
```

#### B. Offline & Local Developer Testing Mode
To ensure the app can be tested locally and offline without active Stripe credentials, implement a **mock account prefix** check (e.g. checking if the account ID starts with a mock prefix like `acct_landlord_` or `acct_mock_`).
- Bypasses active status checks (defaults them to `true`).
- Prevents passing the mock `connectedAccountId` payload to Stripe during checkouts to avoid crashes.

### 2. Multi-Tenant Checkout Routing
When creating the checkout session, retrieve the recipient's `connectedAccountId` from the database. If it is a real account (i.e. does not start with your mock prefix), pass it as `connectedAccountId` in the checkout configuration.
```typescript
const destinationAccountId = property.bankAccountId; // retrieved from DB

const checkoutParams: any = {
    mode: 'payment',
    successUrl: `/rent-success?session_id={CHECKOUT_SESSION_ID}&status=success`,
    cancelUrl: '/rent-success?status=cancel',
    customerEmail: ctx.user.email,
    metadata: {
        leaseId: lease.id,
        bankAccountId: destinationAccountId
    },
    lineItems: [
        {
            name: `Rent Payment - Unit ${lease.unit}`,
            unitAmount: rentAmount,
            currency: 'usd',
            quantity: 1
        }
    ]
};

// Route payout dynamically to Stripe Connect account unless it's a local mock account
if (destinationAccountId && !destinationAccountId.startsWith('acct_mock_')) {
    checkoutParams.connectedAccountId = destinationAccountId;
}

const checkout = await ctx.orders.checkout(checkoutParams);
return { checkoutUrl: checkout.checkoutUrl };
```

### 3. Payment Verification & Deduplication
When the checkout session redirects the user back to the application, the frontend should hit a backend validation handler. To prevent double-fulfillment and handle races between redirect and Stripe webhooks, perform **deduplication** by checking the DB for the checkout session ID.

```typescript
export async function finalizePayment(ctx: any, { sessionId }: { sessionId: string }) {
    if (!sessionId) throw new Error('sessionId is required');

    // 1. Deduplication check
    const existing = await ctx.db.collection('transactions').findOne({ stripeCheckoutSessionId: sessionId });
    if (existing) {
        return { success: true, alreadyProcessed: true, status: existing.status };
    }

    // 2. Fetch fresh checkout session details
    const session = await ctx.orders.getSession(sessionId);
    if (session.sessionStatus !== 'complete') {
        return { success: false, reason: 'payment_not_completed' };
    }

    // 3. Determine status (support both card instant 'paid' and ACH asynchronous 'processing')
    const amount = Number(session.amountTotal);
    const isPaid = session.orderStatus === 'paid' || session.paymentStatus === 'paid';
    const paymentStatus = isPaid ? 'paid' : 'processing';

    // 4. Record the transaction under the manager/sub-merchant's ID
    const managerId = session.metadata?.managerId;
    await ctx.db.collection('transactions').add({
        userId: managerId,
        amount,
        stripeCheckoutSessionId: sessionId,
        status: paymentStatus,
        createdAt: new Date().toISOString()
    });

    // 5. Update application state if fully paid
    if (paymentStatus === 'paid') {
        // fulfill the resources/update balances
    }

    return { success: true, status: paymentStatus };
}
```

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

