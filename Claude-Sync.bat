@echo off
set "ZIP=https://github.com/yvanapplecheng/claude-config-sync/archive/refs/heads/master.zip"
set "SYNCDIR=%USERPROFILE%\.claude"

echo ============================================
echo   Claude Sync vFinal
echo ============================================
echo.

echo [1/2] Downloading...
powershell -Command "Invoke-WebRequest -Uri '%ZIP%' -OutFile '%TEMP%\claude-sync.zip'" 2>nul
if not exist "%TEMP%\claude-sync.zip" (
    echo FAIL: no internet or GitHub blocked
    pause
    exit /b 1
)
echo OK

echo [2/2] Installing...
:: backup local files
if exist "%SYNCDIR%\settings.json" copy /Y "%SYNCDIR%\settings.json" "%SYNCDIR%\settings.json.bak" >nul
if exist "%SYNCDIR%\settings.local.json" copy /Y "%SYNCDIR%\settings.local.json" "%SYNCDIR%\settings.local.json.bak" >nul
:: extract
if exist "%TEMP%\claude-sync-extract" rmdir /S /Q "%TEMP%\claude-sync-extract" >nul 2>&1
powershell -Command "Expand-Archive -Path '%TEMP%\claude-sync.zip' -DestinationPath '%TEMP%\claude-sync-extract' -Force" 2>nul
del "%TEMP%\claude-sync.zip" >nul
:: copy files (skip .git folder — not needed for one-shot sync)
if not exist "%SYNCDIR%" mkdir "%SYNCDIR%"
xcopy "%TEMP%\claude-sync-extract\claude-config-sync-master\*" "%SYNCDIR%\" /E /Y /Q
rmdir /S /Q "%TEMP%\claude-sync-extract" >nul 2>&1
:: restore local files
if exist "%SYNCDIR%\settings.json.bak" move /Y "%SYNCDIR%\settings.json.bak" "%SYNCDIR%\settings.json" >nul
if exist "%SYNCDIR%\settings.local.json.bak" move /Y "%SYNCDIR%\settings.local.json.bak" "%SYNCDIR%\settings.local.json" >nul

echo OK
echo.
echo Files installed:
dir "%SYNCDIR%\CLAUDE.md" /B 2>&1
dir "%SYNCDIR%\plugin-skill-manifest.json" /B 2>&1
dir "%SYNCDIR%\config-sync.ps1" /B 2>&1
dir "%SYNCDIR%\projects\C--Users-10268\memory" /B 2>&1

echo.
echo ============================================
echo   DONE, Master.
echo ============================================
pause
