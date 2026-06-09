# install-clawd.ps1 — Bootstrap Clawd desktop pet on this machine
# Called by Claude-Sync.bat as optional step
param($SyncDir = "$env:USERPROFILE\.claude")

$clawdRepo = "https://github.com/JuliusBrussee/clawd-on-desk.git"
$clawdDir = "$env:USERPROFILE\clawd-on-desk-main"
$clawdConfigDir = "$env:APPDATA\clawd-on-desk"
$prefsSrc = "$SyncDir\templates\clawd-prefs.json"

Write-Host "[Clawd] Installing..."

# 1. Clone repo
if (Test-Path $clawdDir) {
    Write-Host "  [skip] clawd repo exists — pulling..."
    git -C $clawdDir -c http.sslVerify=false pull --rebase 2>&1 | Out-Null
} else {
    Write-Host "  cloning clawd-on-desk..."
    git -c http.sslVerify=false clone $clawdRepo $clawdDir 2>&1
    if (-not (Test-Path $clawdDir)) {
        Write-Host "  [FAIL] Clone failed. Try manual: git -c http.sslVerify=false clone $clawdRepo $clawdDir"
        exit 1
    }
}

# 2. npm install
if (-not (Test-Path "$clawdDir\node_modules")) {
    Write-Host "  npm install..."
    cd $clawdDir
    npm install 2>&1 | Out-Null
}

# 3. Copy prefs template (user should adjust position after launch)
if (Test-Path $prefsSrc) {
    New-Item -ItemType Directory -Force $clawdConfigDir | Out-Null
    if (-not (Test-Path "$clawdConfigDir\clawd-prefs.json")) {
        Copy-Item $prefsSrc $clawdConfigDir\ -Force
        Write-Host "  prefs copied from template (adjust position after launch)"
    } else {
        Write-Host "  prefs already exist — skipped"
    }
} else {
    Write-Host "  [warn] No clawd prefs template found — will use defaults"
}

# 4. Register Claude Code hooks
Write-Host "  registering hooks..."
cd $clawdDir
npm run install:claude-hooks 2>&1 | Out-Null

# 5. Launch
Write-Host "  launching..."
Start-Process "node" -ArgumentList "launch.js" -WorkingDirectory $clawdDir -WindowStyle Hidden

Write-Host "[Clawd] Done. Pet on desktop."
