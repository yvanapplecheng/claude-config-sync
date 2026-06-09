@echo off
setlocal enabledelayedexpansion
set "SYNCDIR=%USERPROFILE%\.claude"
set "REPO=https://github.com/yvanapplecheng/claude-config-sync.git"

echo ============================================
echo   Claude-Sync v5
echo ============================================

:: ── 1. Clone ──
echo.
echo [1/4] Cloning...
set "TEMPREPO=%TEMP%\csync-%RANDOM%"
git clone %REPO% "%TEMPREPO%"
if errorlevel 1 (
    echo FAIL: clone
    pause
    exit /b 1
)
echo OK

:: ── 2. Copy + move .git ──
echo [2/4] Copying...
if not exist "%SYNCDIR%" mkdir "%SYNCDIR%"
xcopy "%TEMPREPO%\*" "%SYNCDIR%\" /E /Y /Q
:: Move .git — only delete old one if it exists
if exist "%SYNCDIR%\.git" rmdir /S /Q "%SYNCDIR%\.git" 2>nul
move "%TEMPREPO%\.git" "%SYNCDIR%\" >nul 2>&1
if errorlevel 1 (
    echo WARNING: .git move failed - trying xcopy fallback
    xcopy "%TEMPREPO%\.git" "%SYNCDIR%\.git\" /E /Y /Q /H >nul 2>&1
)
rmdir /S /Q "%TEMPREPO%" 2>nul
echo OK

:: ── 3. Skills ──
echo [3/4] Skills...
if not exist "%SYNCDIR%\skills" mkdir "%SYNCDIR%\skills"

:: humanizer-zh
if exist "%SYNCDIR%\skills\humanizer-zh" rmdir /S /Q "%SYNCDIR%\skills\humanizer-zh" 2>nul
git clone https://github.com/anthropic-skills/humanizer-zh.git "%SYNCDIR%\skills\humanizer-zh" 2>&1
if errorlevel 1 echo   humanizer-zh: clone failed else echo   humanizer-zh: OK

:: code-review-graph — install via pip, not git clone
echo   code-review-graph: installing via pip...
pip install code-review-graph 2>&1
if errorlevel 1 (
    echo   code-review-graph: pip install failed - skipping
) else (
    code-review-graph install --platform claude-code 2>&1
    echo   code-review-graph: OK
)

echo OK

:: ── 4. Verify ──
echo [4/4] Verify
echo.
echo --- Remote ---
git -C "%SYNCDIR%" remote -v 2>&1
echo.
echo --- Branch ---
git -C "%SYNCDIR%" branch 2>&1
echo.
echo --- Files ---
dir "%SYNCDIR%\CLAUDE.md" "%SYNCDIR%\config-sync.ps1" "%SYNCDIR%\plugin-skill-manifest.json" 2>&1

echo.
echo ============================================
echo DONE
echo ============================================
pause
