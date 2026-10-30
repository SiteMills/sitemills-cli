# Plaid API — Secure Financial Data Aggregation & Bank Linking (BYOK)

The backend runtime exposes `ctx.plaid` for securely launching Plaid Link, exchanging public tokens, and generating processor tokens to connect users' bank accounts directly with Dwolla.

> **Bring Your Own Keys (Keystore Required):** SiteMills does not provide shared platform Plaid credentials. Every project using `ctx.plaid` must configure its own Plaid API credentials in the project **Keystore** (`ctx.env`). At runtime, `ctx.plaid` automatically reads your keys from Keystore for the active environment (`DEV`, `STAGING`, or `PROD`, with `GLOBAL` fallback).

Use this when your app needs to:
- Generate a Link Token in the backend to initialize Plaid Link on the frontend.
- Exchange a `public_token` received from the frontend for an `access_token`.
- Generate a Dwolla `processor_token` to securely link a user's bank account with Dwolla.

---

## Prerequisites: Storing Plaid API Keys in Keystore

Before calling `ctx.plaid.*`, store your Plaid credentials from the [Plaid Dashboard](https://dashboard.plaid.com/developers/keys) in the project Keystore:

### Required Keystore Variables

| Variable Name | Description | Environment Resolution |
| :--- | :--- | :--- |
| `PLAID_CLIENT_ID` | Your Plaid `client_id` | Resolved as a matched pair with `PLAID_SECRET` in the active environment (`DEV`, `STAGING`, `PROD`), falling back to `GLOBAL` only when neither key is set in the active environment. |
| `PLAID_SECRET` | Your Plaid `secret` (Sandbox secret for `DEV`/`STAGING`, Production secret for `PROD`) | Must be stored in the same environment (`DEV`, `STAGING`, `PROD`, or `GLOBAL`) as `PLAID_CLIENT_ID`. |
| `PLAID_ENV` *(optional)* | `'sandbox'` or `'production'` | Optional override (for example, `'sandbox'` in `PROD`). Set `PLAID_ENV=production` in the `PROD` scope only (never in `GLOBAL`, `DEV`, or `STAGING`); a `'production'` value that reaches `DEV` or `STAGING` throws an error, as does any value other than `'sandbox'` or `'production'`. |

### How to Configure Keys

1. **Via SiteMills Dashboard**:
   - Open your project and go to **Settings > API Keys**.
   - Select the target environment (`DEV`, `STAGING`, or `PROD`).
   - Enter your **Plaid Client ID** (`PLAID_CLIENT_ID`) and **Plaid Secret** (`PLAID_SECRET`) and click **Save Changes**.

2. **Via SiteMills CLI (`sitemills-cli`)**:
   ```bash
   # Store Sandbox credentials for DEV (or use GLOBAL to share across environments)
   sitemills-cli env-set <projectId> DEV PLAID_CLIENT_ID "your_plaid_client_id" --description "Plaid Client ID"
   sitemills-cli env-set <projectId> DEV PLAID_SECRET "your_plaid_sandbox_secret" --description "Plaid Sandbox Secret"

   # Store Production credentials for PROD
   sitemills-cli env-set <projectId> PROD PLAID_CLIENT_ID "your_plaid_client_id" --description "Plaid Client ID"
   sitemills-cli env-set <projectId> PROD PLAID_SECRET "your_plaid_production_secret" --description "Plaid Production Secret"

   # Verify configured key names
   sitemills-cli env-list <projectId> DEV
   ```

3. **For AI Agents**:
   - Never hardcode or invent Plaid keys.
   - Check if `PLAID_CLIENT_ID` and `PLAID_SECRET` are already present using `await agent.dashboard.env.list()` (or `await ctx.env.list()` inside a backend handler).
   - If missing, ask the user to provide them or render the inline Keystore secret input widget in chat:
     ````markdown
     ```sitemills-widget
     {"type": "env_secrets", "keys": ["PLAID_CLIENT_ID", "PLAID_SECRET"], "scope": "DEV"}
     ```
     ````

---

## Methods

### 1) Create Link Token
Generates a `link_token` required to initialize the client-side Plaid Link modal.

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
Exchanges a Plaid `public_token` (returned from successful client-side Plaid Link flow) for an `access_token` and `item_id`.

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
Generates a secure `processor_token` to link the authenticated bank account directly with a Dwolla Customer Profile as a Funding Source. Requires the Dwolla processor integration to be enabled in your Plaid account.

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

1. **Keystore Setup**: Ensure both Plaid (`PLAID_CLIENT_ID`, `PLAID_SECRET`) and Dwolla (`DWOLLA_KEY`, `DWOLLA_SECRET`) keys are configured in Keystore.
2. **Frontend**: The user triggers bank connection. The app calls backend to get a `linkToken` using `ctx.plaid.createLinkToken`.
3. **Frontend**: Launches Plaid Link using the retrieved `linkToken`. User logs into their bank and selects an account.
4. **Frontend**: Plaid Link completes and returns a `public_token` and selected `metadata.account_id` to the browser.
5. **Backend Handler**: Frontend posts these details to a backend handler, which calls:
   * `ctx.plaid.exchangePublicToken({ publicToken })` to get the `accessToken`.
   * `ctx.plaid.createProcessorToken({ accessToken, accountId })` to get the `processorToken`.
   * `ctx.dwolla.addFundingSource({ customerId, plaidToken: processorToken, name })` to instantly link the bank account as a verified funding source on Dwolla.
