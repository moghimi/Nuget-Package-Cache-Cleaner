# Security Policy

## Reporting a vulnerability

Please report security issues privately through the repository's [Security advisories](https://github.com/moghimi/Nuget-Package-Cache-Cleaner/security/advisories/new) page instead of opening a public issue. Include reproduction steps and the affected version when possible.

## Safe operation

Always run preview mode first and review every row marked `Remove`. Keep a backup when the cache contains packages that cannot be restored from a configured NuGet source. Do not use `-Confirm:$false` until the preview has been reviewed.
