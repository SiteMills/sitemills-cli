# Stripe Terminal & In-Person Payments Hardware Guide

> **Document Status**: Active / Validated  
> **Source Verification**: Stripe Official Hardware & Terminal API (as of August 2026)

This document provides platform and agent guidance for building and recommending in-person Point-of-Sale (POS) payment solutions using **Stripe Terminal** on SiteMills.

---

## 1. Overview & Restaurant / Retail Use Cases

When users ask how to accept in-person payments for restaurants, cafes, food trucks, or retail stores built on SiteMills, the answer is **Stripe Terminal**.

Stripe Terminal unifies online ordering and in-person POS transactions under the same Stripe account, customer profiles, webhooks, and payouts.

### Device Recommendation Matrix

| Use Case | Recommended Device | Connectivity | Key Features & Links |
| :--- | :--- | :--- | :--- |
| **Countertop / Register POS** *(Standard Restaurant / Retail)* | **[BBPOS WisePOS E](https://stripe.com/terminal/wisepose)** | Wi-Fi / Ethernet (dock) | 5" color touchscreen, customer-facing tip/tax prompt, connects directly to web browser apps over cloud. |
| **High-Performance Countertop** | **[Stripe Reader T600](https://stripe.com/terminal/t600)** | Wi-Fi / Ethernet | Countertop smart reader with vibrant display and PIN pad for fast checkout. |
| **Table-side / Floor Checkout** *(Waitstaff at tables)* | **[Stripe Reader S700](https://stripe.com/terminal/s700)** | Wi-Fi | Handheld Android smart reader, 5.5" touchscreen, customizable app on device, on-screen tipping. |
| **Mobile / Outdoor / Anywhere** *(Food truck, patio, market)* | **[Stripe Reader S710](https://stripe.com/terminal/s710)** | Cellular + Wi-Fi | Handheld smart reader with built-in cellular 4G connectivity + Wi-Fi. |
| **Physical Receipt Printing** *(Dining & table-side)* | **[Verifone V660p](https://stripe.com/terminal/v660p)** | Wi-Fi / Cellular | Handheld smart reader with **built-in thermal paper printer** for itemized receipts. |
| **Self-Service Kiosk / Drive-Thru** | **[Verifone UX700](https://stripe.com/terminal/ux700)** | Ethernet / Wi-Fi | Rugged, weatherproof smart reader for unattended kiosks and ordering stations. |
| **Ultra-Low Budget Mobile** *(Requires Mobile App)* | **[Stripe Reader M2](https://stripe.com/terminal/m2)** | Bluetooth | Low-cost (~$59) compact reader. *Requires native iOS/Android app (cannot be used directly from browser).* |
| **No-Hardware Contactless** *(Requires Mobile App)* | **[Tap to Pay](https://stripe.com/terminal/tap-to-pay)** | NFC on phone | Turn an iPhone or Android into a card reader via native mobile SDK. |

Explore the full catalog at [Stripe Terminal Devices Directory](https://stripe.com/terminal/devices).

---

## 2. Web App (Browser POS) Compatibility Rules

SiteMills web applications (running on Preact / standard web browsers across iPads, Macs, Windows PCs, and Android tablets) follow these strict rules:

### A. Web Browsers MUST Use Internet-Connected / Smart Readers
- **Supported for Web POS**: **BBPOS WisePOS E**, **Stripe Reader S700 / S710**, **Stripe Reader T600**, **Verifone V660p**.
- **How they work**: These devices connect to the local Wi-Fi / Ethernet network and communicate with Stripe's Cloud API. Your web app talks to the reader over the network using the `@stripe/terminal-js` SDK or the Server-Driven API. No local Bluetooth pairing is required.

### B. Bluetooth Readers & Tap to Pay Require Native Mobile Apps
- **Stripe Reader M2** (Bluetooth) and **Tap to Pay on iPhone/Android** **cannot** be controlled directly by a web browser application. They require a native iOS or Android app built with the Stripe Terminal Mobile SDK.
- **Recommendation**: If building a browser-based restaurant POS on SiteMills, **always recommend the BBPOS WisePOS E or Stripe Reader S700**.

---

## 3. Reader Setup & Initial Configuration (After Buying the Hardware)

Once a restaurant or store purchases a Stripe Terminal smart reader (e.g. BBPOS WisePOS E, Stripe Reader S700/S710), follow these step-by-step instructions to configure it from unboxing to first payment:

### Step 1: Network & Hardware Prerequisites
1. **Power & Dock**: Place the reader in its charging cradle/dock or plug into USB-C power.
2. **Wi-Fi / Ethernet Setup**:
   * Connect the reader to the store's Wi-Fi network (or plug Ethernet into the dock).
   * **Network Requirements**: The network must use standard WPA/WPA2-Personal or WPA2-Enterprise encryption. It must have direct outbound access to Stripe over HTTPS (ports 443 and 4443).
   * ⚠️ **Captive Portal Warning**: Smart readers **cannot** open web browsers to accept terms on captive portal networks (e.g. hotel Wi-Fi or guest networks requiring a click-through splash page). Use a dedicated, secure POS/staff Wi-Fi network.
3. **Automatic Firmware Updates**:
   * Upon first connecting to the internet, the reader will check for OS and firmware updates. Allow 5–15 minutes for the initial update to install and reboot.
   * *Best Practice*: Leave the reader plugged into power and connected to Wi-Fi overnight so it receives ongoing security and payment kernel updates automatically.

### Step 2: Location & Stripe Dashboard Configuration
Stripe requires all physical readers to be assigned to a **Location** (representing the restaurant/store's physical street address).

1. **Create a Location**: In the [Stripe Dashboard](https://dashboard.stripe.com/terminal/locations) under **Payments > Terminal > Locations**, add a location with the business's physical address.
2. **Configure On-Screen Tipping & Branding**:
   * Navigate to **Payments > Terminal > Configurations**.
   * Create or edit a configuration profile:
     * **Tipping**: Enable on-screen tipping, specify default percentage buttons (e.g. 15%, 18%, 20%), smart tipping thresholds, and allow custom tip entries.
     * **Branding & Splash Screen**: Upload the restaurant's logo/background image to display on the reader's touchscreen when idle.
     * **Language & Currency**: Set default display language and currency format.
   * Assign this configuration profile to your Location or specific reader.

### Step 3: Pairing & Registration (The Admin PIN `07139`)
To pair the physical device with your Stripe account:
1. On the reader touchscreen, swipe in from the left edge of the screen to open the diagnostic drawer.
2. Tap **Settings** and enter the default admin PIN: `07139`.
3. Tap **Generate registration code**. The reader will display a 3-word pairing code (e.g. `simplicity-is-great`).
4. **Register the Reader**:
   * **Option A (Stripe Dashboard)**: Go to **Payments > Terminal > Readers > Register reader**, select your Location, and enter the 3-word code.
   * **Option B (SiteMills Backend API)**: Call `ctx.orders.registerTerminalReader({ registrationCode, label, locationId })` from your app backend.

---

## 4. Multi-Tenancy & Test vs. Live Mode Configuration

SiteMills is designed from the ground up as a **multi-tenant platform** using Stripe Connect.

### A. Do Project Owners or Tenants Need Stripe API Keys?
**No. Neither project owners nor sub-tenants ever manage raw Stripe API keys.**
* SiteMills operates as a central **Stripe Connect Platform**. The platform securely holds the platform Stripe API keys (`sk_live_...` and `sk_test_...`) in the backend infrastructure.
* Individual project owners (e.g. a restaurant owner creating an app on SiteMills) connect their Stripe account via the **SiteMills Builder / Dashboard settings** (or via `ctx.orders.enablePayments`).
* Sub-tenants in nested marketplaces (e.g. 10 independent food stalls inside a food-court app) connect dynamically via `ctx.orders.createAdHocOnboardingLink(...)`.
* In all cases, the platform handles authentication, webhook verification, and payment routing via Stripe Connect without exposing keys to users or frontends.

---

### B. The Two Multi-Tenancy Models on SiteMills

#### Model 1: Single-Project Tenant (Standard Restaurant / Store)
* **Who it is for**: A standard restaurant or business website created on SiteMills.
* **How it works**: The restaurant owner connects their Stripe account once in the SiteMills Builder settings.
* **Code in `ctx.orders`**: You do **not** need to pass any `connectedAccountId`. SiteMills automatically binds all Terminal calls to the active project's connected Stripe account:
  ```typescript
  // 1. Fetch connection token for the project's reader
  const token = await ctx.orders.createTerminalConnectionToken();

  // 2. Register reader to the current project
  const reader = await ctx.orders.registerTerminalReader({
    registrationCode: 'simplicity-is-great',
    label: 'Main Register'
  });
  ```

#### Model 2: Nested Sub-Merchant Multi-Tenancy (Food Court / Multi-Vendor Marketplace)
* **Who it is for**: Platforms where one SiteMills app hosts multiple distinct restaurants or vendors who each receive their own payouts.
* **How it works**: Vendors onboard dynamically via `ctx.orders.createAdHocOnboardingLink(...)`, which returns a `connectedAccountId` saved to your database (`ctx.db`).
* **Code in `ctx.orders`**: Pass the specific vendor's `connectedAccountId`:
  ```typescript
  // 1. Fetch connection token scoped to this specific vendor
  const token = await ctx.orders.createTerminalConnectionToken({
    connectedAccountId: vendor.stripeAccountId
  });

  // 2. Register reader to this specific vendor
  const reader = await ctx.orders.registerTerminalReader({
    registrationCode: 'simplicity-is-great',
    label: `${vendor.name} Counter`,
    connectedAccountId: vendor.stripeAccountId
  });
  ```

---

### C. How Does a Reader Attach to Test Mode vs. Live Mode?
Physical smart readers (BBPOS WisePOS E, Stripe Reader S700, etc.) **do not have a hardware switch for Test/Live mode**. 

**The environment where the pairing code is registered determines whether the reader is in Test Mode or Live Mode:**

1. **Test Mode (Sandbox / Development)**:
   * When your app runs in `DEV` or `PREVIEW` environment, SiteMills automatically uses the platform's **Test Secret Key** (`sk_test_...`).
   * When you register a 3-word pairing code, Stripe binds that physical device in **Test Mode**. The reader screen will show test mode and accept Stripe test cards.
2. **Live Mode (Production)**:
   * When your app runs in `PRODUCTION`, SiteMills automatically uses the platform's **Live Secret Key** (`sk_live_...`).
   * When you register a 3-word pairing code in Production, Stripe binds that physical device in **Live Mode** and processes real credit cards.

---

### D. Switching a Physical Reader from Test to Live (or Vice Versa)
A physical reader can only be registered to **one account and one mode at a time**. If a merchant previously registered a device in Test mode and wants to switch to Live mode:
1. On the reader screen: Swipe in from the left edge -> tap **Settings** -> enter PIN `07139`.
2. Tap **Diagnostics** -> tap **Unregister reader** (or generate a fresh registration code).
3. Open the **Production** app and register the new registration code under the restaurant's Live connected account.

### E. Cloud Routing (No Bluetooth or Subnet Binding Required)
Because Smart Readers (WisePOS E, S700, T600) communicate directly with the Stripe Cloud API:
- The cashier tablet/computer and the card reader **do not** need to be on the same local subnet or paired via Bluetooth.
- A POS web app running on any browser (even a remote manager tablet) can push a transaction to any registered countertop or table-side reader anywhere in the restaurant.

---

## 5. Developer Architecture & API Workflow

### Architecture Diagram

```
[ Cashier clicks 'Charge $25.00' in Preact POS ]
                       │
                       ▼
             [ Backend API Handler ]
                       │  (Calls ctx.orders.createTerminalConnectionToken)
                       │  (Creates PaymentIntent with payment_method_types: ['card_present'])
                       ▼
             [ Stripe Cloud API ]
                       │
                       ▼
        [ Smart Reader (WisePOS E / S700) ]
        - Displays itemized total & line items
        - Prompts for Tip (e.g. 15%, 18%, 20%, Custom)
        - Customer Taps/Inserts Card or Apple Pay
                       │
                       ▼
             [ Stripe Cloud API ]
                       │
                       ▼
        [ Webhook: payment_intent.succeeded ]
        - Updates Order Status in DB (ctx.db)
        - Prints/Sends Receipt
```

### Backend APIs (`ctx.orders`)

#### 1) Generate Terminal Connection Token
Generates a short-lived Connection Token required by the frontend Stripe Terminal JS SDK to establish communication with Wi-Fi/Ethernet readers.

```typescript
// server/handlers/terminal.ts
export async function getTerminalConnectionToken(ctx: any) {
  const tokenResponse = await ctx.orders.createTerminalConnectionToken({
    connectedAccountId: ctx.user?.connectedAccountId // optional, for multi-merchant setups
  });
  return { secret: tokenResponse.secret };
}
```

#### 2) Register a Physical Terminal Reader
```typescript
export async function registerReader(ctx: any, { registrationCode, label }: { registrationCode: string, label: string }) {
  const reader = await ctx.orders.registerTerminalReader({
    registrationCode,
    label: label || 'Counter 1'
  });
  return { id: reader.id, status: reader.status };
}
```

---

## 6. Summary Advice for Restaurant Clients

When answering users building restaurant, cafe, or retail apps:
1. **Recommend the BBPOS WisePOS E** (`https://stripe.com/terminal/wisepose`) for fixed countertop checkouts (fastest setup, customer display, tip screen).
2. **Recommend the Stripe Reader S700** (`https://stripe.com/terminal/s700`) or **S710** (`https://stripe.com/terminal/s710`) for servers taking orders or payments table-side.
3. **Recommend the Verifone V660p** (`https://stripe.com/terminal/v660p`) if physical paper receipt printing is required.
4. **Remind them** that web apps need smart Wi-Fi/Ethernet readers (not Bluetooth M2) for seamless browser POS checkout.
