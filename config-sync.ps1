# config-sync.ps1 — Auto-pull Claude config repo + skills + plugins on startup
# Hooked via SessionStart in ~/.claude/settings.json
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"

# 1. Pull config repo (CLAUDE.md + memory + scripts + manifest)
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

# 2. Install missing plugins/skills from manifest (merges cross-machine)
$manifestPath = "$syncDir\plugin-skill-manifest.json"
if (Test-Path $manifestPath) {
    try {
        & "$syncDir\sync-plugins-skills.ps1" 2>&1 | Write-Output
    } catch {
        Write-Output "[sync] plugin/skill sync error: $_"
    }
} else {
    Write-Output "[sync] no manifest — run export-plugins-skills.ps1 first"
}

# 3. Pull each installed skill repo for updates
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
