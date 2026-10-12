# Dashboard Analytics and Tracking Semantics

This guide explains how dashboard metrics should be interpreted for user questions such as
"how many users visited my site".

## Tracking Model

Metrics events are keyed by:

- `eventType` (for example `page_view`, `api_call`, `error`)
- optional `eventName` refinement
- optional `identityType` for unique estimates (`userId`, `sessionId`, etc.)
- time range and granularity

## Query Patterns

- Event totals: use metrics aggregation for counts over time windows.
- Visitor estimates: use unique queries with explicit `identityType`.
- Trend analysis: compare adjacent windows using the same filters.

## Important Caveats

- "Users" is ambiguous unless identity type is defined.
- Unique estimates by `sessionId` are not the same as unique users.
- Short windows can undercount low-traffic sites.
- Long windows can mask spikes unless chart granularity is tightened.

## Recommended Response Style

- State which identity key was used.
- State the exact time range and timezone assumption.
- Distinguish exact totals from estimated unique counts.
- If available data is insufficient, ask a clarifying question before claiming precision.
