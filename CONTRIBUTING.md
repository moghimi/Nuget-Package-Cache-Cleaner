# Contributing

Contributions are welcome through issues and pull requests.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Required contribution process

Every change must follow this process, including bug fixes, documentation updates, maintenance, and new features:

1. Open an issue before writing or submitting the change.
2. Describe the problem, expected result, proposed approach, safety implications, and acceptance criteria in the issue.
3. Wait for the issue to be discussed and accepted by a maintainer before starting substantial work.
4. Submit the change through a pull request. Changes must not be pushed directly to `main`.
5. Link the pull request to its issue with a closing keyword such as `Closes #123`.

Pull requests without a sufficiently detailed linked issue may be closed.

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
- Link the required issue using `Closes #<issue-number>`.
- Explain user-visible behavior and safety implications.
- Do not commit NuGet packages, cache contents, credentials, private paths, or generated test output.
- Expect automated tests and maintainer review before merge.
