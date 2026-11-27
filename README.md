# SiteMills CLI

SiteMills CLI Tool for project code management, continuous integration, database seeding, background jobs, sandboxed data operations, and deployment on the SiteMills platform.

## Installation

Pick whichever fits your setup. All of them install the same `sitemills-cli` command.

### macOS / Linux: install script (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/SiteMills/sitemills-cli/main/install.sh | sh
```

Installs to `/usr/local/bin` if it's writable without `sudo`, otherwise `~/.local/bin`. The download is verified against the release's `SHA256SUMS`. The binary keeps itself up to date.

### Windows: install script (recommended)

In PowerShell:

```powershell
irm https://raw.githubusercontent.com/SiteMills/sitemills-cli/main/install.ps1 | iex
```

Installs to `%LOCALAPPDATA%\Programs\sitemills-cli` and adds it to your user `PATH`. No admin rights needed. The binary keeps itself up to date.

### Homebrew (macOS / Linux)

```bash
brew install sitemills/tap/sitemills-cli
```

Upgrade with `brew upgrade sitemills-cli`.

### Scoop (Windows)

```powershell
scoop bucket add sitemills https://github.com/SiteMills/scoop-bucket
scoop install sitemills-cli
```

Upgrade with `scoop update sitemills-cli`.

### npm (any OS with Node.js 18+)

```bash
npm install -g sitemills-cli
```

Upgrade with `npm install -g sitemills-cli@latest`.

### Manual download

Download the binary for your platform from [Releases](https://github.com/SiteMills/sitemills-cli/releases/latest), rename it to `sitemills-cli` (`sitemills-cli.exe` on Windows), and put it on your `PATH`:

- **Linux (x64)**: `sitemills-linux`
- **macOS (Apple Silicon)**: `sitemills-macos-arm64`
- **macOS (Intel)**: `sitemills-macos`
- **Windows (x64)**: `sitemills-win.exe`

Verify it against `SHA256SUMS` from the same release.

> **Note:** This repository holds the CLI's documentation and installers, not an installable package. Cloning it does not install the CLI; use one of the options above.

---

## Authentication & Session Management

SiteMills CLI uses OAuth 2.0 with local loopback callback verification for secure authentication.

### How to Log In

```bash
sitemills-cli login
```

1. **Automatic Browser Launch**: The CLI starts a local loopback server and attempts to open your default browser directly to the SiteMills authorization page.
2. **Headless / Remote / SSH Environments**:
   - If running inside a container, remote server, SSH session, or IDE terminal without a graphical desktop, the CLI will output a clickable login URL:
     ```text
     Opening browser to log in:
       https://sitemills.com/oauth/login?returnUrl=http://localhost:54377/callback
     ```
   - Copy and paste the link into any browser where you are logged into SiteMills.
   - The CLI callback server automatically captures the authentication token and saves it securely to `~/.sitemills/token` with `0600` permissions.
3. **Dynamic Port Discovery**:
   - The CLI starts by attempting port `54321` (or the custom port set via the `PORT` environment variable, e.g. `PORT=54377 sitemills-cli login`).
   - If port `54321` is in use by another service (like PostgreSQL or Docker), the CLI automatically scans and binds to the next available free port without failing.
4. **Token Expiration (HTTP 401)**:
   - If any CLI command fails with `ERROR: Authentication failed. Please log in again using "sitemills-cli login".`, your session token has expired. Simply rerun `sitemills-cli login` to obtain a fresh token.

---

## Developer Guides & Architecture Specifications

SiteMills apps are built on declarative contracts, automatic RPC discovery, sandboxed V8 execution, and structured data operations. Review the comprehensive developer guides below:

| Guide | Description & Scope | Interactive CLI Topic |
|---|---|---|
| **[Contracts & Configuration Guide](docs/CONTRACTS_GUIDE.md)** | Specifications for `contracts/jobs.json` (5-field cron, retries, `JobContext` APIs) vs `server/jobs.ts` (`export const jobs = { ... }`), and `contracts/db.json` (declarative MongoDB collection indexes, unique constraints, compound indexes, TTL expiration). | `sitemills-cli help contracts`<br>`sitemills-cli help jobs`<br>`sitemills-cli help db` |
| **[Server Runtime & RPC Conventions](docs/SERVER_RUNTIME_RPC.md)** | Automatic RPC discovery in `server/handlers/` without central hub re-exports, handler route aliasing, auto-generated stubs (`public/stubs/api-client.ts`), and strict cloud TypeScript compilation constraints (e.g. TS7006 implicit `any` parameter typing). | `sitemills-cli help rpc`<br>`sitemills-cli help typescript` |
| **[Data Operations & Lua Runtime](docs/DATA_OPERATIONS_AND_LUA.md)** | Complete JSON schemas for `sitemills-cli data-op` (`query`, `count`, `seed`, `mutation_preview`, `mutation_apply`, `execute_lua`), sandboxed Lua runtime (`input.docs`, `input.metadata`, allowed/blocked globals, return table structure), and flag restrictions (`--mock-user` strictly rejected in PROD, `--max-write-ops` bounds). | `sitemills-cli help data-op`<br>`sitemills-cli help run-lua`<br>`sitemills-cli help flags` |
| **[Error Diagnostics & Troubleshooting](docs/ERROR_DIAGNOSTICS_AND_TROUBLESHOOTING.md)** | Intelligent CLI error hint engine, debugging MongoDB queries (e.g. `$regex has to be a string`, unknown operators), TypeScript compilation errors, RPC routing mismatches, and mutation count drift. | `sitemills-cli help errors` |
| **[Games Guide](docs/GAMES_GUIDE.md)** | 3D multiplayer games on the SiteMills game engine (Roblox's classes and services in TypeScript, rooms, phones): start from a starter game (`game create "<name>" --template racing`), what's in the folder, the engine's reference (`server/framework/ENGINE.md`), check, push and play; art and sound from the game asset library; 2D games with Phaser. Every starter game's files are in [docs/games/templates](docs/games/templates). | `sitemills-cli help games` |

---

## Quickstart

```bash
sitemills-cli login                    # 1. sign in through your browser
sitemills-cli list                     # 2. find your app's ID or site address
sitemills-cli export <app>             # 3. download it (by ID or site address) into ./<app>
cd <app>
# 4. edit the files, then:
sitemills-cli check                    #    compile your changes without saving anything
sitemills-cli push                     #    upload your changes and update the Working Draft's preview
sitemills-cli deploy prod              # 5. go live (or dev / staging)
```

`export` downloads the app's **Working Draft** and links the folder to it by writing `.sitemills/project.json`. Every command run inside that folder (`check`, `push`, `commit`, `deploy`) uses the link, so you never type IDs. From outside the folder, pass its path instead: `sitemills-cli push ./my-app`.

- The `.sitemills/` folder is never uploaded, and it holds no secrets (your login token lives in `~/.sitemills`), so it's fine to commit it to your own git repo.
- Need a different folder name? `sitemills-cli export <projectId> <outputDir>`.
- Every folder command also accepts the app's ID explicitly: `sitemills-cli push <projectId> [dir]`.
- Wherever a command takes `<projectId>`, you can give the app's **site address** instead: the `<site-address>` in `https://<site-address>.sitemills.com`. `sitemills-cli list` shows both. Older apps have the same project ID and site address; newer apps have a separate project ID.

### Starting from your own code

```bash
sitemills-cli import "My App" ./my-folder   # creates the app and links ./my-folder to it
cd my-folder
sitemills-cli push
```

### Recompile without local changes

```bash
sitemills-cli compile <projectId>
```
*Compiles the app's Working Draft: frontend JSX/TSX components (esbuild + Tailwind CSS) and backend TypeScript handlers into the SiteMills V8 isolate runtime.*

---

## Project URLs & Deployment Hostnames

SiteMills clearly distinguishes between the **Platform Management Dashboard** and the **Live Deployed Client Applications**:

| Purpose | URL / Hostname Pattern | Example |
|---|---|---|
| **Production Live Application (`PROD`)** | `https://<site-address>.sitemills.com` | `https://gradeprep.sitemills.com` |
| **Staging Live Application (`STAGING`)** | `https://<site-address>-staging.sitemills.com` | `https://gradeprep-staging.sitemills.com` |
| **Development Live Application (`DEV`)** | `https://<site-address>-dev.sitemills.com` | `https://gradeprep-dev.sitemills.com` |
| **Branch Preview URL** | `https://<site-address>--<branchId>.sitemills.com/?preview_token=...` | `https://gradeprep--e4d7df82-24b2-4e3b-97ce-5aa4ba5a79ec.sitemills.com` |
| **Platform Project Console / IDE** | `https://sitemills.com/project/<projectId>` | `https://sitemills.com/project/gradeprep` |
| **Project Planning Board** | `https://sitemills.com/project/<projectId>/planning` | `https://sitemills.com/project/gradeprep/planning` |
| **Project Settings / Variables** | `https://sitemills.com/project/<projectId>/settings` | `https://sitemills.com/project/gradeprep/settings` |

> [!WARNING]
> **Important URL Distinction:**
> - **Live Deployed Websites**: Web applications deployed to SiteMills are hosted on subdomains of their site address: `https://<site-address>.sitemills.com` for Production, `https://<site-address>-staging.sitemills.com` for Staging, and `https://<site-address>-dev.sitemills.com` for Dev. Build site links from the site address (`sitemills-cli info` shows it), never from the project ID.
> - **Platform Console Dashboard**: The web dashboard is located at `https://sitemills.com/project/<projectId>` (singular `/project/`, **not** plural `/projects/`). Never link to `https://sitemills.com/projects/<projectId>` as that is an internal API route prefix (`/api/v1/projects/...`) and will fail to load in the browser.

## Preview Access Tokens & Non-Production Environments

Non-production environments (**DEV**, **STAGING**, and **Branch Previews**) are private and developer-gated by default on SiteMills to protect work-in-progress code from unauthorized public access and search engines.

### How `preview_token` Works

1. **Unauthenticated / Guest Access**:
   When you run `sitemills-cli info <projectId>`, `sitemills-cli deploy ...`, `sitemills-cli push ...`, or `sitemills-cli list-branches`, the CLI automatically attaches a cryptographically signed JWT parameter (`?preview_token=...`) to non-production URLs.
   - Send this complete link to clients, QA testers, or open it in incognito/private windows.
   - Upon first visit, SiteMills validates the token and sets a secure `preview_bypass_token` cookie for that session.
   - The user can then navigate internal links, API requests, and pages without needing the parameter repeated.

2. **What Happens When the Token Expires?**:
   - Preview tokens have an expiration lifetime.
   - If an unauthenticated user opens an expired link or the cookie expires, they will receive:
     ```text
     Authentication required. Please log in to SiteMills.
     ```
   - To regain access, simply generate a fresh link using `sitemills-cli info <projectId>` or `sitemills-cli deploy ...`.

3. **Logged-in SiteMills Users**:
   - If a reviewer or team member is logged into their SiteMills account, they **do not need a preview token**.
   - Their active session cookie (`USER_AUTH_TOKEN`) authorizes access directly to all permitted project environments.

4. **Production Environments (`PROD`)**:
   - Production URLs (`https://<site-address>.sitemills.com`) are always public and do not require authentication or preview tokens.

---

## Intelligent Error Diagnostics & Hints

The SiteMills CLI includes an embedded **Error Diagnostics and Hint Engine**. Whenever an operation fails (e.g. push compilation error, invalid MongoDB query in `data-op`, or Lua mutation runtime failure), the CLI parses the server response and outputs clear diagnostic hints and direct documentation links:

```text
ERROR: Push failed (Status 400)
  Message: TypeScript compilation failed

Structured Compilation Errors:
  [compiler] server/handlers/orders.ts:14:32 -> Parameter 'ctx' implicitly has an 'any' type. [TS7006]

DIAGNOSTIC HINT:
  💡 Cloud TypeScript compilation requires explicit type annotations on handler parameters. Add ": any" or dedicated interfaces, e.g. "export async function myHandler(ctx: any, params: any)".

DOCUMENTATION REFERENCE:
  📖 See docs/SERVER_RUNTIME_RPC.md#32-common-compilation-errors--resolutions
  💡 Run "sitemills-cli help typescript" for CLI reference.
```

---

## Complete Command Reference

```bash
sitemills-cli <command> [options]
```

### Topic & Help Commands

- **help [topic]**: Display general usage or in-depth architecture guides for a specific topic:
  ```bash
  sitemills-cli help               # Print general CLI usage and topic list
  sitemills-cli help contracts     # Specifications for contracts/jobs.json and contracts/db.json
  sitemills-cli help jobs          # Cron jobs schema, trigger rules, and server/jobs.ts binding
  sitemills-cli help db            # Database schemas, declarative indexes, and unique constraints
  sitemills-cli help rpc           # Server runtime, RPC discovery in server/handlers/, auto-stubs
  sitemills-cli help typescript    # Cloud TypeScript compilation constraints and typing rules
  sitemills-cli help data-op       # Data operation payload schemas (query, count, seed, mutation)
  sitemills-cli help run-lua       # Lua runtime sandbox, APIs, globals, and return format
  sitemills-cli help flags         # CLI options, syntax examples, and environment restrictions
  sitemills-cli help errors        # Error diagnostics and troubleshooting reference
  sitemills-cli help games         # Games: starter games on the engine, and art and sound from the asset library
  ```
  *Note:* You can also pass `--help` or `-h` to any command (e.g. `sitemills-cli data-op --help` or `sitemills-cli run-lua --help`).

### Project Lifecycle & Deployment

- **login**: Authenticate with SiteMills via interactive OAuth callback.
  ```bash
  sitemills-cli login
  ```
- **logout**: Clear local authentication tokens.
  ```bash
  sitemills-cli logout
  ```
- **whoami**: Display current authenticated user account and email.
  ```bash
  sitemills-cli whoami
  ```
- **list**: List all projects owned by or shared with your account.
  ```bash
  sitemills-cli list
  ```
- **info**: Fetch comprehensive project information, metadata, deployment environment URLs, and branch preview links with `preview_token` bypass parameters.
  ```bash
  sitemills-cli info <projectId>
  ```
- **import**: Import a local project directory into a new SiteMills project. `<projectName>` names the new project; to rename an existing one, use `set-name`.
  ```bash
  sitemills-cli import <projectName> <inputDir>
  ```
- **seed**: Seed a local folder from a SiteMills direct project template.
  ```bash
  sitemills-cli seed <projectName> [outputDir]
  ```
- **Folder commands** (`check`, `push`, `commit`, `deploy`): `[dir]` defaults to the current folder and must be a folder created by `export` or `import`. You can always pass `<projectId> [dir]` instead.
- **export**: Download an app's code into a folder and link the folder to the app, so `check`, `push`, `commit`, and `deploy` work inside it without IDs.
  ```bash
  sitemills-cli export <projectId> [outputDir]              # Working Draft into ./<projectId> by default
  ```
- **commit** (or **save-snapshot**): Quickly save a code snapshot to the Working Draft without triggering cloud compilation or tests (~100ms). Only files that differ from the Working Draft are uploaded, and remote files missing locally are deleted (pass `--no-prune` to keep them). Automatically saves metadata to `.sitemills/build.json` in the local directory and records the build in `~/.sitemills/builds.json`.
  ```bash
  sitemills-cli commit [dir] [--message <message>] [--no-prune]
  ```
- **check**: Compile your local changes against the Working Draft **without saving or deploying anything**. Runs the same frontend and backend compilation as `push`, but creates no snapshot or version, leaves the Working Draft untouched, and runs no sandbox tests. Exits with code 1 if compilation fails. Use it for a fast edit-compile loop, then `push` once it passes.
  ```bash
  sitemills-cli check [dir] [--no-prune]
  ```
- **push**: Push local updates to the app's Working Draft on SiteMills. Only files that differ from the Working Draft are uploaded (compared by content hash), and remote files missing locally are deleted (pass `--no-prune` to keep them). If nothing changed, push exits without recompiling. Performs pre-flight validation on `contracts/jobs.json`, `contracts/db.json`, TypeScript parameter typing, cloud bundle compilation, and automated tests. Pass `--skip-tests` to bypass testing.
  ```bash
  sitemills-cli push [dir] [--message <message>] [--skip-tests] [--no-prune]
  ```
- **compile**: Recompile the app's Working Draft as it is on SiteMills and inspect diagnostics. Pass `--skip-tests` to bypass testing.
  ```bash
  sitemills-cli compile <projectId> [--skip-tests]
  ```
- **deploy**: Deploy a branch to an environment (`dev`, `staging`, or `prod`).
  ```bash
  sitemills-cli deploy [dir] <dev|staging|prod>
  ```
- **list-branches**: List all development branches for a project, including active deployed environments.
  ```bash
  sitemills-cli list-branches <projectId>
  ```
- **version-history**: View the timeline of the Working Draft's code versions and checkpoints.
  ```bash
  sitemills-cli version-history <projectId> [--limit <limit>]
  ```
- **delete**: Delete a project on SiteMills.
  ```bash
  sitemills-cli delete <projectId>
  ```

### Background Jobs Management

Manage background and scheduled jobs defined in `contracts/jobs.json` and implemented in `server/jobs.ts`:

- **jobs list**: List all background jobs registered in an environment with status, schedules, and last run stats.
  ```bash
  sitemills-cli jobs list <projectId> <environment> [--json]
  ```
- **jobs run**: Manually trigger an on-demand run of a job.
  ```bash
  sitemills-cli jobs run <projectId> <environment> <jobName> [--params '{"dryRun":true}']
  ```
- **jobs runs**: View execution history and logs for a specific job.
  ```bash
  sitemills-cli jobs runs <projectId> <environment> <jobName> [--json]
  ```
- **jobs pause**: Temporarily pause scheduled runs of a job.
  ```bash
  sitemills-cli jobs pause <projectId> <environment> <jobName> [--reason "Maintenance"]
  ```
- **jobs resume**: Resume scheduled execution of a paused job.
  ```bash
  sitemills-cli jobs resume <projectId> <environment> <jobName>
  ```
- **jobs metrics**: Query aggregated job runtime metrics, success rates, and token consumption.
  ```bash
  sitemills-cli jobs metrics <projectId> <environment> [--json]
  ```

### Database & Sandboxed Data Operations

- **seed-db**: Seed database records for a project/branch from a JSON file.
  ```bash
  sitemills-cli seed-db <projectId> <dataFile.json>
  ```
- **data-copy** (or **clone-scope**): Clone all database collections and records from a source environment/scope to a target scope (e.g. from PROD to STAGING).
  ```bash
  sitemills-cli data-copy <projectId> <sourceScope> <targetScope>
  sitemills-cli clone-scope <projectId> <sourceScope> <targetScope>
  ```
- **data-op**: Execute structured database operations (query, count, seed, mutation preview, mutation apply, or inline Lua execution).
  ```bash
  sitemills-cli data-op <projectId> <payloadJsonOrFile> [--env <environment>] [--mock-user <email>]
  ```
  *Inline Example:*
  ```bash
  sitemills-cli data-op my-app '{"operation":"query","collection":"Users","filter":{"role":"admin"},"limit":10}' --env DEV
  ```
- **run-lua**: Execute a sandboxed Lua transformation script against collection documents.
  ```bash
  sitemills-cli run-lua <projectId> <collection> <luaScriptFile> [options]
  ```
  *Example:*
  ```bash
  sitemills-cli run-lua my-app Orders scripts/recalculate_totals.lua --env DEV --filter '{"status":"pending"}' --dry-run
  ```

### Logs, Monitoring & Workflows

- **logs**: Fetch runtime logs with optional branch, environment, and level filtering.
  ```bash
  sitemills-cli logs <projectId> [--env <environment>] [--level <INFO|WARN|ERROR>] [--limit <limit>]
  ```
- **workflows**: List recent AI/agentic workflows run on the project, including prompts, token consumption, and status.
  ```bash
  sitemills-cli workflows <projectId> [--limit <limit>]
  ```
- **credits**: Query remaining credit and token usage balances for a project.
  ```bash
  sitemills-cli credits <projectId>
  ```
- **storage**: Retrieve a detailed storage breakdown (database, media uploads, branches, versions).
  ```bash
  sitemills-cli storage <projectId>
  ```
- **billing-history**: View transaction and order history.
  ```bash
  sitemills-cli billing-history [projectId] [--limit <limit>]
  ```

### Collaboration, Media & Settings

- **members**: List project team members, roles, and pending invitation status.
  ```bash
  sitemills-cli members <projectId>
  ```
- **invite**: Invite a collaborator with OWNER, DEVELOPER, or READER privileges.
  ```bash
  sitemills-cli invite <projectId> <email> <role>
  ```
- **remove-member**: Remove a team member or revoke an invitation.
  ```bash
  sitemills-cli remove-member <projectId> <emailOrId>
  ```
- **list-tasks**: List all planning and execution tasks on the project task board.
  ```bash
  sitemills-cli list-tasks <projectId>
  ```
- **add-task**: Add a task to the project task board.
  ```bash
  sitemills-cli add-task <projectId> <title> [description] [--priority <N>] [--assignee <email>]
  ```
- **update-task**: Update task details, assignee, priority, or status.
  ```bash
  sitemills-cli update-task <projectId> <taskId> [--title <title>] [--description <desc>] [--priority <N>] [--assignee <email>] [--status <status>]
  ```
- **env-list**: List all resolved environment variables for a project environment.
  ```bash
  sitemills-cli env-list <projectId> <environment>
  ```
- **env-set**: Create or update an environment variable or secret in the project Keystore (including Bring-Your-Own-Key credentials for `ctx.plaid` and `ctx.dwolla`).
  ```bash
  sitemills-cli env-set <projectId> <environment> <name> <value> [--description <desc>]
  # Examples (Plaid & Dwolla BYOK):
  sitemills-cli env-set <projectId> DEV PLAID_CLIENT_ID "your_plaid_client_id" --description "Plaid Client ID"
  sitemills-cli env-set <projectId> DEV PLAID_SECRET "your_plaid_sandbox_secret" --description "Plaid Sandbox Secret"
  sitemills-cli env-set <projectId> DEV DWOLLA_KEY "your_dwolla_app_key" --description "Dwolla App Key"
  sitemills-cli env-set <projectId> DEV DWOLLA_SECRET "your_dwolla_sandbox_secret" --description "Dwolla Sandbox Secret"
  ```
- **env-delete**: Remove an environment variable.
  ```bash
  sitemills-cli env-delete <projectId> <environment> <name>
  ```
- **set-visibility**: Change project visibility to PRIVATE, UNLISTED, or PUBLIC, with optional SEO indexing enablement.
  ```bash
  sitemills-cli set-visibility <projectId> <visibility> [--indexable | --no-indexable]
  ```
- **set-name**: Rename a project (its display name, 3 to 50 letters, numbers, spaces, hyphens or underscores). The project ID, site address, deployments and media links stay the same. Needs the owner or developer role.
  ```bash
  sitemills-cli set-name <projectId> <name> [--json]
  ```
- **address**: Show a project's site address and the Settings link where the project owner can change it. The CLI can't change a site address.
  ```bash
  sitemills-cli address <projectId>
  ```
- **set-description**: Update the public display description of the project.
  ```bash
  sitemills-cli set-description <projectId> <description>
  ```
- **set-tags**: Set or clear discovery tags for the project.
  ```bash
  sitemills-cli set-tags <projectId> <tag1,tag2,...> [--clear]
  ```
- **upload-media**: Upload a local media asset to SiteMills storage.
  ```bash
  sitemills-cli upload-media <projectId> <filePath> [--type <uploadType>]
  ```
- **set-branding**: Configure project branding assets (banner, gallery, video) using media IDs.
  ```bash
  sitemills-cli set-branding <projectId> --banner <bannerMediaId> [--gallery <mediaId1,mediaId2>] [--video <showcaseVideoMediaId>]
  ```

### Games

3D multiplayer games on the SiteMills game engine: Roblox's classes and services in TypeScript. The platform supplies the engine; a starter game gives you a whole working game to make into yours. See the [Games Guide](docs/GAMES_GUIDE.md).

- **game templates**: List the starter games (baseplate, obby, shooter, racing, rts, world).
  ```bash
  sitemills-cli game templates [--json]
  ```
- **game create**: Create a new app from a starter game, in a folder linked to it. The folder gets the game's files, the engine and its reference, `server/framework/ENGINE.md`. Each starter game's files are also readable in [docs/games/templates](docs/games/templates).
  ```bash
  sitemills-cli game create "<name>" [folder] --template <id>
  sitemills-cli game create "Kart Party" --template racing
  ```

### Game Assets

Over 80,000 CC0 game art and sound assets for SiteMills projects — sprites, tiles, spritesheets, PBR materials, 3D models, sound effects and fonts — plus on-demand custom PBR material and 3D model generation. Library files load on SiteMills sites only (a project's address, its previews and its custom domains). See the [Games Guide](docs/GAMES_GUIDE.md).

- **game-assets kits**: List the hand-picked kits, one per genre.
  ```bash
  sitemills-cli game-assets kits [--json]
  ```
- **game-assets kit**: Show a kit's assets with their URLs, animation clips, grips and sockets, or write them into a project as `GAME_ASSETS`.
  ```bash
  sitemills-cli game-assets kit <id> [--write <file>] [--overwrite] [--json]
  sitemills-cli game-assets kit 3d-shooter --write src/game/assets.ts
  ```
- **game-assets search**: Search the whole library, best match first.
  ```bash
  sitemills-cli game-assets search <words> [--kind <kind>] [--style <style>] [--category <cat>] [--pack <pack>] [--sheet <file>] [--limit <n>] [--json]
  sitemills-cli game-assets search robot --kind MODEL
  ```
- **game-assets similar**: Find visually matching assets from a search result's asset ID.
  ```bash
  sitemills-cli game-assets similar <assetId> [--kind <kind>] [--style <style>] [--sheet <file>] [--limit <n>] [--json]
  ```
- **game-assets sheet**: Save a numbered JPEG contact sheet for 1 to 24 asset IDs.
  ```bash
  sitemills-cli game-assets sheet <id1> <id2> --out sheet.jpg [--overwrite] [--json]
  ```
- **game-assets generate-material**: Generate a seamless PBR texture set (color, normal, ORM, roughness, metalness) and save it to your project (Owner or Developer role required; defaults to the linked `.sitemills/project.json` when `--project` is omitted).
  ```bash
  sitemills-cli game-assets generate-material <prompt> [--project <projectId>] [--name <slug>] [--style <style>] [--resolution <512|1024>] [--roughness <0..1>] [--metalness <0..1>] [--normal-strength <0.5..6>] [--no-seamless] [--json]
  sitemills-cli game-assets generate-material "weathered mossy cobblestone" --project my-game --style realistic
  ```
- **game-assets generate-model**: Generate a custom 3D GLB model from text or `--reference-image` and save it to your project. Add `--rig` to auto-rig a standing humanoid character with `Idle`/`Walk`/`Run` clips (takes 2–4 minutes).
  ```bash
  sitemills-cli game-assets generate-model [prompt] [--project <projectId>] [--reference-image <key>] [--name <slug>] [--style <style>] [--quality <standard|high>] [--height <m>] [--max-triangles <n>] [--rig] [--json]
  sitemills-cli game-assets generate-model "low-poly medieval knight" --project my-game --style low-poly --rig
  ```
- **game-assets blender-model**: Run a sandboxed headless Blender Python script (`bpy`, `bmesh`, `mathutils`, plus helpers `load_glb`, `get_bounds`, `snap_to`, `span_between`, `make_material`, `assign_material`, `recolor`, `merge_materials`, `kitbash_attach`, `bake_action`, `bake_wave_chain`, `audit_scene`, `scene_stats`) to remix or kitbash up to 4 CC0 library or project `.glb` inputs, model parametric 3D props/vehicles/tracks, or bake skeletal animation clips into a grounded, meshopt-compressed `.glb` (free of build credits except optional `--auto-orient` alignment; SHA-256 cached per project).
  ```bash
  sitemills-cli game-assets blender-model <script.py> [--project <projectId>] [--input alias=urlOrPath]... [--name <slug>] [--height <m>] [--max-triangles <n>] [--auto-orient] [--no-animations] [--json]
  sitemills-cli game-assets blender-model remix_car.py --project my-game --input car=https://game-assets.sitemills.com/library/kenney/car-kit/.../race.glb --name crimson-kart --height 1.3 --auto-orient
  ```

### Stripe Payments & In-Person POS Terminal

- **payments-status**: Fetch Stripe Connect payouts and configuration status.
  ```bash
  sitemills-cli payments-status <projectId> <siteEnvironment>
  ```
- **setup-payments**: Interactively guide Stripe Connect payouts onboarding for an environment/scope.
  ```bash
  sitemills-cli setup-payments <projectId> <siteEnvironment> [--owner-name <ownerName>] [--country <country>]
  ```
- **terminal-readers**: List registered physical Stripe Terminal smart readers (WisePOS E, S700, T600) for a project.
  ```bash
  sitemills-cli terminal-readers <projectId> <siteEnvironment> [--location <locationId>]
  ```
- **register-terminal-reader**: Register and configure a physical smart card reader using the 3-word pairing code displayed on the terminal screen.
  ```bash
  sitemills-cli register-terminal-reader <projectId> <siteEnvironment> <registrationCode> [label] [--location <locationId>]
  ```

### Security, Domains & Updates

- **encryption**: Manage project data encryption at rest (status check, secure key generation, configuring key, enabling encryption).
  ```bash
  sitemills-cli encryption <projectId> [status | generate-key | set-key <key> | enable]
  ```
- **domain**: List custom domains and DNS status.
  ```bash
  sitemills-cli domain <projectId>
  ```
- **domain-add**: Attach a custom domain to a project.
  ```bash
  sitemills-cli domain-add <projectId> <domain>
  ```
- **domain-verify**: Trigger DNS verification and SSL certificate issuance.
  ```bash
  sitemills-cli domain-verify <projectId>
  ```
- **version**: Print the current CLI version and check for newer releases.
  ```bash
  sitemills-cli version
  ```
- **update**: Check for updates and force an in-place upgrade of the standalone binary.
  ```bash
  sitemills-cli update [--force]
  ```

---

## Automatic Updates

How the CLI stays current depends on how you installed it:

| Installed with | How it updates |
|---|---|
| Install script or manual download | Updates itself automatically before running a command |
| Homebrew | Tells you when a new version is out; run `brew upgrade sitemills-cli` |
| Scoop | Tells you when a new version is out; run `scoop update sitemills-cli` |
| npm | Tells you when a new version is out; run `npm install -g sitemills-cli@latest` |

`sitemills-cli version` shows your version, how it was installed, and whether an update is available. `sitemills-cli update` upgrades a self-updating install immediately.

- **Non-blocking & fast:** checks use a 2.5-second timeout. If you're offline or GitHub is unreachable, the command runs normally.
- **Cached:** checks run at most once an hour.
- **Opt out:** pass `--no-update` or set `SITEMILLS_NO_UPDATE=1`. Checks are also skipped when the `CI` environment variable is set.

---

## Options & Flags Reference

- `--message <msg>`: Commit message for push (default: `CLI push update`).
- `--skip-tests`: Bypass automated test suite execution during push and compilation.
- `--params <json>`: JSON payload parameters for on-demand job execution (`jobs run`).
- `--reason <reason>`: Reason message when pausing a background job (`jobs pause`).
- `--env <environment>`: Target environment name (`DEV`, `STAGING`, or `PROD`).
- `--filter <filter>`: JSON query filter for `run-lua` (e.g. `'{"status":"pending"}'`).
- `--dry-run`: Execute Lua script as a dry run simulation without applying database writes.
- `--limit <limit>`: Max documents matched for `run-lua` (1 - 200, default: 200).
- `--max-write-ops <N>`: Max database write operations permitted for `run-lua` (integer 1 - 200, default: 200).
- `--mock-user <email>`: Simulate/impersonate a user for permission testing. **Allowed only in DEV/STAGING; strictly rejected in PROD for security.**
- `--type <type>`: Media upload type for `upload-media` (`APP_MEDIA`, `AGENT_ATTACHMENT`, `CODEBASE_FILE`, `USER_CONTENT`).
- `--owner-name <name>`: Owner's name to register during Stripe Connect onboarding.
- `--country <country>`: Business country code to register during Stripe Connect onboarding (default: `US`).
- `--description <desc>`: Brief description metadata for environment variables.
- `--banner <id>`: Media ID of the project banner image.
- `--gallery <ids>`: Comma-separated media IDs to add to the project gallery.
- `--video <id>`: Media ID of the project showcase video.
- `--indexable`: Enable search engine indexing for the project visibility settings.
- `--no-indexable`: Disable search engine indexing for the project visibility settings.
- `--no-update`: Disable automatic update checks for this command invocation.
- `--force`: Force check and apply updates, ignoring local cache TTL.
- `--kind <kind>`: Asset kind for `game-assets search` (`IMAGE`, `SPRITESHEET`, `MODEL`, `SOUND`, `FONT`, `ENVIRONMENT`).
- `--pack <pack>`: Only assets from this pack, for `game-assets search` (a result's `pack`).
- `--project <id>`: Target project ID or site address (defaults to linked `.sitemills/project.json` for `game-assets generate-material` / `generate-model` / `blender-model`).
- `--style <style>`: Art style for `game-assets search` or generation (`realistic`, `stylized`, `low-poly`, `voxel`, `pixel`, `flat`, `toon`, `hand-drawn`, `sketch`).
- `--resolution <px>`: Texture size for `game-assets generate-material` (`512` or `1024`, default `1024`).
- `--roughness <0..1>`: Base PBR roughness for `game-assets generate-material`.
- `--metalness <0..1>`: Base PBR metalness for `game-assets generate-material`.
- `--normal-strength <0.5..6>`: Normal map bump strength for `game-assets generate-material` (default `2.5`).
- `--no-seamless`: Disable toroidal seamless edge blending on `game-assets generate-material`.
- `--reference-image <key>`: Existing project media image path for image-to-3D on `game-assets generate-model`.
- `--quality <tier>`: Model detail tier for `game-assets generate-model` (`standard` or `high`).
- `--height <metres>`: Target standing height in metres (`0.1` to `25.0` for `generate-model`; `0.05` to `100.0` for `blender-model`).
- `--max-triangles <n>`: Maximum triangle count for `game-assets search`, `generate-model` (`1000` to `50000`), or `blender-model` (`100` to `100000`).
- `--rig`: Auto-rig a standing humanoid character with `Idle`/`Walk`/`Run` clips on `game-assets generate-model` (takes 2–4 minutes).
- `--input <alias=urlOrPath>`: Stage a CC0 library `.glb` URL or project `/assets/....glb` path for `load_glb(alias)` in `game-assets blender-model` (repeatable, up to 4).
- `--auto-orient`: Auto-rotate a non-rigged directional model so its front faces `-Z` on `game-assets blender-model`.
- `--no-animations`: Skip exporting Blender actions / NLA clips into the `.glb` on `game-assets blender-model`.
- `--write <file>`: Write a kit's assets to this file as `GAME_ASSETS` (`game-assets kit`).
- `--overwrite`: Let `--write` replace an existing file.
- `--template <id>`: The starter game for `game create` (list them with `game templates`).

### RTS game starter

Create an editable strategy game using the platform's reusable RTS engine:

```sh
sitemills-cli game templates --engine rts-engine
sitemills-cli game create "My RTS" ./my-rts --engine rts-engine --template rts-sandbox
cd my-rts
sitemills-cli check
sitemills-cli push
sitemills-cli deploy dev
```

The starter has two 1,000-unit armies, multiplayer rooms and a local terrain editor. For local inspection before import, `game init rts-sandbox ./my-rts --engine rts-engine` writes only to a new or empty folder; import and deployment are separate steps. Edit game rules in `server/game` and UI/models in `src`. The framework folders are read-only platform code, pinned by `sitemills.json`. These commands use sitemills.com once the engine is released there. Use `--engine gameengine` for the instance/physics engine's templates.
