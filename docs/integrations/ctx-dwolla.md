# Dwolla API — ACH Bank-to-Bank Transfer Routing (BYOK)

The backend runtime exposes `ctx.dwolla` for ACH bank transfer processing, landlord/merchant multi-bank routing, and bank account verification.

> **Bring Your Own Keys (Keystore Required):** SiteMills does not provide shared platform Dwolla credentials. Every project using `ctx.dwolla` must configure its own Dwolla API credentials in the project **Keystore** (`ctx.env`). At runtime, `ctx.dwolla` automatically reads your keys from Keystore for the active environment (`DEV`, `STAGING`, or `PROD`, with `GLOBAL` fallback).

Use this when your app needs to:
- Onboard landlords/merchants by registering their profiles (Verified or Unverified Customers).
- Attach multiple bank accounts (Funding Sources) to a single landlord's profile to route different properties to different banks.
- Allow tenants/customers to link their bank accounts.
- Verify tenant/customer bank accounts using Sandbox micro-deposits (simulated) or Plaid processor tokens.
- Initiate low-cost ACH transfers directly from a tenant to a specific property's bank account.
- Check transfer status (`pending`, `processed`, `failed`, `cancelled`).

---

## Prerequisites: Storing Dwolla API Keys in Keystore

Before calling `ctx.dwolla.*`, store your Dwolla application credentials from the [Dwolla Dashboard](https://dashboard.dwolla.com/applications) (or Sandbox Dashboard) in the project Keystore:

### Required Keystore Variables

| Variable Name | Description | Environment Resolution |
| :--- | :--- | :--- |
| `DWOLLA_KEY` *(or `DWOLLA_CLIENT_ID`)* | Your Dwolla Application Key | Resolved as a matched pair with `DWOLLA_SECRET` (or `DWOLLA_CLIENT_SECRET`) in the active environment (`DEV`, `STAGING`, `PROD`), falling back to `GLOBAL` only when neither key is set in the active environment. |
| `DWOLLA_SECRET` *(or `DWOLLA_CLIENT_SECRET`)* | Your Dwolla Application Secret (Sandbox secret for `DEV`/`STAGING`, Production secret for `PROD`) | Must be stored in the same environment (`DEV`, `STAGING`, `PROD`, or `GLOBAL`) and naming pair as `DWOLLA_KEY` (or `DWOLLA_CLIENT_ID`). |
| `DWOLLA_ENV` *(optional)* | `'sandbox'` or `'production'` | Optional override (for example, `'sandbox'` in `PROD`). Set `DWOLLA_ENV=production` in the `PROD` scope only (never in `GLOBAL`, `DEV`, or `STAGING`); a `'production'` value that reaches `DEV` or `STAGING` throws an error, as does any value other than `'sandbox'` or `'production'`. |

### How to Configure Keys

1. **Via SiteMills Dashboard**:
   - Open your project and go to **Settings > API Keys**.
   - Select the target environment (`DEV`, `STAGING`, or `PROD`).
   - Enter your **Dwolla Application Key** (`DWOLLA_KEY`) and **Dwolla Application Secret** (`DWOLLA_SECRET`) and click **Save Changes**.

2. **Via SiteMills CLI (`sitemills-cli`)**:
   ```bash
   # Store Sandbox credentials for DEV (or use GLOBAL to share across environments)
   sitemills-cli env-set <projectId> DEV DWOLLA_KEY "your_dwolla_app_key" --description "Dwolla Application Key"
   sitemills-cli env-set <projectId> DEV DWOLLA_SECRET "your_dwolla_sandbox_secret" --description "Dwolla Sandbox Secret"

   # Store Production credentials for PROD
   sitemills-cli env-set <projectId> PROD DWOLLA_KEY "your_dwolla_prod_key" --description "Dwolla Production Key"
   sitemills-cli env-set <projectId> PROD DWOLLA_SECRET "your_dwolla_prod_secret" --description "Dwolla Production Secret"

   # Verify configured key names
   sitemills-cli env-list <projectId> DEV
   ```

3. **For AI Agents**:
   - Never hardcode or invent Dwolla keys.
   - Check if `DWOLLA_KEY` (or `DWOLLA_CLIENT_ID`) and `DWOLLA_SECRET` (or `DWOLLA_CLIENT_SECRET`) are already present using `await agent.dashboard.env.list()` (or `await ctx.env.list()` inside a backend handler).
   - If missing, ask the user to provide them or render the inline Keystore secret input widget in chat:
     ````markdown
     ```sitemills-widget
     {"type": "env_secrets", "keys": ["DWOLLA_KEY", "DWOLLA_SECRET"], "scope": "DEV"}
     ```
     ````

---

## Methods

### 1) Create Customer
Creates a Dwolla customer profile. Use `type: "personal"` or `"business"` for verified entities that will receive/send larger amounts. Use `type: "unverified"` for low-friction senders (like tenants).

```typescript
const customer = await ctx.dwolla.createCustomer({
    firstName: 'Landlord',
    lastName: 'Jane',
    email: 'jane@example.com',
    type: 'personal', // 'personal' | 'business' | 'unverified'
    address1: '999 Falcon Dr',
    city: 'Austin',
    state: 'TX',
    postalCode: '78701',
    dateOfBirth: '1985-05-15',
    ssn: '9999' // last 4 of SSN for sandbox auto-verification
});
```

Returns:
```json
{
  "customerId": "bf6b6298-7d10-491a-851f-7325bee774db",
  "customerUri": "https://api-sandbox.dwolla.com/customers/bf6b6298-7d10-491a-851f-7325bee774db"
}
```

---

### 2) Add Funding Source
Links a bank account (checking or savings) to a customer profile via routing/account numbers or a Plaid `processorToken`.

```typescript
const bank = await ctx.dwolla.addFundingSource({
    customerId: 'bf6b6298-7d10-491a-851f-7325bee774db',
    routingNumber: '222222226', // Sandbox default routing number
    accountNumber: '1111111111',
    type: 'checking', // 'checking' | 'savings'
    name: 'Property A Account (Chase)'
});
```

Or using a Plaid Processor Token (`ctx.plaid.createProcessorToken`):
```typescript
const bank = await ctx.dwolla.addFundingSource({
    customerId: 'bf6b6298-7d10-491a-851f-7325bee774db',
    plaidToken: processorToken,
    name: 'Verified Checking Account'
});
```

Returns:
```json
{
  "fundingSourceId": "92327bba-8a42-4870-88f7-ff84924beca2",
  "fundingSourceUri": "https://api-sandbox.dwolla.com/funding-sources/92327bba-8a42-4870-88f7-ff84924beca2"
}
```

---

### 3) Initiate Micro-Deposits
Triggers the sending of two small verification deposits (less than $0.10) to a bank account.

```typescript
const result = await ctx.dwolla.initiateMicroDeposits({
    fundingSourceId: '812938dd-4e45-4f77-92bd-6d36afb0b5ef'
});
```

Returns:
```json
{
  "success": true
}
```

---

### 4) Verify Micro-Deposits
Completes bank verification by confirming the two deposit amounts received.

```typescript
const result = await ctx.dwolla.verifyMicroDeposits({
    fundingSourceId: '812938dd-4e45-4f77-92bd-6d36afb0b5ef',
    amount1: 0.03,
    amount2: 0.09
});
```

Returns:
```json
{
  "success": true
}
```

---

### 5) Initiate Routed ACH Transfer
Initiates an ACH transfer between two funding sources. At least one party (source or destination customer) must be a Verified Customer.

```typescript
const transfer = await ctx.dwolla.transfer({
    sourceFundingSourceUri: 'https://api-sandbox.dwolla.com/funding-sources/812938dd-4e45-4f77-92bd-6d36afb0b5ef',
    destinationFundingSourceUri: 'https://api-sandbox.dwolla.com/funding-sources/7d0006ea-2724-4dd8-b871-c004a97333af',
    amount: 1200.00,
    currency: 'USD' // Optional, defaults to USD
});
```

Returns:
```json
{
  "transferId": "79726baa-ed90-f111-acd5-02ab38c54207",
  "transferUri": "https://api-sandbox.dwolla.com/transfers/79726baa-ed90-f111-acd5-02ab38c54207",
  "status": "pending"
}
```

---

### 6) Get Transfer Status
Retrieves status information for an existing transfer.

```typescript
const status = await ctx.dwolla.getTransfer('79726baa-ed90-f111-acd5-02ab38c54207');
```

Returns:
```json
{
  "id": "79726baa-ed90-f111-acd5-02ab38c54207",
  "status": "pending", // 'pending' | 'processed' | 'failed' | 'cancelled'
  "amount": {
    "value": "1200.00",
    "currency": "USD"
  },
  "created": "2026-08-05T16:49:53.190Z"
}
```

---

## Multi-Tenant Property Routing Design
For applications like **Rentflow** where a landlord receives payments for different properties in different bank accounts:
1. Ensure `DWOLLA_KEY` and `DWOLLA_SECRET` are stored in the project Keystore (`ctx.env`).
2. Onboard the landlord **once** using `ctx.dwolla.createCustomer` with `type: "personal"` or `"business"`.
3. Save their primary customer ID in your database.
4. For each property, call `ctx.dwolla.addFundingSource` under the landlord's customer ID, labeling them dynamically (e.g. "Chase Checking - Property A"). Save each `fundingSourceUri` in your database.
5. Onboard tenants as `unverified` customers. Ask them to link and verify their bank account.
6. When rent is paid, run a transfer with:
   * `sourceFundingSourceUri` set to the tenant's bank account URI.
   * `destinationFundingSourceUri` set to the specific property's bank account URI.
