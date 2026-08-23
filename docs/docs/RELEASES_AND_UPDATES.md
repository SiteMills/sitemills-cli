# SiteMills CLI: Release Management & Auto-Update Guide

This document describes how the SiteMills CLI binary auto-update system functions and provides the step-by-step release process for publishing new CLI versions to clients.

---

## 1. Overview & Architecture

SiteMills CLI binaries (compiled via `pkg` for Linux, macOS, and Windows) feature a built-in, zero-dependency self-updater.

```
+-------------------------------------------------------------------------+
|                        User runs sitemills-cli                          |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                       Pre-Execution Updater Hook                        |
|                                                                         |
|  1. Verify process.pkg (skip if running in dev/source mode)            |
|  2. Check opt-out flags (--no-update or SITEMILLS_NO_UPDATE=1)          |
|  3. Check local cache (~/.sitemills/update-cache.json, TTL: 1 hr)       |
|  4. Query remote manifest (https://raw.githubusercontent.com/...)       |
+-------------------------------------------------------------------------+
                                     |
                         Newer version available?
                                    / \
                              Yes  /   \  No / Timeout (2.5s)
                                  /     \
                                 v       v
+------------------------------------+  +--------------------------------+
|          Apply Hot-Swap            |  |      Proceed Normally          |
|                                    |  |                                |
| 1. Download platform binary (.tmp) |  | Execute the requested command  |
| 2. chmod 0755                      |  | without interruption           |
| 3. In-place atomic swap            |  +--------------------------------+
| 4. Respawn new binary with args    |
| 5. Exit parent process             |
+------------------------------------+
```

### Key Technical Details

* **Zero Dependencies**: Uses only Node.js standard libraries (`https`, `http`, `fs`, `path`, `os`, `child_process`). Clients do **not** need `git`, `npm`, or any external package managers.
* **Fast Non-Blocking Timeout**: Network version checks timeout after **2.5 seconds**. If a client is offline or behind a restrictive firewall, the CLI warns (in debug mode) and executes the requested command immediately.
* **Cache Interval**: Remote checks are throttled to once per hour via `~/.sitemills/update-cache.json` to eliminate network latency on rapid successive commands.
* **Platform Inode Swap**:
  * **Linux / macOS**: Performs atomic rename over the active executable path (`process.execPath`).
  * **Windows**: Handles the Windows active process file lock by renaming the current `.exe` to `.old` before placing the updated binary.

---

## 2. Release Workflow (Step-by-Step for Engineers)

Follow these steps whenever you are ready to publish a new CLI release:

### Step 1: Bump Version
In `samirpatelgx/sitemills-cli-internal`:
Update `"version"` in [`package.json`](file:///home/apstonybrook/codebase/samirpatelgx/sitemills-cli-internal/package.json):

```json
{
  "name": "sitemills-cli",
  "version": "1.0.1",
  ...
}
```

Update `CLI_VERSION` in [`bin/updater.js`](file:///home/apstonybrook/codebase/samirpatelgx/sitemills-cli-internal/bin/updater.js) if necessary to match.

### Step 2: Run Tests
Run the automated test suite to ensure all semver and platform logic pass:

```bash
npm test
```

### Step 3: Build & Obfuscate Binaries
Compile the obfuscated standalone binaries for Linux, macOS, and Windows:

```bash
npm run build
```

This generates:
* `dist/sitemills.js` (Obfuscated CLI entry point)
* `dist/updater.js` (Obfuscated updater module)
* `dist/binaries/sitemills-linux` (Linux x64 binary)
* `dist/binaries/sitemills-macos` (macOS x64 binary)
* `dist/binaries/sitemills-win.exe` (Windows x64 executable)

### Step 4: Sync to Public Repository
Copy the compiled binaries, obfuscated scripts, and documentation to `sitemills-cli`:

```bash
cp -r dist/ ../sitemills-cli/
cp README.md ../sitemills-cli/README.md
cp package.json ../sitemills-cli/package.json
cp -r bin/ ../sitemills-cli/
```

### Step 5: Commit & Release

1. **Commit internal repo**:
   ```bash
   cd ~/codebase/samirpatelgx/sitemills-cli-internal
   git add -A
   git commit -m "Release v1.0.1"
   git push origin main
   ```

2. **Commit public repo & tag release**:
   ```bash
   cd ~/codebase/sitemills-cli
   git add -A
   git commit -m "Release v1.0.1"
   git tag v1.0.1
   git push origin main --tags
   ```

Once pushed, all client binaries in the wild will detect the new version on their next command run and auto-upgrade automatically.

---

## 3. Client Commands & Controls

### Checking Version
```bash
sitemills-cli version
```
Output:
```
sitemills-cli v1.0.1 (linux-x64, binary)
```

### Forcing Immediate Update
Users can bypass the 1-hour cache and force an immediate check:
```bash
sitemills-cli update --force
```

### Disabling Auto-Updates
For CI/CD pipelines, container builds, or air-gapped environments:

* Via command-line flag:
  ```bash
  sitemills-cli list --no-update
  ```
* Via environment variable:
  ```bash
  export SITEMILLS_NO_UPDATE=1
  # or
  export CI=true
  ```

---

## 4. Troubleshooting & Edge Cases

| Issue | Cause | Resolution |
| :--- | :--- | :--- |
| **`EACCES: permission denied`** | Binary was placed in a root-owned path like `/usr/local/bin` without write permissions. | Run `sudo sitemills-cli update` or install in user directory (e.g. `~/.local/bin` or `~/.sitemills/bin`). |
| **Slow or No Internet** | Client is offline or GitHub CDN is slow. | Timeout fires in 2.5s and continues running the local command without failing. |
| **Windows Locked Files** | Windows blocks direct overwrites of running `.exe` files. | Updater automatically renames the active `.exe` to `.old` before swapping in the new binary. |
| **Cache Reset** | Need to reset update check timestamp. | Delete `~/.sitemills/update-cache.json` or pass `--force`. |
| **Debug Logging** | Want to see detailed network/updater logs. | Run with `DEBUG=1 sitemills-cli <command>`. |
