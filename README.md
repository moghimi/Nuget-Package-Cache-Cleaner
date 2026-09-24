# NuGet Package Cache Cleaner

`Clean-NuGetPackages.ps1` analyzes a NuGet global-packages folder and keeps the newest two semantic versions of each package by default. It is designed for Windows PowerShell 5.1 and PowerShell 7+.

## Safety

- Preview mode is the default and never deletes files.
- Deletion requires the explicit `-Apply` switch.
- PowerShell asks for confirmation before each removal unless you pass `-Confirm:$false`.
- Unrecognized version folders are skipped.
- The removal summary counts only folders that were actually deleted.
- Package contents are never uploaded or sent anywhere.

Close Visual Studio, `dotnet`, and other processes that may be using the package cache before applying cleanup.

## Usage

Preview the plan (no files are deleted):

```powershell
.\Clean-NuGetPackages.ps1 -Path .\packages
```

Review the rows whose `Action` is `Remove`. To apply that exact policy, run:

```powershell
.\Clean-NuGetPackages.ps1 -Path .\packages -Apply
```

PowerShell requests confirmation before each removal. Use `-Confirm:$false` only after reviewing the preview. Change the retention count with `-Keep`, for example `-Keep 3`.

Both stages finish with a summary. Preview mode reports the packages analyzed, versions kept, versions to remove, and estimated space to free. Apply mode reports the versions removed and space freed.

The default NuGet packages directory is commonly `$HOME\.nuget\packages`, but the path must be supplied deliberately:

```powershell
.\Clean-NuGetPackages.ps1 -Path "$HOME\.nuget\packages"
```

## Tests

Run the isolated tests with:

```powershell
Invoke-Pester .\Clean-NuGetPackages.Tests.ps1
```

The script skips folders whose names are not recognized as NuGet semantic versions.

The tests use Pester 3.4 or later and create all sample packages in Pester's disposable `TestDrive`; they do not access your real NuGet cache. GitHub Actions also runs the test suite on Windows for every push and pull request.

## Supported version format

Versions can contain one to four numeric components, optional NuGet/SemVer prerelease identifiers, and optional build metadata. Release versions sort after prerelease versions of the same numeric version.

## License

This project is available under the [MIT License](LICENSE).

## Contributing

Public contributions are welcome. Every change must begin with a detailed issue and must be submitted through a pull request linked to that issue. Direct changes to `main` are not part of the accepted contribution process. See [CONTRIBUTING.md](CONTRIBUTING.md) for the required workflow.
