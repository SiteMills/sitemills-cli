# Permissions API — Project-Scoped RBAC via permissionservice

The backend runtime exposes `ctx.permissions` for role-based authorization.

Transport path:
- `ctx.permissions.*` in isolate handler
- routed through clientisolates PermissionsIntegration
- forwarded to permissionservice RBAC endpoints (`/api/rbac/projects/{projectId}/...`)

## Enforcement Model

- Platform request handling adds trusted project/user/session context and applies runtime credit/rate gates.
- Handlers should call `ctx.permissions.check(...)` or `ctx.permissions.require(...)` to enforce authorization within their execution.

## Key Rules

- Project scope is derived from runtime context. Do not pass `projectId` in payloads.
- Mutation methods (create/update/delete/bootstrap) require authenticated owner/admin runtime context.
- Actor identity is derived from runtime context (`ctx.user.email` or `ctx.user.id`), not caller payload.
- Resource strings passed to `ctx.permissions.*` are implicitly project-scoped by the platform. Simply pass relative paths (e.g., `leagues:summer-2026`, `leagues:*`, or `*`).
- Action/resource wildcard matching uses `*`.

## Methods

### Read / Evaluate

```typescript
const permissions = await ctx.permissions.listPermissions();
const roles = await ctx.permissions.listRoles();
const assignments = await ctx.permissions.listAssignments({ subjectId: 'user_123' });

const check = await ctx.permissions.check({
    subjectId: 'user_123',
    action: 'read:league',
    resource: 'leagues:summer-2026'
});

// Throws when denied
await ctx.permissions.require({
    subjectId: 'user_123',
    action: 'write:league',
    resource: 'leagues:summer-2026',
    message: 'User cannot edit this league.'
});
```

### Permissions and Roles (mutation)

```typescript
const permission = await ctx.permissions.createPermission({
    name: 'League Manager',
    actionPattern: 'manage:*',
    resourcePattern: 'leagues:*',
    description: 'Manage all leagues in this organization.'
});

const role = await ctx.permissions.createRole({
    name: 'LEAGUE_MANAGER',
    permissionIds: [permission.id],
    description: 'League manager role'
});
```

### Assignments (mutation)

```typescript
// You can use either the role ID (UUID) or the role name (e.g. 'LEAGUE_MANAGER') directly.
const assignment = await ctx.permissions.assignRole({
    subjectId: 'user_123',
    roleId: 'LEAGUE_MANAGER', // resolves to role UUID under the hood
    scopeResource: 'leagues:*'
});

await ctx.permissions.revokeRole(assignment.id);
```

### Starter Roles Bootstrap

```typescript
await ctx.permissions.bootstrapStarterRoles();
```

This explicit bootstrap creates default OWNER / MANAGER / VIEWER starter roles
if they do not already exist.

## Additional Examples

### Endpoint guard pattern with require

```typescript
export async function updateLeagueSettings(ctx, { leagueId, settings }) {
    await ctx.permissions.require({
        subjectId: ctx.user.id,
        action: 'write:league',
        resource: `leagues:${leagueId}`,
        message: 'You do not have permission to edit this league.'
    });

    await ctx.db.collection('leagues').updateOne(
        { id: leagueId },
        { $set: { settings, updatedAt: new Date().toISOString() } },
        { upsert: false }
    );

    return { updated: true, leagueId };
}
```

### Assign role to a specific project resource scope

```typescript
const role = await ctx.permissions.createRole({
    name: 'LEAGUE_SCOREKEEPER',
    permissionIds: ['perm_write_score', 'perm_read_league']
});

await ctx.permissions.assignRole({
    subjectId: 'user_456',
    roleId: role.id,
    scopeResource: 'leagues:summer-2026'
});
```

### Deny telemetry pattern (check + metrics + logs)

```typescript
export async function deleteLeague(ctx, { leagueId }) {
    const resource = `leagues:${leagueId}`;
    const decision = await ctx.permissions.check({
        subjectId: ctx.user.id,
        action: 'delete:league',
        resource
    });

    if (!decision.allowed) {
        await ctx.metrics.track('rbac_denied', {
            action: 'delete:league',
            resource,
            subjectId: ctx.user.id
        });

        ctx.logs.warn('rbac_denied', {
            action: 'delete:league',
            resource,
            subjectId: ctx.user.id
        });

        throw new Error('You do not have permission to delete this league.');
    }

    await ctx.db.collection('leagues').deleteOne({ id: leagueId });
    return { deleted: true, leagueId };
}
```

## Recommended Usage

- Use `ctx.permissions.check` or `ctx.permissions.require` inside backend handlers before protected operations.
- Keep custom app user identifiers in `subjectId` (for example external auth user IDs).
- Keep resource strings relative (for example `articles:article-123`); the platform handles scoping under the hood.
- Keep authorization logic centralized in permissionservice rather than ad-hoc per-handler role checks.
- Use wildcard patterns intentionally (`read:*`, `manage:*`, etc.) and keep resource paths logical and stable.

## Failure Modes

- Missing runtime auth context on mutation methods → error.
- Mutation caller not owner/admin for project → forbidden.
- Resource path invalid for current runtime scope → validation error.
- Unknown role or permission IDs in payloads → not found / conflict errors.
