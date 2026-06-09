# sync-plugins-skills.ps1 — Read manifest, install missing plugins + skills on THIS machine
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"
$manifestPath = "$syncDir\plugin-skill-manifest.json"

if (-not (Test-Path $manifestPath)) {
    Write-Output "[sync-plugins] No manifest found."
    exit 1
}

$manifest = Get-Content $manifestPath | ConvertFrom-Json

# --- 1. Add marketplaces ---
Write-Output "[sync-plugins] Marketplaces..."
foreach ($mp in $manifest.marketplaces) {
    claude plugin marketplace add $mp.url 2>$null
    Write-Output "  ok: $($mp.name)"
}

# --- 2. Read currently installed plugins from settings ---
$currentPlugins = @{}
$settingsPath = "$syncDir\settings.json"
$settingsLocalPath = "$syncDir\settings.local.json"
$curJson = @{}
if (Test-Path $settingsPath) { try { $curJson = Get-Content $settingsPath | ConvertFrom-Json } catch {} }
if (Test-Path $settingsLocalPath) {
    try { $localJson = Get-Content $settingsLocalPath | ConvertFrom-Json } catch {}
    if ($localJson -and $localJson.enabledPlugins) { $curJson.enabledPlugins = $localJson.enabledPlugins }
}
if ($curJson.enabledPlugins) {
    $curJson.enabledPlugins.PSObject.Properties | ForEach-Object {
        if ($_.Value) { $currentPlugins[$_.Name] = $true }
    }
}

# --- 3. Install missing plugins ---
Write-Output "[sync-plugins] Plugins..."
foreach ($plugin in $manifest.plugins) {
    if (-not $currentPlugins.ContainsKey($plugin)) {
        Write-Output "  installing: $plugin"
        claude plugin install $plugin 2>&1 | Write-Output
    } else {
        Write-Output "  ok: $plugin"
    }
}

# --- 4. Clone/update skills ---
Write-Output "[sync-plugins] Skills..."
$skillsDir = "$syncDir\skills"
if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Force $skillsDir | Out-Null }

foreach ($skill in $manifest.skills) {
    $target = Join-Path $skillsDir $skill.name

    # Handle pip: prefix
    if ($skill.url -match '^pip:(.+)$') {
        $pkg = $Matches[1]
        Write-Output "  pip install: $pkg"
        $pipResult = pip install $pkg --disable-pip-version-check 2>&1
        $statusLine = ($pipResult | Select-String "Requirement already satisfied: $pkg|Successfully installed $pkg|Installing collected packages: $pkg" | Select-Object -First 1)
        if ($statusLine) {
            Write-Output "  ok: $pkg ($($statusLine.Line.Trim()))"
        } elseif ($LASTEXITCODE -ne 0) {
            $errLine = ($pipResult | Select-String "ERROR|error" | Select-Object -Last 1)
            Write-Output "  FAIL: $pkg — $errLine"
        } else {
            Write-Output "  ok: $pkg"
        }
        continue
    }

    if (Test-Path $target) {
        if (Test-Path (Join-Path $target ".git")) {
            git -C $target pull --rebase 2>&1 | Write-Output
        }
        Write-Output "  ok: $($skill.name)"
    } else {
        Write-Output "  cloning: $($skill.name) <- $($skill.url)"
        git clone $skill.url $target 2>&1 | Write-Output
    }
}

Write-Output "[sync-plugins] Done."
