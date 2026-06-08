# sync-plugins-skills.ps1 — Read manifest, install missing plugins + skills on THIS machine
# Also merges machine's current plugins/skills back into manifest for cross-machine sync
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"
$manifestPath = "$syncDir\plugin-skill-manifest.json"

if (-not (Test-Path $manifestPath)) {
    Write-Output "[sync-plugins] No manifest found. Run --export first."
    exit 1
}

$manifest = Get-Content $manifestPath | ConvertFrom-Json

# --- 1. Add marketplaces ---
Write-Output "[sync-plugins] Adding marketplaces..."
foreach ($mp in $manifest.marketplaces) {
    claude plugin marketplace add $mp.url 2>$null
    Write-Output "  marketplace: $($mp.name)"
}

# --- 2. Install missing plugins ---
Write-Output "[sync-plugins] Installing missing plugins..."
# Read currently installed plugins from settings
$currentPlugins = @{}
$settingsPath = "$syncDir\settings.json"
$settingsLocalPath = "$syncDir\settings.local.json"
$curJson = @{}
if (Test-Path $settingsPath) { $curJson = Get-Content $settingsPath | ConvertFrom-Json }
if (Test-Path $settingsLocalPath) {
    $localJson = Get-Content $settingsLocalPath | ConvertFrom-Json
    # simple merge — local overrides
    if ($localJson.enabledPlugins) { $curJson.enabledPlugins = $localJson.enabledPlugins }
}
if ($curJson.enabledPlugins) {
    $curJson.enabledPlugins.PSObject.Properties | ForEach-Object {
        if ($_.Value) { $currentPlugins[$_.Name] = $true }
    }
}

foreach ($plugin in $manifest.plugins) {
    if (-not $currentPlugins.ContainsKey($plugin)) {
        Write-Output "  installing: $plugin"
        claude plugin install $plugin 2>&1 | Write-Output
    } else {
        Write-Output "  already installed: $plugin"
    }
}

# --- 3. Clone missing skills ---
Write-Output "[sync-plugins] Cloning missing skills..."
$skillsDir = "$syncDir\skills"
foreach ($skill in $manifest.skills) {
    $target = Join-Path $skillsDir $skill.name
    if (Test-Path $target) {
        # Already exists — pull if git
        if (Test-Path (Join-Path $target ".git")) {
            git -C $target pull --rebase 2>&1 | Write-Output
        }
        Write-Output "  exists: $($skill.name)"
    } else {
        Write-Output "  cloning: $($skill.name) <- $($skill.url)"
        git clone $skill.url $target 2>&1 | Write-Output
    }
}

Write-Output "[sync-plugins] Done. Run with --export on each machine to merge new additions."
