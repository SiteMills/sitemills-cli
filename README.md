# SiteMills CLI

SiteMills CLI Tool for project code management, continuous integration, database seeding, background jobs, sandboxed data operations, and deployment on the SiteMills platform.

## Installation

### Standalone Pre-Compiled Binaries (Recommended)

Download the standalone binary for your operating system from [SiteMills CLI Releases](https://github.com/SiteMills/sitemills-cli/releases):

- **Linux (x64)**: `sitemills-linux`
- **macOS (x64 / Apple Silicon via Rosetta)**: `sitemills-macos`
- **Windows (x64)**: `sitemills-win.exe`

#### Quick Install (Linux / macOS):

```bash
curl -fsSL https://github.com/SiteMills/sitemills-cli/releases/latest/download/sitemills-linux -o /usr/local/bin/sitemills-cli
chmod +x /usr/local/bin/sitemills-cli
```

### From Source

Clone the repository and link globally via npm:

```bash
git clone https://github.com/SiteMills/sitemills-cli.git
cd sitemills-cli
npm link
```

This registers the `sitemills-cli` command globally on your system.

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

---

## Quickstart: Creating & Deploying a Project

### 1. Import a Local Directory to a New SiteMills Project
```bash
sitemills-cli import <projectName> <inputDir>
```
*Example:*
```bash
sitemills-cli import GradePrep scratch/grade1-superstars
```
*Output:*
```text
SUCCESS: Project imported successfully!
  Project ID: gradeprep
  Branch ID:  e4d7df82-24b2-4e3b-97ce-5aa4ba5a79ec
```

### 2. View Branches & Status
```bash
sitemills-cli list-branches <projectId>
```

### 3. Compile Project Code
```bash
sitemills-cli compile <projectId> --branch <branchId>
```
*Compiles frontend JSX/TSX components (esbuild + Tailwind CSS) and backend TypeScript handlers into the SiteMills V8 isolate runtime.*

### 4. Deploy Branch to an Environment
```bash
sitemills-cli deploy <projectId> <branchId> <DEV|STAGING|PROD>
```
*Example:*
```bash
sitemills-cli deploy gradeprep e4d7df82-24b2-4e3b-97ce-5aa4ba5a79ec DEV
```

---

## Project URLs & Deployment Hostnames

SiteMills clearly distinguishes between the **Platform Management Dashboard** and the **Live Deployed Client Applications**:

| Purpose | URL / Hostname Pattern | Example |
|---|---|---|
| **Production Live Application (`PROD`)** | `https://<projectId>.sitemills.com` | `https://gradeprep.sitemills.com` |
| **Staging Live Application (`STAGING`)** | `https://<projectId>-staging.sitemills.com` | `https://gradeprep-staging.sitemills.com` |
| **Development Live Application (`DEV`)** | `https://<projectId>-dev.dev.sitemills.com` | `https://gradeprep-dev.dev.sitemills.com` |
| **Branch Preview URL** | `https://<projectId>--<branchId>.sitemills.com/?preview_token=...` | `https://gradeprep--e4d7df82-24b2-4e3b-97ce-5aa4ba5a79ec.sitemills.com` |
| **Platform Project Console / IDE** | `https://sitemills.com/project/<projectId>` | `https://sitemills.com/project/gradeprep` |
| **Project Planning Board** | `https://sitemills.com/project/<projectId>/planning` | `https://sitemills.com/project/gradeprep/planning` |
| **Project Settings / Variables** | `https://sitemills.com/project/<projectId>/settings` | `https://sitemills.com/project/gradeprep/settings` |

> [!WARNING]
> **Important URL Distinction:**
> - **Live Deployed Websites**: Web applications deployed to SiteMills are hosted on subdomains: `https://<projectId>.sitemills.com` for Production, `https://<projectId>-staging.sitemills.com` for Staging, and `https://<projectId>-dev.dev.sitemills.com` for Dev.
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
   - Production URLs (`https://<projectId>.sitemills.com`) are always public and do not require authentication or preview tokens.

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
- **import**: Import a local project directory into a new SiteMills project.
  ```bash
  sitemills-cli import <projectName> <inputDir>
  ```
- **seed**: Seed a local folder from a SiteMills direct project template.
  ```bash
  sitemills-cli seed <projectName> [outputDir]
  ```
- **export**: Export project code from a branch to a local directory.
  ```bash
  sitemills-cli export <projectId> [branchId] <outputDir>
  ```
- **push**: Push local updates to a specific branch on SiteMills. Performs pre-flight validation on `contracts/jobs.json`, `contracts/db.json`, and TypeScript parameter typing.
  ```bash
  sitemills-cli push <projectId> <branchId> <inputDir> [--message <message>]
  ```
- **compile**: Trigger manual project code compilation for a branch and inspect diagnostics.
  ```bash
  sitemills-cli compile <projectId> [--branch <branchId>]
  ```
- **deploy**: Deploy a branch to an environment (`DEV`, `STAGING`, or `PROD`).
  ```bash
  sitemills-cli deploy <projectId> <branchId> <environment>
  ```
- **list-branches**: List all development branches for a project, including active deployed environments.
  ```bash
  sitemills-cli list-branches <projectId>
  ```
- **version-history**: View the timeline of code versions and checkpoints for a specific branch.
  ```bash
  sitemills-cli version-history <projectId> [branchId] [--limit <limit>]
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
  sitemills-cli seed-db <projectId> <branchId> <dataFile.json>
  ```
- **data-copy** (or **clone-scope**): Clone all database collections and records from a source environment/scope to a target scope (e.g. from PROD to STAGING).
  ```bash
  sitemills-cli data-copy <projectId> <sourceScope> <targetScope>
  sitemills-cli clone-scope <projectId> <sourceScope> <targetScope>
  ```
- **data-op**: Execute structured database operations (query, count, seed, mutation preview, mutation apply, or inline Lua execution).
  ```bash
  sitemills-cli data-op <projectId> <payloadJsonOrFile> [--branch <branchId>] [--env <environment>] [--mock-user <email>]
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
  sitemills-cli logs <projectId> [--branch <branchId>] [--env <environment>] [--level <INFO|WARN|ERROR>] [--limit <limit>]
  ```
- **workflows**: List recent AI/agentic workflows run on the project, including prompts, token consumption, and status.
  ```bash
  sitemills-cli workflows <projectId> [--branch <branchId>] [--limit <limit>]
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
- **env-set**: Create or update an environment variable or secret.
  ```bash
  sitemills-cli env-set <projectId> <environment> <name> <value> [--description <desc>]
  ```
- **env-delete**: Remove an environment variable.
  ```bash
  sitemills-cli env-delete <projectId> <environment> <name>
  ```
- **set-visibility**: Change project visibility to PRIVATE, UNLISTED, or PUBLIC, with optional SEO indexing enablement.
  ```bash
  sitemills-cli set-visibility <projectId> <visibility> [--indexable | --no-indexable]
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

The compiled standalone binary automatically checks for newer releases before command execution, downloads updates from the official release repository, and seamlessly replaces the binary in-place.

- **Non-Blocking & Fast**: Update checks use a lightweight 2.5-second timeout. If offline or if GitHub is unreachable, the CLI continues executing normally without interruption.
- **Cache Interval**: Automatic checks are cached for 1 hour to prevent network overhead on rapid successive executions.
- **Opt-Out**: Pass `--no-update` or set the `SITEMILLS_NO_UPDATE=1` environment variable to disable automatic update checks in CI/CD or air-gapped environments.

---

## Options & Flags Reference

- `--message <msg>`: Commit message for push (default: `CLI push update`).
- `--params <json>`: JSON payload parameters for on-demand job execution (`jobs run`).
- `--reason <reason>`: Reason message when pausing a background job (`jobs pause`).
- `--branch <branch>`: Target branch ID or branch data scope.
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
