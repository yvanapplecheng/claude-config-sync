# config-sync.ps1 — Auto-pull Claude config repo + skills on startup
# Hooked via SessionStart in ~/.claude/settings.json
# This script lives in the sync repo itself — updates propagate automatically
$ErrorActionPreference = "Stop"
$syncDir = "$env:USERPROFILE\.claude"

# 1. Pull config repo (CLAUDE.md + memory + scripts)
if (Test-Path "$syncDir\.git") {
    try {
        $result = git -C $syncDir pull --rebase 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "[sync] config repo: $result"
        } else {
            Write-Output "[sync] config repo pull failed: $result"
        }
    } catch {
        Write-Output "[sync] config repo error: $_"
    }
} else {
    Write-Output "[sync] no .git in $syncDir — skipping config pull"
}

# 2. Pull each skill repo
$skillsDir = "$syncDir\skills"
if (Test-Path $skillsDir) {
    Get-ChildItem $skillsDir -Directory | ForEach-Object {
        $gitDir = Join-Path $_.FullName ".git"
        if (Test-Path $gitDir) {
            try {
                $result = git -C $_.FullName pull --rebase 2>&1
                Write-Output "[sync] skills/$($_.Name): $result"
            } catch {
                Write-Output "[sync] skills/$($_.Name) error: $_"
            }
        }
    }
}
Write-Output "[sync] done"
