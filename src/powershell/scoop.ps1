# Update current environment from registry
Function Update-Environment {
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
   }
   catch {
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

Function Install-Scoop-Packages ([string[]]$Packages) {
   if ($Packages) {
      Write-Host "Installing scoop packages: $Packages"
      foreach ($Package in $Packages) { 
         Invoke-CommandLine -CommandLine "scoop install $Package"
         Update-Environment
      }
   }
}

Function Install-Scoop() {
   if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
      Invoke-RestMethod get.scoop.sh -outfile '_tmp-install-scoop.ps1'
      if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
         .\_tmp-install-scoop.ps1 -RunAsAdmin
      }
      else {
         .\_tmp-install-scoop.ps1
      }
   }
   Install-Scoop-Packages('git')
   Invoke-CommandLine -CommandLine "scoop update"
   Update-Environment
   Install-Scoop-Packages('lessmsi')
   Invoke-CommandLine -CommandLine "scoop config MSIEXTRACT_USE_LESSMSI $true"
   # Default installer tools, e.g., dark is required for python
   Install-Scoop-Packages('7zip', 'innounp', 'dark')
   Invoke-CommandLine -CommandLine "scoop bucket add extras" -StopAtError $false -Silent $true
}

Function Install-Scoop-List-From-File ([string[]]$file) {
   Install-Scoop-Packages( Get-Content $file )
}
