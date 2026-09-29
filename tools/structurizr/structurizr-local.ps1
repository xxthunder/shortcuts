#Requires -Version 7.4

<#
.SYNOPSIS
    Starts Structurizr local on the architecture model and opens it in the browser.

.DESCRIPTION
    Runs tools/structurizr/structurizr-local.sh in a WSL distribution. The script starts the
    structurizr/structurizr container with docker or podman on docs/architecture (SC-062).
    The browser opens once http://localhost:<Port> answers. Ctrl+C stops the viewer.

.PARAMETER Distro
    The WSL distribution to run the container in. Default: the default WSL distribution.

.PARAMETER Port
    The local port of the viewer. Default: 8080.

.EXAMPLE
    .\structurizr-local.ps1
    Starts the viewer in the default distribution on http://localhost:8080.

.EXAMPLE
    .\structurizr-local.ps1 -Distro Ubuntu-24.04 -Port 8081
    Starts the viewer in Ubuntu-24.04 on http://localhost:8081.
#>
[CmdletBinding()]
param(
    [string]$Distro = "",

    [ValidateRange(1, 65535)]
    [int]$Port = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. "$PSScriptRoot\..\..\lib\utils\utils.ps1"

function Get-StructurizrLocalCommandLine {
    <#
    .SYNOPSIS
        Builds the wsl.exe call that runs structurizr-local.sh from the repository root.

    .DESCRIPTION
        wsl.exe --cd takes the Windows path of the repository, so no path conversion is
        needed; the path is quoted because a user profile may contain spaces. Without a
        distribution, wsl.exe uses the default one.

    .PARAMETER RepoRoot
        Windows path of the shortcuts repository.

    .PARAMETER Distro
        The WSL distribution, or an empty string for the default one.

    .PARAMETER Port
        The local port of the viewer.

    .OUTPUTS
        System.String

    .EXAMPLE
        Get-StructurizrLocalCommandLine -RepoRoot 'C:\Users\dev\shortcuts' -Port 8080
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [string]$Distro = "",

        [Parameter(Mandatory)]
        [int]$Port
    )

    $distroOption = if ([string]::IsNullOrWhiteSpace($Distro)) { "" } else { "--distribution $Distro " }
    return "wsl.exe $distroOption--cd `"$RepoRoot`" --exec bash -l tools/structurizr/structurizr-local.sh --port=$Port"
}

function Wait-StructurizrReady {
    <#
    .SYNOPSIS
        Waits until a URL answers.

    .DESCRIPTION
        Requests the URL once per interval. The first image pull can take minutes, so the
        default allows 300 attempts.

    .PARAMETER Url
        The URL to request.

    .PARAMETER Attempts
        How often to try before giving up.

    .PARAMETER IntervalSeconds
        Pause between two attempts.

    .OUTPUTS
        System.Boolean
        $true as soon as the URL answers, $false after the last attempt.

    .EXAMPLE
        Wait-StructurizrReady -Url 'http://localhost:8080' -Attempts 60
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [int]$Attempts = 300,

        [int]$IntervalSeconds = 1
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Url -TimeoutSec 2 | Out-Null
            return $true
        }
        catch {
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    return $false
}

# Runs in a thread job, which does not see this script's functions: the job gets the
# definition of Wait-StructurizrReady as text and defines it before use.
$script:StructurizrOpenWhenReady = {
    param($WaitDefinition, $Url, $Attempts)
    Set-Item -Path function:Wait-StructurizrReady -Value $WaitDefinition
    if (Wait-StructurizrReady -Url $Url -Attempts $Attempts) {
        Start-Process -FilePath $Url
    }
}

function Start-StructurizrBrowserJob {
    <#
    .SYNOPSIS
        Opens the viewer in the browser from a background thread job once it answers.

    .PARAMETER Url
        The viewer URL.

    .PARAMETER Attempts
        How often the job requests the URL before it gives up without opening the browser.

    .OUTPUTS
        The thread job, or $null with -WhatIf.

    .EXAMPLE
        $job = Start-StructurizrBrowserJob -Url 'http://localhost:8080'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [int]$Attempts = 300
    )

    if (-not $PSCmdlet.ShouldProcess($Url, "Open in the browser once it answers")) {
        return $null
    }
    Start-ThreadJob -ScriptBlock $script:StructurizrOpenWhenReady -ArgumentList ${function:Wait-StructurizrReady}.ToString(), $Url, $Attempts
}

function Invoke-StructurizrLocalMain {
    <#
    .SYNOPSIS
        Starts the viewer in WSL, opens the browser and returns the exit code of the viewer.

    .PARAMETER Distro
        The WSL distribution, or an empty string for the default one.

    .PARAMETER Port
        The local port of the viewer.

    .OUTPUTS
        System.Int32

    .EXAMPLE
        Invoke-StructurizrLocalMain -Port 8080
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$Distro = "",

        [int]$Port = 8080
    )

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $url = "http://localhost:$Port"
    $job = Start-StructurizrBrowserJob -Url $url
    try {
        Write-Information "Starting Structurizr local on $url (Ctrl+C stops it) ..."
        # Out-Host streams the viewer log to the console as it comes; left in the pipeline it
        # would be collected into this function's return value next to the exit code
        Invoke-CommandLine -CommandLine (Get-StructurizrLocalCommandLine -RepoRoot $repoRoot -Distro $Distro -Port $Port) -StopAtError $false -PrintCommand $false | Out-Host
        return $global:LASTEXITCODE
    }
    finally {
        if ($null -ne $job) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not $env:STRUCTURIZR_LOCAL_LIBRARY_MODE) {
    exit (Invoke-StructurizrLocalMain -Distro $Distro -Port $Port)
}
