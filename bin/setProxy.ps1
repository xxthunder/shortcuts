<#
.SYNOPSIS
    Proxy settings for PowerShell
.DESCRIPTION
    Proxy settings for PowerShell
#>

Param(
    [string]$ProxyHost,
    [switch]$askForCreds ## ask for username and password (encrypted)
)

if ($askForCreds) {
    $user_string = Read-Host "Enter username for Proxy authentication"
    $pwd_string_secure = Read-Host "Enter password for Proxy authentication" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd_string_secure)
    $pwd_string = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    $Env:HTTP_PROXY = "http://" + $user_string + ':' + $pwd_string + '@' + $ProxyHost
} else {
    $Env:HTTP_PROXY = "http://$ProxyHost"
}

$Env:HTTPS_PROXY = $Env:HTTP_PROXY
$Env:NO_PROXY = "localhost,.marquardt.de,.marquardt.com"
$WebProxy = New-Object System.Net.WebProxy($Env:HTTP_PROXY, $true, ($Env:NO_PROXY).split(','))
[net.webrequest]::defaultwebproxy = $WebProxy
[net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
