$ErrorActionPreference = "Stop"

. $PSScriptRoot\src\powershell\scoop.ps1

Install-Scoop

Install-Scoop-List-From-File ($PSScriptRoot + "\cfg\scoop.list")
