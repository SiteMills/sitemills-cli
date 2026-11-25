# SiteMills Subscription Plans & Pricing Catalog

This guide provides the authoritative catalog of SiteMills subscription tiers, monthly pricing, credit allowances, storage quotas, and feature capabilities.

## Subscription Tiers & Resource Matrix

SiteMills offers four subscription tiers. All limits and allowances are enforced by the platform runtime:

| Feature / Limit | FREE | BASIC | ADVANCED | ULTRA |
| :--- | :--- | :--- | :--- | :--- |
| **Monthly Price** | **$0 / mo** | **$5 / mo** | **$20 / mo** | **$40 / mo** |
| **Build Credits Allowance** | $1.00 / week | $5.00 / week | $10.00 / week | $20.00 / week |
| **Runtime Credits Allowance** | $1.00 / day | $10.00 / month | $45.00 / month | $90.00 / month |
| **Database Storage** | 50 MB | 200 MB | 500 MB | 1,024 MB (1 GB) |
| **File Storage (Object/Media)** | 50 MB | 75 GB | 300 GB | 600 GB |
| **Max Individual File Size** | 2 GB | 2 GB | 2 GB | 2 GB |
| **View Source Code** | Yes | Yes | Yes | Yes |
| **Edit Code in Browser** | No | No | Yes | Yes |
| **Upload Assets & Media** | Yes | Yes | Yes | Yes |
| **Rename Assets** | No | Yes | Yes | Yes |
| **Data Import & Export** | Yes | Yes | Yes | Yes |
| **All Platform Capabilities** | No | No | No | **Yes** |

## Credit Allowance Replenishment

- **Build Credit Intervals**: Replenished on a recurring weekly cycle. Unused build allowances expire at the end of the interval and do not accumulate.
- **Runtime Credit Intervals**: Replenished on a recurring daily cycle for Free tier, or recurring monthly cycle for Basic, Advanced, and Ultra tiers.
- **Credit Value**: A credit is worth $0.01 of usage, so the allowances above are 100 credits per dollar: Basic's $10.00 runtime allowance is 1,000 runtime credits.
- **Additional Top-Ups**: Projects can purchase one-time credit top-ups in the dashboard at any time if their usage exceeds the recurring allowance. At each renewal the balance goes back up to the allowance, or stays where it is if it's already higher, so bought credits are used before the allowance and whatever is left of them carries over; the allowance itself doesn't.
- **Runtime Credit Rates**: Each page load that reaches SiteMills costs 0.0001 runtime credits; the site's files and stored-file downloads are charged by their size only (File Bandwidth). Each custom backend call or incoming webhook costs 0.005, with database reads and writes (`ctx.db`) inside it included (no per-operation credit fee). Each scheduled job run costs 0.05. Each queue handler run (`ctx.queue`), retries included, costs 0.005; while the project is out of credits, queued messages wait and run once credits are back. Each `ctx.ai` call costs the model's charge for its tokens plus 0.05. Realtime costs 0.0005 per connection and 0.00002 per WebSocket message a client sends (0.00001 per message sent over the SSE fallback / `api/sse-client.js`, shown under Live Updates in billing). Each upload costs 0.0005. The CPU time backend code uses (handlers, API routes, webhooks, jobs, queue handlers and realtime rooms, but not time spent waiting on the database or other services) costs 0.002 per CPU-second ($0.02 per million ms), charged each hour for the hour before; like file storage, it's charged even when the credits are out and comes out of the next credits. A realtime room whose game loop keeps a fifth of a CPU busy all day uses about 35 credits a day. For scale, Basic's 1,000 monthly runtime credits cover about 200,000 backend calls that each use a few milliseconds of CPU, 10 million page loads, or 100 GB of downloads.
- **File Bandwidth**: Runtime credits also pay for the files a site hands to its visitors, at **$0.10 per GB** (0.01 runtime credits per MB). Scripts, styles, images and other files SiteMills sends are charged by their size; stored files (uploads and private downloads) by their size each time a visitor is given one. Files served from a visitor's browser cache or a CDN, and "not modified" responses, are not charged by size, and page loads are charged per request. For example, 500 downloads of a 500 MB file use 2,500 runtime credits ($25); a 5 KB script costs about 0.00005 credits per load.
- **File Storage**: Runtime credits also pay for the files a project keeps in file storage (uploads, and the site's media and chat attachments), at **$0.03 per GB per month** (3 runtime credits per GB), charged once a day for what's stored that day. The plan's file storage (50 MB, 75 GB, 300 GB or 600 GB) is the most a project can keep. The files are kept either way, so the charge is taken even when runtime credits are out, and comes out of the next credits. For example, keeping 75 GB uses 225 runtime credits ($2.25) a month.
- **Modifications to Tiers & Rates**: Plan pricing, credit allowances, and resource limits are subject to change in accordance with our [Terms of Service](terms-of-service.md). Active paid subscribers receive at least 30 days' advance notice prior to any rate increase taking effect on recurring renewals. Free tier quotas may be adjusted at any time.

## Programmatic Inspection via SDK

In `execute_sitemills_script`, agents query live subscription data using `agent.project.*`:

```typescript
// 1. Get complete catalog of all platform tiers and their resource policies
const catalog = await agent.project.getPlans();
// Returns { success: true, plans: [...], projectId, currentTier }

// 2. Get current project credit balances and allowance meters
const credits = await agent.project.getCredits();
// Returns { balance, tier, buildCredits: { balance, allowance, interval }, runtimeCredits: { balance, allowance, interval } }

// 3. Get comprehensive billing snapshot (tier, credit pools, policy limits, and capabilities)
const summary = await agent.project.getBillingSummary();
// Returns { success: true, projectId, tier, buildCredits, runtimeCredits, storage: { usage, limitMb, fileStorageLimitBytes, maxFileBytes }, capabilities }

// 4. View project billing invoice history
const history = await agent.project.getBillingHistory({ limit: 10 });
// Returns { success: true, projectId, billingEmail, limit, history }
```

## Related Platform Guides

- [Dashboard Credits & Metering](dashboard-credits-and-limits.md): How build vs runtime credit meters function in the studio and runtime.
- [Terms of Service](terms-of-service.md): Subscription renewal, cancellation, and refund policies.
- [Dashboard Operations](dashboard-operations.md): Overview of automated SDK capabilities versus UI dashboard flows.
