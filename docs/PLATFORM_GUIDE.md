# SiteMills Platform Architecture & Integration Guide

Welcome to the **SiteMills Platform Documentation**. This guide provides an extensive reference for developers and AI agents build-integrating with the SiteMills ecosystem.

---

## 1. High-Level Architecture

SiteMills is designed around a high-performance, distributed cloud architecture combining web application gateways, sandboxed execution runtimes (V8 Isolates), persistent document storage, and an asynchronous event bus.

```
                  ┌────────────────────────────────────────┐
                  │            Client Browser              │
                  └────────────────────────────────────────┘
                                       │
                                    HTTP/WS
                                       ▼
                  ┌────────────────────────────────────────┐
                  │          Application Gateway           │
                  └────────────────────────────────────────┘
                                       │
                             Secure Platform Mesh
                                       ▼
    ┌──────────────────────┬──────────────────────┬──────────────────────┐
    │   Management API     │   Automation Engine  │   Realtime Gateway   │
    └──────────────────────┴──────────────────────┴──────────────────────┘
               │                       │                       │
               └───────────┬───────────┴───────────┬───────────┘
                           ▼                       ▼
              ┌────────────────────────┐┌────────────────────────┐
              │  Sandboxed Serverless  ││   Managed Databases    │
              │     (V8 Isolates)      ││   & Object Storage     │
              └────────────────────────┘└────────────────────────┘
```

### Core Platform Architecture
- **Application Gateway**: Edge proxy routing web requests, managing SSL/TLS, and serving frontend static assets.
- **Management API**: Platform backend managing user projects, deployment branches, analytics, and access control.
- **Automation Engine**: Service managing deployment builds, preview generations, and AI code workflow pipelines.
- **Realtime Gateway**: Scalable WebSocket communication layer for real-time messaging, updates, and pub/sub topics.
- **Sandboxed Serverless Runtime**: Secure V8 engine isolate worker running user-defined backend handler modules with zero host access.

---

## 2. Server Runtime & Context (`ctx`)

Backend handlers (`server/handlers.ts`) run in a sandboxed V8 isolate. Each handler receives a `ctx` object as its first argument, which gives access to the platform integrations listed below (for example `ctx.db`, `ctx.storage`, `ctx.ai`).

---

## 3. Integration Support Grid

The table below lists the supported integrations, whether they are available on the server `ctx`, and where to find their documentation:

| Integration ID | SDK Prefix | Isolate Runtime? | Frontend? | Documentation Reference |
|---|---|:---:|:---:|---|
| **`ai`** | `ctx.ai` | **Yes** | Yes | [`integrations/ctx-ai.md`](integrations/ctx-ai.md) |
| **`dwolla`** | `ctx.dwolla` | **Yes** | No | [`integrations/ctx-dwolla.md`](integrations/ctx-dwolla.md) |
| **`email`** | `ctx.email` | **Yes** | No | [`integrations/ctx-email.md`](integrations/ctx-email.md) |
| **`env`** | `ctx.env` | **Yes** | No | [`integrations/ctx-env.md`](integrations/ctx-env.md) |
| **`google-workspace`** | `ctx.googleWorkspace` | **Yes** | No | [`integrations/ctx-google-workspace.md`](integrations/ctx-google-workspace.md) |
| **`googlemaps`**| `ctx.googlemaps` | **Yes** | No | [`integrations/ctx-googlemaps.md`](integrations/ctx-googlemaps.md) |
| **`http`** | `ctx.httpClient` | **Yes** | No | [`integrations/ctx-http.md`](integrations/ctx-http.md) |
| **`jobs`** | — | **Yes** | Yes | Background and recurring tasks in `server/jobs.ts`. See [`SCHEDULED_JOBS.md`](SCHEDULED_JOBS.md). |
| **`logs`** | `ctx.logs` | **Yes** | Yes | [`integrations/ctx-logs.md`](integrations/ctx-logs.md) |
| **`orders`** | `ctx.orders` | **Yes** | Yes | [`integrations/ctx-orders.md`](integrations/ctx-orders.md) |
| **`p2p`** | `ctx.p2p` | **Yes** | No | [`integrations/ctx-p2p.md`](integrations/ctx-p2p.md) |
| **`permissions`**| `ctx.permissions`| **Yes** | Yes | [`integrations/ctx-permissions.md`](integrations/ctx-permissions.md) |
| **`plaid`** | `ctx.plaid` | **Yes** | No | [`integrations/ctx-plaid.md`](integrations/ctx-plaid.md) |
| **`push`** | `ctx.push` | **Yes** | Yes | [`integrations/ctx-push.md`](integrations/ctx-push.md) |
| **`queue`** | `ctx.queue` | **Yes** | No | [`integrations/ctx-queue.md`](integrations/ctx-queue.md) |
| **`realtime`** | `ctx.realtime` | **Yes** | No | [`integrations/ctx-realtime.md`](integrations/ctx-realtime.md) |
| **`sms`** | `ctx.sms` | **Yes** | No | [`integrations/ctx-sms.md`](integrations/ctx-sms.md) |
| **`storage`** | `ctx.storage` | **Yes** | No | [`integrations/ctx-storage.md`](integrations/ctx-storage.md) |
| **`analytics`** | — | **No** | Yes | *Frontend analytics only. Unsupported in server isolate.* |

---

## 4. Summary of Supported SDK Features

- **Asynchronous AI Jobs (`ctx.ai`)**: Enqueue chat prompts and one-shot classifications that execute out-of-band and trigger callback routes. Support for model parameterization (e.g. `gemini-3-pro`, `gemini-3-flash-lite`), grounding via Google Search, and attaching project files.
- **Outbound HTTP (`ctx.httpClient`)**: Full REST API clients enabling sandboxed code to request third-party resources.
- **Real-Time Websockets (`ctx.realtime`)**: Establish subscription channels, track clients, and fanout event payloads to connected users.
- **Stripe Payments (`ctx.orders`)**: Initiate customer onboarding, generate checkout sessions, and fulfill purchases post-payment.
- **Durable Storage (`ctx.storage`)**: Write files to cloud buckets, validate metadata, and download blobs.
- **Permissions RBAC (`ctx.permissions`)**: Check if an actor is authorized to perform specific resource-level actions.
- **Background Tasks (`ctx.queue`)**: Schedule delayed workflows or defer compute-heavy actions.
- **SMS & Text Messaging (`ctx.sms`)**: Send transactional notifications, OTP verification codes, and alerts to mobile numbers via a dedicated toll-free number (+1-866-645-5702). Supports delivery status webhooks and inbound reply tracking.
- **WebRTC Peer-to-Peer (`ctx.p2p`)**: Ephemeral TURN/STUN credential issuance and mesh signaling channel setup for direct browser-to-browser audio, video, and data channels (up to 4 participants).
- **Web Push Notifications (`ctx.push`)**: Send permission-based background web push notifications to subscribed user and guest browsers.
- **ACH Bank Transfers & Verification (`ctx.dwolla`, `ctx.plaid` — BYOK)**: Manage customer onboarding, bank funding sources, Plaid Link token exchange, and direct ACH bank-to-bank transfers using your own API keys stored in the project Keystore (`PLAID_CLIENT_ID`, `PLAID_SECRET`, `DWOLLA_KEY`, `DWOLLA_SECRET` via `sitemills-cli env-set`).
- **Google Workspace (`ctx.googleWorkspace`)**: Access connected Google Calendar, Drive, Docs, Sheets, and Gmail via dashboard-authorized OAuth credentials.
- **Runtime Logging (`ctx.logs`)**: Structured logging from backend handlers (`log`, `info`, `warn`, `error`) visible in the dashboard.


---

## Project URLs & Deployment Hostnames

SiteMills clearly distinguishes between the **Platform Management Dashboard** and the **Live Deployed Client Applications**:

| Purpose | URL / Hostname Pattern | Access Policy | Example |
|---|---|---|---|
| **Production Live Application (`PROD`)** | `https://<site-address>.sitemills.com` | **Public** (no auth required) | `https://gradeprep.sitemills.com` |
| **Staging Live Application (`STAGING`)** | `https://<site-address>-staging.sitemills.com` | **Private** (requires login or `?preview_token=...`) | `https://gradeprep-staging.sitemills.com/?preview_token=...` |
| **Development Live Application (`DEV`)** | `https://<site-address>-dev.sitemills.com` | **Private** (requires login or `?preview_token=...`) | `https://gradeprep-dev.sitemills.com/?preview_token=...` |
| **Branch Preview URL** | `https://<site-address>--<branchSlug>.sitemills.com` | **Private** (requires login or `?preview_token=...`) | `https://gradeprep--e4d7df82.sitemills.com/?preview_token=...` |
| **Platform Project Console / IDE** | `https://sitemills.com/project/<projectId>` | `https://sitemills.com/project/gradeprep` |
| **Project Planning Board** | `https://sitemills.com/project/<projectId>/planning` | `https://sitemills.com/project/gradeprep/planning` |
| **Project Settings / Variables** | `https://sitemills.com/project/<projectId>/settings` | `https://sitemills.com/project/gradeprep/settings` |

> [!WARNING]
> **Important URL Distinction:**
> - **Live Deployed Websites**: Web applications deployed to SiteMills are hosted on subdomains of their site address: `https://<site-address>.sitemills.com` for Production, `https://<site-address>-staging.sitemills.com` for Staging, and `https://<site-address>-dev.sitemills.com` for Dev.
> - **Platform Console Dashboard**: The web dashboard is located at `https://sitemills.com/project/<projectId>` (singular `/project/`, **not** plural `/projects/`). Never link to `https://sitemills.com/projects/<projectId>` as that is an internal API route prefix (`/api/v1/projects/...`) and will fail to load in the browser.

