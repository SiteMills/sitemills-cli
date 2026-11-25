# Visitor Network Analytics

Opt in under Project Settings → Visitor Analytics: select the environment, enable
the switch and save. Project write permission is required. Disabled by default; contact SiteMills support if the feature is unavailable.

`await ctx.visitoranalytics.observe()` returns a shared `v1_` network key or null.
It accepts no address or hash. The runtime binds the address from trusted transport.
Call only after application collection/consent settings and admin exclusions pass.
Store the key on events/profile records. IPs are not unique people or devices.

`await ctx.visitoranalytics.resolve(keys)` returns up to 100 network/location records.
Only keys previously observed by this project and authorized data scope/environment
are returned. Published Production and Staging observations survive release changes
within the same environment, including unexpired observations from older releases.
DEV, Working Draft and other branch-scoped observations remain branch-isolated. Reads do
not renew the 30-day observation expiry. Protect the calling application handler with owner/admin authorization.
Never expose a generic public resolver: project authorization is not end-user
authorization. Missing, expired and unauthorized keys all produce no record.

Results contain `key`, `location`, `status`, `lookedUpAt`,
`databaseVersion`, and `expiresAt`. Location includes approximate city, region,
country, coordinates and accuracy radius where available. Pending location must
not delay analytics. An absent GeoIP database leaves locations pending.

Raw `ip` is OMITTED by default, including cached responses. Only a SiteMills
platform administrator can grant raw-IP access to a project/environment in
Project Settings → Visitor Analytics. Project secrets and request parameters
cannot enable it. Revocation takes effect on the next lookup; previously copied
data cannot be recalled. Always handle absent `ip`; show a short network key.

Resolve keys in batches on dashboard display, not during every heartbeat.
Records expire after 30 days without observation. No separate database or cache setup is required in your project.
Location is refreshed asynchronously, not a historical location snapshot.
When the platform uses DB-IP City Lite, every page displaying or using locations
must include a link to `https://db-ip.com` labeled `IP Geolocation by DB-IP`
(CC BY 4.0 attribution). Do not omit this when building a project dashboard.
Test with a permitted visit, then confirm its network appears in your protected analytics view. Missing locations should display as unavailable, without blocking the rest of the report.
