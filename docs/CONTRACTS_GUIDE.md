# SiteMills Contract & Configuration Specification Guide

This guide provides the authoritative specification for project contract files in SiteMills:
- `contracts/jobs.json` and its binding to `server/jobs.ts`
- `contracts/db.json` declarative database schemas, index specifications, and constraints

---

## 1. Overview of Platform Contracts

In SiteMills, project configuration is declarative. Contract files located in the root `contracts/` directory declare platform behaviors and topology:
1. **Background & Scheduled Jobs** (`contracts/jobs.json`): Defines background workers, cron cadences, retries, and execution timeouts.
2. **Database Schemas & Indexes** (`contracts/db.json`): Defines MongoDB collections, unique constraints, compound indexes, and TTL expiration rules.

These contracts are read and enforced automatically during `sitemills-cli push` and cloud deployment.

---

## 2. Background & Scheduled Jobs (`contracts/jobs.json`)

### 2.1 File Location & Schema

Location: `contracts/jobs.json`

```json
{
  "version": "1",
  "jobs": {
    "cleanupAbandonedCarts": {
      "trigger": "schedule",
      "schedule": "0 3 * * *",
      "timezone": "America/New_York",
      "timeoutMs": 60000,
      "retries": 2,
      "description": "Nightly job to clear expired carts",
      "params": {
        "maxAgeHours": "number"
      }
    },
    "syncInventory": {
      "trigger": "manual",
      "timeoutMs": 120000,
      "retries": 0,
      "description": "On-demand inventory reconciliation",
      "params": {
        "vendorId": "string"
      }
    }
  }
}
```

### 2.2 Field Definitions & Constraints

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `version` | string | Optional | `"1"` | Contract format version. |
| `jobs` | object | **Required** | `{}` | Dictionary mapping unique job names to their configuration. |
| `jobs.<name>.trigger` | string | **Required** | — | Execution trigger. Must be either `"schedule"` or `"manual"`. |
| `jobs.<name>.schedule` | string | Required if `trigger: "schedule"` | — | Standard 5-field UNIX cron expression: `minute hour day-of-month month day-of-week`. Forbidden if `trigger: "manual"`. |
| `jobs.<name>.timezone` | string | Optional | `"UTC"` | Valid IANA timezone name (e.g., `"America/New_York"`, `"Europe/London"`, `"Asia/Tokyo"`). |
| `jobs.<name>.timeoutMs` | number | Optional | `60000` | Maximum execution time in milliseconds before the job is terminated. Minimum: `1000` (1s), Maximum: `900000` (15m). |
| `jobs.<name>.retries` | number | Optional | `0` | Number of automatic retries on unhandled failure or timeout. Minimum: `0`, Maximum: `5`. |
| `jobs.<name>.description` | string | Optional | — | Human-readable description shown in the dashboard and CLI. |
| `jobs.<name>.params` | object | Optional | `{}` | JSON Schema / type dictionary defining accepted parameter types for runtime validation. |

### 2.3 UNIX Cron Syntax Reference

The `schedule` field follows standard 5-field cron syntax:

```
┌───────────── Minute (0 - 59)
│ ┌─────────── Hour (0 - 23)
│ │ ┌───────── Day of Month (1 - 31)
│ │ │ ┌─────── Month (1 - 12)
│ │ │ │ ┌───── Day of Week (0 - 6, Sunday = 0 or 7)
│ │ │ │ │
* * * * *
```

**Common Cron Patterns:**
- `0 * * * *`: Top of every hour
- `*/15 * * * *`: Every 15 minutes
- `0 2 * * *`: Daily at 2:00 AM (in the declared `timezone`)
- `0 9 * * 1-5`: Weekdays at 9:00 AM
- `0 0 1 * *`: First day of every month at midnight

---

## 3. Mapping Jobs to `server/jobs.ts`

### 3.1 Export Convention

The platform compiles `server/jobs.ts` and extracts functions exported inside a named `jobs` object:

```typescript
// server/jobs.ts

/**
 * Scheduled and manual jobs exported for the SiteMills job runner.
 * Each exported function key must match a job name declared in contracts/jobs.json.
 */
export const jobs = {
  cleanupAbandonedCarts: async (ctx: any, params: any) => {
    ctx.log('Starting cleanupAbandonedCarts', { maxAgeHours: params.maxAgeHours });
    
    const cutoff = new Date(Date.now() - (params.maxAgeHours || 24) * 60 * 60 * 1000);
    const result = await ctx.db.collection('carts').deleteMany({
      status: 'abandoned',
      updatedAt: { $lt: cutoff }
    });

    ctx.log('Abandoned carts deleted', { count: result.deletedCount });
  },

  syncInventory: async (ctx: any, params: any) => {
    const lastSync = await ctx.state.get('lastSyncTime');
    // Perform sync...
    await ctx.state.set('lastSyncTime', new Date().toISOString());
    ctx.state.setCursor({ lastProcessedId: '12345' });
  }
};
```

> [!IMPORTANT]
> **Export Requirement**: Functions must be exported within `export const jobs = { ... }`. Top-level bare exports in `server/jobs.ts` (e.g. `export async function myJob`) are treated as HTTP RPC endpoints rather than scheduled jobs.

### 3.2 The `JobContext` API

When a job executes, the platform injects an enhanced context object (`ctx`) as the first parameter:

| Property / Method | Type | Description |
|---|---|---|
| `ctx.jobName` | `string` | Name of the job as declared in `contracts/jobs.json`. |
| `ctx.runId` | `string` | Unique UUID generated for this specific execution run. Useful for deduplication and tracing. |
| `ctx.trigger` | `"schedule" | "manual" | "retry"` | What triggered this execution. |
| `ctx.environment` | `"DEV" | "STAGING" | "PROD"` | Deployment environment where the job is executing. |
| `ctx.scheduledAt` | `Date` | Scheduled firing timestamp. |
| `ctx.previousRun` | `object | null` | Details of the most recent successful run: `{ startedAt, finishedAt, status, cursor }`. |
| `ctx.log(message, data?)` | `function` | In-memory structured logging. Stored in execution history and visible in the dashboard / CLI. Buffer cap: 200KB. |
| `ctx.state.get(key)` | `async (key: string) => Promise<any>` | Reads persistent key-value state across job runs. |
| `ctx.state.set(key, value)` | `async (key: string, value: any) => Promise<void>` | Saves persistent key-value state (max 64KB per value, 1MB per job). |
| `ctx.state.setCursor(cursor)` | `function` | Records a checkpoint cursor string/object passed to `ctx.previousRun.cursor` on the next run. |
| `ctx.db` | `Database` | Full SiteMills MongoDB collection access (`ctx.db.collection('name')`). |
| `ctx.realtime` | `Realtime` | Push notification and websocket channels. |
| `ctx.metrics` | `Metrics` | Custom event and metric tracking. |

### 3.3 CLI Job Commands

```bash
# List all jobs and their schedules in an environment
sitemills-cli jobs list <projectId> <environment>

# Trigger a job on-demand with optional JSON parameters
sitemills-cli jobs run <projectId> <environment> <jobName> --params '{"maxAgeHours": 48}'

# View recent execution run history for a job
sitemills-cli jobs runs <projectId> <environment> <jobName>

# Pause / resume a scheduled job
sitemills-cli jobs pause <projectId> <environment> <jobName> --reason "Maintenance"
sitemills-cli jobs resume <projectId> <environment> <jobName>

# View overall job scheduler metrics (success rate, run counts, active jobs)
sitemills-cli jobs metrics <projectId> <environment>
```

---

## 4. Declarative Database Schemas & Indexes (`contracts/db.json`)

### 4.1 File Location & Schema

Location: `contracts/db.json`

```json
{
  "collections": {
    "Users": {
      "indexes": [
        {
          "fields": { "email": 1 },
          "options": { "unique": true, "sparse": false }
        },
        {
          "fields": { "username": 1 },
          "options": { "unique": true }
        },
        {
          "fields": { "status": 1, "createdAt": -1 },
          "options": { "name": "idx_users_status_created" }
        }
      ]
    },
    "Sessions": {
      "indexes": [
        {
          "fields": { "token": 1 },
          "options": { "unique": true }
        },
        {
          "fields": { "expiresAt": 1 },
          "options": { "expireAfterSeconds": 0 }
        }
      ]
    },
    "Articles": {
      "indexes": [
        {
          "fields": { "title": "text", "content": "text" },
          "options": { "weights": { "title": 10, "content": 1 } }
        }
      ]
    }
  }
}
```

### 4.2 Index Specification Fields

| Field | Type | Description |
|---|---|---|
| `fields` | object | Key-value pairs of document fields to index and their index direction. Use `1` for ascending, `-1` for descending, `"text"` for text search, or `"2dsphere"` for geospatial queries. (Note: `key` is supported as an alias for `fields`). |
| `options` | object | Optional MongoDB index options (see below). |

### 4.3 Supported Index Options

| Option | Type | Default | Description |
|---|---|---|---|
| `unique` | boolean | `false` | Enforces uniqueness on the indexed field(s). Any write duplicating an existing value will throw a duplicate key error (code 11000). |
| `sparse` | boolean | `false` | Indexes only documents containing the indexed field. Documents lacking the field do not consume index space or trigger uniqueness collisions. |
| `name` | string | Auto | Custom identifier name for the index. |
| `expireAfterSeconds` | number | — | Creates a TTL (Time-To-Live) index where documents automatically expire and are purged by MongoDB after the specified number of seconds past the date in the indexed field. |

### 4.4 Lifecycle & Deployment Behavior

1. **Automatic Provisioning**: When you run `sitemills-cli push` or deploy to STAGING/PROD, the platform reads `contracts/db.json` and creates missing indexes in MongoDB in the background.
2. **Zero Downtime**: Index creation executes concurrently using MongoDB's background index builder. Ongoing queries and handler executions are never blocked.
3. **Idempotence**: Existing indexes matching the declared specification are left untouched.
