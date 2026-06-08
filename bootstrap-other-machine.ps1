# bootstrap-other-machine.ps1 — Run ONCE on new machine to join the sync
# This script lives in the sync repo. After git clone, run this.
$ErrorActionPreference = "Continue"

Write-Host "=== Claude Code Sync Bootstrap ==="
Write-Host ""

$syncDir = "$env:USERPROFILE\.claude"

# 1. Add marketplaces (idempotent)
Write-Host "[1/4] Adding plugin marketplaces..."
claude plugin marketplace add https://github.com/anthropics/claude-plugins-official.git 2>$null
claude plugin marketplace add https://github.com/anthropics/skills.git 2>$null
claude plugin marketplace add https://github.com/JuliusBrussee/caveman.git 2>$null

# 2. Install plugins (idempotent)
Write-Host "[2/4] Installing plugins..."
claude plugin install claude-md-management@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official
claude plugin install github@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
claude plugin install document-skills@anthropic-agent-skills
claude plugin install caveman@caveman

# 3. Clone standalone skills
Write-Host "[3/4] Cloning skills..."
if (-not (Test-Path "$syncDir\skills\humanizer-zh")) {
    git clone https://github.com/anthropic-skills/humanizer-zh.git $syncDir\skills\humanizer-zh
}
if (-not (Test-Path "$syncDir\skills\code-review-graph")) {
    git clone https://github.com/anthropic-skills/code-review-graph.git $syncDir\skills\code-review-graph
}

# 4. Pull everything fresh
Write-Host "[4/4] Pulling latest config..."
& "$syncDir\config-sync.ps1"

Write-Host ""
Write-Host "=== Bootstrap complete ==="
Write-Host "Next: copy clawd-prefs.json from main machine to %APPDATA%\clawd-on-desk\"
Write-Host "Next: configure ~/.claude.json with MiniMax MCP (copy API key from main machine)"
Write-Host "Next: add SessionStart hook to ~/.claude/settings.json for auto-pull"
