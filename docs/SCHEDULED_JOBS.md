# SiteMills Scheduled Jobs Guide

Jobs are server-side functions that run on a cron schedule or on demand. Unlike request handlers, the browser does not call them over HTTP. They run in the background with no user present.

Use jobs for nightly rollups, cleanup, scheduled emails, batched analytics, recurring imports, or any work that has to run without a visitor on the site.

---

## 1. Availability

| Plan | Jobs |
|---|---|
| FREE | Not available |
| BASIC | Not available |
| ADVANCED | Available |
| ULTRA | Available |

- Jobs are registered per environment when you deploy (`sitemills-cli deploy <projectId> <branchId> <env>`). Each environment keeps its own job list, run history, and state.
- If you remove a job from `contracts/jobs.json`, the next deploy disables it in that environment.
- Pausing a job sticks across redeploys. A paused job stays paused until you resume it.

---

## 2. File Layout

```
server/
  jobs.ts          <-- job functions
contracts/
  jobs.json        <-- schedule, timeout, retry, and param configuration
```

The key of each job must match in both files. `jobs.<jobName>` in `server/jobs.ts` is the implementation, and `jobs.<jobName>` in `contracts/jobs.json` is its configuration.

---

## 3. Declaring Jobs (`contracts/jobs.json`)

```json
{
  "version": "1",
  "jobs": {
    "rollupDailyOrders": {
      "trigger": "schedule",
      "schedule": "0 2 * * *",
      "timezone": "America/New_York",
      "timeoutMs": 60000,
      "retries": 2,
      "params": {
        "windowDays": "number?"
      }
    },
    "backfillCustomerTier": {
      "trigger": "manual",
      "timeoutMs": 120000,
      "params": {
        "fromDate": "string"
      }
    }
  }
}
```

| Field | Required | Description |
|---|---|---|
| `trigger` | Yes | `"schedule"` (runs on its cron, and can also be run manually) or `"manual"` (runs only on demand). |
| `schedule` | When `trigger` is `"schedule"` | 5-field cron expression (`minute hour day-of-month month day-of-week`). Leave it out for manual jobs. |
| `timezone` | No | IANA time zone name used to evaluate `schedule`. Default: `"UTC"`. |
| `timeoutMs` | No | Hard timeout per attempt, in milliseconds. Must be greater than 0. Default: `60000`. |
| `retries` | No | Number of retries after a failed attempt. Must be 0 or more. Default: `0`. |
| `params` | No | Param schema, using the same types as request handlers: `"string"`, `"number"`, `"boolean"`, `"object"`, `"array"`. Add `?` to make a param optional (for example `"string?"`). |

---

## 4. Writing Jobs (`server/jobs.ts`)

Export a top-level `jobs` object. Each property is a job function that receives the job context and the run's params.

```typescript
// server/jobs.ts
export const jobs = {
  rollupDailyOrders: async (ctx, params) => {
    const windowDays = params?.windowDays ?? 1;
    ctx.log('rollup starting', { windowDays, trigger: ctx.trigger });

    // Resume from where the last successful run stopped.
    const since = ctx.previousRun?.cursor
      ?? new Date(Date.now() - windowDays * 86400000).toISOString();

    const orders = await ctx.db.collection('orders').find({ createdAt: { $gte: since } });
    const total = orders.reduce((sum, o) => sum + (o.amount || 0), 0);

    await ctx.db.collection('order_summaries').insertOne({
      runId: ctx.runId,
      date: new Date().toISOString().slice(0, 10),
      total,
      count: orders.length
    });

    // Recorded on this run; the next run reads it from ctx.previousRun.cursor.
    await ctx.state.setCursor(new Date().toISOString());
    ctx.log('rollup complete', { total, count: orders.length });
  },

  backfillCustomerTier: async (ctx, params) => {
    ctx.log('backfill starting', { fromDate: params.fromDate });
  }
};
```

---

## 5. Job Context

The job context is different from the request handler context. Jobs run with no visitor, so there is no `ctx.user` or `ctx.session`, and a job has no caller to return a value to. If a job needs to act for a specific user, pass that user's id in `params`.

```typescript
interface JobContext {
  jobName: string;
  runId: string;                       // unique per run; use it as an idempotency key
  scheduledAt: Date;                   // when the run was scheduled to start
  trigger: 'schedule' | 'manual' | 'retry';
  environment: 'DEV' | 'STAGING' | 'PROD';
  previousRun: {                       // most recent successful run; null if there is none
    startedAt: string;                 // ISO-8601
    finishedAt: string;                // ISO-8601
    status: 'ok';
    cursor: any;                       // value passed to ctx.state.setCursor, or null
  } | null;

  state: {
    get(key: string): Promise<any>;
    set(key: string, value: any): Promise<void>;
    setCursor(value: any): Promise<void>;
  };
  log(message: string, data?: Record<string, unknown>): void;

  // Also available, same as in request handlers:
  db: any;        // ctx.db
  metrics: any;   // ctx.metrics
  realtime: any;  // ctx.realtime
  logs: any;      // ctx.logs
}
```

- **`ctx.state`** is a small key-value store scoped to one job in one environment. Each value can be up to 64 KB.
- **`ctx.state.setCursor(value)`** records a progress marker on the current run. The next run reads it from `ctx.previousRun.cursor`. This is the standard pattern for "process new records since the last run".

### Idempotency

A job can run more than once for the same scheduled time, for example after a retry or a manual re-run. Make every job safe to run twice. Use `ctx.runId` as an idempotency key for external side effects, and move the cursor forward only after the work succeeds.

---

## 6. Failures, Retries & Auto-Pause

- **Retries**: when `retries` is greater than 0, a failed attempt is retried after 30 seconds, then 2 minutes, 10 minutes, 30 minutes, and 1 hour. Any retries after that also wait 1 hour.
- **Auto-pause**: after **5 consecutive failures**, SiteMills pauses the job with the reason `auto-paused: 5 consecutive failures`.
- **Resuming**: fix the code, deploy it, then resume the job with `sitemills-cli jobs resume ...` or from the dashboard.

---

## 7. Managing Jobs from the CLI

```bash
# List jobs in an environment with status, schedule, and last run
sitemills-cli jobs list <projectId> <environment> [--json]

# Run a job now, with optional params
sitemills-cli jobs run <projectId> <environment> rollupDailyOrders --params '{"windowDays": 7}'

# Show run history for a job
sitemills-cli jobs runs <projectId> <environment> rollupDailyOrders [--json]

# Pause and resume scheduled runs
sitemills-cli jobs pause <projectId> <environment> rollupDailyOrders --reason "Maintenance"
sitemills-cli jobs resume <projectId> <environment> rollupDailyOrders

# Aggregate run counts and error rates
sitemills-cli jobs metrics <projectId> <environment> [--json]
```

Project owners can also run, pause, and resume jobs from the Scheduled Jobs tab in the project dashboard.

---

## 8. Best Practices

- Process large data sets in pages (`limit` plus a cursor) so each run finishes well within `timeoutMs`.
- Prefer hourly or daily schedules over minute-level polling. Job runs consume credits.
- Keep state in `ctx.state` or `ctx.db`, not in module-level variables. Nothing in memory carries over between runs.
- Every job declared in `contracts/jobs.json` needs a matching function in `server/jobs.ts`.

---

## 9. Related Documentation

- [`CONTRACTS_GUIDE.md`](CONTRACTS_GUIDE.md): contract syntax for jobs and database indexes.
- [`SERVER_RUNTIME_RPC.md`](SERVER_RUNTIME_RPC.md): the server runtime and its limits.
- [`ERROR_DIAGNOSTICS_AND_TROUBLESHOOTING.md`](ERROR_DIAGNOSTICS_AND_TROUBLESHOOTING.md): debugging job failures.
