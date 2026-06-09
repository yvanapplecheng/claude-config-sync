# config-sync.ps1 — Auto-pull Claude config repo + skills + plugins on startup
# Hooked via SessionStart in ~/.claude/settings.json
# Writes to sync.log for cross-machine verification
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"
$logFile = "$syncDir\sync.log"
$remoteUrl = "https://github.com/yvanapplecheng/claude-config-sync.git"

# Timestamp log header
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logLines = @()
$logLines += "=== sync $now ==="

# 0. Auto-init .git if missing (zip-bootstrap scenario)
if (-not (Test-Path "$syncDir\.git")) {
    try {
        git -C $syncDir init 2>&1 | Out-Null
        git -C $syncDir remote add origin $remoteUrl 2>&1 | Out-Null
        git -C $syncDir fetch origin master 2>&1 | Out-Null
        git -C $syncDir branch -M master 2>&1 | Out-Null
        git -C $syncDir reset --hard origin/master 2>&1 | Out-Null
        $logLines += "[init] .git created, synced from remote"
    } catch {
        $logLines += "[init] ERROR: $_"
    }
}

# 1. Pull config repo (CLAUDE.md + memory + scripts + manifest)
if (Test-Path "$syncDir\.git") {
    try {
        $result = git -C $syncDir pull --rebase origin master 2>&1
        if ($LASTEXITCODE -eq 0) {
            $logLines += "[pull] $result"
        } else {
            $logLines += "[pull] FAIL: $result"
        }
    } catch {
        $logLines += "[pull] ERROR: $_"
    }
} else {
    $logLines += "[pull] SKIP: no .git"
}


# 2. Install missing plugins/skills from manifest (merges cross-machine)
$manifestPath = "$syncDir\plugin-skill-manifest.json"
if (Test-Path $manifestPath) {
    try {
        $syncResult = & "$syncDir\sync-plugins-skills.ps1" 2>&1
        $logLines += $syncResult
    } catch {
        $logLines += "[sync-plugins] ERROR: $_"
    }
} else {
    $logLines += "[sync-plugins] SKIP: no manifest"
}

# 3. Pull each installed skill repo for updates
$skillsDir = "$syncDir\skills"
if (Test-Path $skillsDir) {
    Get-ChildItem $skillsDir -Directory | ForEach-Object {
        $gitDir = Join-Path $_.FullName ".git"
        if (Test-Path $gitDir) {
            try {
                $result = git -C $_.FullName pull --rebase 2>&1
                $logLines += "[skill:$($_.Name)] $result"
            } catch {
                $logLines += "[skill:$($_.Name)] ERROR: $_"
            }
        }
    }
}

$logLines += "[done]"
# Write log
$logLines | Out-File -Encoding utf8 $logFile
