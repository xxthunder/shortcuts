@echo off
REM Launch the Scoop update helper in a classic console (conhost) under Windows
REM PowerShell 5.1, detached from the caller. conhost.exe bypasses the Windows 11
REM "default terminal application" setting (which would otherwise reopen inside
REM Windows Terminal and lock it); powershell.exe (5.1) leaves pwsh.exe unlocked.
REM Both are required so the helper can update pwsh and Windows Terminal.
REM The profile is loaded on purpose (no -NoProfile): on corporate machines the
REM user profile injects proxy configuration (setProxy.ps1) that Scoop needs to
REM reach the internet.
start "Scoop Update" conhost.exe powershell.exe -ExecutionPolicy Bypass -File "%~dp0update-scoop.ps1" %*
