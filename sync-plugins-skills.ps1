# sync-plugins-skills.ps1 — Read manifest, install missing plugins + skills on THIS machine
$ErrorActionPreference = "Continue"
$syncDir = "$env:USERPROFILE\.claude"
$manifestPath = "$syncDir\plugin-skill-manifest.json"

if (-not (Test-Path $manifestPath)) {
    Write-Host "[sync-plugins] No manifest found." -ForegroundColor Red
    exit 1
}

$manifest = Get-Content $manifestPath | ConvertFrom-Json

# --- 1. Add marketplaces ---
Write-Host "[sync-plugins] Marketplaces..." -ForegroundColor Yellow
foreach ($mp in $manifest.marketplaces) {
    claude plugin marketplace add $mp.url 2>$null
    Write-Host "  ok: $($mp.name)" -ForegroundColor Green
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
Write-Host "[sync-plugins] Plugins..." -ForegroundColor Yellow
foreach ($plugin in $manifest.plugins) {
    if (-not $currentPlugins.ContainsKey($plugin)) {
        Write-Host "  installing: $plugin" -ForegroundColor Magenta
        claude plugin install $plugin 2>&1 | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "  ok: $plugin" -ForegroundColor Green
    }
}

# --- 4. Clone/update skills ---
Write-Host "[sync-plugins] Skills..." -ForegroundColor Yellow
$skillsDir = "$syncDir\skills"
if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Force $skillsDir | Out-Null }

foreach ($skill in $manifest.skills) {
    $target = Join-Path $skillsDir $skill.name

    # Handle pip: prefix
    if ($skill.url -match '^pip:(.+)$') {
        $pkg = $Matches[1]
        $pipResult = pip install $pkg --disable-pip-version-check 2>&1
        $statusLine = ($pipResult | Select-String "Requirement already satisfied: $pkg|Successfully installed $pkg|Installing collected packages: $pkg" | Select-Object -First 1)
        if ($statusLine) {
            Write-Host "  ok: $pkg ($($statusLine.Line.Trim()))" -ForegroundColor Green
        } elseif ($LASTEXITCODE -ne 0) {
            $errLine = ($pipResult | Select-String "ERROR|error" | Select-Object -Last 1)
            Write-Host "  FAIL: $pkg — $errLine" -ForegroundColor Red
        } else {
            Write-Host "  ok: $pkg" -ForegroundColor Green
        }
        continue
    }

    if (Test-Path $target) {
        if (Test-Path (Join-Path $target ".git")) {
            git -C $target pull --rebase 2>&1 | ForEach-Object { Write-Host $_ }
        }
        Write-Host "  ok: $($skill.name)" -ForegroundColor Green
    } else {
        Write-Host "  cloning: $($skill.name) <- $($skill.url)" -ForegroundColor Magenta
        git clone $skill.url $target 2>&1 | ForEach-Object { Write-Host $_ }
    }
}

Write-Host "[sync-plugins] Done." -ForegroundColor Yellow
