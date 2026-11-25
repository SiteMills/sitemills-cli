# Dashboard Operations Guide

This guide maps common dashboard requests to automation support and modular UI navigation guides.

## Automation-Ready Operations

- Environment variable catalog and resolution checks (`agent.dashboard.env.*`).
- Environment variable create, update, and delete actions.
- Team member/invite listing, invitation, role update, and removal (`agent.dashboard.permissions.*`).
- Project credit balance and tier summary inspection (`agent.project.getCredits`, `agent.project.getBillingSummary`).
- Owner storefront order summaries (`agent.project.getOrdersReport`).
- Project metrics queries for visitor/traffic analysis (`agent.project.metrics.*`).
- Scope cloning from `prod` into non-production scopes (`agent.project.data.cloneScope('dev')`).
- Scheduled jobs inspection, pause, resume, and execution (`agent.project.jobs.*`).
- Custom domain addition, verification, and DNS records (`agent.project.domain.*`).
- Project metadata, description, marketplace tags, visibility, and encryption (`agent.project.*`).

## Mandatory Mutation Protocol

For any mutating operation:

1. Ask for explicit user approval first.
2. Announce the exact action before execution.
3. Execute the mutation only after approval.

If approval is missing or ambiguous, do not mutate.

## Scope and Access Rules

- Prefer `context.projectId` as the operation scope.
- Reject mismatched explicit project IDs.
- Enforce read or write authorization before each operation.
- Never expose secret env values in read-only status/help responses.

---

## Non-Automated Operations (Modular UI Guides)

When a user asks how to perform a task that requires direct dashboard interaction (due to payment card entry, human interactive OAuth/MFA, browser downloads, or safety double-confirmation), read the corresponding focused guide with `agent.fs.readFile('<path>')` before answering:

| Operation Category | Specific Task | Modular UI Guide |
|---|---|---|
| **Billing** | Upgrading/changing subscription tier | [`docs/sitemills-platform/ui-guides/billing-and-credits.md`](docs/sitemills-platform/ui-guides/billing-and-credits.md) |
| **Billing** | Buying extra credit packs | [`docs/sitemills-platform/ui-guides/billing-and-credits.md`](docs/sitemills-platform/ui-guides/billing-and-credits.md) |
| **Billing** | Configuring credit auto-topup | [`docs/sitemills-platform/ui-guides/billing-and-credits.md`](docs/sitemills-platform/ui-guides/billing-and-credits.md) |
| **Domains** | Purchasing new custom domains via Stripe | [`docs/sitemills-platform/ui-guides/custom-domains.md`](docs/sitemills-platform/ui-guides/custom-domains.md) |
| **Domains** | Designating canonical primary domain | [`docs/sitemills-platform/ui-guides/custom-domains.md`](docs/sitemills-platform/ui-guides/custom-domains.md) |
| **Data Management** | Exporting database collections to JSON/CSV | [`docs/sitemills-platform/ui-guides/data-management.md`](docs/sitemills-platform/ui-guides/data-management.md) |
| **Data Management** | Clearing/wiping test data scopes | [`docs/sitemills-platform/ui-guides/data-management.md`](docs/sitemills-platform/ui-guides/data-management.md) |
| **Settings** | Renaming a project (`Project Name`) | [`docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md`](docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md) |
| **Settings** | Changing a project's site address (`Site Address`) | [`docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md`](docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md) |
| **Support** | Contacting SiteMills support & viewing support cases (`/support`) | [`docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md`](docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md) |
| **Danger Zone** | Permanently deleting a project or user account | [`docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md`](docs/sitemills-platform/ui-guides/project-settings-and-danger-zone.md) |
| **Payments** | Stripe Connect KYC onboarding & banking setup | [`docs/sitemills-platform/ui-guides/stripe-payments-setup.md`](docs/sitemills-platform/ui-guides/stripe-payments-setup.md) |
| **Analytics** | Adding metric charts & saving dashboard layout | [`docs/sitemills-platform/ui-guides/analytics-and-charts.md`](docs/sitemills-platform/ui-guides/analytics-and-charts.md) |
| **Integrations** | Connecting Google Workspace (OAuth consent) | [`docs/sitemills-platform/ui-guides/integrations.md`](docs/sitemills-platform/ui-guides/integrations.md) |
| **Integrations** | Connecting Eufy Smart Locks (Captcha & 2FA) | [`docs/sitemills-platform/ui-guides/integrations.md`](docs/sitemills-platform/ui-guides/integrations.md) |
| **Integrations** | Connecting GitHub, adding repositories, and choosing what the agent and site may do with each | [`docs/sitemills-platform/ui-guides/integrations.md`](docs/sitemills-platform/ui-guides/integrations.md) |
| **Integrations** | Approving the agent's GitHub pull requests (chat card, project owner only) | [`docs/sitemills-platform/ui-guides/integrations.md`](docs/sitemills-platform/ui-guides/integrations.md) |

For unsupported actions, provide the exact dashboard path, button clicks, and required fields as outlined in the dedicated guide.
