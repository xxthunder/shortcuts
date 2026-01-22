@echo off
pwsh -ExecutionPolicy Bypass -File %~dp0install-npm-global.ps1 %* || exit /b 1
