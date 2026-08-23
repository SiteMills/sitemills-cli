# Sitemills Agent Scripting Guide: `execute_script` VM Tool

This guide explains how to use the `execute_script` tool to run JavaScript/TypeScript scripts inside a sandboxed V8 Isolate VM. Use this tool when you need to perform bulk edits, AST-based transformations, loops, or complex conditional tasks that would otherwise require multiple turns.

---

## 1. Context Global Variables

The VM provides a global read-only object called `context` containing metadata about the current execution:
- `context.projectId`: The ID of the active project.
- `context.branchId`: The active branch version.
- `context.threadId`: The agent thread ID.
- `context.userId`: The owner user ID.

---

## 2. In-Memory Filesystem API (`fs`)

The script operates on a virtual in-memory copy of the project files. All file operations are **completely synchronous** and modify the agent's memory map (which will be validated and saved at the end of the turn).

> [!IMPORTANT]
> **Path Resolution Warning**: 
> All paths in the `fs` API are **strictly relative to the project root** (e.g. `src/index.ts`, `server/handlers/getUser.ts`). 
> - `fs.listFiles()` and `fs.grep()` return relative paths from the project root.
> - Do **NOT** prepend a directory path or workspace root prefix twice. When using paths returned by these methods, pass them directly to other `fs` functions without modification.


*   `fs.readFile(path: string): string`
    Reads the contents of a file. Throws an error if the file does not exist.
*   `fs.writeFile(path: string, content: string): void`
    Creates or overwrites a file.
*   `fs.exists(path: string): boolean`
    Checks if a file exists.
*   `fs.listFiles(): string[]`
    Returns a list of all relative file paths in the workspace.
*   `fs.grep(query: string): string[]`
    Performs a fast string search and returns paths of files containing the query.
*   `fs.replaceInFile(path: string, search: string | RegExp, replacement: string): void`
    Synchronously reads a file, replaces occurrences of `search` with `replacement`, and writes the changes.
*   `fs.replaceInFiles(paths: string[], search: string | RegExp, replacement: string): void`
    Loops through `paths` and applies `replaceInFile` to each matching file.
*   `fs.insertAfter(path: string, search: string, codeToInsert: string): void`
    Finds the first occurrence of `search` in a file and inserts `codeToInsert` immediately after it.
*   `fs.insertBefore(path: string, search: string, codeToInsert: string): void`
    Finds the first occurrence of `search` in a file and inserts `codeToInsert` immediately before it.

---

## 3. General Platform Tool Invocation (`sys`)

The script can invoke any other tool in the Sitemills toolbelt asynchronously using `sys.callTool`, or use convenience namespaces. When a tool changes files, changes sync back to the virtual `fs` map.

### Direct Invocation
*   `await sys.callTool(toolName: string, arguments: object): Promise<ToolResult>`
    Calls a Sitemills platform tool and returns a result object: `{ success: boolean, output: string }`.

### Dashboard & Project Convenience SDK

#### 1. Environment Settings (`sys.dashboard.env`)
*   `sys.dashboard.env.list(): Promise<ToolResult>`
    Retrieves the keys and metadata of all environment variables. Secret values are masked.
*   `sys.dashboard.env.getResolved(): Promise<ToolResult>`
    Fetches the actual resolved plaintext values of all variables and secrets.
*   `sys.dashboard.env.set(key: string, value: string): Promise<ToolResult>`
    Creates or updates an environment variable or secret.
*   `sys.dashboard.env.delete(key: string): Promise<ToolResult>`
    Deletes an environment variable or secret.

#### 2. Permissions (`sys.dashboard.permissions`)
*   `sys.dashboard.permissions.listCatalog(): Promise<ToolResult>`
    Retrieves the catalog of user roles and permission grids.
*   `sys.dashboard.permissions.listMembers(): Promise<ToolResult>`
    Retrieves all members currently added to the project.
*   `sys.dashboard.permissions.invite(email: string, role: string): Promise<ToolResult>`
    Invites a user by email to join the project under a role.
*   `sys.dashboard.permissions.updateRole(email: string, role: string): Promise<ToolResult>`
    Changes a member's active role.
*   `sys.dashboard.permissions.removeMember(email: string): Promise<ToolResult>`
    Removes a member from the project.

#### 3. Project Controls (`sys.project`)
*   `sys.project.deploy(): Promise<ToolResult>`
    Compiles, tests, and deploys the active workspace branch to the preview server.
*   `sys.project.getCredits(): Promise<ToolResult>`
    Queries the project owner's active credit balances and usage data.
*   `sys.project.deployAndTest(): Promise<{ build: ToolResult, test?: ToolResult }>`
    Deploys the project, and if successful, automatically executes the unit test suite and returns both results.

#### 4. Backend Invocation (`sys.backend`)
*   `sys.backend.call(route: string, payload?: object, userContext?: object): Promise<any>`
    Invokes the project's backend handler directly. The response is parsed from JSON and returned directly.
    - `route`: The backend handler function name (e.g. `'getCurrentUser'`).
    - `payload`: Optional parameters/payload passed to the handler.
    - `userContext`: Optional mock user context (e.g. `{ id: 'user_123', email: 'test@example.com' }`) to simulate a specific user's requests.

---

## 4. Practical Examples

### Example A: Bulk Replace In Specific Files (Synchronous)
```javascript
// Find all files referencing the legacy database key and update them
const files = fs.grep('legacyDbKey');

for (const path of files) {
  let content = fs.readFile(path);
  content = content.replace(/legacyDbKey/g, 'modernDbClient');
  fs.writeFile(path, content);
  console.log(`Updated legacy key in: ${path}`);
}
```

### Example B: Execute Compile and Run Tests (Asynchronous)
```javascript
// Call the build_and_deploy tool and then run tests
console.log('Starting site compile...');
const buildRes = await sys.callTool('build_and_deploy', {});
console.log('Build Output:', buildRes.output);

if (buildRes.success) {
  console.log('Build succeeded! Running tests...');
  const testRes = await sys.callTool('run_tests', {});
  console.log('Test Output:', testRes.output);
} else {
  console.error('Build failed; skipping tests.');
}
```

### Example C: AST Refactoring with ESLint / Babel / Third-Party Parser
```javascript
// Parse a JSX file using Babel (loaded inside the VM)
const parser = require('@babel/parser');
const generator = require('@babel/generator').default;

const code = fs.readFile('src/components/Button.jsx');
const ast = parser.parse(code, { sourceType: 'module', plugins: ['jsx'] });

// (Perform AST manipulations here...)

const updatedCode = generator(ast).code;
fs.writeFile('src/components/Button.jsx', updatedCode);
console.log('Successfully refactored Button component AST');
```

### Example D: Test Backend Function Directly
```javascript
// Test a backend handler by calling it directly with mock user context
try {
  const result = await sys.backend.call('getCurrentUser', {}, {
    id: 'user_123',
    email: 'test@example.com'
  });
  console.log('Backend invoke result:', result);
} catch (err) {
  console.error('Backend invoke failed:', err.message);
}
```
