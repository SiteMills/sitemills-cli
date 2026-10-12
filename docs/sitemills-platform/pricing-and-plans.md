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
| **Data Import & Export** | Yes | No | Yes | Yes |
| **All Platform Capabilities** | No | No | No | **Yes** |

## Credit Allowance Replenishment

- **Build Credit Intervals**: Replenished on a recurring weekly cycle. Unused build allowances expire at the end of the interval and do not accumulate.
- **Runtime Credit Intervals**: Replenished on a recurring daily cycle for Free tier, or recurring monthly cycle for Basic, Advanced, and Ultra tiers.
- **Additional Top-Ups**: Projects can purchase one-time credit top-ups in the dashboard at any time if their usage exceeds the recurring allowance.
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
