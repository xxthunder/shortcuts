<#
.SYNOPSIS
    Get information about a domain user
.DESCRIPTION
    Get information about a domain user
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$UserName
)

$context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain)
$user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($context, $UserName)
$user

whoami /groups
