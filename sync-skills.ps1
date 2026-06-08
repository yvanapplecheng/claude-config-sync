# sync-skills.ps1 — Pull all cloned skills in ~/.claude/skills/
# Run manually or via Windows Task Scheduler / Claude Code hook
$skillsDir = "$env:USERPROFILE\.claude\skills"
if (-not (Test-Path $skillsDir)) {
    Write-Host "No skills directory found. Skipping."
    exit 0
}
Get-ChildItem $skillsDir -Directory | ForEach-Object {
    $gitDir = Join-Path $_.FullName ".git"
    if (Test-Path $gitDir) {
        Write-Host "Pulling $($_.Name)..."
        git -C $_.FullName pull --rebase 2>&1 | Write-Host
    } else {
        Write-Host "Skipping $($_.Name) — not a git repo"
    }
}
Write-Host "Skills sync done."
