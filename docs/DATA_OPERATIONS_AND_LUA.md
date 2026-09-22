# SiteMills Data Operations & Lua Scripting Reference

This guide provides the complete specification for the `data-op` and `run-lua` CLI commands, payload schemas, Lua sandbox runtime environment, and flag restrictions on the SiteMills platform.

---

## 1. Overview

SiteMills provides two administrative and automated data management commands for inspecting, seeding, migrating, and mutating project database collections:
1. `sitemills-cli data-op`: Executes structured database operations (queries, counts, bulk seeds, atomic mutation previews, and two-phase applies).
2. `sitemills-cli run-lua`: Executes sandboxed Lua migration scripts with safety guardrails against a collection.

---

## 2. `sitemills-cli data-op` Specification

### 2.1 Command Usage

```bash
sitemills-cli data-op <projectId> <payloadJsonOrFile> [--branch <branchId>] [--env <environment>] [--mock-user <email>]
```

- `<payloadJsonOrFile>`: Can be passed as an inline JSON string or as a path to a `.json` file.
- `--branch <branchId>`: Target a specific development branch data scope.
- `--env <environment>`: Target `DEV`, `STAGING`, or `PROD` scope.

### 2.2 Supported Operations & Payload Schemas

#### Operation 1: `query`
Performs a read query against a collection with optional filtering, sorting, projection, and pagination.

```json
{
  "operation": "query",
  "collection": "Tournaments",
  "filter": { "status": "active" },
  "sort": { "createdAt": -1 },
  "projection": { "title": 1, "status": 1, "createdAt": 1 },
  "limit": 50
}
```

- `collection` (string, required): Collection name.
- `filter` (object, optional): MongoDB query filter (default `{}`).
- `sort` (object, optional): Field sort directions: `1` (ascending) or `-1` (descending).
- `projection` (object, optional): Field inclusions (`1`) or exclusions (`0`).
- `limit` (integer, optional): Maximum documents returned (1 to 200, default 50).

#### Operation 2: `count`
Counts documents matching a filter.

```json
{
  "operation": "count",
  "collection": "Participants",
  "filter": { "paid": true }
}
```

- `collection` (string, required): Collection name.
- `filter` (object, optional): MongoDB query filter.

#### Operation 3: `seed`
Inserts an array of documents into a collection.

```json
{
  "operation": "seed",
  "collection": "Settings",
  "documents": [
    { "key": "maintenance_mode", "value": false },
    { "key": "registration_open", "value": true }
  ]
}
```

- `collection` (string, required): Collection name.
- `documents` (array of objects, required): Array of non-empty documents to insert (max 500 documents per batch).

#### Operation 4: `mutation_preview`
Safely previews updates or deletions before applying them. Returns the exact document IDs matched.

```json
{
  "operation": "mutation_preview",
  "collection": "Users",
  "mutationOperation": "update",
  "filter": { "tier": "legacy_beta" },
  "updatePatch": {
    "$set": { "tier": "standard" }
  },
  "allowCollectionWide": false,
  "maxAffected": 100
}
```

- `mutationOperation` (string, required): `"update"` or `"delete"`.
- `filter` (object, required): Must not be empty `{}` unless `"allowCollectionWide": true`.
- `updatePatch` (object, required for update): Atomic MongoDB update operators (`$set`, `$unset`, `$inc`, etc.).
- `maxAffected` (integer, optional): Safety threshold (default 200, max 200). Throws if matched count exceeds this number.

#### Operation 5: `mutation_apply`
Applies a previously previewed mutation with strict drift detection.

```json
{
  "operation": "mutation_apply",
  "collection": "Users",
  "mutationOperation": "update",
  "filter": { "tier": "legacy_beta" },
  "updatePatch": {
    "$set": { "tier": "standard" }
  },
  "expectedCount": 2,
  "expectedDocIds": ["65f1a2b3c4d5e6f7a8b9c0d1", "65f1a2b3c4d5e6f7a8b9c0d2"]
}
```

> [!IMPORTANT]
> **Drift Protection**: If any document in the collection was modified, added, or deleted between the preview and apply phases such that `currentCount !== expectedCount` or `currentDocIds !== expectedDocIds`, the platform aborts the operation immediately with a `Count drift detected` error to prevent unintended data loss.

---

## 3. `sitemills-cli run-lua` Specification

The `run-lua` command executes custom Lua scripts against collection documents inside a secure Lua sandbox.

### 3.1 Command Usage

```bash
sitemills-cli run-lua <projectId> <collection> <luaScriptFile> [options]
```

**Options:**
- `--filter <json>`: JSON query filter to narrow documents passed to Lua (e.g. `'{"status": "pending"}'`).
- `--dry-run`: Previews the planned mutations without writing changes to the database.
- `--limit <N>`: Maximum documents loaded into the Lua sandbox (1 to 200, default 200).
- `--max-write-ops <N>`: Maximum writes allowed (1 to 200, default 200).
- `--branch <branchId>`: Target branch data scope.
- `--env <environment>`: Target environment (`DEV`, `STAGING`, or `PROD`).
- `--mock-user <email>`: Mock user email (DEV/STAGING only).

### 3.2 The Lua Sandbox Environment

The Lua runtime is isolated and sandboxed with strict resource boundaries:
- **Max Instructions**: Hook counter prevents infinite loops or CPU exhaustion.
- **Allowed Libraries**: Standard Lua `math.*`, `string.*`, `table.*`, `utf8.*`, and sanitized `os.*` (`os.clock()`, `os.date()`, `os.difftime()`, `os.time()`).
- **Blocked Functions / Globals**: `io.*`, `package.*`, `debug.*`, `dofile()`, `loadfile()`, `require()`, `collectgarbage()`.

### 3.3 Injected Globals (`input`)

The platform passes an `input` table to the global Lua scope:

```lua
input = {
  docs = {
    -- Array of matching documents as Lua tables:
    {
      _id = "65f1a2b3c4d5e6f7a8b9c0d1",
      email = "alice@example.com",
      status = "pending",
      roles = { "user" }
    }
  },
  metadata = {
    projectId = "proj_123",
    branchId = "main",
    dataScope = "main",
    collection = "Users",
    matchedCount = 1
  }
}
```

### 3.4 Expected Return Format

The Lua script **must return a table** containing the mutation plan:

```lua
return {
  summary = "Brief human-readable explanation of actions taken",
  updates = {
    {
      id = "<docId>",
      patch = {
        ["$set"] = { status = "active", activatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ") }
      }
    }
  },
  deletes = {
    "<docIdToDelete>"
  },
  inserts = {
    {
      name = "New Item",
      status = "active"
    }
  },
  dropIndexes = {
    "legacy_idx_name"
  }
}
```

### 3.5 Execution Rules & Guardrails

1. **Target ID Validation**: Every `id` in `updates` and `deletes` must exist in `input.docs`. Referencing an ID outside the matched document set throws an error.
2. **Write Limits**: `updates.length + deletes.length + inserts.length + dropIndexes.length` must not exceed `maxWriteOps` (default 200).
3. **Dry Run**: When `--dry-run` is passed, the CLI prints the mutation plan counts and summary without executing any database writes.
4. **Production Approvals**: In `PROD`, non-dry-run mutations require a proposal description or approval.

### 3.6 Complete Lua Migration Example

```lua
-- scripts/backfill_user_slugs.lua

local updates = {}

for _, doc in ipairs(input.docs) do
  if not doc.slug and doc.username then
    local slug = string.lower(string.gsub(doc.username, "%s+", "-"))
    table.insert(updates, {
      id = doc._id,
      patch = {
        ["$set"] = {
          slug = slug,
          updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
      }
    })
  end
end

return {
  summary = string.format("Generated slugs for %d users", #updates),
  updates = updates
}
```

Run with:
```bash
sitemills-cli run-lua my-project Users scripts/backfill_user_slugs.lua --filter '{"slug":{"$exists":false}}' --dry-run
```

---

## 4. Flag Reference & Security Restrictions

| Flag | Valid Syntax | Environment Restrictions | Description |
|---|---|---|---|
| `--mock-user <email>` | Valid email address (e.g. `--mock-user dev@example.com`) | **DEV and STAGING only. Strictly forbidden & ignored in PROD.** | Injects `X-SiteMills-Mock-User` header to simulate requests as another user for role testing. |
| `--filter <json>` | Valid JSON MongoDB filter string (e.g. `'{"status":"active"}'`) | All environments | Queries documents matching the filter. |
| `--max-write-ops <N>` | Integer `1` to `200` | All environments | Sets the maximum write operations budget. |
| `--limit <N>` | Integer `1` to `200` | All environments | Sets the maximum documents loaded into the sandbox. |
| `--dry-run` | Flag (no value) | All environments | Simulates execution without applying database writes. |
| `--allow-collection-wide` | Flag (no value) | All environments | Permits operations with an empty filter `{}` across the entire collection. |
