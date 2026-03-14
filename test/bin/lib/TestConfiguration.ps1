function Get-TestConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string[]]$TestPath,

        [Parameter()]
        [switch]$RunUnit,

        [Parameter()]
        [switch]$RunIntegration,

        [Parameter(Position=1)]
        [string]$ExcludePattern,

        [Parameter(Position=2)]
        [string]$RepoRoot
    )

    # 1. Default Paths
    $isDefaultPaths = $false
    if (-not $TestPath -or $TestPath.Count -eq 0) {
        $TestPath = @('tools', 'test', 'bin', 'lib')
        $isDefaultPaths = $true
    }

    # 2. Resolve Paths
    $resolvedPaths = @()
    $invalidPaths = @()
    foreach ($path in $TestPath) {
        $fullPath = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $RepoRoot $path }
        if (Test-Path $fullPath) {
            $resolvedPaths += $fullPath
        } else {
            $invalidPaths += $path
        }
    }

    # Only throw for missing user-provided paths; silently skip missing default paths
    if (-not $isDefaultPaths -and $invalidPaths.Count -gt 0) {
        Throw "The following test paths do not exist: $($invalidPaths -join ', ')"
    }

    # 3. Apply Mode Logic
    $pesterPaths = $resolvedPaths
    $pesterExcludePaths = @()

    $isUnitOnly = $RunUnit -and -not $RunIntegration
    $isIntegrationOnly = $RunIntegration -and -not $RunUnit

    if ($isUnitOnly) {
        # Scan for all tests but exclude integration tests
        # We explicitly expand to files to ensure exclusion works reliably
        $unitTestFiles = @()
        foreach ($path in $resolvedPaths) {
            if (Test-Path $path -PathType Container) {
                # Find all tests
                $files = Get-ChildItem -Path $path -Filter '*.Tests.ps1' -Recurse -File -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    if ($file.Name -notlike '*.Integration.Tests.ps1') {
                        $unitTestFiles += $file.FullName
                    }
                }
            } elseif ($path -like '*.Tests.ps1' -and $path -notlike '*.Integration.Tests.ps1') {
                $unitTestFiles += $path
            }
        }
        $pesterPaths = $unitTestFiles
    } elseif ($isIntegrationOnly) {
        # Find *.Integration.Tests.ps1 in resolved paths and run ONLY those
        $integrationFiles = @()
        foreach ($path in $resolvedPaths) {
            if (Test-Path $path -PathType Container) {
                # If path is a container, find integration tests inside
                $found = Get-ChildItem -Path $path -Filter "*.Integration.Tests.ps1" -Recurse -File -ErrorAction SilentlyContinue
                if ($found) { $integrationFiles += $found.FullName }
            } elseif ($path -like '*.Integration.Tests.ps1') {
                # If path is a file and matches, include it
                $integrationFiles += $path
            }
        }

        if ($integrationFiles.Count -eq 0) {
            Write-Warning "No integration tests found in paths: $($resolvedPaths -join ', ')"
        }
        $pesterPaths = $integrationFiles
    }

    # 4. Handle External ExcludePattern
    if ($ExcludePattern) {
        # Search RepoRoot for excludes to maintain compatibility with existing functionality
        $found = Get-ChildItem -Path $RepoRoot -Filter $ExcludePattern -Recurse -File -ErrorAction SilentlyContinue
        if ($found) { $pesterExcludePaths += $found.FullName }
    }

    return @{
        TestPaths     = $pesterPaths
        ExcludePaths  = [string[]]@($pesterExcludePaths | Select-Object -Unique)
        OriginalPaths = $resolvedPaths
    }
}
