# SiteMills Server Runtime & RPC Routing Conventions

This document specifies the backend runtime architecture, RPC endpoint discovery mechanics, routing conventions, and TypeScript compilation constraints on the SiteMills platform.

---

## 1. Server Architecture & Execution Environment

SiteMills runs backend application code in high-performance, secure **V8 Isolated VMs**. 
- **Sandboxed Execution**: Handlers execute with zero access to the host Node.js process, host filesystem, or host network sockets.
- **Injected Context (`ctx`)**: All external I/O (database queries, HTTP requests, scheduled jobs, realtime messaging) is mediated through the injected `ctx` platform APIs.
- **Fast Startup & Re-use**: Isolates are pooled and reused across requests. Memory state within global scope persists across invocations within the same worker instance, but should not be relied upon for critical state (use `ctx.db` or `ctx.state` instead).

---

## 2. RPC Discovery & Routing Conventions

### 2.1 File Location & Automatic Discovery

Backend handlers are placed under the `server/` directory, typically in `server/handlers/`:

```
server/
├── handlers/
│   ├── tournament_service.ts
│   ├── team_service.ts
│   └── users/
│       └── profile_service.ts
├── jobs.ts
└── helpers.ts
```

When code is pushed to SiteMills (`sitemills-cli push`), the platform compiler traverses all `.ts` and `.js` files under `server/` and automatically discovers exported functions.

### 2.2 Export Patterns

The platform recognizes two ways to export callable RPC handlers:

#### Pattern A: Direct Exported Async Functions (Recommended)

```typescript
// server/handlers/tournament_service.ts

export async function getTournament(ctx: any, params: { tournamentId: string }) {
  const tournament = await ctx.db.collection('Tournaments').findOne({ _id: params.tournamentId });
  if (!tournament) {
    throw new Error('Tournament not found');
  }
  return tournament;
}

export async function createTournament(ctx: any, params: any) {
  // ...
}
```

#### Pattern B: Scoped Public RPCs via `routes` Object (Recommended for Files with Helpers)

When a file defines an explicit `routes` object, **ONLY** the functions inside `routes` are registered into the global RPC routing table. Other top-level exports in the file (such as shared calculations, formatting utilities, or data transformers) remain module-internal helpers and are **NOT** registered as public RPC endpoints.

```typescript
// server/handlers/tournament_service.ts

// 1. Internal module helpers (can be exported and imported by other files without global RPC collision)
export function formatTournamentScore(score: number): string {
  return score.toFixed(1);
}

// 2. Public RPC routes exposed to the client
export const routes = {
  getTournament: async (ctx: any, params: { tournamentId: string }) => {
    const tournament = await ctx.db.collection('Tournaments').findOne({ _id: params.tournamentId });
    if (!tournament) throw new Error('Tournament not found');
    return tournament;
  },
  createTournament: async (ctx: any, params: any) => {
    // ...
  }
};
```

> [!TIP]
> **Pure Utility Files (Zero Public RPC Routes)**:
> If a file under `server/handlers/` or `server/` contains shared helper functions but should NOT expose any public RPC routes, declare an empty `routes` object:
> ```typescript
> export const routes = {};
> export function sharedHelperA() { ... }
> export function sharedHelperB() { ... }
> ```

### 2.3 RPC Endpoint Routing & Aliasing

Every discovered handler is automatically registered under multiple route aliases:

1. **Bare Function Name**: `getTournament`
2. **File Stem Prefix**: `tournament_service.getTournament`
3. **Simplified Service Prefix**: `tournament.getTournament` (if the file ends in `_service.ts` or `_handler.ts`)
4. **Full Path Prefix**: `server/handlers/tournament_service.getTournament`

For subdirectories (e.g. `server/handlers/users/profile_service.ts`):
- `users/profile_service.updateProfile`
- `users/profile.updateProfile`

> [!IMPORTANT]
> **No Root Hub Re-Exporting Required**:
> Developers **do NOT** need to maintain a central hub file (like `index.ts` or re-exporting every service in `tournament_service.ts`). Every exported function across all files under `server/handlers/` is automatically registered and callable by client requests and auto-generated stubs.

### 2.4 Auto-Generated Frontend Stubs

When `sitemills-cli push` succeeds, the platform inspects the discovered handler signatures and automatically generates type-safe client stubs:
- Generated at: `public/stubs/api-client.ts` (or `src/services/api-client.ts`)
- Frontend views and components should import and call methods directly from this client:
  ```typescript
  import { api } from './stubs/api-client';

  const tournament = await api.tournament_service.getTournament({ tournamentId: 'xyz' });
  ```
- **Do not edit stub files manually**: They are overwritten automatically on every push.

---

## 3. Cloud TypeScript Compilation & Strict Constraints

During `sitemills-cli push`, backend files are compiled in the cloud before isolate deployment. The cloud compiler operates under strict TypeScript checks.

### 3.1 Compiler Configuration

The cloud compiler runs with:
- **Target**: `ES2020`
- **Module**: `CommonJS`
- **Module Resolution**: `NodeJs`
- **Strict Diagnostics**: Warnings and errors are captured; any diagnostic with `DiagnosticCategory.Error` will fail compilation and abort the push.

### 3.2 Common Compilation Errors & Resolutions

#### 1. Implicit Parameter Types (TS7006)
- **Problem**: In local JavaScript or loosely-configured TypeScript, developers often write:
  ```typescript
  export async function myHandler(ctx, params) { ... } // FAILS
  ```
- **Error in CLI**: `server/handlers/my_handler.ts:1:32: [7006] Parameter 'ctx' implicitly has an 'any' type.`
- **Resolution**: Always explicitly type handler parameters:
  ```typescript
  export async function myHandler(ctx: any, params: any) { ... } // OK
  ```
  Or define typed interfaces:
  ```typescript
  interface UpdateParams {
    userId: string;
    role: string;
  }

  export async function myHandler(ctx: any, params: UpdateParams) { ... } // OK
  ```

#### 2. Missing Return Types on Helpers
- Exported helper utilities in `server/` must have valid TypeScript syntax and resolve all imports.

#### 3. Unresolved Cross-File Imports
- Relative imports work seamlessly:
  ```typescript
  import { calculateElo } from './ladder_engine';
  import { TournamentStatus } from '../types';
  ```
- Do not import external npm packages not bundled into the platform isolate (e.g. `axios`, `express`, `fs`). Use platform context APIs instead (`ctx.http.fetch`, `ctx.db`).

---

## 4. Handler Context (`ctx`) Reference

Every RPC handler receives `(ctx, params)`:

| API | Description |
|---|---|
| `ctx.db` | MongoDB Collections DB (`ctx.db.collection('name')`) with full CRUD, aggregation pipelines, and transactions. |
| `ctx.user` | The authenticated user context (`{ id, email, role, ... }`) or `null` if unauthenticated. |
| `ctx.session` | Session metadata (`{ sessionId, createdAt, ... }`). |
| `ctx.http` | Outgoing HTTP requests (`await ctx.http.fetch(url, options)`). |
| `ctx.realtime` | WebSocket broadcast and direct client messaging. |
| `ctx.ai` | AI LLM completions and embeddings. |
| `ctx.storage` | Blob and object storage upload/download. |
| `ctx.orders` | Payment processing and Stripe checkout. |
| `ctx.env` | Project environment variables configured via `sitemills-cli env-set`. |
| `ctx.metrics` | Custom metric telemetry emission. |
