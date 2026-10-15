# SiteMills Error Diagnostics & Troubleshooting Guide

This guide provides developers with root-cause explanations, diagnostic guidance, and concrete solutions for common errors encountered when developing on the SiteMills platform.

---

## 1. Overview of Platform Error Feedback

SiteMills isolates user code in sandboxed V8 execution environments. To maintain security, internal infrastructure details (internal addresses, server filesystem paths, and platform secrets) are sanitized. 

When an RPC handler, cloud compilation, database query, or CLI command fails, use this guide and the built-in CLI diagnostic engine (`sitemills-cli help errors`) to identify the exact cause and resolution.

---

## 2. Database Query & MongoDB Errors

### 2.1 `$regex has to be a string`
- **Root Cause**: A database query filter supplied a non-string value (such as a boolean, number, null, or nested object) to the MongoDB `$regex` operator.
- **Incorrect**:
  ```json
  { "email": { "$regex": true } }
  { "title": { "$regex": { "pattern": "site" } } }
  ```
- **Correct**:
  ```json
  { "email": { "$regex": "^admin.*@example\\.com$", "$options": "i" } }
  ```
- **Resolution**: Ensure the operand of `$regex` is a valid regex pattern string. If you want case-insensitive matching, use the `$options: "i"` companion field.

### 2.2 `unknown operator: <name>` / `unknown top level operator`
- **Root Cause**: A query filter or update patch used an invalid operator or misspelled a standard MongoDB operator.
- **Common Operators**:
  - Comparison: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`
  - Logical: `$and`, `$or`, `$nor`, `$not`
  - Element / Array: `$exists`, `$type`, `$size`, `$all`, `$elemMatch`
  - Update: `$set`, `$unset`, `$inc`, `$push`, `$pull`, `$addToSet`
- **Resolution**: Ensure all operators begin with a dollar sign (`$`) and are valid MongoDB operators.

### 2.3 `Argument passed in must be a single String of 12 bytes or a string of 24 hex characters`
- **Root Cause**: Querying by `_id` with an invalid ObjectId string format.
- **Resolution**: SiteMills stores standard MongoDB ObjectIds as 24-character hexadecimal strings (e.g. `"65f1a2b3c4d5e6f7a8b9c0d1"`). When querying by `_id`, verify that the ID string contains exactly 24 hexadecimal characters (`[0-9a-fA-F]{24}`).

### 2.4 `E11000 duplicate key error collection`
- **Root Cause**: Attempting to insert or update a document with a value that violates a `unique: true` index declared in `contracts/db.json`.
- **Resolution**: Check the collection's unique index fields in `contracts/db.json`. Ensure incoming data does not duplicate an existing document, or use `$set` to update the existing record.

---

## 3. Server Runtime & RPC Handler Errors

### 3.1 `No route registered with name: '<name>'`
- **Root Cause**: The client or frontend stub requested an RPC route that was not discovered or exported by the backend.
- **Troubleshooting Checklist**:
  1. Verify the file exists in `server/handlers/` and ends with `.ts` or `.js`.
  2. Verify the function is explicitly exported (`export async function myHandler(ctx: any, params: any)` or inside `export const routes = { ... }`).
  3. Check the route name used by the caller:
     - Bare name: `myHandler`
     - Stem prefix: `tournament_service.myHandler`
     - Service prefix: `tournament.myHandler`
  4. Ensure you ran `sitemills-cli push` after creating or modifying the handler.

### 3.2 `Parameter '<name>' expected '<type>' but got <type>`
- **Root Cause**: Contract parameter validation failed against the schema declared in `contracts/*.json`.
- **Resolution**: Inspect the required parameter type in the contract. Ensure the client passes the expected data type (e.g. passing a string `"123"` when a number `123` is expected).

### 3.3 `TypeError: Cannot read properties of undefined`
- **Root Cause**: Unhandled null or undefined access inside a handler function (e.g. attempting `user.profile.name` when `user` or `profile` is null).
- **Resolution**: Add defensive null-checks or optional chaining (`user?.profile?.name`) in your handler.

---

## 4. Cloud Compilation & TypeScript Errors during `push`

When `sitemills-cli push` runs, backend files are compiled by the cloud TypeScript compiler.

### 4.1 `[7006] Parameter 'ctx' implicitly has an 'any' type`
- **Root Cause**: Handler functions omitted parameter type annotations in a TypeScript file.
- **Fix**:
  ```typescript
  // Change:
  export async function myHandler(ctx, params) { ... }

  // To:
  export async function myHandler(ctx: any, params: any) { ... }
  ```

### 4.2 `[2304] Cannot find name 'require'` / Unbundled Modules
- **Root Cause**: Attempting to use Node.js runtime built-ins like `require('fs')` or unbundled npm modules.
- **Fix**: Use the injected `ctx` APIs (`ctx.http`, `ctx.db`, `ctx.storage`) instead of Node built-ins.

---

## 5. Contract Schema Errors (`contracts/jobs.json` & `contracts/db.json`)

### 5.1 `contracts/jobs.json: job '<name>' trigger=schedule requires 'schedule'`
- **Root Cause**: A job declared `"trigger": "schedule"` but omitted the `"schedule"` field.
- **Fix**: Add a valid 5-field UNIX cron expression: `"schedule": "0 2 * * *"`.

### 5.2 `contracts/jobs.json: job '<name>' trigger=manual must not have 'schedule'`
- **Root Cause**: A job declared `"trigger": "manual"` but also included a `"schedule"` field.
- **Fix**: Remove the `"schedule"` field for manual-trigger jobs.

### 5.3 `Invalid JSON in contracts/jobs.json: Unexpected token`
- **Root Cause**: Trailing comma, unquoted key, or invalid JSON syntax in the contract file.
- **Fix**: Validate the JSON file using standard JSON formatters or `jq`.

---

## 6. Data Operations & Lua Scripting Errors

### 6.1 `Refusing collection-wide preview: filter {} matches entire collection`
- **Root Cause**: Running `mutation_preview` or `execute_lua` with an empty filter `{}` without explicit permission.
- **Fix**: Provide a specific filter or explicitly pass `"allowCollectionWide": true` in the JSON payload (or `--allow-collection-wide` via CLI).

### 6.2 `Count drift detected` / `Document set drift detected`
- **Root Cause**: Documents in the target collection changed between the `mutation_preview` step and the `mutation_apply` step.
- **Fix**: Run a fresh `mutation_preview` to get the latest `matchedCount` and `docIds`, then immediately apply.

### 6.3 `Lua write plan exceeds maxWriteOps=<N>`
- **Root Cause**: The Lua script's returned mutations (`updates + deletes + inserts + dropIndexes`) exceeded the configured `maxWriteOps` ceiling (default 200).
- **Fix**: Increase `--max-write-ops <N>` (up to 200) or narrow the query `--filter`.

### 6.4 `Lua update references unknown id '<id>' outside matched document set`
- **Root Cause**: The script attempted to update or delete a document ID that was not present in the matched `input.docs` array.
- **Fix**: Only mutate documents that were passed into the sandbox via `input.docs`.

---

## 7. Inspecting Live Error Logs

To inspect full backend handler error logs in real-time from the CLI:

```bash
# View all recent error logs for your project in an environment
sitemills-cli logs <projectId> --env DEV --level ERROR --limit 50

# View logs for a specific branch
sitemills-cli logs <projectId> --branch feature-branch --level ERROR
```


---

## 8. Escalating Issues, Reporting Bugs & Filing Feature Requests

When an automated agent, developer, or CLI diagnostics pipeline encounters an unresolvable error, system outage, or user request, create a structured ticket on the project or platform queue instead of silently failing or spinning in retry loops.

### 8.1 Issue Classification Matrix

| Category | When to Use | Recommended Priority |
|---|---|:---:|
| `INFRA_DOWN` | Platform databases, platform services, or gateways return connection refused / 502 / 503 / 504 | P0 (Critical) |
| `PLATFORM_BUG` | Core platform APIs or cloud compiler return unexpected 500 internal errors or break contract validation | P1 (High) |
| `AGENT_ERROR` | Autonomous runner or agentic pipeline throws unhandled exceptions or loops unexpectedly | P1 (High) |
| `USER_CODE_BUG` | Runtime exceptions (`TypeError`, broken handlers) diagnosed in client application code | P2 (Medium) |
| `USER_CONFIG_ERROR` | Invalid environment variables, broken contract JSON, or bad DNS configuration | P2 (Medium) |
| `USER_SUPPORT` | User explicitly requests assistance from the engineering or operations team | P2 (Medium) |
| `FEATURE_REQUEST` | User or client proposes a new platform capability, tool, or UI enhancement | P3 (Low) / P2 |

### 8.2 Submitting via CLI
```bash
# Report an unexpected platform or compiler error:
sitemills-cli add-task <projectId> "Cloud compiler failed on module resolution" "Diagnostics details: ..." --category PLATFORM_BUG --priority 1

# File a user feature request:
sitemills-cli add-task <projectId> "Support CSV export in Orders table" "User requested ability to export order history as CSV" --category FEATURE_REQUEST --priority 3
```

### 8.3 Submitting via Developer API
```bash
curl -s -X POST "https://agent.sitemills.com/api/v1/dashboard/projects/<projectId>/planning/tasks" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Database connection timeout during peak hours",
    "description": "Database query timed out after 5000ms",
    "category": "INFRA_DOWN",
    "priority": 0
  }'
```
