# sync-status.ps1 — Unified cross-machine sync checklist
# Run: . "$env:USERPROFILE\.claude\sync-status.ps1"
param(
    [switch]$Quiet  # -Quiet returns exit code only (0=OK, 1=issues)
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

# === 2. Memory ===
Write-Host "`n--- Memory ---" -ForegroundColor Yellow
$memDir = "$syncDir\projects\C--Users-10268\memory"
if (Test-Path "$memDir\MEMORY.md") {
    $count = (Get-ChildItem $memDir -Filter "*.md" | Measure-Object).Count
    Write-Host "  [OK] Memory: $count files"
    Get-ChildItem $memDir -Filter "*.md" | ForEach-Object {
        Write-Host "       $($_.Name) ($($_.LastWriteTime.ToString('MM-dd HH:mm')))"
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

# === 5. Plugins ===
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

# === 6. Skills (all sources) ===
Write-Host "`n--- Skills ---" -ForegroundColor Yellow
$allSkills = @{}
if (Test-Path "$syncDir\skills") {
    Get-ChildItem "$syncDir\skills" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $allSkills[$_.Name] = "standalone" }
}
$mpSkillsDir = "$syncDir\plugins\marketplaces"
if (Test-Path $mpSkillsDir) {
    Get-ChildItem $mpSkillsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $mpSkills = Join-Path $_.FullName "skills"
        if (Test-Path $mpSkills) {
            Get-ChildItem $mpSkills -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not $allSkills.ContainsKey($_.Name)) { $allSkills[$_.Name] = "plugin:$($_.Parent.Parent.Name)" }
            }
        }
    }
}
if (Test-Path "$syncDir\plugins\ecc\skills") {
    Get-ChildItem "$syncDir\plugins\ecc\skills" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $allSkills.ContainsKey($_.Name)) { $allSkills[$_.Name] = "plugin:ecc" }
    }
}
$standaloneCount = ($allSkills.GetEnumerator() | Where-Object { $_.Value -eq "standalone" } | Measure-Object).Count
$pluginCount = ($allSkills.GetEnumerator() | Where-Object { $_.Value -match "^plugin" } | Measure-Object).Count
Write-Host "  [OK] Total: $($allSkills.Count) skills ($standaloneCount standalone, $pluginCount from plugins)"

# === 7. Clawd Desktop Pet ===
Write-Host "`n--- Clawd Pet ---" -ForegroundColor Yellow
$clawdDir = "$env:USERPROFILE\clawd-on-desk-main"
$clawdPrefs = "$env:APPDATA\clawd-on-desk\clawd-prefs.json"
$clawdNodeModules = "$clawdDir\node_modules"
$electronCount = (Get-Process "electron" -ErrorAction SilentlyContinue | Measure-Object).Count
$clawdRunning = $electronCount -ge 2

$clawdIndicators = @()
if (Test-Path $clawdDir) { $clawdIndicators += "[OK] repo" } else { $clawdIndicators += "[!!] repo MISSING"; $errors++ }
if (Test-Path $clawdNodeModules) { $clawdIndicators += "[OK] node_modules" } else { $clawdIndicators += "[!!] node_modules MISSING"; $errors++ }
if (Test-Path $clawdPrefs) { $clawdIndicators += "[OK] prefs" } else { $clawdIndicators += "[!!] prefs MISSING"; $errors++ }
if ($clawdRunning) { $clawdIndicators += "[OK] RUNNING ($electronCount electrons)" } else { $clawdIndicators += "[!!] NOT RUNNING ($electronCount electrons)"; $errors++ }

Write-Host "  $($clawdIndicators -join ' | ')"
if ($clawdRunning) { Write-Host "  Status: Clawd is ALIVE" -ForegroundColor Green } else { Write-Host "  Status: Clawd is DEAD" -ForegroundColor Red }

# === 8. Hook ===
Write-Host "`n--- Hook ---" -ForegroundColor Yellow
$hookFound = $false
if (Test-Path $settingsPath) {
    try {
        $j = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($j.hooks.SessionStart) {
            foreach ($entry in $j.hooks.SessionStart) {
                foreach ($h in $entry.hooks) { if ($h.command -match 'config-sync') { $hookFound = $true } }
            }
        }
    } catch {}
}
if ($hookFound) { Write-Host "  [OK] SessionStart hook installed" } else { Write-Host "  [!!] SessionStart hook MISSING" -ForegroundColor Red; $errors++ }

# === 9. Last Sync ===
Write-Host "`n--- Last Sync ---" -ForegroundColor Yellow
$logFile = "$syncDir\sync.log"
if (Test-Path $logFile) {
    $lines = Get-Content $logFile
    $lastSync = $lines | Select-String "^=== sync" | Select-Object -Last 1
    if ($lastSync) { Write-Host "  $lastSync" }
    if ($lines | Select-String "\[done\]" | Select-Object -Last 1) { Write-Host "  [OK] sync completed" }
} else {
    Write-Host "  [!!] No sync.log" -ForegroundColor Red
    $errors++
}

# === 10. Cross-Machine Comparison ===
$statusFiles = Get-ChildItem "$syncDir\status-*.json" -ErrorAction SilentlyContinue
if ($statusFiles.Count -ge 2) {
    Write-Host "`n--- Cross-Machine ---" -ForegroundColor Yellow
    $rows = @()
    foreach ($sf in $statusFiles) {
        try {
            $s = Get-Content $sf.FullName -Raw | ConvertFrom-Json
            $rows += [PSCustomObject]@{
    Machine = $s.machine
    Sync = $s.lastSync
    CLAUDE = if($s.claudeMd){"OK"}else{"XX"}
    Memory = if($s.memory){"OK"}else{"XX"}
    Plugins = $s.plugins
    Clawd = if($s.clawdRunning){"LIVE"}else{"DEAD"}
    Hook = if($s.hook){"OK"}else{"XX"}
}
        } catch {}
    }
    $rows | Format-Table -AutoSize
    Write-Host ""
    # Match check
    if ($rows.Count -ge 2) {
        $match = ($rows[0].CLAUDE -eq $rows[1].CLAUDE) -and ($rows[0].Memory -eq $rows[1].Memory) -and ($rows[0].Plugins -eq $rows[1].Plugins) -and ($rows[0].Hook -eq $rows[1].Hook)
        if ($match) { Write-Host "  [OK] Machines match on core config" -ForegroundColor Green }
        else { Write-Host "  [!!] Machines DIFFER — check above" -ForegroundColor Red; $errors++ }
    }
}

# === SUMMARY ===
Write-Host "`n============================================" -ForegroundColor Cyan
if ($errors -eq 0) {
    Write-Host "  ALL GREEN — $hostname is in sync, Master." -ForegroundColor Green
} else {
    Write-Host "  $errors issue(s) found on $hostname." -ForegroundColor Red
}
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($Quiet) { exit $errors }
