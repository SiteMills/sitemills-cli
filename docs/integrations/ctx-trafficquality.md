# ctx.trafficquality

Read-only traffic-quality integration. Enable per environment in Project Settings → Traffic Protection. Only a platform superadmin can change monitoring, allowlists, route declarations, or IP/range enforcement. Project secrets and project handlers cannot grant themselves enforcement authority.

```ts
const report = await ctx.trafficquality.report(networkHashes); // optional array, max 100
// { enabled, labelLikelyBots, events: [{key,label,reason,count,missingBrowserCount,likelyBot,firstSeen,lastSeen}], partial }
```

Protect your report handler with your application's admin authorization. Never expose this report publicly. Results are restricted to the current project and deployed environment scope. No raw IPs, request URLs, query values, cookies, form contents, or user-agent strings are returned. Keys match Visitor Network Analytics hashes; absence of evidence does not prove a human visitor. Shared IPs do not identify a person.

Labels: `verified_crawler`, `claimed_crawler`, `unusual_request`, `suspected_attack`. Claimed crawlers are unverified, not proven spoofers. Unknown routes and parameters are weak evidence and never trigger automatic bans. Short visits and missing visible-time measurements are not attack evidence. Verified crawler classification requires current operator-provided vendor CIDRs matching the crawler claim.

Evidence is retained 30 days and returned newest first, capped at 500 records; check `partial`. This is a server request report, not browser session/engagement totals. One evidence record aggregates a reason/network in a ten-minute window. SDK methods for blocking or writing evidence deliberately do not exist.

The superadmin-only per-project/environment **Label likely bot networks** checkbox enables derived `events[].likelyBot` values. Join by `key` to filter project analytics. This is independent of automatic bans and preserves the underlying reason. Repeated suspicious probes qualify; generic route/query mismatches also need repeated absent User-Agent evidence. No browser type in analytics, short visits, or ordinary repeated pages alone do not qualify. `likelyBot:false` is not proof of a person. Keep verified and claimed crawlers separately filterable. Turning the checkbox off removes derived labels without deleting evidence.
