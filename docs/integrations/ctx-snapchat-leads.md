# Snapchat Leads

## Existing integration flow

Configure this integration in **Project Settings → Snapchat Leads**. Only the project owner may read or update its settings. Verified inbound deliveries supply `ctx.webhook` metadata; there is no outbound Snapchat SDK.

## Client setup

1. Deploy a backend handler named `receiveSnapchatLead` and an admin-only inbox in the project. Configuration does not install application code automatically.
2. Open Settings → Snapchat Leads. Enter Snapchat's ad-account ID (not Pixel ID) and permitted form UUIDs. The screen generates the production webhook URL and registration JSON. Copy from the deployed HTTPS dashboard, not a local development URL.
3. Save with receiver disabled while awaiting credentials. Obtain Marketing API authorization as Snapchat Organization Admin using private OAuth tooling. Check existing form integrations before registering: only one webhook per form is supported. Register the generated URL with `POST https://adsapi.snapchat.com/v1/lead_gen/integrations/public_webhook`. The screen does **not** implement OAuth, register webhooks, or replace an existing vendor integration.
4. Snapchat supplies `adAccountId`, `formId`, `integrationId`, and `hmacSecret`. Paste the signing secret into the password field, enable receiver and save. Retain integration IDs privately for testing. SiteMills generates the URL/payload, **not** Snapchat IDs or signing keys. Client secrets and access/refresh tokens are only needed in the private OAuth registration/test tooling; do not put them in app source, URLs, chat or logs.
5. Enable temporary dummy-lead mode, save, and call Snapchat's authenticated `GET /v1/lead_gen/integrations/{integration_id}/test`. Confirm one test lead in the project's inbox. Repeat to verify deduplication, then disable dummy mode and test the real form with your own details. There is no paid SMS, outbound message, or external CRM in this feature.

Status means configuration saved, not registered, reachable, or delivery verified. A saved configuration does not confirm successful delivery; test the form before relying on it. To rotate a signing secret, paste the new Snapchat-issued secret and save; a blank field preserves the existing secret. Changing ad accounts requires entering a replacement. Disabling the receiver retains the encrypted configuration and does not delete leads or unregister Snapchat. Use the receiver switch to disable delivery; do not remove configuration through generic secret-management tools.

## Runtime contract

Settings apply to the published production site. Saved signing secrets are never displayed. Coordinate credential changes with other project owners.

At runtime the native host verifies the raw signed body before invoking the handler, then attaches:

```ts
ctx.webhook = {
  verified: true, provider: 'snapchat', route: 'receiveSnapchatLead',
  configuration: { adAccountId, formIds, projectFields, allowTest }
};
```

`configuration` is a non-secret snapshot of the verified delivery settings. It is absent for legacy manually configured routes. The application must require verified metadata, validate lead/account/form IDs against this snapshot, normalize only needed contact/project/campaign/timestamp fields, and persist with a unique lead_id before returning `{accepted:true}`. Duplicate delivery must not reset read/status state. Invalid payloads return `{rejected:true}`; storage failures must remain retryable. Never trust webhook metadata in a normal handler payload. The runtime never injects the secret into metadata. Use owner/admin authorization for lead list/status APIs and escaped UI output; Call/Text links open device apps, not a messaging service.

Optional projectFields maps actual configured form UUIDs to `custom_field_1` … `custom_field_8`. Do not guess question meanings. Test mode permits only the documented fixed dummy identity, still with a valid signature. For the full raw-body, limits, rollout and test contract, see `docs/project-webhooks.md`.

## Troubleshooting

If setup is unavailable, contact SiteMills support. For missing leads, check the published handler, form registration, account/form IDs and receiver switch. Test with a dummy lead before a real submission. Keep the inbox restricted to authorized staff.

Official references: [Lead Generation API](https://developers.snap.com/marketing-api/Ads-API/lead-generation-ads), [Marketing OAuth](https://developers.snap.com/marketing-api/Ads-API/authentication).
