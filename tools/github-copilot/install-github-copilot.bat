powershell -ExecutionPolicy Bypass -File %~dp0..\..\lib\install\install-npm-global.ps1 -PackageName "@github/copilot" -CheckCommand "copilot" || exit /b 1
