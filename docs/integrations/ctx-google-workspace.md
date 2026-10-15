# Google Workspace API — ctx.googleWorkspace

`ctx.googleWorkspace` lets your website's backend handlers work with the
project owner's Google Calendar, Drive, Docs, Sheets and (optionally) Gmail.
Project owners first authorize Google from **Project Settings → Google
Workspace** in the SiteMills dashboard. Runtime calls are then resolved by
project and deployed site environment; Google credentials stay protected by
SiteMills and are never sent to your handlers or your website.

## Capabilities

- Authorization is started from the SiteMills dashboard for a specific project
  and site environment (DEV, STAGING or PROD).
- If authorization expires or fails, restart **Connect Google** from Settings.
- Project Settings includes a read-only **Test Calendar connection** action.
  It retrieves the first calendar-list page and changes no events.
- Calendar access uses `calendar.calendarlist.readonly` to enumerate calendars
  and `calendar.events.owned` for events on calendars the connected Google
  account owns.
- Drive file listing/creation, Docs creation/batch updates, and Sheets
  creation/value append/update use only the `drive.file` scope (files created by
  or opened with your app).
- Google Picker is not available.
- Gmail sending (`gmail.send`) is an optional capability that is not requested by
  the normal connection flow; it requires separate approval and consent.

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

Parameter notes:
- `calendarId` is optional and defaults to `primary`.
- `event` is a Google Calendar event object (for example
  `{ summary, start: { dateTime }, end: { dateTime } }`).
- `drive.create` takes a Drive file metadata object (for example `{ name, mimeType }`).
- `docs.update` takes a Docs batch-update body (for example `{ requests: [...] }`).
- `sheets.append` / `sheets.update` take an A1 `range` and a value-range body
  (for example `{ values: [['Name', 'Email']] }`).
- `gmail.send` takes `to`, `subject` and a string `body`.
- String identifiers (`eventId`, `documentId`, `spreadsheetId`, `range`, `title`,
  `to`, `subject`, `calendarId`) must be non-empty and at most 500 characters.

## Environment rules

- Calls work only on a deployed DEV, STAGING or PROD site. Preview branches
  cannot borrow a DEV, STAGING or PROD connection.
- The project environment must have exactly one active Google connection.
- The Gmail method is available only after the connection has separately
  granted `gmail.send`.

## Safety rules

- Identify the project and environment only through the authenticated runtime
  context. Never accept a caller-supplied tenant, connection, Google account,
  access token or refresh token as authority.
- Restrict event and document changes to authorized users of your site.
- Give Calendar creates an idempotency strategy (for example, store the created
  `eventId` against your own record) before retrying.
- Update/delete operations should use a resource identifier selected from your
  own records for the connected project.
- Show provider errors to users as safe, fixed messages; never expose tokens or
  raw authorization responses.
- Never put credentials in page source or public responses.

## Setup and test

1. Open Project Settings → Google Workspace and select the website environment.
2. Connect the intended Google account and review the requested permissions.
3. Use **Test Calendar connection** to confirm read access without changing events.
4. Build a protected handler using the methods above. Test changes with a
   disposable event or an app-created document before using real data.

For missing permissions, reconnect and grant the capability your feature
requires. A working Calendar connection does not prove Drive, Docs, Sheets or
Gmail access. Disconnect through Settings when access is no longer wanted.
