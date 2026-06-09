# sync-status.ps1 — Unified cross-machine sync checklist
# Run: powershell -ExecutionPolicy Bypass -File sync-status.ps1
param(
    [switch]$Quiet  # -Quiet returns exit code only (0=OK, 1=stale)
)

$syncDir = "$env:USERPROFILE\.claude"
$errors = 0

# === HEADER ===
$hostname = $env:COMPUTERNAME
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Claude Sync Status — $hostname" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# === 1. CLAUDE.md ===
Write-Host "`n--- Core Config ---" -ForegroundColor Yellow
$claudeMd = "$syncDir\CLAUDE.md"
if (Test-Path $claudeMd) {
    $size = (Get-Item $claudeMd).Length
    $mtime = (Get-Item $claudeMd).LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    Write-Host "  [OK] CLAUDE.md ($size bytes, $mtime)"
} else {
    Write-Host "  [!!] CLAUDE.md MISSING" -ForegroundColor Red
    $errors++
}

# === 2. Memory files ===
Write-Host "`n--- Memory ---" -ForegroundColor Yellow
$memDir = "$syncDir\projects\C--Users-10268\memory"
if (Test-Path "$memDir\MEMORY.md") {
    $count = (Get-ChildItem $memDir -Filter "*.md" | Measure-Object).Count
    Write-Host "  [OK] Memory: $count files"
    Get-ChildItem $memDir -Filter "*.md" | ForEach-Object {
        $mt = $_.LastWriteTime.ToString("MM-dd HH:mm")
        Write-Host "       $($_.Name) ($mt)"
    }
} else {
    Write-Host "  [!!] MEMORY.md MISSING" -ForegroundColor Red
    $errors++
}

# === 3. Scripts ===
Write-Host "`n--- Scripts ---" -ForegroundColor Yellow
@("config-sync.ps1", "sync-plugins-skills.ps1", "export-plugins-skills.ps1", "install-sync-hook.ps1", "sync-status.ps1") | ForEach-Object {
    $p = "$syncDir\$_"
    if (Test-Path $p) { Write-Host "  [OK] $_" } else { Write-Host "  [--] $_ (missing)" -ForegroundColor DarkGray }
}

# === 4. Manifest ===
Write-Host "`n--- Manifest ---" -ForegroundColor Yellow
$manifestPath = "$syncDir\plugin-skill-manifest.json"
if (Test-Path $manifestPath) {
    $m = Get-Content $manifestPath | ConvertFrom-Json
    Write-Host "  [OK] manifest: $($m.plugins.Count) plugins, $($m.skills.Count) skills, $($m.marketplaces.Count) marketplaces"
} else {
    Write-Host "  [!!] manifest MISSING" -ForegroundColor Red
    $errors++
}

# === 5. Plugins (enabled) ===
Write-Host "`n--- Plugins ---" -ForegroundColor Yellow
$settingsPath = "$syncDir\settings.json"
$settingsLocalPath = "$syncDir\settings.local.json"
$curJson = @{}
if (Test-Path $settingsPath) { try { $curJson = Get-Content $settingsPath | ConvertFrom-Json } catch {} }
if (Test-Path $settingsLocalPath) {
    try { $localJson = Get-Content $settingsLocalPath | ConvertFrom-Json } catch {}
    if ($localJson -and $localJson.enabledPlugins) { $curJson.enabledPlugins = $localJson.enabledPlugins }
}
if ($curJson.enabledPlugins) {
    $count = 0
    $curJson.enabledPlugins.PSObject.Properties | ForEach-Object {
        if ($_.Value) { Write-Host "  [ON] $($_.Name)"; $count++ }
    }
    Write-Host "  Total: $count enabled"
} else {
    Write-Host "  [--] No enabledPlugins found"
}

# === 6. Skills ===
Write-Host "`n--- Skills ---" -ForegroundColor Yellow

# Collect all skill names from all sources
$allSkills = @{}

# 6a. Standalone skills (~/.claude/skills/)
$skillsDir = "$syncDir\skills"
if (Test-Path $skillsDir) {
    Get-ChildItem $skillsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $allSkills[$_.Name] = "standalone"
    }
}

# 6b. Plugin-provided skills (~/.claude/plugins/marketplaces/*/skills/)
$mpSkillsDir = "$syncDir\plugins\marketplaces"
if (Test-Path $mpSkillsDir) {
    Get-ChildItem $mpSkillsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $mpSkills = Join-Path $_.FullName "skills"
        if (Test-Path $mpSkills) {
            Get-ChildItem $mpSkills -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not $allSkills.ContainsKey($_.Name)) {
                    $allSkills[$_.Name] = "plugin:$($_.Parent.Parent.Name)"
                }
            }
        }
    }
}

# 6c. Skills from installed plugins cache (~/.claude/plugins/cache/*/plugins/*/skills/)
$cacheDir = "$syncDir\plugins\cache"
if (Test-Path $cacheDir) {
    Get-ChildItem $cacheDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $ps = Join-Path $_.FullName "skills"
            if (Test-Path $ps) {
                Get-ChildItem $ps -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    if (-not $allSkills.ContainsKey($_.Name)) {
                        $allSkills[$_.Name] = "plugin"
                    }
                }
            }
        }
    }
}

# 6d. ECC plugin skills (~/.claude/plugins/ecc/skills/)
if (Test-Path "$syncDir\plugins\ecc\skills") {
    Get-ChildItem "$syncDir\plugins\ecc\skills" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $allSkills.ContainsKey($_.Name)) {
            $allSkills[$_.Name] = "plugin:ecc"
        }
    }
}

$standaloneCount = ($allSkills.GetEnumerator() | Where-Object { $_.Value -eq "standalone" } | Measure-Object).Count
$pluginCount = ($allSkills.GetEnumerator() | Where-Object { $_.Value -match "^plugin" } | Measure-Object).Count
Write-Host "  [OK] Total: $($allSkills.Count) skills ($standaloneCount standalone, $pluginCount from plugins)"
# Show first 5 standalone if any
$standalone = $allSkills.GetEnumerator() | Where-Object { $_.Value -eq "standalone" } | Select-Object -First 5
foreach ($s in $standalone) { Write-Host "       [standalone] $($s.Name)" }
# Show count per source
$sources = $allSkills.GetEnumerator() | Group-Object Value | Sort-Object Count -Descending
foreach ($src in $sources) { Write-Host "       $($src.Name): $($src.Count)" }

# === 7. Clawd Desktop Pet ===
Write-Host "`n--- Clawd Pet ---" -ForegroundColor Yellow
$clawdPrefs = "$env:APPDATA\clawd-on-desk\clawd-prefs.json"
$clawdDir = "$env:USERPROFILE\clawd-on-desk-main"
$clawdNodeModules = "$clawdDir\node_modules"
$clawdRunning = (Get-Process "electron" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match 'clawd|Clawd' } | Measure-Object).Count -gt 0
# Graceful fallback: any electron process count
if (-not $clawdRunning) {
    $clawdRunning = (Get-Process "electron" -ErrorAction SilentlyContinue | Measure-Object).Count -ge 2
}

$clawdOK = 0
if (Test-Path $clawdDir) { $clawdOK++ } else { Write-Host "  [!!] clawd-on-desk-main MISSING" -ForegroundColor Red; $errors++ }
if (Test-Path $clawdNodeModules) { $clawdOK++ } else { Write-Host "  [!!] clawd node_modules MISSING (run npm install)" -ForegroundColor Red; $errors++ }
if (Test-Path $clawdPrefs) { $clawdOK++ } else { Write-Host "  [!!] clawd-prefs.json MISSING" -ForegroundColor Red; $errors++ }
if ($clawdRunning) { $clawdOK++ } else { Write-Host "  [--] clawd not running" -ForegroundColor DarkYellow }

if ($clawdOK -ge 3) {
    $theme = "?"
    if (Test-Path $clawdPrefs) {
        try { $prefs = Get-Content $clawdPrefs -Encoding utf8 | ConvertFrom-Json; $theme = $prefs.theme } catch {}
    }
    Write-Host "  [OK] Clawd installed (repo + node_modules + prefs), theme=$theme"
    if ($clawdRunning) { Write-Host "  [OK] Clawd running" } else { Write-Host "  [--] Not running (npm start to launch)" }
}

# === 8. Sync log ===
Write-Host "`n--- Last Sync ---" -ForegroundColor Yellow
$logFile = "$syncDir\sync.log"
if (Test-Path $logFile) {
    $lines = Get-Content $logFile
    $lastSync = $lines | Select-String "^=== sync" | Select-Object -Last 1
    $lastDone = $lines | Select-String "\[done\]"
    if ($lastSync) { Write-Host "  $lastSync" }
    if ($lastDone) { Write-Host "  [OK] sync completed" } else { Write-Host "  [??] No [done] marker in log" -ForegroundColor DarkYellow }
    # Show last 3 lines
    $lines | Select-Object -Last 5 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
} else {
    Write-Host "  [!!] No sync.log — hook hasn't fired yet" -ForegroundColor Red
    $errors++
}

# === 8. Hook check ===
Write-Host "`n--- Hook ---" -ForegroundColor Yellow
if (Test-Path $settingsPath) {
    $j = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $found = $false
    if ($j.hooks.SessionStart) {
        foreach ($entry in $j.hooks.SessionStart) {
            foreach ($h in $entry.hooks) {
                if ($h.command -match 'config-sync') { $found = $true }
            }
        }
    }
    if ($found) { Write-Host "  [OK] SessionStart hook installed" } else { Write-Host "  [!!] SessionStart hook MISSING" -ForegroundColor Red; $errors++ }
} else {
    Write-Host "  [!!] No settings.json" -ForegroundColor Red
    $errors++
}

# === SUMMARY ===
Write-Host "`n============================================" -ForegroundColor Cyan
if ($errors -eq 0) {
    Write-Host "  ALL GREEN — $hostname is in sync, Master." -ForegroundColor Green
} else {
    Write-Host "  $errors issue(s) found on $hostname." -ForegroundColor Red
    Write-Host "  Run: claude-sync.bat (double-click)" -ForegroundColor Yellow
}
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($Quiet) { exit $errors }
