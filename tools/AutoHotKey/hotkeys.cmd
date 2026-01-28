@echo off

set "THIS_DIR=%~dp0"
start "" AutoHotkey.exe "%THIS_DIR%hotkeys.ahk" || pause
