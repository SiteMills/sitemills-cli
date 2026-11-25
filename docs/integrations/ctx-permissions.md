# Permissions API — Project-Scoped RBAC

The backend runtime exposes `ctx.permissions` for role-based authorization.

Enforcement routing:
- `ctx.permissions.*` in a server handler
- Evaluated against project RBAC permission definitions

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
- Keep authorization logic centralized in platform permissions rather than ad-hoc per-handler role checks.
- Use wildcard patterns intentionally (`read:*`, `manage:*`, etc.) and keep resource paths logical and stable.

## Failure Modes

- Missing runtime auth context on mutation methods → error.
- Mutation caller not owner/admin for project → forbidden.
- Resource path invalid for current runtime scope → validation error.
- Unknown role or permission IDs in payloads → not found / conflict errors.

## Website-only role delegation

Existing platform collaborator permissions and the existing `assignRole`, `updateAssignment`, `revokeRole`, definition-mutation and bootstrap conditions are unchanged.

A project owner can create application roles (non-system roles) and explicitly grant a website superadmin `rbac:assign` on `roles:<roleId>` for each role that person may assign. Grant exact role IDs, not a wildcard. The website must separately guard its member-management handlers; ordinary admins/residents must not reach them.

```typescript
await ctx.permissions.grantWebsiteRole({subjectId: memberEmail, roleId, scopeResource: '*'});
await ctx.permissions.updateWebsiteRole(assignmentId, {subjectId: memberEmail, roleId, scopeResource: '*'});
await ctx.permissions.revokeWebsiteRole(assignmentId);
```

The platform derives actor and project from trusted runtime context. Only existing non-system roles can be assigned. Each operation checks `rbac:assign` against that exact role; updates require authorization for both old and new roles and cannot change the member's identity. Scope must be the current project's `*`. Platform/starter roles are rejected, even for an actor with a wildcard permission. These operations do not modify Sitemills collaborator access or grant platform administration. Keep project-owner recovery access outside the website's editable role set.

## Custom website property security roles

`ctx.permissions.listSecurityRoles()`, `saveSecurityRole({roleId?,name,grants})`, `deleteSecurityRole({roleId})`, `assignSecurityRole({roleId,email})` and `revokeSecurityRole({assignmentId})` manage custom website property security roles using trusted project and actor context. All five require `eufy:admin` on `integrations:eufy` in the current project. This is an integration-specific delegated API; existing platform role mutation conditions and endpoints are unchanged.

A grant is `{propertyId,permissions:[...]}`. The property ID is the exact 40-character Eufy house ID, not its display name. Supported actions are `view`, `access:list`, `codes:write`, `codes:delete`, `codes:reveal`, `access:rename` and `cameras:view`. Device viewing is included for each selected property. The service creates exact `eufy:property:<action>` permission definitions on `integrations:eufy:properties:<id>`, plus `eufy:manage` for entry to the integration. It cannot create wildcard permissions, `eufy:admin`, platform roles or superadmins. Roles have an internal website-integration marker; this API cannot edit or assign unrelated/system roles. Assignments are restricted to the current project.

Role names are user-defined. An unassigned member receives no property security access; existing ordinary admins also need property grants. Website superadmins should receive the narrowly scoped `eufy:admin` permission through the website's owner-controlled bootstrap. Other superadmin delegation stays in the existing website-role API. No platform collaborator access is conferred. Deleting a custom role removes the rights it grants; multiple assigned custom roles combine their permitted properties/actions. `listSecurityRoles` returns `{roles:[{id,name,grants}],assignments:[{id,roleId,email}]}`.
