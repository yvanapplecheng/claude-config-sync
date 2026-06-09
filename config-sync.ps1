# config-sync.ps1 — Auto-pull Claude config repo + skills + plugins on startup
# Hooked via SessionStart in ~/.claude/settings.json
# Writes status.json for cross-machine dashboard
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"
$logFile = "$syncDir\sync.log"
$statusFile = "$syncDir\status.json"
$remoteUrl = "https://github.com/yvanapplecheng/claude-config-sync.git"

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$status = @{
    machine = $env:COMPUTERNAME
    lastSync = $now
    ok = $true
    errors = @()
}

# 0. Auto-init .git if missing
if (-not (Test-Path "$syncDir\.git")) {
    try {
        git -C $syncDir init 2>&1 | Out-Null
        git -C $syncDir remote add origin $remoteUrl 2>&1 | Out-Null
        git -C $syncDir fetch origin master 2>&1 | Out-Null
        git -C $syncDir branch -M master 2>&1 | Out-Null
        git -C $syncDir reset --hard origin/master 2>&1 | Out-Null
        $status.init = "ok"
    } catch {
        $status.init = "FAIL"
        $status.errors += "init"
    }
} else { $status.init = "already" }

# 1. Pull config repo
if (Test-Path "$syncDir\.git") {
    try {
        $result = git -C $syncDir pull --rebase origin master 2>&1
        if ($LASTEXITCODE -eq 0) {
            $status.pull = if ($result -match 'Already up to date') { "unchanged" } else { "updated" }
        } else {
            $status.pull = "FAIL"
            $status.errors += "pull"
        }
    } catch {
        $status.pull = "ERROR"
        $status.errors += "pull"
    }
} else { $status.pull = "no-.git" }

# 2. CLAUDE.md + Memory
$status.claudeMd = Test-Path "$syncDir\CLAUDE.md"
$status.memory = Test-Path "$syncDir\projects\C--Users-10268\memory\MEMORY.md"

# 3. Plugins count
try {
    $settings = Get-Content "$syncDir\settings.json" -Raw | ConvertFrom-Json
    $plugCount = 0
    if ($settings.enabledPlugins) {
        $settings.enabledPlugins.PSObject.Properties | ForEach-Object { if ($_.Value) { $plugCount++ } }
    }
    $status.plugins = $plugCount
} catch { $status.plugins = 0 }

# 4. Skills count (standalone only for status)
if (Test-Path "$syncDir\skills") {
    $status.skills = (Get-ChildItem "$syncDir\skills" -Directory -ErrorAction SilentlyContinue).Count
} else { $status.skills = 0 }

# 5. Clawd pet
$clawdDir = "$env:USERPROFILE\clawd-on-desk-main"
$clawdPrefs = "$env:APPDATA\clawd-on-desk\clawd-prefs.json"
$status.clawdInstalled = (Test-Path $clawdDir)
$status.clawdRunning = (Get-Process "electron" -ErrorAction SilentlyContinue | Measure-Object).Count -ge 2

# 6. Hook
$status.hook = $false
try {
    $j = Get-Content "$syncDir\settings.json" -Raw | ConvertFrom-Json
    foreach ($entry in $j.hooks.SessionStart) {
        foreach ($h in $entry.hooks) {
            if ($h.command -match 'config-sync') { $status.hook = $true }
        }
    }
} catch {}

# 7. Manifest sync
$manifestPath = "$syncDir\plugin-skill-manifest.json"
if (Test-Path $manifestPath) {
    try {
        & "$syncDir\sync-plugins-skills.ps1" 2>&1 | Out-Null
        $status.manifestSync = "ok"
    } catch {
        $status.manifestSync = "ERROR"
    }
} else { $status.manifestSync = "no-manifest" }

# Refresh skill count
if (Test-Path "$syncDir\skills") {
    $status.skills = (Get-ChildItem "$syncDir\skills" -Directory -ErrorAction SilentlyContinue).Count
}

# Pull standalone skill repos
if (Test-Path "$syncDir\skills") {
    Get-ChildItem "$syncDir\skills" -Directory | ForEach-Object {
        $gitDir = Join-Path $_.FullName ".git"
        if (Test-Path $gitDir) {
            try { git -C $_.FullName pull --rebase 2>&1 | Out-Null } catch {}
        }
    }
}

$status.errors = ($status.errors -join ",")
$status.ok = ([string]$status.errors).Length -eq 0
$status | ConvertTo-Json -Depth 3 | Out-File -Encoding utf8 $statusFile

# Also write machine-named file for cross-machine comparison
$machineFile = "$syncDir\status-$($env:COMPUTERNAME).json"
$status | ConvertTo-Json -Depth 3 | Out-File -Encoding utf8 $machineFile
