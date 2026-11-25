# Dashboard Credits & Metering

This guide explains how SiteMills credit pools, periodic replenishment, overage protection, and dashboard meters operate.

## The Two Independent Credit Pools

SiteMills separates resource metering into two distinct pools to ensure development activity never impacts running client applications:

1. **Build Credits**:
   - **Purpose**: Consumed by AI code generation, conversational prompt modifications, visual editing, and app compilation workflows in the studio.
   - **Isolation**: Depleting build credits prevents new AI edits in the builder, but does **not** interrupt public website traffic or live application execution.
   - **Replenishment**: Refreshes on a recurring weekly schedule based on the project's tier allowance.

2. **Runtime Credits**:
   - **Purpose**: Consumed by the live site: page loads, backend calls (handlers, API routes and webhooks, with the database reads and writes inside them included), the CPU time backend code uses, scheduled jobs, queue handler runs (`ctx.queue`), `ctx.ai` calls, realtime connections and messages, live updates (SSE), uploads, the bandwidth of files the site sends ($0.10 per GB) and the files it keeps ($0.03 per GB a month). See [Plans & Pricing](pricing-and-plans.md) for each rate. A credit is worth $0.01.
   - **Isolation**: Depleting runtime credits affects application backend compute, but does **not** impact the project owner's ability to chat with the AI builder or edit code.
   - **Replenishment**: Refreshes on a recurring daily cycle (Free tier) or monthly cycle (Basic, Advanced, Ultra).

## Meter Tracking & Balances

When communicating credits and usage to users, distinguish clearly between:

- **Current Balance**: The credits currently remaining in the pool.
- **Period Allowance**: The recurring allocation granted at the start of each interval.
- **Interval**: The recurring replenishment period (`week`, `month`, or `day`).
- **Spend Rate**: Recent consumption trends across AI workflow runs or backend executions.

## Replenishment & Auto-Topup Mechanics

- **No Rollover**: Unused allowance expires at the end of each period. At renewal the balance goes back up to the allowance, or stays where it is if it's already higher, so credits bought as top-ups are used before the allowance and whatever is left of them carries over.
- **Top-Ups**: Users can purchase one-time credit top-ups in the dashboard at any time to continue operations when an allowance is exhausted before its renewal date.
- **Runtime Grace Period**: When a project's runtime credits run out, its site keeps running for a grace period: 15 minutes to 1 hour on Free, 6 to 24 hours on Basic, 12 to 48 hours on Advanced and 18 to 72 hours on Ultra, rising evenly with the project's age over its first year. The balance may go below zero meanwhile, by up to a quarter of the period's allowance, and that usage comes out of the next credits added or renewed. After the grace period the site is paused until credits are added or renew: visitors get a "This site is temporarily unavailable" page that doesn't say why, with the site's pages and files answered `503 Service Unavailable` and `Retry-After`; backend calls get `402 Payment Required`; realtime connections are closed. Preview links, which only the project's team can open, show an out-of-credits page instead. The owner and billing owner get emails when the credits run out and when a grace longer than an hour ends, the project page shows a banner, and a message from SiteMills appears in the project's Support cases (its developers see it too), closed once credits are added.
- **Auto-Topup Guardrails**: On paid plans, users can turn on auto top-up in `Dashboard > Billing`. When a pool's balance drops below the threshold, it buys that pool's configured pack within about a minute, charged to the card that pays for the plan, up to a spend limit per 30 days.
- **Credit Breakdown**: The Billing tab's Credit Usage Breakdown shows where the current period's runtime credits went, by rate: page loads, backend calls (API routes, webhooks and queue messages), connections and uploads, realtime messages, live updates, AI calls, scheduled jobs, bandwidth and file storage, each with its share of the total and, for per-use rates, how many uses. When a user asks where their credits went, point them there.
- **Low-Balance Emails**: The project's owner and billing owner get an email when runtime credits drop below 20% of the period's allowance, and again below 5% (once per period; once a week for the Free plan's daily credits).
- **Storage Limits**: Each plan has two. Database storage (50 MB on Free, 200 MB on Basic, 500 MB on Advanced, 1,024 MB on Ultra) holds the project's data, code and build output. File storage (50 MB on Free, 75 GB on Basic, 300 GB on Advanced, 600 GB on Ultra) holds uploads and the site's media and chat attachments. Before either limit is reached, the owner and billing owner get an email when database storage passes 80% of its limit and again at 95%, and when file storage passes 90%; each warning goes out at most once a week, and while usage stays past its level, only every 90 days. When database storage goes over its limit, the public site is paused until it's back under the limit or the plan is upgraded: visitors get a "This site is temporarily unavailable" page (`503 Service Unavailable` with `Retry-After`) that doesn't say why, preview links show the project's team a storage-limit page instead, and the AI builder won't start new work. When the files fill the file storage, new uploads are refused and the site keeps running. Either way, the owner and billing owner get an email, and a message from SiteMills appears in the project's Support cases, which its developers see too. The case closes itself once the project is back under.
- **File Storage Charges**: Files in file storage cost 3 runtime credits per GB per month ($0.03), charged once a day for what's stored that day. The charge is taken even when runtime credits are out, since the files are kept either way, and comes out of the next credits.
- **Site & Visitor Request Rate Limits**: All site requests (pages, assets, and backend calls) enforce per-site and per-visitor rate limits by plan and environment. Live site (`PROD`) per-site limits are 20 req/s (burst 200) on Free, 60 req/s (burst 600) on Basic, 200 req/s (burst 2,000) on Advanced, and 600 req/s (burst 6,000) on Ultra; live site per-visitor limits (by signed-in account, or client IP / IPv6 `/64`) are 5 req/s (burst 100) on Free, 10 req/s (burst 200) on Basic, 20 req/s (burst 400) on Advanced, and 50 req/s (burst 1,000) on Ultra so one heavy visitor cannot exhaust the site's allowance. Non-production environments (`DEV`, `STAGING`, Working Draft) allow 10/20/50/150 req/s (burst 100/200/500/1,500) for both site and visitor. Exceeding either limit returns HTTP `429 Too Many Requests` with `Retry-After` and `Cache-Control: no-store`.

## Related Platform Guides

- [Pricing & Subscription Plans](pricing-and-plans.md): Full breakdown of Free, Basic, Advanced, and Ultra tier allowances, quotas, and pricing.
- [Dashboard Operations](dashboard-operations.md): Overview of automated SDK capabilities versus manual dashboard actions.
- [Terms of Service](terms-of-service.md): Subscription terms, credit non-refundability, and billing cycle rules.
