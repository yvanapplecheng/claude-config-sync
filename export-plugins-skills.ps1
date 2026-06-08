# export-plugins-skills.ps1 — Scan THIS machine's plugins + skills, merge into manifest
# Run on any machine that has new stuff. Commit + push manifest afterward.
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"
$manifestPath = "$syncDir\plugin-skill-manifest.json"

$manifest = @{
    marketplaces = @()
    plugins = @()
    skills = @()
}

# --- 1. Read current enabled plugins from settings ---
$settingsPath = "$syncDir\settings.json"
$settingsLocalPath = "$syncDir\settings.local.json"
$curJson = @{}
if (Test-Path $settingsPath) { $curJson = Get-Content $settingsPath | ConvertFrom-Json }
if (Test-Path $settingsLocalPath) {
    $localJson = Get-Content $settingsLocalPath | ConvertFrom-Json
    if ($localJson.enabledPlugins) { $curJson.enabledPlugins = $localJson.enabledPlugins }
}
if ($curJson.enabledPlugins) {
    $curJson.enabledPlugins.PSObject.Properties | ForEach-Object {
        if ($_.Value) { $manifest.plugins += $_.Name }
    }
}

# --- 2. Read marketplaces ---
if ($curJson.extraKnownMarketplaces) {
    $curJson.extraKnownMarketplaces.PSObject.Properties | ForEach-Object {
        $manifest.marketplaces += @{ name = $_.Name; url = $_.Value.source.url }
    }
}
# Official marketplaces (always needed)
$manifest.marketplaces += @{ name = "claude-plugins-official"; url = "https://github.com/anthropics/claude-plugins-official.git" }
$manifest.marketplaces += @{ name = "anthropic-agent-skills"; url = "https://github.com/anthropics/skills.git" }

# --- 3. Read skills from ~/.claude/skills ---
$skillsDir = "$syncDir\skills"
if (Test-Path $skillsDir) {
    Get-ChildItem $skillsDir -Directory | ForEach-Object {
        $remote = ""
        $gitDir = Join-Path $_.FullName ".git"
        if (Test-Path $gitDir) {
            try { $remote = (git -C $_.FullName remote get-url origin 2>&1) -join "" } catch {}
        }
        $manifest.skills += @{ name = $_.Name; url = $remote }
    }
}

# --- 4. Merge with existing manifest if any ---
if (Test-Path $manifestPath) {
    $existing = Get-Content $manifestPath | ConvertFrom-Json
    # Merge plugins (union, keep existing order, append new)
    $existingPlugins = @{}; $existing.plugins | ForEach-Object { $existingPlugins[$_] = $true }
    $manifest.plugins | ForEach-Object { if (-not $existingPlugins[$_]) { $existing.plugins += $_ } }
    $manifest.plugins = $existing.plugins

    # Merge skills (union by name)
    $existingSkillNames = @{}; $existing.skills | ForEach-Object { $existingSkillNames[$_.name] = $true }
    $manifest.skills | ForEach-Object { if (-not $existingSkillNames[$_.name]) { $existing.skills += $_ } }
    $manifest.skills = $existing.skills

    # Merge marketplaces (union by name)
    $existingMpNames = @{}; $existing.marketplaces | ForEach-Object { $existingMpNames[$_.name] = $true }
    $manifest.marketplaces | ForEach-Object { if (-not $existingMpNames[$_.name]) { $existing.marketplaces += $_ } }
    $manifest.marketplaces = $existing.marketplaces
}

# --- 5. Write ---
$manifest | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 $manifestPath
Write-Output "[export-plugins-skills] Manifest written to $manifestPath"
Write-Output "  marketplaces: $($manifest.marketplaces.Count)"
Write-Output "  plugins: $($manifest.plugins.Count)"
Write-Output "  skills: $($manifest.skills.Count)"
