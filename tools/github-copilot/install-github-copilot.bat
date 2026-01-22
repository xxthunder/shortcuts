@echo off
pwsh -ExecutionPolicy Bypass -File %~dp0..\install\install-npm-global.ps1 -PackageName "@github/copilot" -CheckCommand "copilot" || exit /b 1
