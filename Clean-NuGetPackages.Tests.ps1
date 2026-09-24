$scriptPath = Join-Path $PSScriptRoot 'Clean-NuGetPackages.ps1'
. $scriptPath -Path $PSScriptRoot

Describe 'Clean-NuGetPackages' {
    BeforeEach {
        $packagesPath = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $packagesPath | Out-Null
    }

    It 'keeps only the newest two stable versions in the plan' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'example.package')
        @('1.0.0', '2.0.0', '10.0.0') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $package.FullName $_) | Out-Null
        }

        $plan = @(Get-NuGetCleanupPlan -PackagesPath $packagesPath -VersionsToKeep 2)

        @($plan | Where-Object Action -eq 'Keep').Version | Should Be @('10.0.0', '2.0.0')
        @($plan | Where-Object Action -eq 'Remove').Version | Should Be @('1.0.0')
    }

    It 'orders prerelease versions using NuGet semantic version precedence' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'prerelease.package')
        @('2.0.0-beta.2', '2.0.0-beta.10', '2.0.0', '1.9.9') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $package.FullName $_) | Out-Null
        }

        $plan = @(Get-NuGetCleanupPlan -PackagesPath $packagesPath -VersionsToKeep 2)

        @($plan | Where-Object Action -eq 'Keep').Version | Should Be @('2.0.0', '2.0.0-beta.10')
    }

    It 'does not delete anything unless deletion is explicitly enabled' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'safe.package')
        @('1.0.0', '2.0.0', '3.0.0') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $package.FullName $_) | Out-Null
        }

        & $scriptPath -Path $packagesPath | Out-Null

        (Get-ChildItem -LiteralPath $package.FullName -Directory).Count | Should Be 3
    }

    It 'deletes only versions marked for removal when enabled' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'delete.package')
        @('1.0.0', '2.0.0', '3.0.0') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $package.FullName $_) | Out-Null
        }

        & $scriptPath -Path $packagesPath -Apply -Confirm:$false | Out-Null

        @(Get-ChildItem -LiteralPath $package.FullName -Directory | Select-Object -ExpandProperty Name | Sort-Object) | Should Be @('2.0.0', '3.0.0')
    }

    It 'skips an unrecognized folder instead of risking its deletion' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'mixed.package')
        @('1.0.0', '2.0.0', 'not-a-version') | ForEach-Object {
            New-Item -ItemType Directory -Path (Join-Path $package.FullName $_) | Out-Null
        }

        $plan = @(Get-NuGetCleanupPlan -PackagesPath $packagesPath -VersionsToKeep 1 -WarningAction SilentlyContinue)

        ($plan.Version -contains 'not-a-version') | Should Be $false
        Test-Path -LiteralPath (Join-Path $package.FullName 'not-a-version') | Should Be $true
    }

    It 'summarizes the number of versions and space to free during review' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'summary.package')
        foreach ($version in @('1.0.0', '2.0.0', '3.0.0')) {
            $versionPath = New-Item -ItemType Directory -Path (Join-Path $package.FullName $version)
            [IO.File]::WriteAllBytes((Join-Path $versionPath.FullName 'package.bin'), [byte[]]::new(1024))
        }

        $plan = @(Get-NuGetCleanupPlan -PackagesPath $packagesPath -VersionsToKeep 2)
        $summary = Get-NuGetCleanupSummary -Plan $plan -Stage Review

        $summary.PackagesAnalyzed | Should Be 1
        $summary.VersionsKept | Should Be 2
        $summary.VersionsToRemove | Should Be 1
        $summary.SpaceToFreeBytes | Should Be 1024
        $summary.Space | Should Be '1.00 KB to free'
    }

    It 'summarizes removed versions and freed space after removal' {
        $package = New-Item -ItemType Directory -Path (Join-Path $packagesPath 'removed-summary.package')
        foreach ($version in @('1.0.0', '2.0.0', '3.0.0')) {
            $versionPath = New-Item -ItemType Directory -Path (Join-Path $package.FullName $version)
            [IO.File]::WriteAllBytes((Join-Path $versionPath.FullName 'package.bin'), [byte[]]::new(2048))
        }

        $plan = @(Get-NuGetCleanupPlan -PackagesPath $packagesPath -VersionsToKeep 2)
        Invoke-NuGetPackageCleanup -PackagesPath $packagesPath -VersionsToKeep 2 -Delete $true -Confirm:$false | Out-Null
        $summary = Get-NuGetCleanupSummary -Plan $plan -Stage Remove

        $summary.VersionsRemoved | Should Be 1
        $summary.SpaceFreedBytes | Should Be 2048
        $summary.Space | Should Be '2.00 KB freed'
    }

    It 'reports only removals that were actually completed' {
        $plan = @(
            [pscustomobject]@{ Action = 'Keep'; Package = 'confirmed.package'; SizeBytes = 100 }
            [pscustomobject]@{ Action = 'Remove'; Package = 'confirmed.package'; SizeBytes = 200 }
            [pscustomobject]@{ Action = 'Remove'; Package = 'confirmed.package'; SizeBytes = 300 }
        )

        $summary = Get-NuGetCleanupSummary -Plan $plan -Stage Remove -RemovedItems @($plan[1])

        $summary.VersionsRemoved | Should Be 1
        $summary.VersionsRemaining | Should Be 2
        $summary.SpaceFreedBytes | Should Be 200
    }
}
