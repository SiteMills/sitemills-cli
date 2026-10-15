# Dwolla API — ACH Bank-to-Bank Transfer Routing

The backend runtime exposes `ctx.dwolla` for ACH bank transfer processing, multi-bank payout routing, and bank verification.

Use this when your app needs to:
- Onboard payees (for example landlords or merchants) by registering their profiles (Verified or Unverified Customers).
- Attach multiple bank accounts (Funding Sources) to a single payee profile to route different properties or products to different banks.
- Allow payers (for example tenants or customers) to link their bank accounts.
- Verify payer bank accounts using Sandbox micro-deposits (simulated) or Plaid processor tokens.
- Initiate low-cost ACH transfers directly from a payer to a specific destination bank account.
- Check transfer status (`pending`, `processed`, `failed`).

---

## Methods

### 1) Create Customer
Creates a Dwolla customer profile. Use `type: "personal"` or `"business"` for verified entities that will receive/send larger amounts. Use `type: "unverified"` for low-friction senders (like tenants).

Required: `firstName`, `lastName`, `email`, `type`.

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
Links a bank account (checking or savings) to a customer profile.

Required: `customerId`, `name`, and either:
- `routingNumber`, `accountNumber`, and `type` (manual entry), or
- `plaidToken` (a Plaid processor token — see [ctx.plaid](ctx-plaid.md)).

```typescript
// Manual entry
const bank = await ctx.dwolla.addFundingSource({
    customerId: 'bf6b6298-7d10-491a-851f-7325bee774db',
    routingNumber: '222222226', // Sandbox default routing number
    accountNumber: '1111111111',
    type: 'checking', // 'checking' | 'savings'
    name: 'Property A Account (Chase)'
});

// Instant verification via a Plaid processor token
const verifiedBank = await ctx.dwolla.addFundingSource({
    customerId: 'bf6b6298-7d10-491a-851f-7325bee774db',
    plaidToken: processorToken,
    name: 'Tenant Checking'
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
Completes bank verification by confirming the two deposit amounts received. `amount1` and `amount2` must be numbers.

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

### 5) Initiate routed ACH Transfer
Initiates an ACH transfer between two funding sources. At least one party (source or destination customer) must be a Verified Customer. `amount` must be a number.

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
Retrieves status information for an existing transfer. Accepts a transfer ID string or `{ transferId }`.

```typescript
const status = await ctx.dwolla.getTransfer('79726baa-ed90-f111-acd5-02ab38c54207');
```

Returns:
```json
{
  "id": "79726baa-ed90-f111-acd5-02ab38c54207",
  "status": "pending",
  "amount": {
    "value": "1200.00",
    "currency": "USD"
  },
  "created": "2026-08-05T16:49:53.190Z"
}
```

`status` is one of `pending`, `processed`, `failed`, or `cancelled`.

---

## Multi-Tenant Property Routing Design
For rental or marketplace applications where one payee receives payments for different properties in different bank accounts:
1. Onboard the payee **once** using `ctx.dwolla.createCustomer` with `type: "personal"` or `"business"`.
2. Save their customer ID in your database.
3. For each property, call `ctx.dwolla.addFundingSource` under the payee's customer ID, labeling each account (e.g. "Chase Checking - Property A"). Save each `fundingSourceUri` in your database.
4. Onboard payers (tenants) as `unverified` customers. Ask them to link and verify their bank account.
5. When rent is paid, run a transfer with:
   * `sourceFundingSourceUri` set to the tenant's bank account URI.
   * `destinationFundingSourceUri` set to the specific property's bank account URI.

## Security notes

- Call `ctx.dwolla.*` only from authenticated, authorized backend handlers. Look up customer IDs and funding source URIs from your own database records for the signed-in user rather than accepting them directly from the browser.
- Never log or persist full bank account numbers or SSN data in your application records.
