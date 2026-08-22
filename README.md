# SiteMills CLI

SiteMills CLI Tool for project code management, continuous integration, database seeding, and deployment on the SiteMills platform.

> [!IMPORTANT]
> **Repository Sync & Release Workflow:**
> This is the internal private source code repository (`sitemills-cli-internal`). The public repository (`sitemills-cli`) contains only the compiled/obfuscated binaries and documentation.
> To prevent code and documentation divergence, you must sync changes to the public repository whenever this repo is updated:
> 
> 1. Commit and push your code updates in this internal repository.
> 2. Compile the obfuscated binaries:
>    ```bash
>    npm install && npm run build
>    ```
> 3. Copy the updated `README.md` and the new binaries from `dist/binaries/` to the public `sitemills-cli` repository.
> 4. Commit and push the updates in the public repository to release them to users.

## Installation

### From Source

Clone the repository and link globally:

```bash
git clone https://github.com/samirpatelgx/sitemills-cli-internal.git sitemills-cli
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
     ```
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
```
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

## Complete Command Reference

```bash
sitemills-cli <command> [options]
```

### Available Commands

- **login**: Authenticate with SiteMills via interactive OAuth callback.
  ```bash
  sitemills-cli login
  ```
- **list**: List all projects owned by or shared with your account.
  ```bash
  sitemills-cli list
  ```
- **import**: Import a local project directory into a new SiteMills project.
  ```bash
  sitemills-cli import <projectName> <inputDir>
  ```
- **seed**: Seed a local folder from a SiteMills direct project template.
  ```bash
  sitemills-cli seed <projectName> [outputDir]
  ```
- **seed-db**: Seed database records for a project/branch from a JSON file.
  ```bash
  sitemills-cli seed-db <projectId> <branchId> <dataFile.json>
  ```
- **data-copy** (or **clone-scope**): Clone all database collections and records from a source environment/scope to a target scope (e.g. from PROD to STAGING).
  ```bash
  sitemills-cli data-copy <projectId> <sourceScope> <targetScope>
  sitemills-cli clone-scope <projectId> <sourceScope> <targetScope>
  ```
- **export**: Export project code from a branch to a local directory.
  ```bash
  sitemills-cli export <projectId> [branchId] <outputDir>
  ```
- **push**: Push local updates/commits to a specific branch on SiteMills.
  ```bash
  sitemills-cli push <projectId> <branchId> <inputDir> [--message <message>]
  ```
- **compile**: Trigger manual project code compilation for a branch and inspect results.
  ```bash
  sitemills-cli compile <projectId> [--branch <branchId>]
  ```
- **deploy**: Deploy a branch to an environment (DEV, STAGING, or PROD).
  ```bash
  sitemills-cli deploy <projectId> <branchId> <environment>
  ```
- **list-branches**: List all development branches for a project, including their kind (e.g. WORKING or CHECKPOINT), active deployed environments, and version references.
  ```bash
  sitemills-cli list-branches <projectId>
  ```
- **version-history**: View the timeline of code versions and checkpoints for a specific branch.
  ```bash
  sitemills-cli version-history <projectId> [branchId] [--limit <limit>]
  ```
- **logs**: Fetch and view project execution and runtime logs, with optional branch, environment, and level filtering.
  ```bash
  sitemills-cli logs <projectId> [--branch <branchId>] [--env <environment>] [--level <level>] [--limit <limit>]
  ```
- **workflows**: List recent AI/agentic workflows run on the project, including their status, prompt, and execution token costs.
  ```bash
  sitemills-cli workflows <projectId> [--branch <branchId>] [--limit <limit>]
  ```
- **credits**: Query and check remaining credit and token usage balances for a project.
  ```bash
  sitemills-cli credits <projectId>
  ```
- **storage**: Retrieve a detailed storage usage breakdown (database, media uploads, branches, versions).
  ```bash
  sitemills-cli storage <projectId>
  ```
- **billing-history**: View transaction and order history for your account or project.
  ```bash
  sitemills-cli billing-history [projectId] [--limit <limit>]
  ```
- **set-visibility**: Change project visibility to PRIVATE, UNLISTED, or PUBLIC, with optional SEO indexing enablement.
  ```bash
  sitemills-cli set-visibility <projectId> <visibility> [--indexable | --no-indexable]
  ```
- **set-description**: Update the public display description of the project.
  ```bash
  sitemills-cli set-description <projectId> <description>
  ```
- **upload-media**: Upload a local media file to SiteMills storage.
  ```bash
  sitemills-cli upload-media <projectId> <filePath> [--type <uploadType>]
  ```
- **set-branding**: Configure project branding assets (banner, gallery, video) using media IDs.
  ```bash
  sitemills-cli set-branding <projectId> --banner <bannerMediaId> [--gallery <mediaId1,mediaId2>] [--video <showcaseVideoMediaId>]
  ```
- **data-op**: Execute a structured data operation payload.
  ```bash
  sitemills-cli data-op <projectId> <payloadJsonOrFile> [--branch <branchId>] [--env <environment>] [--mock-user <email>]
  ```
- **run-lua**: Execute a Lua script against a collection.
  ```bash
  sitemills-cli run-lua <projectId> <collection> <luaScriptFile> [--branch <branchId>] [--env <environment>] [--filter <jsonFilter>] [--dry-run] [--mock-user <email>]
  ```
- **members**: List project team members, roles, and pending invitation status.
  ```bash
  sitemills-cli members <projectId>
  ```
- **invite**: Invite a new collaborator to the project with OWNER, DEVELOPER, or READER privileges.
  ```bash
  sitemills-cli invite <projectId> <email> <role>
  ```
- **remove-member**: Remove a team member or revoke a pending invitation by ID or email.
  ```bash
  sitemills-cli remove-member <projectId> <emailOrId>
  ```
- **list-tasks**: List all planning and execution tasks on the project task board.
  ```bash
  sitemills-cli list-tasks <projectId>
  ```
- **add-task**: Add a new task to the project's task board.
  ```bash
  sitemills-cli add-task <projectId> <title> [description] [--priority <N>] [--assignee <email>]
  ```
- **update-task**: Update an existing task's title, description, priority, assignee, or status.
  ```bash
  sitemills-cli update-task <projectId> <taskId> [--title <title>] [--description <desc>] [--priority <N>] [--assignee <email>] [--status <status>]
  ```
- **env-list**: List all resolved environment variables for a project environment.
  ```bash
  sitemills-cli env-list <projectId> <environment>
  ```
- **env-set**: Create or update an environment variable/secret.
  ```bash
  sitemills-cli env-set <projectId> <environment> <name> <value> [--description <desc>]
  ```
- **env-delete**: Remove an environment variable/secret from a project environment.
  ```bash
  sitemills-cli env-delete <projectId> <environment> <name>
  ```
- **payments-status**: Fetch Stripe Connect payouts and configuration status.
  ```bash
  sitemills-cli payments-status <projectId> <siteEnvironment>
  ```
- **setup-payments**: Interactively guide Stripe Connect payouts onboarding for an environment/scope.
  ```bash
  sitemills-cli setup-payments <projectId> <siteEnvironment> [--owner-name <ownerName>] [--country <country>]
  ```
- **encryption**: Manage project data encryption at rest (status check, secure key generation, configuring key, enabling encryption).
  ```bash
  sitemills-cli encryption <projectId> [status | generate-key | set-key <key> | enable]
  ```
- **delete**: Delete a project on SiteMills.
  ```bash
  sitemills-cli delete <projectId>
  ```

---

## Options

- `--message <msg>`: Commit message for push (default: `CLI push update`)
- `--branch <branch>`: Target branch ID
- `--env <environment>`: Target environment name (`DEV`, `STAGING`, or `PROD`)
- `--filter <filter>`: JSON query filter for `run-lua`
- `--dry-run`: Execute Lua script as a dry run
- `--limit <limit>`: Max documents matched for `run-lua`
- `--max-write-ops <N>`: Max writes allowed for `run-lua`
- `--type <type>`: Media upload type for `upload-media` (`APP_MEDIA`, `AGENT_ATTACHMENT`, `CODEBASE_FILE`, `USER_CONTENT`)
- `--owner-name <name>`: Owner's name to register during Stripe Connect onboarding
- `--country <country>`: Business country code to register during Stripe Connect onboarding (default: `US`)
- `--description <desc>`: Brief description metadata for environment variables
- `--banner <id>`: Media ID of the project banner image
- `--gallery <ids>`: Comma-separated media IDs to add to the project gallery
- `--video <id>`: Media ID of the project showcase video
- `--indexable`: Enable search engine indexing for the project visibility settings
- `--no-indexable`: Disable search engine indexing for the project visibility settings
- `--mock-user <email>`: Impersonate / test as a specific user for data ops in dev environments
