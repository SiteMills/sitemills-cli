# Google Workspace integration

`ctx.googleWorkspace` is the generated-site runtime API. Project owners first
authorize Google through the central SiteMills Project Settings flow. Runtime
calls are then resolved by project and deployed site environment; credentials
remain protected by SiteMills and are never sent to your website.

## Current capability boundary

- Authorization is started from the SiteMills dashboard for a specific project
  and site environment.
- If authorization expires or fails, restart **Connect Google** from Settings.
- Project Settings includes a read-only **Test Calendar connection** action.
  It retrieves the first calendar-list page and changes no events.
- Google refresh tokens remain server-side and are never passed to generated
  handlers, browser storage, logs, traces, or agent context.
- Calendar access currently uses `calendar.calendarlist.readonly` to enumerate
  calendars and `calendar.events.owned` for events on calendars the connected
  Google account owns.
- Dashboard and generated-site Drive file listing/creation, Docs
  creation/batch updates, and Sheets creation/value append/update are available
  through the central service and use only `drive.file`. Google Picker is not
  available yet. Gmail send-only is an explicit backend capability using
  `gmail.send`; it is not requested by the normal connection flow and must not
  be enabled without the separate sensitive-scope review.

## Runtime methods

```typescript
await ctx.googleWorkspace.calendar.list();
await ctx.googleWorkspace.calendar.create({ calendarId, event });
await ctx.googleWorkspace.calendar.update({ calendarId, eventId, event });
await ctx.googleWorkspace.calendar.delete({ calendarId, eventId });
await ctx.googleWorkspace.drive.list();
await ctx.googleWorkspace.drive.create({ name, mimeType });
await ctx.googleWorkspace.docs.create({ title });
await ctx.googleWorkspace.docs.update({ documentId, body });
await ctx.googleWorkspace.sheets.create({ title });
await ctx.googleWorkspace.sheets.append({ spreadsheetId, range, body });
await ctx.googleWorkspace.sheets.update({ spreadsheetId, range, body });
await ctx.googleWorkspace.gmail.send({ to, subject, body });
```

The project environment must have exactly one active Google connection. The
Working Draft and checkpoints cannot borrow a DEV, STAGING, or PROD connection. The Gmail method is
available only after the connection has separately granted `gmail.send`.

## Safety rules

Generated workflows must identify the project and site environment through the
authenticated SiteMills runtime context. They must not accept a caller-supplied
tenant, connection, Google account, access token, or refresh token as authority.
Calendar creates need an idempotency strategy at the workflow layer before a
retry is attempted. Update/delete operations must use a resource identifier
selected from the connected project context. Provider errors should be shown as
safe fixed messages and must not expose tokens or raw authorization responses.

## Setup and test

1. Open Project Settings → Google Workspace and select the website environment.
2. Connect the intended Google account and review the requested permissions.
3. Use **Test Calendar connection** to confirm read access without changing events.
4. Build a protected project handler using the methods above. Test changes with a disposable event or app-created document before using real data.

For missing permissions, reconnect and grant the capability your feature requires.
A working Calendar connection does not prove Drive, Docs, Sheets or Gmail access.
Google Picker is not available; Gmail sending requires separate approval and consent.
Disconnect through Settings when access is no longer wanted. Never put credentials
in page source or public responses. Restrict event and document changes to authorized users.
