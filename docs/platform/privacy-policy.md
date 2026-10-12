# SiteMills Privacy Policy & Data Safeguards

This document summarizes SiteMills Inc.'s Privacy Policy, data protection practices, AI training boundaries, and third-party integration policies. When users ask questions regarding how their data, code, or prompts are handled, reference this guidance.

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

## 5. Third-Party Subprocessors

SiteMills works with vetted infrastructure and platform subprocessors:

- **Stripe**: Payment processing and billing subscriptions (PCI-DSS Level 1).
- **Cloudflare**: Global edge proxy, DDoS mitigation, CDN media delivery, and SSL management.
- **AI Model Providers**: Google Cloud Vertex AI, Anthropic, and OpenAI under enterprise agreements with zero data-retention for training.
- **MongoDB**: Encrypted database clustering for Collections DB.

## 6. User Rights & Data Portability

- **Export**: Users can export all code, database documents, and uploaded media at any time from the dashboard or via the SiteMills CLI.
- **Deletion**: Deleting a project removes its runtime containers, database collections, storage objects, and environment secrets.

## Related Platform Policies

- [Terms of Service](terms-of-service.md): Complete contractual agreement, code ownership, and billing terms.
- [Acceptable Use Policy](acceptable-use-policy.md): Standards on prohibited content, security abuse, and moderation duties.
- [Pricing & Subscription Plans](pricing-and-plans.md): Subscription tier breakdown, credit allowances, and storage quotas.
