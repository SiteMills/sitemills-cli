# Storage API — ctx.storage

Use `ctx.storage` for project-scoped object storage and staged upload claim flows.

Typical use cases:
- persist user-uploaded files from frontend `fileId` handoff
- store generated artifacts from backend handlers
- fetch metadata/URLs for rendering and downloads
- attach stored files to AI workflows

## Methods

### Private and paid downloads

`claimUpload` is for PUBLIC media (avatars, thumbnails, gallery images). For
sensitive or paid files, use `claimPrivateUpload` instead. Private files live in
private object storage and have no public URL.

```typescript
// Authenticated backend handler: verify this user may upload/publish this file first.
const file = await ctx.storage.claimPrivateUpload(fileId);
// Returns { id, visibility: 'PRIVATE', originalFilename, sizeBytes }; persist id in your app.

// Separate authenticated download handler: load your app's file/purchase records
// and verify ctx.userId owns the file or has a valid paid entitlement BEFORE this call.
const grant = await ctx.storage.createDownloadGrant(file.id, browserProof);
// Returns { url, token, expiresAt } with a 60-second lifetime.

// After verifying the current user is authorized to delete this file:
await ctx.storage.deletePrivateFile(file.id);
```

The platform enforces project/branch isolation and requires an authenticated app
session. **Your handler enforces per-file ownership, roles and payment.** Never
expose an unconditional grant/delete handler that accepts arbitrary file IDs.
Never take project, branch, user or session IDs from the browser; the runtime
supplies them from trusted request context.

Frontend usage (the callback is your authenticated handler call):

```typescript
import { fetchPrivateDownload } from '/api/asset-client.js';

const response = await fetchPrivateDownload(proof =>
    requestAuthorizedDownload({ fileId, browserProof: proof }));
const blob = await response.blob(); // Or consume response.body as a stream.
```

`fetchPrivateDownload` generates a random browser-held proof, passes it to your
callback, then sends the proof and the returned grant in request headers
directly to storage. A copied URL alone, or a grant without the proof, cannot
download. The grant/proof pair is a short-lived capability: sharing BOTH allows
access until expiry. There is no per-chunk session revalidation; revocation takes
at most the grant lifetime for new requests. An already-started stream may finish
afterward. Downloaded files can always be shared onward by their recipients.

Keep grants/proofs out of URLs, logs, persisted app records and shared caches.
Private responses use no-store, attachment delivery and origin-bound CORS.
`storage.url`/`storage.get` reject private files; the public upload URL returns no
file. `storage.list` lists public files only; retain private IDs in your
authorized app records. Private files are retained until you call
`deletePrivateFile`; there is no private TTL option. Deletion removes the stored
object before its metadata.

Browser `uploadFile(file)` (from `api/asset-client.js`) reserves the project's
file quota, uploads the file directly to storage in signed chunks, and finalizes
metadata. It supports files up to 2,000,000,000 bytes, subject to remaining
project space. The custom domain and platform hostname share the same project
allowance; client-supplied project IDs cannot change the scope. Claim the
returned file ID as public or private. Decide visibility before publishing:
a file that was claimed as public and shared cannot be made secret retroactively.
Private claim retries are idempotent within the pending upload's one-hour
lifetime. If private storage is unavailable, private claims fail with an error
rather than falling back to public storage.

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

    const resource = `profiles:${ctx.user.id}`; // project-relative; the platform scopes it automatically

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

- `storage.upload` accepts small server-generated files up to 10 MiB and counts
  against the same project file-storage quota as browser uploads.
- Browser `uploadFile(file)` supports up to 2 GB per file, uploaded directly in
  bounded chunks. Files must fit remaining project storage (Free 50 MiB,
  Basic 75 GB, Advanced 300 GB, Ultra 600 GB). Pending uploads reserve space too.
- Database storage and file storage have separate allowances. Authorize uploads
  and downloads in app handlers as appropriate for your users/entitlements.
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

- ❌ Sending raw base64 payloads in normal business handler endpoints.
- ❌ Skipping content-type/size validation before claim and persistence.
- ❌ Trusting frontend-provided file metadata without server-side checks.
- ❌ Storing sensitive files indefinitely without explicit retention rules.
