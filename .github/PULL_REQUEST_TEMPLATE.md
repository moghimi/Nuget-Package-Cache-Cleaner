## Summary

Describe the problem and the proposed change.

## Validation

- [ ] I ran `Invoke-Pester .\Clean-NuGetPackages.Tests.ps1`.
- [ ] I added or updated tests for behavior changes.
- [ ] Tests use disposable fixtures and never access a real NuGet cache.
- [ ] Preview mode remains non-destructive.
- [ ] I updated documentation where needed.

## Security and compatibility

- [ ] Deletion still requires explicit user intent.
- [ ] Unrecognized paths or versions fail safely.
- [ ] The change works with Windows PowerShell 5.1 or PowerShell 7+.
