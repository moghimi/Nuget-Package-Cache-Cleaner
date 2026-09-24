# Contributing

Contributions are welcome through issues and pull requests.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). For substantial changes, open a feature request first so the design and safety implications can be discussed.

## Development

1. Use Windows PowerShell 5.1 or PowerShell 7+.
2. Install Pester if it is not already available.
3. Keep preview mode non-destructive and require `-Apply` for deletion.
4. Add or update tests for every behavior change.
5. Run the complete suite before opening a pull request:

```powershell
Invoke-Pester .\Clean-NuGetPackages.Tests.ps1
```

Tests must operate only on disposable fixtures. Never point automated tests at a real package cache.

## Pull requests

- Keep each pull request focused on one change.
- Explain user-visible behavior and safety implications.
- Do not commit NuGet packages, cache contents, credentials, private paths, or generated test output.
- Expect automated tests and maintainer review before merge.
