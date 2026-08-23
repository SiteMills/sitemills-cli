# AI Workflows API — ctx.ai

Use `ctx.ai` to enqueue asynchronous AI jobs from backend handlers.

Platform behavior:
- Requests are queued (RabbitMQ), not executed inline in the handler.
- Completed AI work invokes your callback handler route in the isolate.
- Retries are queue-driven and visible in the dashboard AI Workflows tab.
- Runtime credits are charged from token usage + fixed infra surcharge.

## Methods

### 1) Generic enqueue

```typescript
const result = await ctx.ai.enqueue({
        workflowType: 'CHAT',           // required: CHAT | ONE_SHOT
        prompt: 'Draft a concise status update for this incident',
        fileIds: ['mid_abc123'],        // optional: attach uploaded files by id
        callbackRoute: 'handlers/ai_callbacks.onStatusDraftReady',
        callbackPayload: { incidentId: 'inc_123' },
        callbackContext: { attemptId: 'att_001' }, // optional: echoed back on callback
        model: 'gemini-3-flash',        // optional
    enableGoogleSearch: true,       // optional, default false
        maxRetries: 2,                  // optional, 0..5
        timeoutMs: 45000                // optional, 1000..120000
});
```

### 2) Chat shorthand

```typescript
const result = await ctx.ai.chat({
        prompt: 'Act as a support assistant and answer politely.',
    fileIds: ['mid_abc123'],        // optional
        callbackRoute: 'handlers/ai_callbacks.onSupportReplyReady',
        callbackPayload: { ticketId: 't_42' },
    callbackContext: { convoId: 'convo_42' }, // optional
        model: 'gemini-3-flash-lite', // optional; this is already the default
        enableGoogleSearch: true       // optional, default false
});
```

### 3) One-shot shorthand

```typescript
const result = await ctx.ai.oneShot({
        prompt: 'Classify sentiment: positive, neutral, or negative. Text: ...',
    fileIds: ['mid_abc123'], // optional
        callbackRoute: 'handlers/ai_callbacks.onSentimentReady',
        callbackPayload: { reviewId: 'r_77' },
    callbackContext: { reviewAttemptId: 'ra_77' }, // optional
        enableGoogleSearch: true // optional, default false
});

// Alias:
const same = await ctx.ai.analyze({
        prompt: 'Extract top 3 themes from this feedback... ',
        callbackRoute: 'handlers/ai_callbacks.onThemesReady'
});
```

### 4) Callback chaining example (multi-step workflow)

```typescript
export async function summarizeIncidentAndNotify(ctx, { incidentId, notes }) {
    // Step 1: queue a summary workflow
    await ctx.ai.chat({
        prompt: `Summarize this incident in 3 bullet points:\n\n${notes}`,
        callbackRoute: 'handlers/ai_callbacks.onIncidentSummaryReady',
        callbackPayload: { incidentId },
        callbackContext: { stage: 'summary' },
        maxRetries: 2
    });

    return { queued: true, incidentId };
}

export async function onIncidentSummaryReady(ctx, params) {
    const summary = params?.response;
    const incidentId = params?.incidentId;

    if (!summary || !incidentId) {
        throw new Error('Missing callback fields for summary stage');
    }

    await ctx.db.collection('incidents').updateOne(
        { id: incidentId },
        { $set: { aiSummary: summary, summaryUpdatedAt: new Date().toISOString() } },
        { upsert: false }
    );

    // Step 2: queue a follow-up rewrite for customer-safe language
    await ctx.ai.oneShot({
        prompt: `Rewrite this incident summary for customers:\n\n${summary}`,
        callbackRoute: 'handlers/ai_callbacks.onCustomerSummaryReady',
        callbackPayload: { incidentId },
        callbackContext: { stage: 'customer_rewrite' }
    });
}
```

## Default model + supported models

- If `model` is omitted (or blank), runtime defaults to `gemini-3-flash-lite`.
- Allowed explicit values:
    - `gemini-3-pro`
    - `gemini-3.6-flash`
    - `gemini-3.5-flash`
    - `gemini-3-flash`
    - `gemini-3-flash-lite`

## Optional Google Search Grounding

- Set `enableGoogleSearch: true` to allow Gemini to use Google Search as a tool while generating the response.
- If omitted, `enableGoogleSearch` defaults to `false`.
- This option is available on `ctx.ai.enqueue`, `ctx.ai.chat`, `ctx.ai.oneShot`, and `ctx.ai.analyze`.

## Optional File Attachments

- Set `fileIds: string[]` to attach uploaded files to the Gemini prompt.
- Each `fileId` must belong to the same project as the workflow.
- Supported attachment types are text files, JSON, XML, images, and PDF.
- `fileIds` entries may be plain strings or objects containing one of:
  `fileId`, `id`, `uploadId`, or `assetId`.
- This option is available on `ctx.ai.enqueue`, `ctx.ai.chat`, `ctx.ai.oneShot`, and `ctx.ai.analyze`.

## Cross-integration recipe (uploads + RBAC + metrics)

```typescript
export async function summarizeUploadedSpec(ctx, { fileId, specId }) {
    if (!fileId || !specId) {
        throw new Error('fileId and specId are required');
    }

    const resource = `sitemills:projects:project-1:specs:${specId}`;

    await ctx.permissions.require({
        subjectId: ctx.user.id,
        action: 'read:spec',
        resource,
        message: 'You do not have access to this spec.'
    });

    const staged = await ctx.storage.getUploadMetadata(fileId);
    if (staged.sizeBytes > 5_000_000) {
        throw new Error('Spec upload exceeds 5 MB limit for summary workflow');
    }

    const queued = await ctx.ai.oneShot({
        prompt:
            'Summarize this specification in 6 bullet points. Include risks and open questions.',
        fileIds: [fileId],
        callbackRoute: 'handlers/ai_callbacks.onSpecSummaryReady',
        callbackPayload: { specId, fileId },
        callbackContext: { source: 'spec_summary' }
    });

    await ctx.metrics.track('ai_spec_summary_enqueued', {
        specId,
        fileId,
        contentType: staged.contentType,
        workflowId: queued.workflowId
    });

    return {
        queued: true,
        workflowId: queued.workflowId,
        fileId
    };
}

export async function onSpecSummaryReady(ctx, params) {
    const { specId, fileId, response, usage } = params;
    if (!specId || !response) {
        throw new Error('Missing specId/response in AI callback');
    }

    await ctx.db.collection('spec_summaries').updateOne(
        { specId },
        {
            $set: {
                summary: response,
                sourceFileId: fileId,
                updatedAt: new Date().toISOString()
            }
        },
        { upsert: true }
    );

    await ctx.metrics.track('ai_spec_summary_completed', {
        specId,
        fileId,
        totalTokenCount: String(usage?.totalTokenCount ?? 0)
    });
}
```

If you need a durable media reference before enqueueing AI work, claim the staged
upload first via `ctx.storage.claimUpload(fileId)` and pass `claimed.id` in
`fileIds`.

## Enqueue response

All methods return quickly after queueing:

```json
{
    "workflowId": "2ecf8d26-...",
    "status": "QUEUED",
    "queuedAt": "2026-04-30T16:03:11.512Z"
}
```

## Callback behavior

When the model call succeeds, runtime invokes your callback route with payload:

```typescript
{
    workflowId: string,
    status: 'COMPLETED',
    type: 'CHAT' | 'ONE_SHOT',
    prompt: string,
    response: string,
    model: string,
    usage: {
        promptTokenCount?: number,
        cachedTokenCount?: number,
        candidateTokenCount?: number,
        thoughtsTokenCount?: number,
        totalTokenCount?: number
    },
    cost: {
        modelCostUsd: number,
        infraCostUsd: number,
        totalCostUsd: number
    },
    callbackPayload?: any,
    callbackContext?: any
}
```

The canonical AI text field is `response`.
Runtime also includes `result` as a compatibility alias with the same value.

`callbackContext` (when provided at enqueue time) is echoed back verbatim for
callback bookkeeping.

**Both `callbackPayload` and `callbackContext` object fields are surfaced to the
top level of `params`.** You can destructure directly —
`const { taskId, attemptId } = params` works. The nested forms
(`params.callbackPayload.taskId`, `params.callbackContext.attemptId`) also work.
Platform-owned keys
(`workflowId`, `status`, `response`, `model`, `usage`, `cost`, etc.) always
take precedence and cannot be overwritten by callback metadata.

**Example Callback handler pattern:**

```typescript
// server/handlers/ai_callbacks.ts (not a real file, just an example)
export async function onStatusDraftReady(ctx: any, params: any) {
    // ✅ AI text is at top-level params.response
    const aiText =
        typeof params?.response === 'string'
            ? params.response
            : (typeof params?.result === 'string' ? params.result : '');

    if (!aiText) {
        throw new Error('AI callback missing response text');
    }

    // ✅ callback metadata fields are spread to top level — both forms work
    const { incidentId } = params;              // ✅ top-level destructure
    // const incidentId = params.callbackPayload?.incidentId;  // also works

    await ctx.db.collection('incidents').updateOne(
        { id: incidentId },
        { $set: { statusDraft: aiText, updatedAt: new Date().toISOString() } },
        { upsert: false }
    );
}
```

This enables chaining. A callback handler can enqueue a follow-up `ctx.ai.*` workflow.

**ctx.user in callback handlers is the platform system identity, not a browser user.**
AI workflow callbacks are invoked by the platform runtime — `ctx.user.isSystem === true`
and `ctx.user.id === 'system'`. Do NOT use `ctx.user.email` to identify the original
user; pass user-specific data in `callbackPayload` or `callbackContext` instead. Do NOT add authentication
guards like `if (!ctx.user) return` — the system identity is always present.

## Retry and failure lifecycle

Workflow statuses:
- `QUEUED`
- `PROCESSING`
- `RETRYING`
- `COMPLETED`
- `FAILED`
- `TIMED_OUT`

Retry attempts are controlled by `maxRetries` (default 2).
Retry scheduling is queue-based with backoff and appears in the dashboard.

## Validation rules

- `prompt` is required and max 50,000 chars.
- `callbackRoute` is required.
- `workflowType` is required for `ctx.ai.enqueue`; `chat/oneShot/analyze` set it for you.
- `enableGoogleSearch` must be a boolean when provided.
- `fileIds` must be an array of non-empty strings when provided.
- `maxRetries` must be 0..5 when provided.
- `timeoutMs` must be 1000..120000 when provided.

## Dashboard visibility

The dashboard AI Workflows tab surfaces per-project workflow state including:
- queue/processing/retry/failure status
- attempts and failure reason
- token usage and total costs
- callback route and timestamps

## Anti-patterns

- ❌ Treating `ctx.ai.*` as synchronous request/response.
- ❌ Returning AI completion data immediately from the enqueue handler.
- ❌ Omitting callback route and expecting polling by default.
- ❌ Adding test-only parser branches that look for deterministic mock text (for example `Mock AI response`) in service handlers.
    Keep handler logic production-oriented; tests should invoke callbacks with explicit payloads when specific content is needed.
- ❌ Hardcoding secrets in prompts (use `ctx.env` and sanitize before prompt construction).
- ❌ Treating `ctx.user` in callback handlers as a real browser user — AI callbacks are invoked by
                            the platform system; `ctx.user.isSystem === true`. Pass user context via `callbackPayload` or `callbackContext`.
