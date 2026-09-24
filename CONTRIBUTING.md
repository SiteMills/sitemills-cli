# Contributing

**Do not commit to this repository directly.**

This repository is generated. It contains only the obfuscated build, the prebuilt binaries, and the user documentation for the SiteMills CLI. Every commit here is produced by the release tool in the private source repository (`scripts/release-public.mjs`, run as `npm run release:public`), which:

- scans for secrets before anything is published,
- verifies the build is obfuscated,
- copies only allow-listed files, and
- bumps the version so installed CLIs auto-update.

Hand-made commits skip all of those checks and can publish source code or credentials. Maintainers: make changes in the private repository and release with the tool.

Found a bug or have a question? Please open an issue.
