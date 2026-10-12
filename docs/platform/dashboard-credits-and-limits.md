# Dashboard Credits & Metering

This guide explains how SiteMills credit pools, periodic replenishment, overage protection, and dashboard meters operate.

## The Two Independent Credit Pools

SiteMills separates resource metering into two distinct pools to ensure development activity never impacts running client applications:

1. **Build Credits**:
   - **Purpose**: Consumed by AI code generation, conversational prompt modifications, visual editing, and app compilation workflows in the studio.
   - **Isolation**: Depleting build credits prevents new AI edits in the builder, but does **not** interrupt public website traffic or live application execution.
   - **Replenishment**: Refreshes on a recurring weekly schedule based on the project's tier allowance.

2. **Runtime Credits**:
   - **Purpose**: Consumed by backend server execution, server-side TypeScript handlers, database transactions, background queues (`ctx.queue`), and scheduled jobs.
   - **Isolation**: Depleting runtime credits affects application backend compute, but does **not** impact the project owner's ability to chat with the AI builder or edit code.
   - **Replenishment**: Refreshes on a recurring daily cycle (Free tier) or monthly cycle (Basic, Advanced, Ultra).

## Meter Tracking & Balances

When communicating credits and usage to users, distinguish clearly between:

- **Current Balance**: The credits currently remaining in the pool.
- **Period Allowance**: The recurring allocation granted at the start of each interval.
- **Interval**: The recurring replenishment period (`week`, `month`, or `day`).
- **Spend Rate**: Recent consumption trends across AI workflow runs or backend executions.

## Replenishment & Auto-Topup Mechanics

- **No Rollover**: Unused periodic allowances expire at the end of each billing cycle; they do not accumulate across periods.
- **Top-Ups**: Users can purchase one-time credit top-ups in the dashboard at any time to continue operations when an allowance is exhausted before its renewal date.
- **Auto-Topup Guardrails**: Users can configure automated top-up thresholds in `Dashboard > Billing` to prevent unexpected service interruptions during high-traffic spikes.

## Related Platform Guides

- [Pricing & Subscription Plans](pricing-and-plans.md): Full breakdown of Free, Basic, Advanced, and Ultra tier allowances, quotas, and pricing.
- [Dashboard Operations](dashboard-operations.md): Overview of automated SDK capabilities versus manual dashboard actions.
- [Terms of Service](terms-of-service.md): Subscription terms, credit non-refundability, and billing cycle rules.
