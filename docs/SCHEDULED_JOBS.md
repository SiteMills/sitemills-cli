# SiteMills Scheduled Jobs Guide

SiteMills allows developers and AI agents to declare recurring scheduled tasks (cron-like) and manual background tasks that execute in an isolated environment.

---

## 1. Overview & Capabilities

- **Scheduled & Manual Background Jobs**: Declare jobs in a contract file that run either on a specified cron cadence or are triggered manually from the project dashboard/API.
- **Sandboxed Execution**: Scheduled jobs reuse the same V8 Isolate sandbox, filesystem context, and integration APIs (`ctx`) as standard HTTP handlers.
- **Dashboard Management**: A web UI is provided to list jobs, check run metrics, pause/resume, and view execution history.
- **Automatic Retries**: Failed jobs can be automatically retried up to 5 times.
- **Concurrency & Claiming**: Highly available scheduler that claims and leases jobs to avoid double-runs across multiple runtime instances.

---


## 2. Tier gating (authoritative)

| Tier      | Jobs enabled? | Scopes allowed |
|-----------|---------------|----------------|
| FREE      | No            | —              |
| BASIC     | No            | —              |
| ADVANCED  | Yes           | PROD only      |
| ULTRA     | Yes           | STAGING + PROD |

> **Open question flagged:** User requirement #1 said "basic tier and up" but #2 said "disabled for free and basic." We are going with #2/#3/#4 as authoritative. Revisit if wrong.

Gating is enforced in **two places**:
1. **Frontend** (`TierGate`) hides the Jobs tab for FREE/BASIC; shows an "Advanced only" lock banner for ADVANCED when viewing STAGING.
2. **Backend** (`clientruntimeservice` scheduler + manual-trigger endpoint) re-validates tier + scope before every execution and claim. Fail-fast; no silent downgrade.

DEV-scope jobs **never fire automatically**. Agents can invoke them manually only (and only if their tier permits — DEV is implicitly allowed for any paid tier via manual trigger while iterating). *Decision:* for simplicity in v1, **DEV manual triggers are allowed for any tier that has jobs enabled** (ADVANCED + ULTRA). DEV manual triggers do not count against prod credit caps — but they do still spend runtime credits.

---

## 3. Authoring model

### 3.1 Contract file

Agent writes `contracts/jobs.json`:

```json
{
  "jobs": {
    "rollupDailyOrders": {
      "trigger": "schedule",
      "schedule": "0 2 * * *",
      "timezone": "America/New_York",
      "timeoutMs": 60000,
      "retries": 2,
      "params": { "windowDays": "number | null" }
    },
    "backfillCustomerTier": {
      "trigger": "manual",
      "params": { "fromDate": "string" }
    }
  }
}
```

Rules, validated during deploy-time manifest sync:
- `trigger` is required and must be either `"schedule"` or `"manual"`.
- If `trigger` is `"schedule"`, `schedule` (standard 5-field cron) is required.
- If `trigger` is `"manual"`, `schedule` must be omitted.
- `timeoutMs` ≤ 900000 (15 min). Default 60000.
- `retries` ≤ 5. Default 0.
- `timezone` IANA name. Default `UTC`.
- `params` uses the same schema vocabulary as existing handler contracts (`"string"`, `"number"`, `"boolean"`, `"string | null"`, …).

A second file, `contracts/handlers.json` (the existing one), is untouched. Two separate files keeps the mental model tidy.

### 3.2 Handler signature

```ts
export async function rollupDailyOrders(
  ctx: JobContext,
  params: { windowDays?: number }
): Promise<void> {
  // ...
}
```

### 3.3 `JobContext` polyfill API

Injected by `dispatch.js` when the invocation envelope is of kind `"job"`:

```ts
interface JobContext {
  jobName: string;
  runId: string;                 // uuid, usable as idempotency key
  scheduledAt: Date;             // tick time that fired the job
  trigger: 'schedule' | 'manual' | 'retry';
  environment: 'DEV' | 'STAGING' | 'PROD';
  previousRun: null | {
    startedAt: Date;
    finishedAt: Date;
    status: 'ok' | 'fail' | 'timeout' | 'skipped';
    cursor: unknown | null;      // whatever the previous run stored
  };
  state: {
    get<T>(key: string): Promise<T | null>;
    set<T>(key: string, value: T): Promise<void>;
    setCursor(cursor: unknown): Promise<void>;  // written to JobRun for next time
  };
  log(msg: string, data?: Record<string, unknown>): void;
}
```

`state` is a small KV keyed by `(projectId, environment, jobName, key)`, stored in a platform-managed Mongo collection (not user-space). Per-value size cap: 64KB. Per-job total cap: 1MB. Exceeding caps throws.

`previousRun` is populated by reading the most recent successful `JobRun` for the same scope/job.

`setCursor` is a convenience: it's written onto the current `JobRun` record so it surfaces in the dashboard AND is available as `previousRun.cursor` next time.

---

## 4. Data model

### 4.1 `JobDefinition` (Mongo collection `scheduled_job_definitions`)

```
_id              ObjectId
projectId        String
branchId         String           // the branch that was compiled
environment      enum(DEV|STAGING|PROD)
jobName          String
schedule         String?          // cron expression; null for manual jobs
timezone         String           // IANA, "UTC" default
timeoutMs        int
retries          int
paramsSchema     Map              // raw from contract
enabled          boolean          // pause/resume
trigger          enum(schedule|manual)
nextFireAt       Instant?         // null for manual
claimedBy        String?          // node id of runtime that claimed
claimedUntil     Instant?         // lease expiry
contractVersion  String           // deploy version that defined this job
createdAt        Instant
updatedAt        Instant
pauseReason      String?          // e.g. "auto-paused: 5 consecutive failures"
consecutiveFailures  int
```

**Indexes:**
- `{projectId: 1, environment: 1, jobName: 1}` — unique (scope-scoped definition).
- `{enabled: 1, trigger: 1, nextFireAt: 1}` — the hot scheduler query index.
- `{claimedUntil: 1}` — sparse, for lease-expiry sweeps.

### 4.2 `JobRun` (Mongo collection `scheduled_job_runs`)

```
_id              ObjectId
projectId        String
branchId         String
environment      enum
jobName          String
runId            String           // uuid, also sent into ctx.runId
trigger          enum(schedule|manual|retry)
scheduledAt      Instant
startedAt        Instant?
finishedAt       Instant?
status           enum(pending|running|ok|fail|timeout|skipped)
error            String?
errorStack       String?
creditsSpent     double
durationMs       long?
logs             List<LogEntry>   // small inline log buffer, cap ~200KB
cursor           Object?          // set via ctx.state.setCursor
attemptNumber    int              // 1 for first try, 2+ for retries
parentRunId      String?          // set when trigger=retry
nodeId           String           // which runtime instance ran it
createdAt        Instant
```

**Indexes:**
- `{projectId: 1, environment: 1, jobName: 1, createdAt: -1}` — dashboard list.
- `{createdAt: 1}` — TTL-style pruning (done via background sweep, not Mongo TTL, so we can keep last-N-per-job).

### 4.3 `JobState` (Mongo collection `scheduled_job_state`)

```
_id              ObjectId
projectId        String
environment      enum
jobName          String
key              String
value            Any              // <= 64KB serialized
updatedAt        Instant
```

**Index:** unique `{projectId: 1, environment: 1, jobName: 1, key: 1}`.

---

## 5. Efficient scheduler trigger (answer to Q6)

This is the core of the design. We index on `nextFireAt`, tick every 30s, and do a range query.

### 5.1 Algorithm

```
every 30 seconds (per runtime instance):
  now = Instant.now()
  claimWindow = 5 minutes
  nodeId = <this instance id>

  // Atomic claim: single round-trip to Mongo, uses {enabled, trigger, nextFireAt} index
  candidates = db.scheduled_job_definitions.findAndModify(
    query = {
      enabled: true,
      trigger: "schedule",
      nextFireAt: { $lte: now },
      $or: [
        { claimedUntil: null },
        { claimedUntil: { $lt: now } }
      ]
    },
    sort = { nextFireAt: 1 },
    update = { $set: {
      claimedBy: nodeId,
      claimedUntil: now + claimWindow,
    }},
    new = true
  )
  // findAndModify returns a single doc; loop until null.

  for each claimed job:
    dispatch asynchronously (bounded worker pool):
      runJob(def)
```

**Why this is efficient:**
- The compound index `{enabled: 1, trigger: 1, nextFireAt: 1}` makes the query an index range scan on `nextFireAt <= now` within the `enabled=true, trigger=schedule` partition. Cost is O(log N + K) where K is the number of due jobs.
- `findAndModify` with an atomic update acts as a distributed lock — two runtime instances can't both claim the same doc.
- The `claimedUntil` lease means if a node crashes mid-run, another node picks the job up after the lease expires.

### 5.2 Computing `nextFireAt`

Use `cron-utils` (Java) with the job's `timezone`. After a run starts, compute the next fire time **from the current `nextFireAt`**, not from `now`, so a backed-up scheduler still fires missed slots in order until caught up. *But*: if we're more than 1 hour behind, skip forward and record `status: skipped` for the gap — don't create a thundering herd.

### 5.3 Per-project/job concurrency

Before dispatching, the runJob worker verifies no `JobRun` for the same `(projectId, environment, jobName)` is in `running` state. If one is, record `status: skipped` and advance `nextFireAt`.

### 5.4 Jitter

When updating `nextFireAt` after a fire, add deterministic jitter `hash(projectId + jobName) % 30s` so projects don't all stampede at top-of-minute.

### 5.5 Global concurrency cap

Scheduler worker pool: 50 concurrent invocations per runtime instance (configurable via `clientruntime.jobs.workerPoolSize`). Claims beyond capacity wait for next tick.

---

## 6. Execution flow

### 6.1 Scheduled trigger

```
SchedulerTickService (clientruntimeservice)
  → claim JobDefinition
  → create JobRun (status=pending)
  → tier + scope gate check (fail-fast)
  → credit check (fail-fast, record status=failed, reason=insufficient_credits)
  → JobInvokeService.invoke(def, run)
       → POST /api/isolate/{projectId}/{branchId}/invoke
           envelope = { kind: "job", jobName, runId, scheduledAt, environment, trigger, previousRun }
       → dispatch.js sees kind=job, builds JobContext, calls registered job handler
       → await result with timeoutMs
  → update JobRun (status, duration, logs, cursor, error)
  → spend credits
  → compute next nextFireAt, clear claim lease, update JobDefinition
  → on failure: schedule retry OR increment consecutiveFailures; auto-pause at 5
```

### 6.2 Manual trigger ("Run now")

```
POST /api/v1/jobs/{projectId}/{environment}/{jobName}/run  (dashboard endpoint)
  → authz (project owner)
  → tier + scope gate
  → credit check
  → create JobRun (trigger=manual)
  → JobInvokeService.invoke(...)
  → return runId; client polls /api/v1/jobs/.../runs/{runId}
```

### 6.3 Pause / Resume / Cancel

- **Pause**: `enabled = false`. In-flight run completes, no new runs fire.
- **Resume**: `enabled = true`, `pauseReason = null`, `consecutiveFailures = 0`, recompute `nextFireAt` from now.
- **Cancel a run**: marks `JobRun.status = cancelling`, posts to isolates to abort. Isolate-level abort is best-effort (the existing invoke path doesn't have first-class cancel; v1 marks `cancelled` in DB and lets the run finish on its own — noted limitation).

---

## 7. Contract sync (deploy-time)

When `clientcodeforge` compiles and the agent has edited `contracts/jobs.json`:

1. Parse and validate the file.
2. For the target branch, upsert `JobDefinition` rows keyed by `(projectId, environment, jobName)` — but we don't know the environment at compile time. **Solution:** compile produces a **job manifest** tied to `(projectId, branchId, contractVersion)`. Deployment to an environment (`STAGING`/`PROD`) is what materializes the `JobDefinition` rows for that scope.
3. On deploy:
   - Upsert `JobDefinition` rows for the target environment from the manifest.
   - Tombstone any `JobDefinition` for this `(projectId, environment)` whose `jobName` is no longer in the manifest (set `enabled=false, pauseReason="removed from contract"`). Don't hard-delete — preserves history and pause state.
   - Compute initial `nextFireAt` for newly enabled jobs.
   - **Preserve** `enabled=false` (user-paused) across re-deploys. If an existing def has `pauseReason` starting with `"user:"`, keep it paused.

This is cleaner than trying to sync on every code edit: jobs only come alive when deployed to a scope that permits them.

---

## 8. Security

1. **No user identity in JobContext.** Invocation envelope carries `systemContext = { kind: 'scheduled-job', jobName, runId }`. SDK methods that read user identity must fail-fast; they shouldn't silently return null.
2. **Manual trigger authz**: only project owner/editor can POST `/run`. Enforce in `clientruntimeservice` using the existing JWT + project permissions check.
3. **Tier+scope re-check at execution time**, not only at claim time. A downgrade between claim and execution must be caught.
4. **Contract-declared side-effect scopes** — reserved field for v2, not enforced in v1 (noted so we can add without breaking).
5. **No outbound HTTP** from isolate — same rule as handlers; nothing new.

---

## 9. Billing & quota

- Each `JobRun` with status in {ok, fail, timeout} spends `RUNTIME_COST_PER_INVOCATION` credits (same as HTTP handler). `skipped` runs are free.
- **Per-project monthly cap** on scheduled-job-triggered credits (default 100000; configurable). When hit, auto-pause all scheduled (not manual) jobs for the project with `pauseReason="monthly cap reached"`. Surfaced in dashboard.
- Credit spend records tagged `source=scheduled|manual` so dashboard can break down.
- Credits checked *before* invocation; refusal records `status=failed, error="insufficient_credits"` and does NOT spend.

---

## 10. Observability / Dashboard

New project-view tab **"Jobs"** (gated by tier). For each scope (STAGING tab / PROD tab within the Jobs section):

- Table of jobs: name, schedule (humanized), last run status, next run, enabled toggle, "Run now" button (for manual-trigger jobs), three-dot menu (pause/resume/view code).
- Per-job drill-down: run history (paginated), each row shows trigger, started, duration, status, credits, [view logs] link.
- Run detail view: full logs, error + stack, cursor, params.

Implementation: new `ScheduledJobsView.ts` + REST endpoints on `dashboardservice` that proxy/query the two collections.

---

## 11. Retries & failure handling

- `retries: N` in contract → on failure, insert a `JobRun` with `trigger=retry, attemptNumber=k+1, parentRunId=prev` at `now + backoff(k)` (exponential, capped at 10 min). The scheduler picks it up like any other due job — we simulate retries via `nextFireAt` on a synthetic row? **No** — retries are handled by the scheduler maintaining a separate per-def "pending retry" field, OR by creating a `JobDefinition`-like ephemeral row. *Simpler:* use `JobRun` with `status=pending` and a field `fireAt`; scheduler tick also queries `JobRun` for pending retries. Add index `{status: 1, fireAt: 1}` on JobRun.
- After exhausting retries: status=failed, bump `consecutiveFailures` on JobDefinition.
- At `consecutiveFailures == 5`: auto-pause with `pauseReason="auto-paused: 5 consecutive failures"`.
- Successful run resets `consecutiveFailures = 0`.

---

## 12. Retention

Background sweep every 6h: for each `(projectId, environment, jobName)`, keep the most recent 500 `JobRun` docs and any from the last 30 days (whichever is larger). Delete the rest. Configurable.

---

## 13. Phasing

### Phase 1 — Plumbing (compile-time + runtime, no scheduler)
- Contract schema + parsing in `clientcodeforge`.
- `TypeScriptCompiler.ts` recognizes `contracts/jobs.json` and emits `__registerJob(name, fn)` calls.
- `dispatch.js` routes `kind=job` envelopes into registered job functions with a `JobContext` built from envelope + SDK.
- `JobState` SDK polyfill (Mongo-backed).
- Models + Mongo indexes (`JobDefinition`, `JobRun`, `JobState`) in `projectlib`.
- Manual-trigger endpoint in `clientruntimeservice`.
- Deploy-time manifest sync.

### Phase 2 — Scheduler
- `SchedulerTickService` in `clientruntimeservice` with `@Scheduled(fixedDelay=30s)` + `@EnableScheduling`.
- Atomic claim via `findAndModify`.
- `nextFireAt` computation (cron-utils).
- Worker pool, concurrency guard, jitter, skipped-gap logic.

### Phase 3 — Dashboard + tier gating
- `Jobs` tab in project-view, gated via `TierGate`.
- `dashboardservice` REST endpoints for list/history/pause/resume/run-now/cancel.
- Backend tier + scope re-validation.

### Phase 4 — Retries, auto-pause, credit cap, retention sweep, observability polish

---

## 14. Open items (decide as we go)

- Exact endpoint path for dashboardservice vs clientruntimeservice (manual trigger currently planned on clientruntimeservice; dashboard reads via dashboardservice).
- Whether DEV manual trigger is actually useful in v1 or punt to v2 (leaning: allow, it's cheap).
- Whether log storage inline in JobRun (easy, size-capped) or separate collection (scales better). v1: inline with 200KB cap.
