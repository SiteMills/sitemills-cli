# ctx.httpClient - External HTTP API (Sandbox Safe)

`ctx.httpClient` is the only supported way to make outbound HTTP calls from backend handlers.

Security guarantees:
- Local/internal destinations are blocked (localhost, loopback, private RFC1918 ranges, link-local, etc.)
- Non-http(s) protocols are rejected
- Redirects are not auto-followed (`redirect: manual`)
- Direct imports of Node network modules (`http`, `https`, `net`, `dns`, `http2`, `tls`, `dgram`, `undici`) are blocked

## Methods

```typescript
await ctx.httpClient.request({
    method: 'POST',
    url: 'https://api.example.com/v1/items',
    headers: { Authorization: 'Bearer ...' },
    body: { name: 'Sample' },
    timeoutMs: 10000,
    query: { preview: true }
});

await ctx.httpClient.get('https://api.example.com/v1/items');
await ctx.httpClient.post('https://api.example.com/v1/items', {
    headers: { Authorization: 'Bearer ...' },
    body: { name: 'Sample' }
});
await ctx.httpClient.put('https://api.example.com/v1/items/123', { body: { enabled: false } });
await ctx.httpClient.patch('https://api.example.com/v1/items/123', { body: { enabled: true } });
await ctx.httpClient.delete('https://api.example.com/v1/items/123');
```

## Response Shape

All methods return:

```typescript
{
  status: number,
  ok: boolean,
  url: string,
  redirected: boolean,
  headers: Record<string, string>,
  body: any
}
```

Notes:
- If response `content-type` is JSON, `body` is parsed JSON.
- Otherwise, `body` is returned as text.

## Additional Examples

### Authenticated GET with query params

```typescript
const token = await ctx.env.get('CRM_API_TOKEN');

const contacts = await ctx.httpClient.get('https://api.example.com/v2/contacts', {
  headers: { Authorization: `Bearer ${token}` },
  query: { page: 1, pageSize: 50 },
  timeoutMs: 8000
});

if (!contacts.ok) {
  throw new Error(`Contacts fetch failed: status=${contacts.status}`);
}
```

### Upstream error passthrough with safe logging

```typescript
export async function syncPartnerStatus(ctx, { partnerId }) {
  const apiKey = await ctx.env.get('PARTNER_API_KEY');
  const result = await ctx.httpClient.request({
    method: 'PATCH',
    url: `https://partner.example.com/v1/partners/${partnerId}`,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: { status: 'ACTIVE' },
    timeoutMs: 10000
  });

  if (!result.ok) {
    await ctx.logs.warn('partner_sync_failed', {
      partnerId,
      status: result.status,
      responseType: typeof result.body
    });
    throw new Error(`Partner sync failed with status ${result.status}`);
  }

  return { synced: true, partnerId };
}
```

## Best Practices

- Keep outbound calls in backend handlers only.
- Keep timeouts explicit for slow/critical integrations.
- Read API tokens from `ctx.env` (never hardcode secrets).
- Check `result.ok` and throw explicit errors on non-2xx responses.

## Do Not Do This

- `import http from 'http'`
- `import https from 'https'`
- `require('net')`, `require('dns')`, `require('undici')`

These are blocked by sandbox policy. Use `ctx.httpClient`.
