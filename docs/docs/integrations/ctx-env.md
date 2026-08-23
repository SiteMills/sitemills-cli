# ctx.env - Project Secrets / Environment Variables

`ctx.env` exposes project-scoped secret variables at runtime.

Security model:
- The LLM can see variable names and optional descriptions (for example `OPENAI_API_KEY` + "OpenAI backend key"), never secret values.
- Secret values are resolved inside backend runtime only.
- Use `ctx.env.list()` to discover available names and `ctx.env.get(name)` to read a value at execution time.

## Methods

```typescript
// List variables available for current environment (names only)
const vars = await ctx.env.list();

// Detailed metadata (still no secret values)
const detailed = await ctx.env.listDetailed();
// detailed item shape:
// {
//   name: string,
//   sourceEnvironment: string,
//   isShared: boolean,
//   description: string | null
// }

// Get one secret value for current environment (throws if missing)
const apiKey = await ctx.env.get('OPENAI_API_KEY');

// Alias with same behavior
const token = await ctx.env.require('SLACK_BOT_TOKEN');

// Optional read (returns null when missing)
const maybe = await ctx.env.getOptional('SENTRY_DSN');
```

## Environment Resolution

Variables are resolved using explicit environment precedence:
1. Exact current environment key
2. GLOBAL shared key (if configured)

If neither exists, `ctx.env.get(...)` throws a descriptive error.

## Recommended Usage

```typescript
export async function checkIntegrations(ctx) {
    const openAiKey = await ctx.env.get('OPENAI_API_KEY');
    const hasSentry = (await ctx.env.getOptional('SENTRY_DSN')) !== null;

    await ctx.db.collection('integration_status').updateOne(
        { _id: 'latest' },
        {
            $set: {
                openAiConfigured: !!openAiKey,
                sentryConfigured: hasSentry,
                updatedAt: new Date().toISOString()
            }
        },
        { upsert: true }
    );

    return { openAiConfigured: true, sentryConfigured: hasSentry };
}
```

## Additional Examples

### Fail-fast startup validation for required keys

```typescript
export async function validateEnv(ctx) {
    const required = ['STRIPE_SECRET_KEY', 'SLACK_BOT_TOKEN'];

    for (const key of required) {
        const value = await ctx.env.get(key); // throws immediately if missing
        if (!value || !value.trim()) {
            throw new Error(`Required env key is blank: ${key}`);
        }
    }

    return { valid: true, checked: required.length };
}
```

### Optional integration with graceful feature toggle

```typescript
export async function buildTelemetryConfig(ctx) {
    const sentryDsn = await ctx.env.getOptional('SENTRY_DSN');
    return {
        sentryEnabled: !!sentryDsn,
        sentryDsn
    };
}
```

## Good Practices

- Store only provider secrets in `ctx.env` (API keys, tokens, signing secrets).
- Do not log secret values.
- Use variable descriptions to document what each key is for.
- Keep variable names stable and descriptive (`STRIPE_SECRET_KEY`, not `KEY1`).
- Use `GLOBAL` for shared values and per-environment overrides only when needed.
