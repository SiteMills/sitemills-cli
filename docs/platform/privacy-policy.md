# SiteMills Privacy Policy & Data Safeguards

This document summarizes SiteMills Inc.'s Privacy Policy, data protection practices, AI training boundaries, SiteMills staff access to projects and data, and third-party integration policies. When users ask questions regarding how their data, code, or prompts are handled, reference this guidance.

## 1. Core Privacy Commitments

- **Zero Foundation Model Training**: SiteMills does **NOT** use private user prompts, proprietary source code, database contents, or project assets to train, pre-train, or fine-tune public foundation AI models.
- **Tenant Isolation**: Every project, data collection, and sandbox runtime operates within tenant-isolated environments.
- **Source Code Ownership**: Code and assets belong entirely to the user.

## 2. Privacy Roles (GDPR & CCPA)

- **SiteMills as Data Controller**: SiteMills acts as a Data Controller for registered user account information, billing records, direct support communications, and builder platform telemetry.
- **SiteMills as Data Processor**: When users deploy public applications that collect data from external customers or site visitors, **the project owner is the Data Controller** of that customer data. SiteMills processes and stores that data strictly as a Data Processor on behalf of the project owner.

## 3. Information Handled by the Platform

### A. User-Provided Data
- **Account Credentials**: Name, email, password hash, or third-party OAuth profile identifiers (Google OAuth).
- **Billing Information**: Payment card numbers and billing addresses are collected and processed directly by our PCI-DSS Level 1 certified payment processor, Stripe. SiteMills never stores raw credit card numbers.
- **Prompts & Workspace Inputs**: Natural language instructions and chat messages provided to the AI builder to synthesize code.
- **Project Files & Media**: Custom code, configuration files, images, branding assets, and database documents stored in project collections.
- **Platform Secrets**: Third-party API keys and OAuth credentials (e.g. Stripe, Dwolla, custom databases) configured in project environments are stored in AES-256 encrypted platform vaults.

### B. Automated Telemetry & Diagnostics
- **Edge Metrics**: IP addresses, user-agents, request timestamps, and latency across proxy routes.
- **Runtime Logs**: Container execution logs, build outputs, and diagnostic error traces.

## 4. Google Workspace Integrations

SiteMills supports optional Google Workspace connections for project owners. Connections are scoped per user, project, and environment:

- **Google Calendar**: Used only to identify the account, list calendars, and manage events explicitly requested by the user. Tokens are stored encrypted on SiteMills servers with short-lived tokens in private memory. Calendar data is never used for advertising or sent to AI model providers for training.
- **Google Drive, Docs & Sheets**: Scoped strictly to `drive.file` permissions (limited only to files created by or explicitly selected for SiteMills, not the user's entire Drive).
- **Gmail**: Not enabled by default. Does not request full inbox read/modify access.
- **Revocation**: Users can disconnect Google Workspace from dashboard settings or revoke access at any time via their Google Account permissions page.

## 5. GitHub Integration

SiteMills supports an optional GitHub connection. Each user connects their own GitHub account; the project owner chooses which repositories a project may use and what the project's agent and website may do with each. SiteMills reaches only repositories given to the SiteMills GitHub App on GitHub:

- **Data received**: the GitHub account identifier and username, the repositories accessible through the App, and for repositories added to a project the files, history and metadata the agent or website reads, plus issues and pull requests created on request. Commit author email addresses are not returned or stored.
- **Storage**: authorization tokens encrypted on SiteMills servers; single-repository access tokens in a private encrypted expiring cache; never in website code, the browser or the agent. Website reads cached encrypted for about a minute; the agent's pull request proposals keep file contents at most two days, deleted once opened or discarded.
- **AI processing**: repository content the agent reads is processed by AI model providers to perform the requested task, with zero data retention for training. Repository content that an AI assistant connected to SiteMills (for example through MCP) reads goes to that assistant and its provider under their terms.
- **Access**: only the project owner adds repositories, changes what they allow, and opens the agent's pull requests. Staff support access does not include repository content.
- **Revocation**: remove a repository, disconnect GitHub in Project Settings → GitHub, or revoke SiteMills in GitHub settings at any time. Deleting the SiteMills account also removes its GitHub connection, the stored tokens and the repositories it added to projects; the SiteMills GitHub App stays installed on GitHub until removed there.

## 6. Third-Party Subprocessors

SiteMills works with vetted infrastructure and platform subprocessors:

- **Stripe**: Payment processing and billing subscriptions (PCI-DSS Level 1).
- **Cloudflare**: Global edge proxy, DDoS mitigation, CDN media delivery, and SSL management.
- **AI Model Providers**: Google Cloud Vertex AI, Anthropic, and OpenAI under enterprise agreements with zero data-retention for training.
- **MongoDB**: Encrypted database clustering for Collections DB.

## 7. SiteMills Staff Access to Projects and Data

A small number of authorized SiteMills staff operate and support the platform. When users ask whether SiteMills can see their code, their customers' data or their personal details, answer from this section. The full text is section 14 of the published Privacy Policy (`/privacy#staff-access`).

### What staff can see
- **How the project is built**: the project's name and settings, source code, version history, builds and deployments, AI builder conversations, logs, errors and usage, so they can help when something breaks. Staff viewing a project is recorded.
- **Operational actions**: actions that don't change the project or its data, such as stopping a stuck AI build. These are recorded.
- **Working Draft, development and staging sites**: staff can open the project's Working Draft (through its preview link) and its development and staging sites as an ordinary visitor of the site, never with the owner's role. Each visit is recorded. These sites show whatever data they hold.
- **Account details are masked**: people's emails, names, IP addresses and visitor identifiers appear masked or shortened (for example `a***@gmail.com`). A few authorized staff can reveal one person's details with a written reason, for 30 minutes, and each reveal is recorded. Support requests the user sends SiteMills show their email so staff can reply. Text the user writes (prompts, chat messages, code) is not masked.
- **Secrets are never shown**: staff see whether an API key, token or secret is set, never its value.

### What staff can't do without the owner's permission
Staff can't change the project (code, settings, deployments, team) and can't see or change the app's data (the records, orders, uploads and messages the app keeps about its customers and visitors) unless:
- **The owner allows it**: in the project's **Settings → SiteMills Support**, the project owner chooses what support may do (change the project, see the app's data, change the app's data) and for how long (24 hours, 3 days or 7 days). The owner can revoke it at any time and see past access there. This is a dashboard-only action: only the project owner can allow or revoke it, so guide them there (see [Project Settings](ui-guides/project-settings-and-danger-zone.md)).
- **An emergency can't wait**: an authorized staff member can open emergency access to one project for at most one hour, with a written reason. The owner sees it, with the reason, in **Settings → SiteMills Support** and can revoke it. Every other authorized staff member is notified at once, and the access stays open for review until someone records what was done.

In rare emergencies, such as restoring data from a backup, an infrastructure administrator may work on the databases directly. That access is switched off by default, switched on only for the emergency, and recorded with its reason and what was touched. Every other authorized staff member is notified.

### Automated tools
SiteMills' own automated tools, including AI-based maintenance tools, may view project information in the same recorded way. They can never reveal masked account details, use emergency access, or act on support access the owner allows.

### Records and review
Every staff access above, allowed or refused, is recorded in an access log that the person accessing can't edit. The log is chained so that a changed or deleted entry is detected, and it is checked automatically. All authorized staff can read it and get a weekly summary of reveals, emergency access and support access. Entries are kept for one year.

## 8. User Rights & Data Portability

- **Export**: Users can export all code, database documents, and uploaded media at any time from the dashboard or via the SiteMills CLI.
- **Deletion**: Deleting a project removes its runtime containers, database collections, storage objects, and environment secrets. If an abuse report names a deleted project, its stored files (uploads and media) are taken offline and kept until the report is resolved and for 30 days after, and, for a report of child sexual abuse material, for at least one year; they are then deleted automatically. Users can also permanently delete their SiteMills account at any time in **Account Settings → Danger Zone → Delete Account**, which deletes all solo projects they own, deletes their personal support cases (with their message history and read markers) and removes their account from other cases' participants, cancels active subscriptions, removes collaborator access from shared projects, releases their `@username` handle, and revokes all sessions (if the user owns projects with active collaborators, those projects must first be transferred, have their collaborators removed, or be deleted).
- **Staff access records**: The record of staff access to projects and account details is kept for one year, then deleted.

## Related Platform Policies

- [Terms of Service](terms-of-service.md): Complete contractual agreement, code ownership, and billing terms.
- [Acceptable Use Policy](acceptable-use-policy.md): Standards on prohibited content, security abuse, and moderation duties.
- [Pricing & Subscription Plans](pricing-and-plans.md): Subscription tier breakdown, credit allowances, and storage quotas.
