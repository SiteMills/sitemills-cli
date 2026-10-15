# Plaid API — Secure Financial Data Aggregation & Bank Linking

The backend runtime exposes `ctx.plaid` for securely launching Plaid Link, exchanging public tokens, and generating processor tokens to connect users' bank accounts directly with Dwolla.

Use this when your app needs to:
- Generate a Link Token in the backend to initialize Plaid Link on the frontend.
- Exchange a `public_token` received from the frontend for an `access_token`.
- Generate a Dwolla `processor_token` to securely link a user's bank account with Dwolla.

---

## Methods

### 1) Create Link Token
Generates a `link_token` required to initialize the client-side Plaid Link modal. `userId` is required.

```typescript
const result = await ctx.plaid.createLinkToken({
    userId: 'user_12345' // Unique identifier for the user in your database
});
```

Returns:
```json
{
  "linkToken": "link-sandbox-1234abcd-56ef-78gh-90ij-1234567890ab",
  "expiration": "2026-08-05T18:30:00Z"
}
```

---

### 2) Exchange Public Token
Exchanges a Plaid `public_token` (returned from a successful client-side Plaid Link flow) for an `access_token` and `item_id`. `publicToken` is required.

```typescript
const result = await ctx.plaid.exchangePublicToken({
    publicToken: 'public-sandbox-9876zyxw-43vu-21ts-09rq-0987654321ba'
});
```

Returns:
```json
{
  "accessToken": "access-sandbox-1234abcd-56ef-78gh-90ij-1234567890ab",
  "itemId": "item-sandbox-1234abcd-56ef-78gh-90ij-1234567890ab"
}
```

---

### 3) Create Processor Token (for Dwolla)
Generates a secure `processor_token` to link the authenticated bank account directly with a Dwolla Customer Profile as a Funding Source. `accessToken` and `accountId` are required.

```typescript
const result = await ctx.plaid.createProcessorToken({
    accessToken: 'access-sandbox-1234abcd-56ef-78gh-90ij-1234567890ab',
    accountId: 'account-12345' // The Plaid Account ID selected by the user in Link
});
```

Returns:
```json
{
  "processorToken": "processor-sandbox-1234abcd-56ef-78gh-90ij-1234567890ab"
}
```

---

## Secure Bank Verification Flow (Plaid + Dwolla)

To securely verify and link a user's bank account for Dwolla transfers without handling raw routing or account numbers:

1. **Frontend**: The user triggers bank connection. The app calls a backend handler that returns a `linkToken` from `ctx.plaid.createLinkToken`.
2. **Frontend**: Launches Plaid Link using the retrieved `linkToken`. The user logs into their bank and selects an account.
3. **Frontend**: Plaid Link completes and returns a `public_token` and the selected `metadata.account_id` to the browser.
4. **Backend Handler**: The frontend posts these details to a backend handler, which calls:
   * `ctx.plaid.exchangePublicToken({ publicToken })` to get the `accessToken`.
   * `ctx.plaid.createProcessorToken({ accessToken, accountId })` to get the `processorToken`.
   * `ctx.dwolla.addFundingSource({ customerId, plaidToken: processorToken, name })` to instantly link the bank account as a verified funding source on Dwolla (see [ctx.dwolla](ctx-dwolla.md)).

```typescript
export async function linkBankAccount(ctx, { publicToken, accountId }) {
    // Look up the Dwolla customer for the signed-in user from your own records
    const profile = await ctx.db.collection('payers').findOne({ userId: ctx.userId });
    if (!profile?.dwollaCustomerId) {
        throw new Error('Create a payer profile before linking a bank account.');
    }

    const { accessToken } = await ctx.plaid.exchangePublicToken({ publicToken });
    const { processorToken } = await ctx.plaid.createProcessorToken({ accessToken, accountId });
    const bank = await ctx.dwolla.addFundingSource({
        customerId: profile.dwollaCustomerId,
        plaidToken: processorToken,
        name: 'Linked bank account'
    });

    await ctx.db.collection('payers').updateOne(
        { userId: ctx.userId },
        { $set: { fundingSourceUri: bank.fundingSourceUri } }
    );

    return { linked: true };
}
```

## Security notes

- Keep `accessToken` values server-side only; never return them to the browser or write them to logs.
- Derive the user and customer from the authenticated runtime context and your own records, not from browser-supplied IDs.
