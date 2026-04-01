@echo off
pwsh -ExecutionPolicy Bypass -File %~dp0install-claude-code.ps1 || exit /b 1
