# Storage API — ctx.storage

Use `ctx.storage` for project-scoped object storage and staged upload claim flows.

Typical use cases:
- persist user-uploaded files from frontend `fileId` handoff
- store generated artifacts from backend handlers
- fetch metadata/URLs for rendering and downloads
- attach stored files to AI workflows

## Methods

### 1) Upload bytes from backend code

```typescript
const uploaded = await ctx.storage.upload({
    data: base64Content, // required
    key: `exports/${reportId}.csv`, // optional
    originalFilename: `report-${reportId}.csv`, // optional
    contentType: 'text/csv', // optional
    metadata: { reportId } // optional
});
```

Returns:

```typescript
{
    id: string,
    key: string,
    url: string,
    contentType: string,
    sizeBytes: number
}
```

### 2) Read file payload or metadata

```typescript
const file = await ctx.storage.get('asset_or_key');
const meta = await ctx.storage.getMetadata('asset_or_key');
const url = await ctx.storage.url('asset_or_key');
```

Accepted reference shapes:
- string id/key
- object with one of `id`, `assetId`, `uploadId`, `fileId`, `key`

### 3) List and delete files

```typescript
const recentExports = await ctx.storage.list('exports/', 50);
await ctx.storage.delete('asset_or_key');
```

Notes:
- `list(prefix, limit)` returns newest-first.
- `limit` is capped at 1000.

### 4) Claim staged frontend uploads

```typescript
const claimed = await ctx.storage.claimUpload('pending_file_id');

const claimedWithTtl = await ctx.storage.claimUpload('pending_file_id', {
    ttlSeconds: 60 * 60 * 24 * 30
});

// Also accepted:
const claimedFromObject = await ctx.storage.claimUpload({
    fileId: 'pending_file_id',
    ttlSeconds: 3600
});
```

Returns:

```typescript
{
    id: string,
    key: string,
    url: string,
    contentType: string,
    sizeBytes: number,
    originalFilename: string,
    expiresAt: string | null
}
```

### 5) Inspect staged upload metadata before claim

```typescript
const staged = await ctx.storage.getUploadMetadata('pending_file_id');
```

Returns:

```typescript
{
    fileId: string,
    originalFilename: string,
    contentType: string,
    sizeBytes: number,
    expiresAt: string | null
}
```

## End-to-end user upload pattern (frontend -> backend)

Frontend should upload bytes with `api/asset-client.js` and send only `fileId`
to backend business handlers.

```typescript
export async function saveProfileAvatar(ctx, { fileId }) {
    if (!fileId) {
        throw new Error('fileId is required');
    }

    const resource = `sitemills:projects:project-1:profiles:${ctx.user.id}`;

    await ctx.permissions.require({
        subjectId: ctx.user.id,
        action: 'write:profile',
        resource,
        message: 'You do not have permission to update this profile.'
    });

    const staged = await ctx.storage.getUploadMetadata(fileId);
    if (!staged.contentType.startsWith('image/')) {
        throw new Error(`Unsupported avatar content type: ${staged.contentType}`);
    }

    const uploaded = await ctx.storage.claimUpload(fileId, {
        ttlSeconds: 60 * 60 * 24 * 365
    });

    await ctx.db.collection('profiles').updateOne(
        { userId: ctx.user.id },
        {
            $set: {
                avatar: {
                    id: uploaded.id,
                    url: uploaded.url,
                    contentType: uploaded.contentType,
                    sizeBytes: uploaded.sizeBytes,
                    originalFilename: uploaded.originalFilename
                },
                updatedAt: new Date().toISOString()
            }
        },
        { upsert: true }
    );

    await ctx.metrics.track('profile_avatar_claimed', {
        userId: ctx.user.id,
        uploadId: uploaded.id,
        contentType: uploaded.contentType
    });

    return { photo: uploaded };
}
```

## Opt-in frontend fetch fallback for pending uploads

For UI flows that need immediate browser access to an upload id before backend
business logic claims it, the runtime supports an explicit fetch fallback:

- `GET /api/v1/uploads/{fileId}?claimIfPending=true`
- or header `X-Sitemills-Claim-If-Pending: true`

When enabled, runtime attempts to claim the pending upload on cache miss and then
serves it as committed media.

Behavior boundaries:

- Fallback is opt-in only (legacy fetch behavior is unchanged without the flag/header).
- Session and scope checks remain strict (`projectId`, `branchId`, `sessionId`).
- Retention semantics are unchanged: no implicit `ttlSeconds` is injected.
- Unclaimed pending uploads still expire via pending-upload TTL.

## AI handoff pattern with claimed uploads

```typescript
export async function queueInvoiceExtraction(ctx, { fileId, invoiceId }) {
    if (!fileId || !invoiceId) {
        throw new Error('fileId and invoiceId are required');
    }

    const uploaded = await ctx.storage.claimUpload(fileId, {
        ttlSeconds: 60 * 60 * 24 * 90
    });

    const queued = await ctx.ai.oneShot({
        prompt: 'Extract invoice number, due date, line items, and total from this document.',
        fileIds: [uploaded.id],
        callbackRoute: 'handlers/ai_callbacks.onInvoiceExtracted',
        callbackPayload: { invoiceId, uploadId: uploaded.id }
    });

    return {
        queued: true,
        workflowId: queued.workflowId,
        uploadId: uploaded.id
    };
}
```

## Limits and validation

- `storage.upload` max file size is 10 MB.
- `claimUpload.ttlSeconds` is optional, but when provided it must be:
  - an integer
  - greater than 0
  - less than or equal to 315360000 (10 years)
- Reference arguments fail fast when required id/key fields are missing.
- Claim/metadata APIs enforce project + scope + session boundaries.

## Testing note

`storage.seedPendingUpload(...)` is test-only helper behavior available in
`test-*` scopes via the test framework for deterministic claim-flow tests.
It is not a normal production handler API surface.

## Anti-patterns

- ❌ Sending raw base64 payloads in normal business endpoint contracts.
- ❌ Skipping content-type/size validation before claim and persistence.
- ❌ Trusting frontend-provided file metadata without server-side checks.
- ❌ Storing sensitive files indefinitely without explicit retention rules.
