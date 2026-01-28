if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

$scriptDir = $PSScriptRoot
$regFiles = Get-ChildItem -Path $scriptDir -Filter "disable*.reg"

foreach ($file in $regFiles) {
    while ($true) {
        $response = Read-Host "Import $($file.Name)? [Y/n]"
        if ($response -eq "") { $response = "y" }

        if ($response -match "^y") {
            Write-Output "Importing $($file.Name)..."
            Start-Process "reg.exe" -ArgumentList "import `"$($file.FullName)`"" -Wait -NoNewWindow
            break
        }
        elseif ($response -match "^n") {
            Write-Output "Skipping $($file.Name)..."
            break
        }
    }
}
