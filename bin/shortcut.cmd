@ECHO OFF

if "%1"=="" (
   exit /b 1
) else (
   set "SOURCE=%1"
)

if "%2"=="" (
   set "TARGET_PATH=%USERPROFILE%\Start Menu\Programs\Startup"
) else (
   set "TARGET_PATH=%2"
)

mkdir "%TARGET_PATH%"

FOR %%i IN ("%SOURCE%") DO (
   set "SOURCE_FULL_PATH=%%~fi"
   set "SOURCE_DRIVE=%%~di"
   set "SOURCE_PATH=%%~pi"
   set "SOURCE_NAME=%%~ni"
   set "SOURCE_EXTENSION=%%~xi"
)

powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%TARGET_PATH%\%SOURCE_NAME%.lnk');$s.TargetPath='%SOURCE_FULL_PATH%';$s.Save()" || exit /b 1
