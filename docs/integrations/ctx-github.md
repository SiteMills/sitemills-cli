# GitHub (`ctx.github`)

`ctx.github` lets this site's backend handlers read GitHub repositories and open issues in them. It only works on repositories the **project owner** added in Project Settings → GitHub and turned on for the site:

- **Site can read**: `getFile`, `listFiles`, `readme`, `releases`, `latestRelease`, `tags`, `commits`.
- **Site can create issues**: `createIssue`.

Both switches start off, because site code runs for every visitor. GitHub credentials stay on SiteMills' servers: nothing secret reaches your handler or the browser.

## Check what's available

```typescript
const { repositories } = await ctx.github.repositories();
// [{ repository: 'acme/docs', repositoryId: 123, private: false, defaultBranch: 'main',
//    url: 'https://github.com/acme/docs', read: true, issues: false }]
```

When the repository you need isn't listed, or the switch you need is off, tell the user to turn it on in Project Settings → GitHub (the project owner does this). Name a repository as `owner/name` or by its `repositoryId`.

## Reading

```typescript
const page = await ctx.github.getFile('acme/docs', 'guide/intro.md');            // { repository, ref, path, size, content }
const atTag = await ctx.github.getFile('acme/docs', 'guide/intro.md', { ref: 'v2.0' });
const dir = await ctx.github.listFiles('acme/docs', 'guide');                    // { entries: [{ name, path, type: 'file' | 'dir', size }] }
const root = await ctx.github.listFiles('acme/docs');
const readme = await ctx.github.readme('acme/docs');                             // { path, size, content }
const { releases } = await ctx.github.releases('acme/app', { limit: 5 });        // [{ name, tag, notes, url, publishedAt, prerelease, assets }], up to 30
const { release } = await ctx.github.latestRelease('acme/app');                  // null when there's no release yet
const { tags } = await ctx.github.tags('acme/app', { limit: 20 });               // [{ name, commit }]
const { commits } = await ctx.github.commits('acme/app', { path: 'CHANGELOG.md', limit: 10 });
// [{ sha, message, author, login, date, parents }]
```

- `ref` is a branch, tag or full 40-character commit SHA; the default branch when left out.
- `getFile` and `readme` return UTF-8 text files up to 1 MB. A binary file (an image, a font), a larger file or a directory throws with the reason. To show an image from a **public** repository, link to `https://raw.githubusercontent.com/<owner>/<name>/<ref>/<path>` instead.
- `limit` is 1 to 100 (default 10); for `releases`, 1 to 30, with each release's notes cut at 10,000 characters. Draft releases aren't returned; for a private repository, release assets have no `downloadUrl`.
- Commit authors come with a name and GitHub `login`, never an email address.
- **Answers are cached for about a minute**, so a push shows up on the site shortly after, not instantly. Every call counts against a per-project budget (600 a minute), and calls that reach GitHub against a smaller one (30 a minute, 250 an hour), so cache or pre-render where you can rather than calling GitHub on every page view. Under heavy load a call can be turned away with "try again in a moment".
- Treat repository content as content: render Markdown with a sanitizer, and never run code from it.

## Opening issues

```typescript
const issue = await ctx.github.createIssue('acme/app', {
  title: 'Bug report from the site',            // required, up to 256 characters
  body: `${message}\n\nSent from the contact form`,  // optional, up to 60,000 characters
});
// { repository, number: 42, url: 'https://github.com/acme/app/issues/42' }
```

- Issues are opened by the SiteMills GitHub App, not by the visitor, and end with a line saying a website visitor sent them. `@mentions`, `owner/repo#123` references and links to other GitHub issues in the title or body are made inert, so visitors can't notify people or post into other repositories. Labels aren't supported (`labels` is refused); use the repository's own automation to label issues.
- If `createIssue` times out, the issue may still have been opened: don't retry it automatically.
- Visitors can reach this, so protect the form: require sign-in (`ctx.user`) or another check, validate and trim what they type, and never put secrets or other people's data in the issue.
- Each repository can get at most 20 issues an hour from sites, and each project 50 an hour and 100 a day.
- In project tests (`runTests()`), every `ctx.github` method is mocked by default: nothing reaches GitHub. Arguments are checked as for real, `repositories()` lists `mock-owner/mock-repo`, files and READMEs have placeholder content, lists are empty, and `createIssue` returns a numbered fake issue. For fixed test data, mock a method with `integrations.mock('github.getFile', ...)`.

## Errors

Every method throws with a message saying what's wrong and who can fix it, for example:
- the repository isn't added or isn't turned on for the site;
- the person who added it needs to reconnect GitHub;
- the GitHub App hasn't been given permission to open issues yet;
- GitHub's rate limit was reached.

Catch errors in your handler and show visitors a short, friendly message; log the details.
