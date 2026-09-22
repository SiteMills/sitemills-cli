# SiteMills Platform Architecture & Integration Guide

Welcome to the **SiteMills Platform Documentation**. This guide provides an extensive reference for developers and AI agents build-integrating with the SiteMills ecosystem.

---

## 1. High-Level Architecture

SiteMills is designed around a decoupled, service-oriented architecture combining Spring Boot microservices, Node.js sandboxed execution runtimes (V8 Isolates), and RabbitMQ queue-based workflow management.

```
                  ┌────────────────────────────────────────┐
                  │            Client Browser              │
                  └────────────────────────────────────────┘
                                       │
                                    HTTP/WS
                                       ▼
                  ┌────────────────────────────────────────┐
                  │                 WebFE                  │
                  └────────────────────────────────────────┘
                                       │
                         Internal HTTP / RabbitMQ
                                       ▼
    ┌──────────────────────┬──────────────────────┬──────────────────────┐
    │   dashboardservice   │     agentservice     │     chatservice      │
    └──────────────────────┴──────────────────────┴──────────────────────┘
               │                       │                       │
               └───────────┬───────────┴───────────┬───────────┘
                           ▼                       ▼
              ┌────────────────────────┐┌────────────────────────┐
              │     clientisolates     ││        Redis /         │
              │  (V8 Sandbox Runtime)  ││     MongoDB / S3       │
              └────────────────────────┘└────────────────────────┘
```

### Core Services
- **`webfe`**: Spring Boot service serving the main user frontend resources.
- **`dashboardservice`**: Platform dashboard backend managing user projects, branches, analytics, and permissions.
- **`agentservice`**: Workflows execution service managing AI code modifications and terminal compilation commands.
- **`chatservice`**: Real-time websocket communication layer for support and team chat.
- **`clientisolates`**: Sandboxed V8 engine execution server running user-defined backend handler modules.

---

## 2. Sandbox Execution VM (`execute_script`)

For batch file processing, AST-based codebase modification, and testing backend code, SiteMills features a V8 Isolate sandboxed virtual machine via the `execute_script` tool.

### In-Memory Filesystem (`fs`)
Scripts in the VM operate on a virtual, synchronous copy of the project files:
- **Relative Path Resolution**: All paths are relative to the project root (e.g., `src/App.tsx`, `server/handlers.ts`).
- `fs.readFile(path)`: Synchronously reads file content.
- `fs.writeFile(path, content)`: Writes/overwrites file content.
- `fs.exists(path)`: Checks file existence.
- `fs.listFiles()`: List of all files in workspace.
- `fs.grep(query)`: Ripgrep-style search.
- `fs.replaceInFile(path, search, replacement)` / `fs.replaceInFiles(paths, search, replacement)`.
- `fs.insertAfter(path, search, codeToInsert)` / `fs.insertBefore(path, search, codeToInsert)`.

### System Interface (`sys`)
Provides direct access to execute platform tasks:
- `await sys.callTool('build_and_deploy', {})`: Asynchronously trigger project build.
- `sys.dashboard.env`: Plaintext/masked secret get/set methods.
- `sys.dashboard.permissions`: Role management and invitation actions.
- `sys.project.deployAndTest()`: Build, deploy to sandbox branch, and execute tests.
- `sys.backend.call(route, payload, userContext)`: Directly invoke a backend TypeScript handler within the isolate workspace with optional mock user permissions.

*For more details, see the [`EXECUTE_SCRIPT_VM_GUIDE.md`](EXECUTE_SCRIPT_VM_GUIDE.md).*

---

## 3. Isolate Runtime & Context (`ctx`)

When a user's backend handler (`server/handlers.ts`) runs in the sandbox isolate, it is passed a `ctx` object. The `ctx` object acts as the SDK bridge connecting the sandbox code to sitemills platform integrations.

### SDK Bridge & Provider Design
Methods invoked on the `ctx` object are intercepted by an internal **SDK Bridge**, which parses the integration prefix (e.g., `storage` from `ctx.storage.getUploadMetadata`) and delegates the execution to a registered `IntegrationProvider`.

---

## 4. Integration Support Grid

SiteMills defines a canonical lock-file of integration modules (`integrations.lock.json`). The table below outlines what services are supported, which are enabled inside the isolated backend runtime, and where to find their specific documentation:

| Integration ID | SDK Prefix | Isolate Runtime? | Frontend? | Documentation Reference |
|---|---|:---:|:---:|---|
| **`ai`** | `ctx.ai` | **Yes** | Yes | [`integrations/ctx-ai.md`](integrations/ctx-ai.md) |
| **`email`** | `ctx.email` | **Yes** | No | [`integrations/ctx-email.md`](integrations/ctx-email.md) |
| **`env`** | `ctx.env` | **Yes** | No | [`integrations/ctx-env.md`](integrations/ctx-env.md) |
| **`googlemaps`**| `ctx.googlemaps` | **Yes** | No | [`integrations/ctx-googlemaps.md`](integrations/ctx-googlemaps.md) |
| **`http`** | `ctx.httpClient` | **Yes** | No | [`integrations/ctx-http.md`](integrations/ctx-http.md) |
| **`orders`** | `ctx.orders` | **Yes** | Yes | [`integrations/ctx-orders.md`](integrations/ctx-orders.md) |
| **`p2p`** | `ctx.p2p` | **Yes** | No | [`integrations/ctx-p2p.md`](integrations/ctx-p2p.md) |
| **`permissions`**| `ctx.permissions`| **Yes** | Yes | [`integrations/ctx-permissions.md`](integrations/ctx-permissions.md) |
| **`queue`** | `ctx.queue` | **Yes** | No | [`integrations/ctx-queue.md`](integrations/ctx-queue.md) |
| **`realtime`** | `ctx.realtime` | **Yes** | No | [`integrations/ctx-realtime.md`](integrations/ctx-realtime.md) |
| **`storage`** | `ctx.storage` | **Yes** | No | [`integrations/ctx-storage.md`](integrations/ctx-storage.md) |
| **`analytics`** | — | **No** | Yes | *Frontend analytics only. Unsupported in server isolate.* |
| **`jobs`** | — | **No** | Yes | *WebFE scheduled job dashboard config only. No isolate SDK.* |
| **`logs`** | — | **No** | Yes | *Dashboard display only. Server handlers use `console.log`.* |

---

## 5. Summary of Supported SDK Features

- **Asynchronous AI Jobs (`ctx.ai`)**: Enqueue chat prompts and one-shot classifications that execute out-of-band and trigger callback routes. Support for model parameterization (e.g. `gemini-3-pro`, `gemini-3-flash-lite`), grounding via Google Search, and attaching project files.
- **Outbound HTTP (`ctx.httpClient`)**: Full REST API clients enabling sandboxed code to request third-party resources.
- **Real-Time Websockets (`ctx.realtime`)**: Establish subscription channels, track clients, and fanout event payloads to connected users.
- **Stripe Payments (`ctx.orders`)**: Initiate customer onboarding, generate checkout sessions, and fulfill purchases post-payment.
- **Durable Storage (`ctx.storage`)**: Write files to cloud buckets, validate metadata, and download blobs.
- **Permissions RBAC (`ctx.permissions`)**: Check if an actor is authorized to perform specific resource-level actions.
- **Background Tasks (`ctx.queue`)**: Schedule delayed workflows or defer compute-heavy actions.


---

## Project URLs & Deployment Hostnames

SiteMills clearly distinguishes between the **Platform Management Dashboard** and the **Live Deployed Client Applications**:

| Purpose | URL / Hostname Pattern | Access Policy | Example |
|---|---|---|---|
| **Production Live Application (`PROD`)** | `https://<projectId>.sitemills.com` | **Public** (no auth required) | `https://gradeprep.sitemills.com` |
| **Staging Live Application (`STAGING`)** | `https://<projectId>-staging.sitemills.com` | **Private** (requires login or `?preview_token=...`) | `https://gradeprep-staging.sitemills.com/?preview_token=...` |
| **Development Live Application (`DEV`)** | `https://<projectId>-dev.sitemills.com` | **Private** (requires login or `?preview_token=...`) | `https://gradeprep-dev.sitemills.com/?preview_token=...` |
| **Branch Preview URL** | `https://<projectId>--<branchSlug>.sitemills.com` | **Private** (requires login or `?preview_token=...`) | `https://gradeprep--e4d7df82.sitemills.com/?preview_token=...` |
| **Platform Project Console / IDE** | `https://sitemills.com/project/<projectId>` | `https://sitemills.com/project/gradeprep` |
| **Project Planning Board** | `https://sitemills.com/project/<projectId>/planning` | `https://sitemills.com/project/gradeprep/planning` |
| **Project Settings / Variables** | `https://sitemills.com/project/<projectId>/settings` | `https://sitemills.com/project/gradeprep/settings` |

> [!WARNING]
> **Important URL Distinction:**
> - **Live Deployed Websites**: Web applications deployed to SiteMills are hosted on subdomains: `https://<projectId>.sitemills.com` for Production, `https://<projectId>-staging.sitemills.com` for Staging, and `https://<projectId>-dev.dev.sitemills.com` for Dev.
> - **Platform Console Dashboard**: The web dashboard is located at `https://sitemills.com/project/<projectId>` (singular `/project/`, **not** plural `/projects/`). Never link to `https://sitemills.com/projects/<projectId>` as that is an internal API route prefix (`/api/v1/projects/...`) and will fail to load in the browser.

