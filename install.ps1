Function ReloadEnvVars () {
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

# executes a command line call
Function Invoke-CommandLine {
    param (
        [string]$CommandLine,
        [bool]$StopAtError = $true,
        [bool]$Silent = $false
    )
    if (-Not $Silent) {
        Write-Host "Executing: $CommandLine"
    }

    try {
        Invoke-Expression $CommandLine
    } catch {
        # do nothing
    }
    
    if ($LASTEXITCODE -ne 0) {
        if ($StopAtError) {
            Write-Error "Command line call `"$CommandLine`" failed with exit code $LASTEXITCODE"
            exit 1
        }
        else {
            if (-Not $Silent) {
                Write-Host "Command line call `"$CommandLine`" failed with exit code $LASTEXITCODE, continuing ..."
            }
        }
    }
}

# installs scoop packages; can be a single package or multiple packages at once
Function ScoopInstall ([string[]]$Packages) {
    if ($Packages) {
        Invoke-CommandLine -CommandLine "scoop install $Packages"
        ReloadEnvVars
    }
}

Function Install-Basic-Tools() {
    if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        irm get.scoop.sh -outfile '_tmp-install-scoop.ps1'
        if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            .\_tmp-install-scoop.ps1 -RunAsAdmin
        } else {
            .\_tmp-install-scoop.ps1
        }
    }
    ScoopInstall('git')
    Invoke-CommandLine -CommandLine "scoop update"
    ReloadEnvVars
    ScoopInstall('lessmsi')
    Invoke-CommandLine -CommandLine "scoop config MSIEXTRACT_USE_LESSMSI $true"
    # Default installer tools, e.g., dark is required for python
    ScoopInstall('7zip', 'innounp', 'dark')
}

Install-Basic-Tools
