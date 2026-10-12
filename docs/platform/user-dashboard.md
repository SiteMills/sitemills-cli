# SiteMills User Dashboard Guide

This guide explains what users can access in the User Dashboard, what each tab does,
and how core concepts (like data scopes and environments) work in SiteMills.

## User Dashboard at a Glance

User Dashboard is the operational workspace for a single project. It combines:

- AI-assisted build and code editing
- Data management and inspection
- Deployment and environment control
- Billing, payments, logs, jobs, and workflow observability

Main navigation tabs:

- Build
- Data Management
- Settings
- Analytics
- Deployment
- Billing
- Payments
- Scheduled Jobs
- Logging
- AI Workflows

## Core Concepts

### Project

A project is the top-level container for your app, code, data, deployments,
and billing policy.

### Branch

A branch is an editable line of development for a project. Branches can be
deployed independently to environments.

### Environment

SiteMills uses three environment labels:

- `DEV`
- `STAGING`
- `PROD`

Branches can be deployed to one or more of these environments.

### Credits

SiteMills tracks two credit pools:

- Build credits: consumed by AI/code generation workflows.
- Runtime credits: consumed by runtime/backend activity.

### Preview Branches & Preview Tokens

Preview subdomains (`https://<projectId>--<branch>.<domain>/`) and non-production environments (`DEV`, `STAGING`) are private and developer-gated by default. 

To allow testing with unauthenticated users, different test accounts, or external reviewers who do not have SiteMills accounts, preview URLs automatically include a `preview_token` query parameter. This token grants scoped preview access and establishes a temporary bypass cookie for seamless navigation. See [preview-branch-tokens.md](docs/platform/preview-branch-tokens.md).

### What is a data scope?

A data scope is the partition key SiteMills uses to separate project data.

In practice, a data scope can be:

- An environment scope (`DEV`, `STAGING`, `PROD`)
- A branch scope (branch identifier)

This lets you keep development/staging/production data isolated and avoid
cross-environment contamination.

Data Management lets users inspect data by scope, and backend/runtime writes
can target specific scopes. Users can view, edit, and remove data by scope,
and new data appears in the scope where it was written.

## Global Controls in User Dashboard

Across tabs, users can access:

- Sidebar tab navigation
- Branch/version selector
- Build/runtime credit meters
- Mobile/desktop responsive controls
- Back to Dashboard action

## Tab-by-Tab Reference

### Build

Purpose:

- Build and modify the app with AI chat, file explorer, code editor, and live preview.

What users can see:

- AI chat panel with thread switching/forking
- Model selector and prompt strategy controls
- File explorer sections (`PUBLIC`, `SERVER`, `ASSETS`, `DOCUMENTATION`)
- File history panel for selected file
- Editor tabs and preview frame
- Compile/build status indicator and details modal

What users can do:

- Ask AI to generate or modify project files
- Open/edit files (tier-dependent), including code and assets
- Use undo/redo and file history restoration
- Switch between code and live preview modes
- Refresh preview or open preview in a new tab
- Trigger build/deploy action from compile controls

Access note:

- Free-tier projects may keep preview access while code editing is locked.
- Preview URLs opened in a new tab or copied include `preview_token` to permit testing with unauthenticated sessions, incognito windows, or external collaborators without SiteMills accounts.

### Data Management

Purpose:

- Inspect and manage project data records by scope and collection.

What users can see:

- Data Scope selector (`All Scopes` + specific scopes)
- Collection list and quick stats
- Paginated table: key/path, scope, collections, actions

What users can do:

- Filter data by scope
- Filter by collection
- Search keys/data
- View record details
- Add new records in the selected scope
- Edit JSON payloads for existing records
- Delete one or many records
- Clear all records for selected scope
- Export scoped data

Data-scope behavior:

- Selecting `All Scopes` aggregates records across scopes.
- Selecting one scope narrows browsing/editing/deletion actions to that scope.
- New records are written into the active scope.

### Settings

Purpose:

- Configure project-level behavior, integrations, team access, and safety actions.

Sections and capabilities:

- `General`: project visibility and indexing toggles.
- `Branding`: upload/remove project banner (center-cropped and optimized).
- `Payments`: Stripe Connect setup, mode selection (`Sandbox` or `Production`), onboarding status.
- `API Keys`: create/delete environment keys, preview environment resolution, descriptions, audit metadata.
- `Team Members`: invite users, update member role, remove member (permission-gated).
- `Share Project`: copy share link.
- `Notifications`: notification preference toggles.
- `Danger Zone`: delete project permanently.

API key concept:

- Keys are managed by name + environment scope (`GLOBAL`, `DEV`, `STAGING`, `PROD`, etc.).
- Preview resolution shows which scoped value is active for the selected environment.

### Analytics

Purpose:

- Visualize project metrics over time with configurable charts.

What users can see and do:

- KPI cards (page views, latency, errors)
- Adjustable lookback, end time, and aggregation
- Live mode toggle and live-head jump
- Time-window navigation (previous/next)
- Zoom/pan charts and reset zoom
- Add/remove charts
- Configure chart event types and grouping (`eventType` or `eventName`)
- Save dashboard chart configuration per project

### Deployment

Purpose:

- Manage branches and deploy them to environments.

What users can see:

- Environment cards (`DEV`, `STAGING`, `PROD`) with deployment status and open-site links
- Branch list with metadata and deployment badges
- Deployment history

What users can do:

- Open branch details
- Open selected branch in Build editor
- Fork new branches
- Deploy selected branch to an environment

### Billing

Purpose:

- Manage subscription tier, credits, and usage.

What users can see and do:

- Plan comparison (Free, Basic, Advanced, Ultra)
- Current tier and entitlement summary
- Build/runtime/storage usage meters
- Buy extra build/runtime credits
- Upgrade/downgrade subscription via checkout
- View billing-side payment history for subscriptions and credit purchases

### Payments

Purpose:

- Monitor project storefront order and revenue performance.

What users can see and do:

- Revenue and order summary cards
- Top products table
- Recent orders table
- Refresh insights
- Jump to `Settings > Payments` for Stripe setup actions

### Scheduled Jobs

Purpose:

- Configure branch job manifests and control runtime execution.

Configuration capabilities (branch-scoped):

- Select branch context
- Read/edit scheduled jobs configuration
- Add, edit, remove jobs
- Set trigger mode (`SCHEDULE` or `MANUAL`)
- Build cadence in local time and save as UTC cron
- Run job immediately from config rows

Runtime capabilities (environment-scoped):

- Choose active environment (`DEV`, `STAGING`, `PROD`)
- View runtime-registered job list and metrics
- Run now, pause, resume
- View recent run history (status, trigger, duration, reason)

### Logging

Purpose:

- Inspect recent runtime logs for debugging.

What users can see and do:

- Log stream limited to the last hour
- Filter by branch
- Filter by level (`DEBUG`, `INFO`, `WARN`, `ERROR`)
- Filter by log group (application logs, test logs, all)
- Regex search across log message/context fields
- Expand/collapse long structured logs
- Copy full log messages
- Auto-refresh at a short interval

### AI Workflows

Purpose:

- Observe asynchronous AI workflow processing for the project/branch.

What users can see and do:

- Workflow list with status chips and timestamps
- Filters (`All`, `Active`, `Failed/Timed Out`)
- Summary totals (active/completed/failed, credits)
- Prompt/response previews (expandable)
- Attempt counters, token usage, callback route, workflow ID
- Copy prompt/response text

## Permissions and Visibility Notes

- Some actions are tier-gated (for example, code editing).
- Some actions are role/permission-gated (for example, member role updates/removals).
- Environment-sensitive features (deployments, jobs, keys, payments mode) are intentionally scoped.

## Recommended User Workflow

1. Build and test changes in `Build` on a branch.
2. Validate data behavior in `Data Management` with the correct scope.
3. Configure required keys and integrations in `Settings`.
4. Check metrics/logs/workflows in `Analytics`, `Logging`, and `AI Workflows`.
5. Deploy branch via `Deployment` to target environment.
6. Monitor costs and credits in `Billing` and commercial performance in `Payments`.
