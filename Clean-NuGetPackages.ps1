<#
.SYNOPSIS
Keeps the newest NuGet package versions and optionally removes older versions.

.DESCRIPTION
Analyzes a NuGet global-packages folder using NuGet semantic-version precedence.
The default mode is read-only. Pass -Apply to remove versions beyond the retention count.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $Path,

    [ValidateRange(1, 100)]
    [int] $Keep = 2,

    [switch] $Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-NuGetVersionParts {
    param([Parameter(Mandatory = $true)][string] $Version)

    $match = [regex]::Match(
        $Version,
        '^(?<numbers>\d+(?:\.\d+){0,3})(?:-(?<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    )

    if (-not $match.Success) {
        return $null
    }

    $numbers = @($match.Groups['numbers'].Value.Split('.') | ForEach-Object { [uint64] $_ })
    while ($numbers.Count -lt 4) {
        $numbers += [uint64] 0
    }

    $prerelease = $null
    if ($match.Groups['prerelease'].Success) {
        $prerelease = @($match.Groups['prerelease'].Value.Split('.'))
    }

    [pscustomobject]@{
        Numbers   = $numbers
        Prerelease = $prerelease
    }
}

function Compare-NuGetVersion {
    param(
        [Parameter(Mandatory = $true)] $Left,
        [Parameter(Mandatory = $true)] $Right
    )

    for ($index = 0; $index -lt 4; $index++) {
        if ($Left.Numbers[$index] -lt $Right.Numbers[$index]) { return -1 }
        if ($Left.Numbers[$index] -gt $Right.Numbers[$index]) { return 1 }
    }

    if ($null -eq $Left.Prerelease -and $null -eq $Right.Prerelease) { return 0 }
    if ($null -eq $Left.Prerelease) { return 1 }
    if ($null -eq $Right.Prerelease) { return -1 }

    $count = [Math]::Min($Left.Prerelease.Count, $Right.Prerelease.Count)
    for ($index = 0; $index -lt $count; $index++) {
        $leftPart = $Left.Prerelease[$index]
        $rightPart = $Right.Prerelease[$index]
        $leftNumber = [uint64] 0
        $rightNumber = [uint64] 0
        $leftIsNumber = [uint64]::TryParse($leftPart, [ref] $leftNumber)
        $rightIsNumber = [uint64]::TryParse($rightPart, [ref] $rightNumber)

        if ($leftIsNumber -and $rightIsNumber) {
            if ($leftNumber -lt $rightNumber) { return -1 }
            if ($leftNumber -gt $rightNumber) { return 1 }
        }
        elseif ($leftIsNumber) { return -1 }
        elseif ($rightIsNumber) { return 1 }
        else {
            $comparison = [string]::Compare($leftPart, $rightPart, [StringComparison]::OrdinalIgnoreCase)
            if ($comparison -ne 0) { return $comparison }
        }
    }

    return $Left.Prerelease.Count.CompareTo($Right.Prerelease.Count)
}

function Get-NuGetCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $PackagesPath,
        [Parameter(Mandatory = $true)][int] $VersionsToKeep
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $PackagesPath).Path
    foreach ($packageDirectory in Get-ChildItem -LiteralPath $resolvedRoot -Directory) {
        $sortedVersions = [System.Collections.ArrayList]::new()

        foreach ($versionDirectory in Get-ChildItem -LiteralPath $packageDirectory.FullName -Directory) {
            $parts = ConvertTo-NuGetVersionParts -Version $versionDirectory.Name
            if ($null -eq $parts) {
                Write-Warning "Skipping unrecognized version folder: $($versionDirectory.FullName)"
                continue
            }

            [uint64] $size = 0
            foreach ($file in Get-ChildItem -LiteralPath $versionDirectory.FullName -File -Recurse -Force) {
                $size += $file.Length
            }

            $item = [pscustomobject]@{ Directory = $versionDirectory; Parts = $parts; SizeBytes = [uint64] $size }
            $insertAt = $sortedVersions.Count
            for ($index = 0; $index -lt $sortedVersions.Count; $index++) {
                if ((Compare-NuGetVersion -Left $parts -Right $sortedVersions[$index].Parts) -gt 0) {
                    $insertAt = $index
                    break
                }
            }
            $sortedVersions.Insert($insertAt, $item)
        }

        for ($index = 0; $index -lt $sortedVersions.Count; $index++) {
            [pscustomobject]@{
                Action  = if ($index -lt $VersionsToKeep) { 'Keep' } else { 'Remove' }
                Package = $packageDirectory.Name
                Version = $sortedVersions[$index].Directory.Name
                Path    = $sortedVersions[$index].Directory.FullName
                SizeBytes = $sortedVersions[$index].SizeBytes
            }
        }
    }
}

function Format-ByteSize {
    param([Parameter(Mandatory = $true)][uint64] $Bytes)

    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Get-NuGetCleanupSummary {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array] $Plan,
        [Parameter(Mandatory = $true)][ValidateSet('Review', 'Remove')][string] $Stage,
        [AllowEmptyCollection()][array] $RemovedItems
    )

    $removals = @($Plan | Where-Object Action -eq 'Remove')
    if ($Stage -eq 'Remove' -and $PSBoundParameters.ContainsKey('RemovedItems')) {
        $removals = @($RemovedItems)
    }
    [uint64] $bytes = 0
    foreach ($item in $removals) {
        $bytes += $item.SizeBytes
    }

    [pscustomobject]@{
        Stage             = $Stage
        PackagesAnalyzed  = @($Plan.Package | Sort-Object -Unique).Count
        VersionsKept      = @($Plan | Where-Object Action -eq 'Keep').Count
        VersionsRemaining = $Plan.Count - $removals.Count
        VersionsRemoved   = if ($Stage -eq 'Remove') { $removals.Count } else { 0 }
        VersionsToRemove  = if ($Stage -eq 'Review') { $removals.Count } else { 0 }
        SpaceToFreeBytes  = if ($Stage -eq 'Review') { [uint64] $bytes } else { [uint64] 0 }
        SpaceFreedBytes   = if ($Stage -eq 'Remove') { [uint64] $bytes } else { [uint64] 0 }
        Space             = "$(Format-ByteSize -Bytes $bytes) $(if ($Stage -eq 'Review') { 'to free' } else { 'freed' })"
    }
}

function Show-NuGetCleanupSummary {
    param([Parameter(Mandatory = $true)] $Summary)

    Write-Host ''
    Write-Host "NuGet cleanup summary ($($Summary.Stage))"
    Write-Host "  Packages analyzed : $($Summary.PackagesAnalyzed)"
    if ($Summary.Stage -eq 'Review') {
        Write-Host "  Versions to keep  : $($Summary.VersionsKept)"
        Write-Host "  Versions to remove: $($Summary.VersionsToRemove)"
    }
    else {
        Write-Host "  Versions remaining: $($Summary.VersionsRemaining)"
        Write-Host "  Versions removed  : $($Summary.VersionsRemoved)"
    }
    Write-Host "  Space              : $($Summary.Space)"
}

function Invoke-NuGetPackageCleanup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][string] $PackagesPath,
        [Parameter(Mandatory = $true)][int] $VersionsToKeep,
        [Parameter(Mandatory = $true)][bool] $Delete
    )

    $plan = @(Get-NuGetCleanupPlan -PackagesPath $PackagesPath -VersionsToKeep $VersionsToKeep)
    if ($Delete) {
        foreach ($item in $plan | Where-Object Action -eq 'Remove') {
            if ($PSCmdlet.ShouldProcess($item.Path, "Remove NuGet package $($item.Package) version $($item.Version)")) {
                Remove-Item -LiteralPath $item.Path -Recurse -Force
            }
        }
    }

    return $plan
}

if ($MyInvocation.InvocationName -ne '.') {
    $plan = @(Get-NuGetCleanupPlan -PackagesPath $Path -VersionsToKeep $Keep)
    $removedItems = @()
    if ($Apply) {
        foreach ($item in $plan | Where-Object Action -eq 'Remove') {
            if ($PSCmdlet.ShouldProcess($item.Path, "Remove NuGet package $($item.Package) version $($item.Version)")) {
                Remove-Item -LiteralPath $item.Path -Recurse -Force
                $removedItems += $item
            }
        }
    }

    $plan
    $stage = if ($Apply) { 'Remove' } else { 'Review' }
    if ($Apply) {
        Show-NuGetCleanupSummary -Summary (Get-NuGetCleanupSummary -Plan $plan -Stage $stage -RemovedItems $removedItems)
    }
    else {
        Show-NuGetCleanupSummary -Summary (Get-NuGetCleanupSummary -Plan $plan -Stage $stage)
    }
}
