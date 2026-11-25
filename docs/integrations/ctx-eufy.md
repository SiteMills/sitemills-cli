# Eufy Security integration

Eufy Security provides the `ctx.eufy` server API, browser helper, dashboard project settings, and deterministic test mocks. Any website can use it. One Eufy account is saved per project and deployed website environment (`DEV`, `STAGING`, `PROD`). The Working Draft and checkpoints cannot connect to saved accounts.

This release supports login, captcha, verification codes and device discovery using an **unofficial** third-party Eufy integration SDK. It supports administrator-requested camera snapshots, bounded WebRTC live viewing when TURN is configured, and separately permissioned on-demand lock/unlock commands (`lockDoorNow`, `unlockDoorNow`) on verified T85D0 locks. It does not implement payment-triggered residential access changes. SDK-reported capabilities are not proof of compatibility with a physical device.

## Account setup in a client website

A website admin can enter the account directly in the website's settings. No Sitemills dashboard visit is required. Use the native client helper, served through the same runtime asset mechanism as other browser clients:

```javascript
import { eufy } from '../api/eufy-client.js';

await eufy.saveAccount({ email, password, countryCode: 'US' });
// Clear password input immediately after submission, including failures.
let status = await eufy.connect();
// Poll eufy.status() every 2–3 seconds while CONNECTING.
// For CAPTCHA_REQUIRED show challengeImage and collect characters:
status = await eufy.verifyCaptcha({ answer });
// For VERIFICATION_REQUIRED collect the code from Eufy:
status = await eufy.verifyCode({ answer });
```

Do not send passwords or verification codes through generated backend handlers, store them in client collections/browser storage, or log them. The native endpoints bypass handler invocation traces. The platform stores the password in the encrypted project keystore. There is no credential-read endpoint. Saving replaces the environment's prior account and ends its discovery session; `{saved:true}` means the details were saved, not that Eufy accepted the login.

Native routes derive project/environment from trusted host routing and actor from the signed website cookie. Mutations require an exact same-origin request. Bodies reject project, environment, scope and actor overrides. The runtime applies its integration invocation rate gate. Requests and responses must not be cached. Use `credentials:'same-origin'`, `redirect:'error'`, JSON content type, and a bounded timeout when calling the endpoints without the helper.

### Website permissions

Every native endpoint and `ctx.eufy` call checks `eufy:manage` on `integrations:eufy`. Project owners' wildcard grants cover this. A website's admin role can receive just this action/resource through the existing permissions integration; being named “admin” or hiding a form does not confer access. Grant it only to people authorized to manage the security account. There is no hardcoded website, email address or platform superadmin requirement.

An interactive challenge belongs to the initiating admin. Another authorized admin cannot view or answer it, but can disconnect an abandoned session. Authorized managers can view completed discovery. Replacing/removing an account is sensitive: render a clear confirmation before removal.

## Browser and dashboard HTTP APIs

Client website base: `/api/v1/eufy` (website login cookie and host routing).

Sitemills dashboard base: `/api/v1/dashboard/eufy/connect/projects/{projectId}` with required `?siteEnvironment=DEV|STAGING|PROD`. These endpoints use the standard token validator and project-owner authorization. Project readers/developers cannot manage a security account. The dashboard Settings → Eufy Security card uses these endpoints and the same shared account service as client websites.

| Method | Suffix (both bases) | JSON body | Result |
| --- | --- | --- | --- |
| GET | `/status` | none | Status, including `configured` |
| POST | `/credentials` | `{email,password,countryCode}` | `{saved:true}` |
| POST | `/connect` | `{}` | Start/reuse saved login; status |
| POST | `/verifyCaptcha` | `{answer}` | Continue captcha challenge; status |
| POST | `/verifyCode` | `{answer}` | Continue verification; status |
| POST | `/discover` | `{}` | Refresh discovered devices; status |
| POST | `/disconnect` | `{}` | End session, erase cached login tokens; keep saved credentials |
| POST | `/removeAccount` | `{}` | Disconnect and delete this environment's saved credentials; `configured:false` |

`connect` is the manifest's enable/setup operation: no separate feature flag or billing plan is introduced. Each environment requires explicit account setup; GLOBAL or other-environment secrets are never used as fallback. Platform activation and per-project account setup are separate states.

## Backend SDK

```typescript
await ctx.eufy.status();
await ctx.eufy.connect();
await ctx.eufy.verifyCaptcha({ answer });
await ctx.eufy.verifyCode({ answer });
await ctx.eufy.discover();
await ctx.eufy.disconnect();
await ctx.eufy.lockDoorNow({ serial });
await ctx.eufy.unlockDoorNow({ serial });
```

Use native browser verification routes for interactive forms so answers do not pass through generated handler logs. `ctx.eufy` remains available for trusted server logic with standard permissions and usage metrics. Discovery options accept `answer` only for verification. Access methods accept the explicitly documented options below. Credential setup/removal is intentionally on the native endpoints rather than `ctx.eufy`.

### Status and errors

States: `UNAVAILABLE`, `DISCONNECTED`, `CONNECTING`, `CAPTCHA_REQUIRED`, `VERIFICATION_REQUIRED`, `CONNECTED`, `ERROR`. Poll during `CONNECTING`; stop on failure or unmount. Platform not configured returns `available:false` on status and fails mutations. Native/dashboard status also returns `configured` to distinguish saved credentials from a live session. `expiresAt` is epoch milliseconds.

`challengeImage` is an allowlisted PNG/JPEG data URI. `devices` contain only `serial`, `name`, `model`, `stationSerial`, `deviceClass`, `capabilities`, `capabilityStatus`, `controlsEnabled:false`, and optional `details` (device health and available snapshot methods). `capabilityStatus` is `SDK_REPORTED` or `UNAVAILABLE`. Unsupported capability inspection still returns the device/model. An empty device list with `CONNECTED` means the provider returned no devices; errors never masquerade as connected accounts.

HTTP failures: 400 malformed request or a call from the Working Draft or a checkpoint, 401 unauthenticated, 403 missing permission/origin mismatch, 429 runtime rate limit, 503 unavailable dependency. Provider/lifecycle failures return `state:'ERROR'` with fixed codes such as `ACCOUNT_CHANGED`, `ACCOUNT_NOT_CONFIGURED`, `CONNECTION_BUSY`, `LOGIN_COOLDOWN`, `CONNECT_FIRST`, `NO_MATCHING_CHALLENGE`, `VERIFICATION_LIMIT`, `CONNECTION_OWNED_BY_ANOTHER_ADMIN`, `SESSION_EXPIRED`, `CONNECTION_FAILED` or `SERVICE_UNAVAILABLE`. Treat them as failures even on HTTP 200; show actionable text, not raw provider errors.

## Tests

The existing project `runTests()` framework mocks `eufy` by default. Override with `integrations.mock('eufy.status', ...)` to exercise connected/challenge/error UI states. Mock success is not evidence of real account compatibility.

## Sign-in sessions and limits

A sign-in challenge (captcha or two-factor code) lasts at most 15 minutes, and each session allows five verification attempts. If a challenge expires or SiteMills restarts during one, the owner connects again; a completed sign-in is kept and reused. Account passwords are stored only in the project keystore and are never returned to the browser. The minimum login cooldown is 60 seconds, and cooldowns Eufy imposes are honored for up to 24 hours. This is interactive discovery, not a background monitor or scheduler. Real Eufy login, MFA and physical-device compatibility need a test with the owner's own account: mocked tests don't show them.

## Device health and camera images

`status()` / `discover()` return optional `details` per device: `observedAt`, `batteryPercent`, `charging`, `cameraEnabled`, `lockState` (`LOCKED`, `UNLOCKED`, `UNKNOWN`), `lockControlAvailable` (boolean, true on verified T85D0 locks exposing the SDK lock capability), `firmwareVersion`, `snapshotLive`, `snapshotStored`, and `accessCodes:T85D0_PIN_MANAGEMENT|T85L1_PIN_MANAGEMENT|UNSUPPORTED`. Unknown readings are absent/null, never inferred as online or unlocked. These are cloud/SDK-reported values, not a fresh physical-state guarantee. `controlsEnabled:false` refers to generic SDK device controls; verified T85D0 lock/unlock capability is reported via `details.lockControlAvailable`.

Images use native browser/dashboard endpoints only, keeping images out of generated handler traces. They use the same authorization, trusted project/environment context and no-store response contract as account setup. No media request is made by discovery.

| POST suffix / helper method | Body | Result |
| --- | --- | --- |
| `configureCameras` | `{serials:[...]}` | Save explicit viewing allowlist; discovery status |
| `cameraSnapshot` | `{serial,kind:'LIVE'|'STORED'}` | `{requestId,state:'PENDING',expiresAt}` |
| `cameraSnapshotStatus` | `{requestId}` | PENDING, READY, ERROR, or expired/not found |
| `cancelCameraSnapshot` | `{requestId}` | CANCELLED; abort and discard image |

Only discovered cameras in the saved allowlist can be viewed. Start with no enabled cameras, then let an authorized manager choose them. The allowlist is per project/environment/account, expires after one year, and resets when account credentials are replaced/removed. Disconnect preserves it. Native status returns `enabledCameraSerials`.

Poll a pending image every two seconds. READY includes a bounded JPEG `image` data URI, `source:LIVE|RETAINED`, `retrievedAt` and `expiresAt`. RETAINED does not have a known capture timestamp: never label it live. A LIVE request may return RETAINED when the SDK cannot capture fresh media. The service keeps at most one result per account session, clears images after 60 seconds and never persists images to cache or disk. Clear browser images on expiry, logout and component unmount. Cancel active requests when leaving the page. Request IDs are bound to project, session and initiating actor.

Captures have a 30-second timeout, two simultaneous operations per service, one per account, ten seconds between starts, and a 512 KiB image limit. Fixed errors include CAMERA_NOT_ENABLED, CAMERA_DISABLED, CAMERA_BUSY, CAMERA_COOLDOWN, SNAPSHOT_UNSUPPORTED, SNAPSHOT_NOT_FOUND, SNAPSHOT_UNAVAILABLE, SNAPSHOT_TIMEOUT, SNAPSHOT_INTERRUPTED and IMAGE_TOO_LARGE. An image error does not invalidate a successful account login. Live snapshots are decoded on the server; there is no public streaming ingress or public media URL.

An authorized, validated live start reserves its account before interrupting pending preview images, including requests from other tabs. The original preview caller sees `SNAPSHOT_INTERRUPTED`; it does not lose account access. New snapshots on any camera in that account return `CAMERA_BUSY` while a live view is reserved or active. Cancelled previews release their busy reservation promptly even if a provider promise settles late. Stop closes the live reservation, allowing previews again subject to the normal cooldown. Invalid or unauthorized live starts do not interrupt previews.

## Access lists and four-digit PIN management

Exact models **T85D0 (C30)** and **T85L1 (C32)** are enabled. T85D0C remains unsupported. Owner credentials and users with mixed fingerprint/PIN entries remain protected. Do not infer PIN support from generic SDK lock capabilities. On-demand lock/unlock (`lockDoorNow`, `unlockDoorNow`) is separately indicated by `details.lockControlAvailable` on verified T85D0 locks.

Native browser and dashboard endpoints share the table below (all POST, same existing authorization/Origin/no-store controls). Browser helper names match suffixes.

| Method | Body | Result |
| --- | --- | --- |
| `listAccessUsers` | `{serial}` | `{requestId,serial,state:PENDING,entries:[]}` |
| `accessUsersStatus` | `{requestId}` | PENDING / READY / ERROR; READY entries have `entryId,name,role,editable` |
| `rotateExistingAccessCode` | `{serial,entryId}` | `{plan}`; replace one selected regular PIN with a new random four-digit PIN |
| `listAccessPlans` | `{}` | `{plans:[...]}`; metadata only |
| `createAccessPlan` | `{reference,serial,label,purpose,timeZone,pinLength:4,startsAt,endsAt}` | `{plan}`; starts background installation |
| `rotateAccessCode` | `{planId}` | `{plan}`; random replacement, existing schedule retained |
| `removeAccessPlan` | `{planId}` | `{plan}`; delete only a website-created scheduled user |
| `reconcileAccessPlan` | `{planId}` | `{plan}`; readback/reconcile a known user after interruption |
| `revealAccessCode` | `{planId}` | `{planId,pin}`; **native only**, confirmed current PIN only |

Poll directory status or plan lists every 2–3 seconds while pending. Access entries are account/session scoped and expire after five minutes. Select names using their opaque `entryId`, never name alone: duplicate names are possible. Owner/master, non-PIN and unnamed entries are protected. An existing member replacement verifies the exact user, name, permission and password identifier before writing, and checks unchanged access metadata afterward. Existing plaintext codes are never retrievable. Code values must remain only in transient admin UI memory; clear on hide, navigation and timeout. Do not send them through generated handlers, URLs, logs, storage or analytics.

`ctx.eufy` exposes **listAccessPlans, createAccessPlan, rotateAccessCode, removeAccessPlan, reconcileAccessPlan** to backend handlers. It deliberately excludes directory mutation and PIN reveal. Responses use a closed metadata projection and never include a PIN. Every method requires the signed user's `eufy:manage` permission; unattended jobs do not gain account authority automatically.

```typescript
const result = await ctx.eufy.createAccessPlan({
  reference: 'confirmed-booking-123:front-door', serial: verifiedSerial,
  label: 'Guest name', purpose: 'VACATION', timeZone: 'America/New_York',
  pinLength: 4, startsAt: '2027-01-15T20:00:00.000Z', endsAt: '2027-01-17T16:00:00.000Z'
});
// Persist/show metadata only. Poll listAccessPlans; reveal in the native admin UI.
```

Purposes are `VACATION` and `STAFF`. Timestamps must be UTC ISO strings at minute precision, interpreted in the explicitly provided IANA zone. Start may be at most ten minutes past; duration is at most 180 days, end at most 366 days ahead. Ambiguous repeated daylight-saving hours are rejected. Website business logic must enforce confirmed booking dates and verified door/property association. A staff shift is one bounded window, not a recurring weekly schedule. Four-digit PINs are generated by default. Native `createAccessPlan`, `rotateAccessCode` and `rotateExistingAccessCode` accept an optional `pin` string of exactly four ASCII digits, preserving leading zeros. Send chosen PINs directly through the native helper, never through generated handler inputs/traces. Confirmation and the existing `codes:write` permission still apply; PINs never enter audit events. Replacing a known PIN with the identical value returns ACCESS_PIN_UNCHANGED. Reusing a reference with the same options is idempotent; different options conflict.

The full validity window is installed on the lock immediately. Activation/expiry is handled by its clock, independent of the 15-minute website session. Verify the lock's time zone/clock and first scheduled activation/expiry physically; acknowledgment and date/time readback do not prove physical expiry. C30 firmware may omit validity mode in readback. Expired metadata is retained, but PIN retrieval is disabled; removing a record explicitly removes its device user. No payment status triggers a residential lockout.

Plans report `PENDING`, `ROTATING`, `REMOVING`, `VERIFYING`, `INSTALLED`, `EXPIRED`, `REMOVED` or `NEEDS_REVIEW`. Only INSTALLED permits reveal. One access operation runs per account. An encrypted durable journal is written before each mutation, bound to project/environment/account and fenced by the connection lease; retention is two years. Reconnect/restart keeps plans; account replacement isolates the prior account's plans. Unknown writes are never automatically retried. Readback cannot verify a PIN value: a lost change-PIN acknowledgment requires manual checking; reconciliation refuses that ambiguous phase. User/cloud cleanup follows device-confirmed removal. Never report a pending or unknown command as success.

Fixed access errors include `ACCESS_BUSY`, `ACCESS_LIST_EXPIRED`, `ACCESS_LIST_UNAVAILABLE`, `ACCESS_OWNER_PROTECTED`, `ACCESS_MODEL_UNSUPPORTED`, `ACCESS_REFERENCE_CONFLICT`, `INVALID_ACCESS_WINDOW`, `AMBIGUOUS_ACCESS_TIME`, `ACCESS_DEVICE_REJECTED`, `ACCESS_RECORD_CHANGED`, `ACCESS_READBACK_FAILED`, `ACCESS_RESULT_UNKNOWN`, `ACCESS_MANUAL_CHECK_REQUIRED`, and `ACCESS_CODE_UNAVAILABLE`.

## Property authorization and superadmin change logs

The integration entry permission remains `eufy:manage`. It alone **does not authorize property operations**. Website superadmins have `eufy:admin` on `integrations:eufy`; ordinary admins/members need exact `eufy:property:<action>` permissions on `integrations:eufy:properties:<houseId>`. Supported actions: `view`, `access:list`, `codes:write`, `codes:delete`, `codes:reveal`, `access:rename`, `cameras:view`, `settings:view`, `settings:write`, `lock:operate`, `lock:unlock`. Server-side authorization resolves the target property from provider state, checks the signed actor against project permissions, and applies only server-derived grants. Caller-supplied authority, actor or property overrides are rejected. The provider independently applies these grants and rechecks current cloud membership for scoped device operations. Inventory and plan lists are filtered; unassigned devices are visible only to superadmins.

Eufy `house_id` determines membership; `get_house_list` supplies names. Duplicate names remain distinct IDs. Discovery fails visibly if property discovery fails; it never guesses membership from device names. `status` includes `properties`, each device's `propertyId`, `superadmin`, and `propertyPermissions` for rendering controls. `listProperties()` (native POST, empty body) returns only permitted groups. Account credential changes/removal, account disconnect and camera allowlist configuration require superadmin. Saved-account reconnect remains available to permitted members.

Custom website role creation/assignment uses the permissions integration's **listSecurityRoles / saveSecurityRole / deleteSecurityRole / assignSecurityRole / revokeSecurityRole** methods. These use the existing RBAC store and evaluator, separate website-only endpoints and strictly limited Eufy actions. Platform role conditions are unchanged. Only website superadmins can manage those roles.

Additional native operations:
- `removeExistingAccessCode({serial,entryId})`: select a regular member from a fresh access list and remove that member from this lock. Requires `codes:delete`. The service refuses owner/master entries and ambiguous users with multiple credential records; it verifies device removal before deleting device-specific cloud metadata. No other door is modified.
- `renameAccessEntry({serial,entryId,label})`: change the **website display name**, requiring `access:rename`. It preserves the original Eufy name/schedule and sends no physical command. Labels are encrypted and matched to exact user/password IDs plus original provider name; stale matches are not reused. A device-level rename is deliberately not implemented because the provider command also rewrites schedule data.
- `listAccessAudit()` (empty body): superadmin-only, latest 200 events. Events contain ID, time, signed actor, operation, plan ID, lock serial/property ID, person label, outcome and fixed error; never PINs, account credentials or raw provider data. A durable REQUESTED event precedes mutation; CONFIRMED or NEEDS_REVIEW records the outcome. Native PIN reveals are recorded as REVEALED. Events are append-only through this API, encrypted and account scoped; retention is the latest 10,000 events or two years. There is no audit deletion endpoint. This logs website operations from this release onward, not changes performed in the official app or historic manual probes.


### Individual camera permissions

Custom website roles accept optional `deviceSerial` on a grant:

```js
await ctx.permissions.saveSecurityRole({name: 'Entrance camera viewer', grants: [
  {propertyId: groupId, deviceSerial: cameraSerial, permissions: ['cameras:view']}
]});
```

This is a website security-superadmin operation. Device grants allow only `view`
and `cameras:view`; they never authorize door codes or access-list changes.
Resources remain in the existing RBAC store at
`integrations:eufy:properties:<groupId>:devices:<serial>` using the same
`eufy:property:<action>` actions. Group grants remain compatible and additive.
A camera moved to another Eufy group no longer matches its old individual grant.
Native status includes filtered `devicePermissions` alongside `propertyPermissions`.
Every native image or live-video request and poll rechecks permissions; filtering the UI alone
is not authorization. The global website camera allowlist also still applies.

The client website can display grouped lock permissions (list, rename, create/replace,
delete, reveal) independently of camera selection. Renaming means a website display
label; existing provider PINs cannot be recovered. No platform role conditions change.


Native snapshots return `CAMERA_UNREACHABLE` when the authenticated SDK cannot
establish the station media connection. This does not imply invalid credentials
or that the camera is offline in the official app. Live viewing requires a working provider media connection and an externally verified TURN deployment.

## Bounded live video (native browser routes)

Use the same `../api/eufy-client.js` helper and native POST routes as snapshots.
These methods are intentionally absent from `ctx.eufy`: SDP and video must not pass
through generated handlers or their traces.

| Method | Input | Result |
| --- | --- | --- |
| `startCameraStream` | `{serial,offer}`; completed recv-only video SDP with optional recv-only audio, maximum 12,000 characters | `{requestId,serial,state,expiresAt}` |
| `cameraStreamStatus` | `{requestId}` | PENDING, READY, LIVE, STOPPED, ERROR; READY/LIVE may include `answer` SDP |
| `stopCameraStream` | `{requestId}` | terminal state |

Native account status includes `liveVideoAvailable`. This reflects server TURN
configuration, not a guarantee that a particular camera is reachable. Obtain browser
ICE credentials from the existing authenticated `/api/v1/p2p/ice` route. Create one
recv-only video transceiver (H.264) and optionally one recv-only audio transceiver
(Opus), wait for ICE gathering, then submit the offer. Poll every 1–4 seconds, apply the answer once, and attach the incoming video
and audio tracks to the same MediaStream on a muted inline video element. Offer
an explicit Enable sound / Mute sound control; never request browser microphone
access. Inspect inbound audio RTP statistics to distinguish received audio from
a camera that sends none. Show “Live” only when the browser plays frames.

Each poll rechecks current `cameras:view` property/device permissions. Request handles
are bound to project, environment, account session and signed actor. Only explicitly
enabled cameras are eligible. A missing or rejected heartbeat ends media within 20
seconds. Viewing ends after five minutes or earlier account expiry/disconnect. Clients
must stop on hide, navigation, unmount, logout and manual Stop. Reconnect explicitly;
do not start video automatically during discovery. Account/camera configuration
changes end existing streams.

When switching cameras, stop the previous viewer and await `stopCameraStream`
before starting another. If a start response arrives after cancellation, stop its
returned request ID too. Stop releases the server TURN allocation and waits for
relay cleanup; closing only the browser peer is insufficient.

The platform relays Eufy's encrypted P2P media and transcodes it to WebRTC
(H.264 video with optional mono Opus audio). Initial limits:
640×360, 12 fps, with optional mono Opus audio at 48 kHz / 24 kbit/s. One video
encoder and at most one audio encoder per camera are shared by up to four viewers,
up to two concurrent camera sources, and one active viewer per account
actor. Images and video from the same camera cannot run concurrently. Media is not
written to disk, persistent caches, or handler logs. TURN relays encrypted WebRTC packets; it does
not replace the Eufy handshake or the encoder. The initial server peer uses relay-only
ICE; browser peers can reach that relay directly or use their own TURN fallback.

Errors include STREAM_NOT_CONFIGURED, STREAM_UNSUPPORTED, STREAM_CONNECTION_FAILED,
STREAM_TIMEOUT, STREAM_UNAVAILABLE, STREAM_BUSY, STREAM_NOT_FOUND and
CAMERA_UNREACHABLE. A stream failure does not invalidate account credentials.

Device `details.connectionState` is `ONLINE`, `OFFLINE`, `DISABLED`, or `UNKNOWN`.
`connectionSource` is `EUFY_SIGNAL`, `EUFY_DEVICE_STATUS`, or `UNKNOWN`.
Only explicit Eufy device availability or device status reports supply
these states; media timeouts and P2P connection failures do not prove offline.
Readings are a discovery snapshot: use `observedAt` and refresh discovery for a
new reading. Missing or unrecognized values remain unknown. No raw parameters,
provider endpoints or tokens escape.

### Read-only lock connection check

`eufy.checkLockConnection({serial})` uses native `POST /api/v1/eufy/checkLockConnection`.
Dashboard clients use the same operation under the existing project Eufy route.
Requires the current property/device `view` permission (or website superadmin),
plus integration entry permission. Accepts only `serial`; no settings or PINs.

For T85D0 and T85L1 (C32), the server performs a single read-only encrypted
settings check and discards the settings content. It does not set auto-lock,
operate the latch, enumerate access codes, or change credentials. Other models
return UNSUPPORTED without contacting the device. Model support must be validated
against actual read responses before advertising it in client websites.

Returns `{serial,state,checkedAt?,responseTimeMs?,lastRespondedAt?,lastResponseTimeMs?,error?}`.
States: UNKNOWN, UNSUPPORTED, RESPONDED, NOT_RESPONDING, ERROR. RESPONDED proves a
reply at the reported time, not continuous availability. NOT_RESPONDING means the
eight-second deadline elapsed; it does not prove the device is powered off.
ERROR represents a failed check, not offline. Previous successful timing survives
a failed check. Evidence shares the bounded project/environment/account RAM cache with camera history, survives same-account reconnect and sign-in, and also appears on lock device
`details.lockConnectionCheck` in native status. No settings content is returned.

One active check per account, bounded concurrency, 30-second per-lock cooldown.
Checks and physical access management exclude each other. Disconnect/account change
aborts outstanding checks. An explicitly enabled client rotation may check devices sequentially with a 20-second completion gap, five-minute success interval and ten-minute timeout backoff. Pause during live media, access management, hidden tabs or offline browsers. Account replacement, device rebinding/removal and service restart clear evidence. Never use write commands to probe availability. Safe errors: LOCK_CHECK_BUSY,
LOCK_CHECK_COOLDOWN, LOCK_CHECK_TIMEOUT, LOCK_CHECK_FAILED.

### On-demand lock and unlock commands

`eufy.lockDoorNow({serial})` (`POST /api/v1/eufy/lockDoorNow`) and `eufy.unlockDoorNow({serial})` (`POST /api/v1/eufy/unlockDoorNow`) are exposed on the native browser helper, dashboard project routes, and `ctx.eufy`:
- `lockDoorNow({serial})` requires `eufy:property:lock:operate` (or website superadmin) and returns `{state:'SENT',serial,requestedAt,confirmed:false}`.
- `unlockDoorNow({serial})` requires the separate `eufy:property:lock:unlock` permission (or website superadmin) and returns `{state:'SENT',serial,requestedAt,confirmed:false}`.
- Supported only for verified T85D0 locks where `details.lockControlAvailable` is `true` (unsupported hardware sub-revisions return `LOCK_CONTROL_UNSUPPORTED`).
- Neither command toggles: each sends an explicit lock or unlock command. Both are fire-and-forget at the device protocol layer (`confirmed:false` means sent, not confirmed bolt movement), and record an access audit entry (`SENT` or `UNCONFIRMED`). Fixed errors include `LOCK_CONTROL_UNSUPPORTED`, `LOCK_CONTROL_BUSY`, and `LOCK_COMMAND_FAILED`. Connection checks remain strictly read-only.


### Shared camera connection history

Native `status()` includes authorized cameras' `details.cameraConnectionHistory`:
`{state?: "CONNECTED"|"FAILED", at?, lastReachedAt?, reportedState?: "ONLINE"|"OFFLINE"|"DISABLED", reportedAt?}`.
All dates are epoch milliseconds. This metadata is shared across website users
with current property/device `cameras:view` and `view` permission. It grants no
viewing rights. Polling status reads local service memory; it does not probe a camera.
No client write endpoint exists: only fresh server snapshots and outbound live
camera media establish successful reachability. Retained images, SDP negotiation,
login, cancellation and browser transport errors do not establish camera reachability.
A failed camera request preserves the previous success and never implies offline.
Only explicit provider device reports supply offline/disabled states.

History lives solely in ephemeral server memory, scoped by
project, environment, integration scope and Eufy account. It survives website
reload/logout/login and same-account reconnect. Account replacement
or removal clears it; discovery prunes removed/rebound cameras. The bounded cache
holds at most 100 scopes and 200 cameras per scope, with evidence expiring after
90 days. Eviction, restart or deployment clears history.
Never write this history or media to browser storage, persistent caches, files or logs. Existing
encrypted authentication sessions and user display preferences are separate data.


### Live audio

The existing media session subscribes to SDK `audio` frames. AAC-LC (ADTS) and
G.711 A-law (16 kHz mono) convert to Opus in bounded
in-memory server transcoding pipes; no media files are created. AAC-ELD input is
accepted by the same AAC decoder but is not verified on a deployed camera.
Unsupported input, decoder errors or a 128 KiB queued-input limit disable audio
for that session without interrupting video. No automatic audio-decoder retries.
Audio closes with the same actor lease, permissions, account lifetime and Stop
as video. Audio packets alone do not establish camera video availability.
No new API endpoint, credentials, permission grants, public ports or TURN settings
are needed. A camera's disabled microphone setting is not changed automatically.

Read-only lock connection checks support T85D0 and T85L1 (C32). Access-code management is separately allowlisted to T85D0 and T85L1. T85D0C is a separate unverified variant and remains unsupported.

## Background door access batches (native browser API)

Use native `POST /api/v1/eufy/startAccessBatch` with `{reference,label,action,items,pin}` for a bounded batch
of up to 50 doors. `action` is `APPLY` or `REMOVE`. APPLY items have the same
non-secret fields as `createAccessPlan`; REMOVE items contain only `serial`.
APPLY requires one shared four-digit PIN. Submit it only through this native
endpoint, never through a generated handler or client storage. Each door needs
`access:list` plus `codes:write` or `codes:delete` at acceptance. The accepted
command runs sequentially on the server under that authorization; it does not
need browser polling to execute. An existing matching entry keeps its schedule
when its PIN is updated. Protected/ambiguous entries cannot be changed.

The response `{job}` is acceptance, not success. native `POST /api/v1/eufy/listAccessBatches` with `{}`
returns `{jobs}` (latest 20, retained for 30 days), scoped to account/environment,
creator or superadmin, and current access-list permissions for every included
door. Native projections return metadata only, never the shared PIN or raw
options. Show RUNNING / COMPLETED / NEEDS_ATTENTION and each item's state:
WAITING, CHECKING, UPDATING, ADDED, UPDATED, UNCHANGED, REMOVED, NOT_FOUND,
FAILED, NEEDS_REVIEW, NOT_STARTED. Poll every 2–3 seconds during active work and
less often when idle; navigation/reload can restore progress from this list.

The reference is an idempotency key: reusing the same accepted command does not
execute it again. On disconnect/service restart, unfinished batches become
NEEDS_ATTENTION; uncertain changes are never replayed. The batch PIN is kept
only in worker memory (individual access plans retain their established
encrypted PIN journal). Other door mutations/list reads and lock probes yield
to a running batch. Check saved access plans for uncertain writes before any
explicit retry. Do not claim a failed/unfinished submission was installed.

These two routes are not yet exported by the shared `eufy-client.js` helper.
Call them with same-origin credentials, JSON, `redirect: 'error'`,
`cache: 'no-store'`, and a 35-second request timeout. Treat HTTP errors and
JSON `error`/`state: ERROR` responses as failures; never log the request body.
