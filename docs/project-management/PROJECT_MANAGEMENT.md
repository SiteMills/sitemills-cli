# SiteMills Project Management & User Dashboard Guide

This guide details everything a user or development agent can do when managing a project in SiteMills. It covers the layout of the operational workspace, global controls, branch/version selectors, billing scopes, data management, and monitoring.

---

## 1. User Dashboard Overview

The User Dashboard serves as the central control room for a single SiteMills project. It integrates:
* **AI-Assisted Development**: Interactive generation and editing of source files.
* **Data Management**: Scoped key-value and collections inspection.
* **Deployments & Environment Control**: Multi-stage release pipelines (`DEV`, `STAGING`, `PROD`).
* **Operational Monitoring**: Real-time logging, metrics charts, scheduled cron jobs, and AI execution tracking.
* **Commercial & Financial Insights**: Stripe billing, storefront order stats, and credit counters.

---

## 2. Core Concepts

### Project
The top-level container for code repositories, branch trees, database records, environments, API keys, and subscription/billing scopes.

### Branch
A single path of development for code. You can fork branches, edit files inside them, compile/test them, and deploy them independently.

### Environment
Three preconfigured release stages:
1. **`DEV`**: Active development sandbox.
2. **`STAGING`**: Integration testing stage.
3. **`PROD`**: Live customer-facing production environment.

### Data Scope
The partition key SiteMills uses to separate project databases:
- **Environment scopes** (e.g., separating `PROD` database state from `STAGING` state).
- **Branch scopes** (used during automated branch testing).

### Credits
Two distinct resource meters tracked per project:
- **Build Credits**: Consumed during AI chat prompting, code generation, and esbuild bundling.
- **Runtime Credits**: Consumed by node isolates executing server-side handlers and API routes.

---

## 3. Global Control Panel

At the top and sidebar of every project view:
- **Tab Switcher**: Navigate between build interfaces, logs, database grids, and billing.
- **Branch Selector**: Set the active code branch/version for the editor, data, and jobs views.
- **Credit Meters**: Real-time indicators of remaining Build and Runtime credit balances.
- **Responsive Options**: Toggle mobile-view simulations or desktop layouts.

---

## 4. Tab-by-Tab Capabilities Reference

### 🛠️ Build Tab
- **AI Chat Panel**: Ask the assistant to write, refactor, or test code. Thread history supports branching.
- **Model & Strategy Selectors**: Choose LLM families (Gemini) and prompting strategies.
- **File Explorer**: Browse directories categorized by `PUBLIC` (assets, HTML), `SERVER` (TypeScript handlers, unit tests), and `CONTRACTS` (JSON schemas).
- **Editor & Live Preview**: Real-time TSX editor next to a hot-reloaded iframe displaying the built site.
- **Compile Status**: Compilation outcome log with detailed, line-indexed build errors.

### 🗄️ Data Management Tab
- **Data Scope Filter**: Toggle between aggregating all data or narrowing view to a specific scope.
- **Collection Directory**: Catalog of collections with document counts.
- **Records Table**: Searchable, paginated grid of keys, paths, and raw JSON payloads.
- **Write Actions**: Add new records to the active scope, edit document JSON fields, or delete single/bulk documents.

### ⚙️ Settings Tab
- **General**: Configure visibility, SEO indexing, and general project metadata.
- **Custom Domains**: Bind custom apex domains or subdomains with automatic SSL certificate issuance, GoDaddy DNS auto-configuration, and DNS challenge verification.
- **Branding**: Upload crops of banners for the project's header.
- **Payments**: Link a Stripe Connect account to process commercial sales. Toggles between Sandbox and Production modes.
- **API Keys**: Register names, resolutions, and audit scopes for environment variables. Toggles plain vs masked secrets.
- **Team Access**: Grant access roles to email addresses or revoke permissions.
- **Danger Zone**: Action buttons to permanently delete the project.

### 📊 Analytics Tab
- **KPI Metrics**: View page impressions, HTTP error rates, and backend response latencies.
- **Chart Management**: Configure visualization lookbacks, live-stream updates, and save customized chart grids.

### 🚀 Deployment Tab
- **Environment Status Cards**: Cards for `DEV`, `STAGING`, and `PROD` showing active branches and links to the live URLs.
- **Git History**: Sequential log of previous branch-level deployments.
- **Deploy Trigger**: Push the active branch to a selected environment target.

### 💳 Billing Tab
- **Plan Subscriptions**: View features across Free, Basic, Advanced, and Ultra tiers. See [docs/platform/pricing-and-plans.md](../platform/pricing-and-plans.md) for complete resource quotas and tier pricing matrix.
- **Credit Store**: Purchase top-up packets of Build or Runtime credits. See [docs/platform/dashboard-credits-and-limits.md](../platform/dashboard-credits-and-limits.md).
- **Transaction Logs**: Export invoices for past subscription renewals and top-ups.
- **Rate Modifications & Policies**: Free tier allowances may be modified, throttled, or discontinued at any time. Active paid subscriptions require at least 30 days' advance notice before rate increases or quota reductions take effect on recurring renewals under our [Terms of Service](../platform/terms-of-service.md).

### 🛍️ Payments Tab
- **Storefront Dashboard**: Displays sales charts, total transaction volumes, and average order values.
- **Product Sales**: Identifies top-performing products by volume and total earnings.
- **Orders Directory**: Searchable history of recent customers, transaction IDs, and fulfillment statuses.

### ⏰ Scheduled Jobs Tab
- **Job Configuration**: Define chronologies inside `contracts/jobs.json`, set schedules via local timezone inputs, or launch jobs manually.
- **Job Orchestration**: Pause, resume, or trigger active cron loops on `DEV`, `STAGING`, or `PROD` instances. View historical run logs (cadence, execution time, completion status).

### 📝 Logging Tab
- **Stream Viewer**: Real-time log capture (buffered for the last 1 hour).
- **Filtering**: Query logs by level (`DEBUG`, `INFO`, `WARN`, `ERROR`), source (`application` vs `unit tests`), or regex search fields.

### 🤖 AI Workflows Tab
- **Workflow Pipeline**: List of background asynchronous AI jobs.
- **Details Modal**: Expand prompt sequences, responses, token counters, callback statuses, and credit charges.

### 📋 Tasks, Bugs & Queues Tab
- **Kanban Task Board**: Visual agile workflow organized across `ASSIGNED`, `IN_PROGRESS`, and `FIXED` columns. Supports drag-and-drop transitions, priority tagging (P0-P4), member assignees, and quick task creation.
- **Dedicated Tickets & Requests Queue**: Filterable view isolating inbound issues, bug reports, and user feature requests.
- **Backlog & Sprint History**: Unassigned task backlogs and chronological history of completed tasks.
- **Structured Categories**:
  - `FEATURE`: Planned sprint features and engineering deliverables.
  - `FEATURE_REQUEST`: Inbound feature proposals and enhancement ideas requested by users, agents, or CLI.
  - `INFRA_DOWN`: Critical service or platform downtime (P0).
  - `PLATFORM_BUG`: Core platform defects, unhandled service errors, or API contract mismatches (P1).
  - `AGENT_ERROR`: Runner, pipeline, or agentic loop exceptions and tool execution failures (P1).
  - `USER_CODE_BUG`: Issues identified within the project's frontend or backend TypeScript handlers (P2).
  - `USER_CONFIG_ERROR`: Misconfigured environment variables, custom domain DNS, or contract specifications (P2).
  - `USER_SUPPORT`: User inquiries and operational assistance requests (P2).

---

## 5. Managing Tasks & Tickets via the CLI

Developers and AI agents can query, create, and update tasks and tickets directly from the CLI:

### 5.1 Listing Tasks
Fetch the project's task board, with optional filtering by category or status:
```bash
# List all tasks across board
sitemills-cli list-tasks <projectId>

# List only feature requests
sitemills-cli list-tasks <projectId> --category FEATURE_REQUEST

# List only open bugs
sitemills-cli list-tasks <projectId> --category USER_CODE_BUG --status ASSIGNED
```

### 5.2 Adding Tasks & Submitting Tickets
Create a sprint task, report an issue, or submit a feature request:
```bash
# Create a standard sprint feature task
sitemills-cli add-task <projectId> "Build checkout modal" "Implement Stripe checkout drawer" --priority 2

# Submit a feature request
sitemills-cli add-task <projectId> "Add dark mode toggle" "User requested dark mode in top navigation" --category FEATURE_REQUEST --priority 3

# Report a platform or agent error
sitemills-cli add-task <projectId> "500 Internal Server Error in push" "Cloud compilation failed with internal error" --category PLATFORM_BUG --priority 1

# Report user code bug
sitemills-cli add-task <projectId> "Null pointer in user_service.ts" "Cannot read properties of undefined on line 42" --category USER_CODE_BUG --priority 1
```

### 5.3 Updating Task Status & Assignment
Update status, priority, category, or assignee as work progresses:
```bash
# Move task to IN_PROGRESS and assign to yourself
sitemills-cli update-task <projectId> TASK-1234 --status IN_PROGRESS --assignee dev@example.com

# Mark task as FIXED upon completion
sitemills-cli update-task <projectId> TASK-1234 --status FIXED

# Change task priority or category
sitemills-cli update-task <projectId> TASK-1234 --priority 1 --category PLATFORM_BUG
```
