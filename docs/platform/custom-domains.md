# Multiple domains for one project

Open the project's **Custom Domains** panel. With an existing primary domain,
choose **Add domain**:

- **Buy a new domain** opens search and checkout above the workspace. Search
  does not charge your account. Review availability and price before paying.
  Registration depends on the environment's registrar and billing configuration.
- **Connect a domain I own → Keep my DNS provider** attaches an additional
  hostname such as `www.example.com`. Add the displayed TXT and CNAME records
  at your current DNS provider, then use **Check** to verify ownership, HTTPS,
  and website routing. Manual root-domain attachment is not supported.
- **Connect a domain I own → Let SiteMills manage DNS** accepts your registered
  domain, attaches `www`, and opens the existing managed DNS review. Compare the
  discovered records against your old provider, including email and subdomains;
  add anything missing. Review DNSSEC before confirming. Only then use the
  supplied nameservers at your registrar. This changes DNS hosting, not domain
  registration. The root redirects to that domain's `www` address.

Each additional domain offers **DNS settings**, when managed DNS supports its
hostname, and the manual verification records. Existing managed DNS records can
be viewed, added, or deleted through that domain's panel, with provider-managed
website records protected by the provisioning service.

## Changing the preferred address

Use **Make primary** on a fully verified, routed additional domain. The change
preserves both domains, their verification tokens, provider identifiers,
certificates, purchase references, and managed DNS bindings. The former primary
becomes an additional domain. No new purchase or nameserver change is needed.

All connected domains continue serving the same published project. Making a
domain primary does not add automatic redirects or rewrite the site's canonical
URLs, links, cookies, or third-party callback registrations. Those are separate
site/application settings. Before disconnecting a primary that has additional
domains, promote another domain first. This prevents orphaning the other domains.

## API and lifecycle

All routes below are beneath `/api/v1/dashboard/projects/{projectId}/domains`:

| Method | Route | Purpose |
| --- | --- | --- |
| POST | `/primary` | Promote an existing verified alias; body `{ "domain": "www.example.com" }` |
| POST | `/aliases` | Attach an existing hostname |
| POST | `/aliases/{domain}/verify` | Check domain readiness |
| DELETE | `/aliases/{domain}` | Disconnect an additional hostname |
| POST | `/aliases/{domain}/managed` | Prepare this domain's DNS review |
| GET | `/aliases/{domain}/managed` | Read DNS review/delegation status |
| POST | `/aliases/{domain}/managed/confirm` | Confirm reviewed records and DNSSEC |
| GET / POST | `/aliases/{domain}/managed/records` | List or add DNS records |
| DELETE | `/aliases/{domain}/managed/records/{recordId}` | Delete an unprotected DNS record |

Existing primary-domain managed DNS routes remain unchanged. Mutations require
project write permission; status and record reads require project read access.
Provider bindings come from project metadata, not caller-supplied identifiers.
Primary promotion and DNS mutations use the existing project operation lease.
Aliases retain independent managed DNS and payment fields. Missing managed DNS
fields in older records default to false.

Background reconciliation refreshes primary and additional domain verification
independently. One failed primary check must not suppress a healthy alias route.
A route is returned only with recent ownership, DNS, and HTTPS readiness and is
marked active after the infrastructure controller acknowledges it.

## Validation

Run the dashboard's `*CustomDomain*Test` and `*ManagedDns*Test` suites. The browser
regression is `node tests/domain-management.browser.mjs` from `node/webfe`; it
uses intercepted APIs and does not purchase domains or modify external DNS.

## Purchase failure handling

New Stripe domain checkout is disabled unless the dashboard environment explicitly
sets `SITEMILLS_DOMAIN_CHECKOUT_ENABLED=true`. Keep it disabled until the registrar
account has a default payment method, a default registrant contact, and the
registration agreement accepted, and the registration lifecycle has been verified.
This gate does not disable connecting an already-owned domain.

Confirmation verifies the Stripe payment server-side (project, domain, purchase
metadata, successful full payment, and no refund/dispute). Failed and already-started
registrar claims cannot be blindly replayed, including through the admin retry route.
Only a terminal successful Cloudflare registration permits DNS provisioning.
Pending registration is polled using read-only status requests for a bounded window;
unresolved or action-required results still require support reconciliation. Provider errors retain
HTTP status and numeric codes without disclosing provider bodies or credentials.
The client exits the registration spinner on failure and advises against paying again.

Refunds are currently support-managed. Before refunding, confirm the registrar did
not complete the purchase and verify the Stripe charge and any previous refunds.
Use a stable per-payment idempotency key. Never automatically refund an ambiguous
502, timeout, or DNS failure after registration succeeded. Automated refunds require
a durable payment/registration reconciliation workflow; they are not enabled by
these safeguards. Prefer payment authorization followed by capture after confirmed
registration for a future checkout revision, with reconciliation for capture failures.

Cloudflare prerequisites and response states:
https://developers.cloudflare.com/registrar/registrar-api/

A refunded, released reservation without a DNS zone can start a fresh checkout;
it receives a new Stripe payment reference and clears the detached flag. The old
refunded payment cannot be reused. Stripe retains the original payment/refund audit.
A detached binding with a DNS zone requires support review and is never adopted by
this purchase path. After confirmed registration, only an exact domain/account
zone can be reused when Cloudflare already created it.

The search response exposes `checkoutPaused` from the dashboard checkout setting.
The buy button is disabled and labeled "Purchases paused" while that setting is off.
Checkout checks this setting before creating a project binding or Stripe payment.
The browser confirmation timeout is 95 seconds, covering the backend's 90-second
budget. This does not add automatic refunds or reuse a refunded payment.

## CLI Integration for Managed DNS

Developers and site owners can manage their project's custom domains and DNS records
directly from the terminal using `tools/sitemills-cli.js`.

### Prerequisites
Log in to the target SiteMills platform:
```bash
node tools/sitemills-cli.js login --host https://sitemills.com
```

### 1. View Connected Domains
Inspect primary domain, aliases, routing status, and whether Managed DNS is active:
```bash
node tools/sitemills-cli.js domain PROJECT_ID [--host <host>]
```

### 2. List DNS Records
View all current DNS records (both system-locked routing records and customer records):
```bash
node tools/sitemills-cli.js domain dns list PROJECT_ID [--domain <aliasDomain>] [--host <host>]
```
Example output:
```text
RECORD ID                           TYPE    NAME                           CONTENT                             TTL     PRIORITY  SYSTEM
----------------------------------------------------------------------------------------------------------------------------------------
rec_sys_cname_01                    CNAME   www.example.com                customers.sitemills.com             300     -         LOCKED (System)
rec_sys_apex_02                     A       example.com                    192.0.2.1                           Auto    -         LOCKED (System)
rec_sys_challenge_03                TXT     _sitemills-challenge.exampl... 8f3d8a1...                          300     -         LOCKED (System)
```

### 3. Adding Third-Party DNS Records (e.g., Hostinger Setup)
When a domain is managed by SiteMills, third-party services such as **Hostinger Email**
or **Hostinger Web Hosting** can be attached by adding their DNS records:

```bash
# Add Hostinger Primary and Secondary MX Records
node tools/sitemills-cli.js domain dns add PROJECT_ID --type MX --name @ --content mx1.hostinger.com --priority 5
node tools/sitemills-cli.js domain dns add PROJECT_ID --type MX --name @ --content mx2.hostinger.com --priority 10

# Add Hostinger SPF Verification Record
node tools/sitemills-cli.js domain dns add PROJECT_ID --type TXT --name @ --content "v=spf1 include:_spf.hostinger.com ~all"

# Add Hostinger DKIM / Domain Key Record
node tools/sitemills-cli.js domain dns add PROJECT_ID --type TXT --name hostingermail-a._domainkey --content "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQ..."

# Point a subdomain (e.g., blog or mail) to Hostinger
node tools/sitemills-cli.js domain dns add PROJECT_ID --type CNAME --name blog --content connect.hostinger.com
```

### 4. Updating an Existing DNS Record
Update an existing record's content, TTL, or priority by ID or name/type:
```bash
# Update by Record ID
node tools/sitemills-cli.js domain dns update PROJECT_ID rec_12345 --content "v=spf1 include:_spf.hostinger.com include:sendgrid.net ~all"

# Update with custom TTL or Priority
node tools/sitemills-cli.js domain dns update PROJECT_ID rec_12345 --content mx1.hostinger.com --priority 10 --ttl 600
```

### 5. Deleting a DNS Record
Delete an obsolete or replaced record:
```bash
node tools/sitemills-cli.js domain dns delete PROJECT_ID rec_12345
```

### 6. Admin CLI Operations (`sitemills-admin-cli.js`)
Platform administrators and automated operational agents can inspect and manage project domains across environments (`--env dev|prod|local`) with optional raw JSON output (`--json`):

```bash
# Inspect domain status as an admin
node tools/sitemills-admin-cli.js domains status PROJECT_ID [--env dev|prod] [--json]

# List managed DNS records
node tools/sitemills-admin-cli.js domains dns-list PROJECT_ID [--domain <aliasDomain>] [--env dev|prod] [--json]

# Add a record (e.g. Hostinger MX, SPF TXT, or external CNAME)
node tools/sitemills-admin-cli.js domains dns-add PROJECT_ID --type MX --name @ --content mx1.hostinger.com --priority 5 [--env dev|prod]

# Update an existing record
node tools/sitemills-admin-cli.js domains dns-update PROJECT_ID RECORD_ID --content <NEW_CONTENT> [--ttl <TTL>] [--priority <PRIORITY>] [--env dev|prod]

# Delete a record
node tools/sitemills-admin-cli.js domains dns-delete PROJECT_ID RECORD_ID [--domain <aliasDomain>] [--env dev|prod]
```

### Security & Guardrails
- **System Record Protection**: Records essential for SiteMills platform routing (the `www` website CNAME to `customers.sitemills.com`, root apex HTTPS redirect, and `_sitemills-challenge` tokens) are marked `isSystem: true`. The CLI and backend explicitly reject attempts to modify or delete these records.
- **Type Whitelisting**: Supported record types are strictly validated: `A`, `AAAA`, `CNAME`, `TXT`, `MX`, `CAA`, `SRV`.
- **Reserved Name Filtering**: Challenge records (`_sitemills-challenge*`, `_acme-challenge*`) and website root targets cannot be overwritten.
- **Project Authorization**: All mutations require project write permissions and use Bearer tokens stored securely in `~/.sitemills/token` (file permission `0o600`). Tokens are never disclosed in command logs or error outputs.
- **Input Sanitization**: All URL parameters (`projectId`, `aliasDomain`, `recordId`) are strictly sanitized via URL encoding to prevent path traversal.
