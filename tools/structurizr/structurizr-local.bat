@echo off
pwsh -ExecutionPolicy Bypass -File "%~dp0structurizr-local.ps1" %* || exit /b 1
