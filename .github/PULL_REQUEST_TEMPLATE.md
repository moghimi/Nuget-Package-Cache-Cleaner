## Summary

Describe the problem and the proposed change.

## Required issue

Every change requires a detailed issue before a pull request is opened.

Closes #

- [ ] The linked issue describes the problem, expected result, proposed approach, safety implications, and acceptance criteria.
- [ ] A maintainer accepted the issue before substantial work began.

## Validation

- [ ] I ran `Invoke-Pester .\Clean-NuGetPackages.Tests.ps1`.
- [ ] I added or updated tests for behavior changes.
- [ ] Tests use disposable fixtures and never access a real NuGet cache.
- [ ] Preview mode remains non-destructive.
- [ ] I updated documentation where needed.
- [ ] This change was submitted through a pull request and was not pushed directly to `main`.

## Security and compatibility

- [ ] Deletion still requires explicit user intent.
- [ ] Unrecognized paths or versions fail safely.
- [ ] The change works with Windows PowerShell 5.1 or PowerShell 7+.
