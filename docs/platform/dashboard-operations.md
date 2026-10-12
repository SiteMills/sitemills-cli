# Dashboard Operations Guide

This guide maps common dashboard requests to automation support and fallback UI steps.

## Automation-Ready Operations

- Environment variable catalog and resolution checks.
- Environment variable create, update, and delete actions.
- Team member/invite listing.
- Invite member, update member role, remove member.
- Project credit balance and tier summary.
- Owner storefront order summaries.
- Project metrics queries for visitor/traffic analysis.

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

## Non-Automated Operations (Provide UI Guidance)

Some dashboard tasks are intentionally not automated in chat tools and should return concrete navigation guidance:

- Delete project: `Settings > Danger Zone`.
- Scheduled job advanced controls and history triage.
- Full logging workflow with custom filter combinations.
- Deep AI workflow forensic inspection across attempts.

For unsupported actions, provide exact dashboard path and required fields/clicks.
