@echo off
pwsh -ExecutionPolicy Bypass -File "%~dp0px-proxy.ps1" %* || exit /b 1
