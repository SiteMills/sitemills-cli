# SiteMills Developer API — Agent & CLI Reference

> **Audience:** AI coding agents (Antigravity, Claude Code, Cursor, etc.) and CLI tooling that need to create, read, modify, compile, and deploy SiteMills project code programmatically.

---

## Overview

This API enables a **create → pull → edit → push delta → compile/deploy** workflow:

1. **Create** a new project via the import endpoint.
2. **Pull** the full project source into a local working directory.
3. **Edit** files locally using any agent or editor.
4. **Push only the changed files** back to SiteMills.
5. Receive **compilation results, test outcomes, and deployment status** in the response so the agent can iterate.
6. If local state drifts, **refresh** by pulling the full project again.

```
┌─────────────┐   import (create)   ┌──────────────────┐
│  Local Agent │──────────────────►│  SiteMills API    │
│  (tmp dir)   │◄── project info ──│  (agentservice)   │
│              │                   │                   │
│              │◄─── pull ─────────│                   │
│              │─── push delta ──►│                   │
│              │◄── build result ──│  compile ► deploy │
└─────────────┘                   └──────────────────┘
```

> **Important:** The Developer API can only push to projects it created. Projects created through the SiteMills web UI cannot be modified via this API.

---

## Base URL

| Environment | Base URL |
|------------|---------|
| Local dev  | `http://localhost:8093` |
| Dev cluster | `https://agent.dev.sitemills.com` |
| Production | `https://agent.sitemills.com` |

All endpoints live under the agentservice.

---

## Authentication

Every request must include a **Developer API Key** in the `X-Developer-Api-Key` header:

```
X-Developer-Api-Key: <your_api_key>
```

The API key is a shared secret configured in the server's `application.yml` under `agent.developer.api.secret` (env var: `DEVELOPER_API_SECRET`).

> **No JWT required.** This API uses a simple secret key, unlike the web frontend which uses Bearer JWT tokens.

---

## Core Concepts

| Concept | Description |
|---------|-------------|
| **projectId** | Unique identifier for a SiteMills project (auto-generated from project name, e.g. `my-portfolio-site`). |
| **branchId** | UUID identifying a specific branch/version within a project. Each project has at least one branch. Returned in the import response. |
| **files** | A `Map<String, String>` where keys are relative file paths (e.g. `app.tsx`, `styles.css`, `server/handlers.ts`) and values are file contents. |
| **snapshot** | An immutable point-in-time capture of all project files. Every code mutation creates a new snapshot. |
| **codeVersion** | A versioned entry in the code history chain, linked to a snapshot. Supports undo/redo. |
| **developerApiManaged** | Projects created via this API are tagged so that only this API can push changes to them. |

---

## Endpoints

### 1. Create Project (Import)

Create a new SiteMills project with the given files. The project is tagged as **developer-API-managed** so it can be updated via the push endpoint.

```
POST /api/v1/agent/projects/import
```

**Headers:**
```
X-Developer-Api-Key: <your_api_key>
Content-Type: application/json
```

**Request Body (Custom Files):**
```json
{
  "projectName": "My Portfolio Site",
  "files": {
    "app.tsx": "import { h } from 'preact';\n...",
    "styles.css": "@tailwind base;\n...",
    "index.html": "<!DOCTYPE html>\n..."
  }
}
```

**Request Body (Seed from Canonical Platform Template):**
```json
{
  "projectName": "My Portfolio Site",
  "seed": true,
  "projectStructureType": "DIRECT"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `projectName` | string | **Yes** | Human-readable project name. Used to generate the projectId. |
| `seed` | boolean | No | When `true`, automatically scaffolds the project using the canonical SiteMills project template (Preact app shell, backend handlers, contracts, PWA manifest, and service worker push notification handlers). |
| `projectStructureType` | string | No | Project layout structure, defaults to `DIRECT`. |
| `files` | `Map<String, String>` | Yes (unless `seed: true`) | Initial file paths → contents. Optional when `seed: true`. |

**Response: `200 OK`**
```json
{
  "projectId": "my-portfolio-site",
  "branchId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "success": true,
  "message": "Project imported successfully"
}
```

> **Save the `projectId` and `branchId`** — you'll need both for export and push.

**Errors:**

| Code | Reason |
|------|--------|
| `400` | Missing project name or empty files |
| `401` | Invalid or missing API key |
| `409` | Project ID already exists |

---

### 2. Pull Project Code (Full Export)

Download the complete source code for a project branch.

```
GET /api/v1/agent/projects/{projectId}/export?branchId={branchId}
```

**Headers:**
```
X-Developer-Api-Key: <your_api_key>
```

**Query Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `branchId` | No | Specific branch to export. If omitted, uses the first/default branch. |

**Response: `200 OK`**
```json
{
  "projectId": "my-portfolio-site",
  "projectName": "My Portfolio Site",
  "branchId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "exportedAt": "2026-06-04T15:00:00Z",
  "files": {
    "app.tsx": "import { h } from 'preact';\n...",
    "styles.css": "@tailwind base;\n...",
    "index.html": "<!DOCTYPE html>\n...",
    "server/handlers.ts": "export default {\n...",
    "tailwind.config.json": "{ \"theme\": { ... } }"
  }
}
```

**Notes:**
- Internal/framework files (`api/*`, `backend-store.js`, `*.js.map`, `*.d.ts`) are automatically excluded.
- The `files` map is keyed by **relative path** from the project root.
- Asset files (images, fonts) under `assets/` are returned as data URIs.
- The `branchId` is included in the response for use in push requests.

**Errors:**

| Code | Reason |
|------|--------|
| `401` | Invalid or missing API key |
| `404` | No files found, or project does not exist |

---

### 3. Push Changed Files (Partial Update)

Send **only the files that changed** back to SiteMills. This persists the changes, creates a new snapshot and code version, then automatically triggers compilation and deployment.

**Only works on projects created via this API** (the import endpoint).

```
POST /api/v1/agent/projects/{projectId}/push
```

**Headers:**
```
X-Developer-Api-Key: <your_api_key>
Content-Type: application/json
```

**Request Body:**
```json
{
  "branchId": "a1b2c3d4-...",
  "files": {
    "app.tsx": "import { h } from 'preact';\n// updated component\n...",
    "styles.css": "/* updated styles */\n..."
  },
  "deletedFiles": [
    "old-component.tsx"
  ],
  "message": "Refactored navigation component"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `branchId` | string | **Yes** | Target branch to update (from import or export response). |
| `files` | `Map<String, String>` | **Yes**, unless `deletedFiles` is non-empty | Changed/new file paths → contents. Only include files that were modified or added. |
| `deletedFiles` | `string[]` | No | File paths to remove from the project. A request may contain only deletions. |
| `message` | string | No | Description of the change (stored in version history). |

**Response: `200 OK`**
```json
{
  "success": true,
  "filesPersisted": 2,
  "filesDeleted": 1,
  "snapshotId": "snap-uuid-...",
  "compilation": {
    "success": true,
    "compilationSuccess": true,
    "testsPassed": true,
    "message": "✅ Compiled 5 frontend files.\n✅ Backend TypeScript compiled and deployed successfully (2 files).\n🧪 Tests: 3 passed, 0 failed"
  }
}
```

**When compilation fails:**
```json
{
  "success": false,
  "filesPersisted": 2,
  "filesDeleted": 0,
  "snapshotId": "snap-uuid-...",
  "compilation": {
    "success": false,
    "compilationSuccess": false,
    "testsPassed": false,
    "message": "❌ Frontend compilation failed:\n  app.tsx:42:5: Property 'onClick' does not exist on type ...",
    "structuredErrors": [
      {
        "domain": "FRONTEND",
        "file": "app.tsx",
        "line": 42,
        "column": 5,
        "message": "Property 'onClick' does not exist on type 'IntrinsicAttributes'"
      }
    ]
  }
}
```

**Errors:**

| Code | Reason |
|------|--------|
| `400` | Both `files` and `deletedFiles` are empty, or missing branchId |
| `401` | Invalid or missing API key |
| `403` | Project was not created via the Developer API |
| `404` | Project not found |
| `409` | A workflow is currently running on this branch (cannot push while agent is active) |

> **Key:** Files are persisted even if compilation fails. The agent can read the structured errors and push a corrected version. To catch errors *before* persisting anything, use the [Check endpoint](#3b-check-compile-only-no-save-no-deploy).

---

### 3a. File Manifest (What Changed?)

Returns a SHA-256 hash for every file on the branch, without the file contents. Compare it with hashes of your local files to find out which files to send to push, and which remote files no longer exist locally, without downloading the whole project.

```
GET /api/v1/agent/projects/{projectId}/manifest?branchId={branchId}
```

**Response: `200 OK`**
```json
{
  "branchId": "a1b2c3d4-...",
  "files": {
    "app.tsx": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
    "public/logo.png": "60303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752"
  }
}
```

Each hash is the lowercase hex SHA-256 of the file's content string encoded as UTF-8, exactly as it was sent in `files` (binary files are hashed as their `data:` URI string).

---

### 3b. Check (Compile Only, No Save, No Deploy)

Compiles your changes against the current branch state **without saving or deploying anything**. The server applies `files` and `deletedFiles` to the branch in memory and runs the same frontend and backend compilation as push. It creates no snapshot or version, does not touch the live branch, and runs no sandbox tests.

```
POST /api/v1/agent/projects/{projectId}/check
```

**Request Body:** same shape as push (`branchId`, `files`, `deletedFiles`). Both maps may be empty to check the current branch state as is.

**Response: `200 OK`**
```json
{
  "success": false,
  "message": "❌ Frontend compilation failed:\n  app.tsx:42:5: ...",
  "structuredErrors": [
    { "domain": "FRONTEND", "file": "app.tsx", "line": 42, "column": 5, "message": "..." }
  ]
}
```

`success` is `true` only when both frontend and backend compile.

---

### 4. Refresh / Re-pull Project Code

If your local state becomes stale or out of sync, simply call the **Pull** endpoint again to get the latest state:

```
GET /api/v1/agent/projects/{projectId}/export?branchId={branchId}
```

This is the same as endpoint #2. The response always reflects the **current HEAD** snapshot for the branch.

**Recommended refresh triggers:**
- Before starting a new editing session
- After receiving a `409 Conflict` (workflow completed since last pull)
- Periodically during long-running agent sessions

---

## Agent Workflow — Recommended Pattern

### 1. Create the Project

```bash
export SM_API_KEY="sitemills-developer-api-secret"
export SM_BASE="http://localhost:8093"

# Create a new project
IMPORT_RESPONSE=$(curl -s -X POST \
  -H "X-Developer-Api-Key: $SM_API_KEY" \
  -H "Content-Type: application/json" \
  "$SM_BASE/api/v1/agent/projects/import" \
  -d '{
    "projectName": "My Portfolio Site",
    "files": {
      "app.tsx": "export default function App() { return <h1>Hello</h1>; }",
      "styles.css": "body { font-family: sans-serif; }",
      "index.html": "<!DOCTYPE html><html><body><div id=\"app\"></div></body></html>"
    }
  }')

# Extract projectId and branchId for later use
export PROJECT_ID=$(echo "$IMPORT_RESPONSE" | jq -r '.projectId')
export BRANCH_ID=$(echo "$IMPORT_RESPONSE" | jq -r '.branchId')
echo "Created project: $PROJECT_ID, branch: $BRANCH_ID"
```

### 2. Pull Full Project (for reference)

```bash
curl -s -H "X-Developer-Api-Key: $SM_API_KEY" \
  "$SM_BASE/api/v1/agent/projects/$PROJECT_ID/export?branchId=$BRANCH_ID" \
  > /tmp/sitemills-project/project.json

# Extract files to disk
cat /tmp/sitemills-project/project.json | jq -r '.files | to_entries[] | @base64' | \
  while read entry; do
    FILE=$(echo "$entry" | base64 -d | jq -r '.key')
    mkdir -p "/tmp/sitemills-project/$(dirname $FILE)"
    echo "$entry" | base64 -d | jq -r '.value' > "/tmp/sitemills-project/$FILE"
  done
```

### 3. Edit → Push → Iterate Loop

```bash
# Edit files locally with your agent...

# Optional: compile without saving anything first
#   POST $SM_BASE/api/v1/agent/projects/$PROJECT_ID/check  (same body as push)

# Push only changed files
curl -s -X POST \
  -H "X-Developer-Api-Key: $SM_API_KEY" \
  -H "Content-Type: application/json" \
  "$SM_BASE/api/v1/agent/projects/$PROJECT_ID/push" \
  -d "{
    \"branchId\": \"$BRANCH_ID\",
    \"files\": {
      \"app.tsx\": \"export default function App() { return <h1>Updated!</h1>; }\"
    },
    \"message\": \"Updated heading text\"
  }"

# Check the response for compilation/test results
# If compilation failed, fix the errors and push again
# If tests failed, fix the code and push again
```

### 4. Refresh When Needed

```bash
# If state is out of sync, pull the full project again
curl -s -H "X-Developer-Api-Key: $SM_API_KEY" \
  "$SM_BASE/api/v1/agent/projects/$PROJECT_ID/export?branchId=$BRANCH_ID" \
  > /tmp/sitemills-project/project.json
```

---

## File Path Conventions

SiteMills projects use a flat-ish file structure:

| Path Pattern | Domain | Description |
|-------------|--------|-------------|
| `app.tsx` or `public/app-shell.tsx` | Frontend | Main application entry point |
| `*.tsx`, `*.ts`, `*.jsx`, `*.js` | Frontend | Components and modules |
| `styles.css` or `public/styles.css` | Frontend | Global styles (Tailwind processed) |
| `index.html` or `public/index.html` | Frontend | HTML shell |
| `tailwind.config.json` | Frontend | Tailwind CSS configuration |
| `public/sw.js` | Frontend / PWA | Service worker handling offline caching, app lifecycle, and Web Push notifications (`push`, `notificationclick`) |
| `public/manifest.json` | Frontend / PWA | Web App Manifest defining icons, theme colors, and standalone display mode |
| `server/handlers.ts` or `server/handlers/*.ts` | Backend | Server-side request handlers |
| `server/tests.ts` | Backend | Server-side test suite |
| `server/*.ts` | Backend | Any backend TypeScript files |
| `contracts/*.json` | Backend | API contracts defining typed interfaces between frontend and backend |
| `assets/*` | Assets | Images, fonts, etc. (stored as data URIs) |

> **Do NOT include** these in your push (they are platform-managed): `api/*`, `backend-store.js`, `*.js.map`, `*.d.ts`

---

## Progressive Web Apps (PWA) & Push Notifications

SiteMills projects provide built-in Progressive Web App (PWA) capabilities and service worker push notification handling.

### Service Worker (`public/sw.js`)
When a project is created via `sitemills-cli seed` (or imported with `seed: true`), the default service worker provides:
- **Offline Caching**: Caches core shell assets (`index.html`, `styles.css`, `manifest.json`, `app-shell.js`) using a stale-while-revalidate strategy.
- **Web Push Handling**: Listens to browser `push` events and displays notifications using `event.waitUntil(self.registration.showNotification(title, options))`.
- **Notification Clicks**: The `notificationclick` event focuses an existing open tab or navigates a new window to the target URL.

### Notification Best Practices
- **Server-Side Dispatch**: Web push notifications must be dispatched from a backend handler, scheduled cron job, or the SiteMills push gateway. Do NOT use `setTimeout` or intervals inside the service worker for delayed reminders, as mobile browsers terminate or freeze service worker threads within 15–30 seconds when the screen turns off or the app is backgrounded.
- **Delivery Urgency**: The platform push gateway sends notifications with RFC 8030 `Urgency: high` and a 24-hour TTL, ensuring notifications wake devices from low-power states (Android Doze mode and iOS low-power mode).

---

## Compilation Pipeline

When you push changes, SiteMills runs the following pipeline automatically:

```
┌────────────────────────────────────────────────────────┐
│  1. Validate   →  Structural + reference error check   │
│  2. Compile FE →  TSX/TS/JS/CSS → bundled JS + CSS    │
│  3. Deploy BE  →  server/*.ts → isolate deployment     │
│  4. Run Tests  →  server/tests.ts on sandbox branch    │
└────────────────────────────────────────────────────────┘
```

- **Step 1** catches structural errors (syntax, missing exports) before compilation.
- **Step 2** compiles all frontend files using the SiteMills compiler service (esbuild-based with Tailwind CSS processing).
- **Step 3** deploys backend TypeScript to an isolated runtime.
- **Step 4** runs backend tests on a forked sandbox branch (so test side-effects don't pollute the main branch).

### Structured Errors

When compilation or tests fail, the response includes `structuredErrors` with:

```json
{
  "domain": "FRONTEND | BACKEND | TEST",
  "file": "app.tsx",
  "line": 42,
  "column": 5,
  "message": "Property 'onClick' does not exist on type..."
}
```

Use these for precise error correction without guessing.

---

## Error Handling

| HTTP Code | Meaning | Agent Action |
|-----------|---------|--------------|
| `200` | Success | Process the response |
| `400` | Bad request (missing fields, invalid data) | Fix the request |
| `401` | Invalid or missing API key | Check your `X-Developer-Api-Key` header |
| `403` | Forbidden — project not API-managed | You can only push to projects you created via import |
| `404` | Project or branch not found | Check projectId/branchId |
| `409` | Conflict (workflow running, or project exists) | Wait and retry, or refresh |
| `500` | Server error | Retry with backoff |

---

## Rate Limits & Best Practices

1. **Create once, push many.** Import creates the project; use push for all subsequent changes.
2. **Minimize full pulls.** Only call `/export` at the start of a session or when state is known to be stale.
3. **Push small deltas.** Only include files that actually changed. Use `GET /manifest` to find them by hash instead of re-downloading the project with `/export`.
4. **Check before you push.** `POST /check` returns the same compiler diagnostics as push without creating a version or deploying.
5. **Read structured errors.** Use `structuredErrors` rather than parsing the human-readable `message` string.
6. **Use the `message` field** in push requests to document what changed — this appears in version history.
7. **Handle 409 gracefully.** If you get a conflict, wait for the running workflow to finish, then refresh and retry.
8. **Save your branchId.** It's returned in import and export responses — you need it for every push.

---

## Quick Reference Card

| Action | Method | Endpoint |
|--------|--------|----------|
| Create project | `POST` | `/api/v1/agent/projects/import` |
| Pull full project | `GET` | `/api/v1/agent/projects/{id}/export?branchId=...` |
| File hashes (manifest) | `GET` | `/api/v1/agent/projects/{id}/manifest?branchId=...` |
| Compile-only check | `POST` | `/api/v1/agent/projects/{id}/check` |
| Push changed files | `POST` | `/api/v1/agent/projects/{id}/push` |
| Refresh (re-pull) | `GET` | `/api/v1/agent/projects/{id}/export?branchId=...` |
| Get Env Vars | `GET` | `/api/v1/agent/projects/{id}/env?environment=...` |
| Set Env Var | `PUT` | `/api/v1/agent/projects/{id}/env/{name}` |
| Get Preview Token | `GET` | `/api/v1/agent/projects/{id}/preview-token` |
| Deploy Project | `POST` | `/api/v1/agent/projects/{id}/deploy` |
| Create Checkpoint | `POST` | `/api/v1/agent/projects/{id}/checkpoint` |
| Get Logs | `GET` | `/api/v1/agent/projects/{id}/logs` |
| Get AI Workflows | `GET` | `/api/v1/agent/projects/{id}/ai-workflows` |
| Get Metrics | `GET` | `/api/v1/agent/projects/{id}/metrics?eventType=...&from=...&to=...` |
| Get Orders | `GET` | `/api/v1/agent/projects/{id}/orders` |

**All requests require:** `X-Developer-Api-Key: <your_api_key>`

---

## 7. Analytics & Operations

The Developer API exposes robust analytics and operational metrics for managing SiteMills projects programmatically.

### Get Runtime Logs

Fetches application logs across environments.

**Endpoint:** `GET /api/v1/agent/projects/{id}/logs`

**Query Parameters:**
- `branchId` (string, optional): Filter by branch.
- `environment` (string, optional): Filter by environment (`DEV`, `STAGING`, `PROD`).
- `level` (string, optional): Filter by log level (`INFO`, `ERROR`, etc.).
- `limit` (integer, optional): Max results (default 100).

### Get AI Workflows

Fetches the history of AI workflow executions on the project.

**Endpoint:** `GET /api/v1/agent/projects/{id}/ai-workflows`

**Query Parameters:**
- `branchId` (string, optional): Filter by branch.
- `limit` (integer, optional): Max results (default 50).

### Get Metrics

Query analytics metrics for a project (e.g. pageviews, API calls).

**Endpoint:** `GET /api/v1/agent/projects/{id}/metrics`

**Query Parameters:**
- `eventType` (string, required): Type of metric (e.g. `pageview`).
- `from` (string, required): ISO-8601 start date.
- `to` (string, required): ISO-8601 end date.
- `scope` (string, optional): Metric scope.
- `granularity` (string, optional): `hour` or `day`.

### Get Orders

Fetches order and billing history for the project owner.

**Endpoint:** `GET /api/v1/agent/projects/{id}/orders`

**Query Parameters:**
- `limit` (integer, optional): Max results (default 50).

---

## 4. Environment Variables

### Get Environment Variables

Retrieve environment variables for a specific environment (`DEV`, `STAGING`, `PROD`).

**Endpoint:** `GET /api/v1/agent/projects/{id}/env`

**Query Parameters:**
- `environment` (string, required): The environment to fetch (e.g., `DEV`).

**Response:**
```json
{
  "API_URL": {
    "value": "https://api.example.com",
    "environment": "DEV"
  }
}
```

### Upsert Environment Variable

Create or update an environment variable.

**Endpoint:** `PUT /api/v1/agent/projects/{id}/env/{name}`

**Request Body:**
```json
{
  "environment": "DEV",
  "value": "my-secret-value",
  "description": "API Key for third party service"
}
```

---

## 4b. Get Preview Token

Generates a cryptographically signed JWT preview token for unauthenticated access bypass to private non-production environments (`DEV`, `STAGING`, and branch previews).

**Endpoint:** `GET /api/v1/agent/projects/{id}/preview-token`

**Response:**
```json
{
  "previewToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Usage in URLs:**
```text
https://<projectId>-dev.sitemills.com/?preview_token=<previewToken>
https://<projectId>--<branchSlug>.sitemills.com/?preview_token=<previewToken>
```

---

## 5. Deploy Project

Deploys the specified branch to an environment (`DEV`, `STAGING`, `PROD`).

**Endpoint:** `POST /api/v1/agent/projects/{id}/deploy`

**Request Body:**
```json
{
  "branchId": "uuid-of-branch",
  "environment": "STAGING"
}
```

---

## 6. Create Checkpoint

Creates a frozen checkpoint of the current state of a branch.

**Endpoint:** `POST /api/v1/agent/projects/{id}/checkpoint`

**Request Body:**
```json
{
  "branchId": "uuid-of-branch-to-checkpoint",
  "checkpointName": "v1.0 Release"
}
```

---

## 8. Version History & Time Travel

The Developer API supports navigating code history and recovering from mistakes using the undo/redo stack.

### Get Version History

Fetches the sequence of code versions for a project/branch, including whether each version is the current head, and which environments it is deployed to.

**Endpoint:** `GET /api/v1/agent/projects/{id}/versions`

**Query Parameters:**
- `branchId` (string, optional): Filter by branch. Defaults to main branch.
- `limit` (integer, optional): Max results (default 50).

**Response Highlights:**
- `isHead`: True if the version is the current active code state.
- `deployedEnvironments`: Array of strings (e.g. `["PROD"]`) indicating where this exact code version is currently live.

### Undo Version

Roll back the project to the previous version in the history tree.

**Endpoint:** `POST /api/v1/agent/projects/{id}/undo`

**Query Parameters:**
- `branchId` (string, optional): Target branch.

### Redo Version

Move forward to the next version in the history tree, if one exists (i.e., if no new changes were made after an undo).

**Endpoint:** `POST /api/v1/agent/projects/{id}/redo`

**Query Parameters:**
- `branchId` (string, optional): Target branch.
