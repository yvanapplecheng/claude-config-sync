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
if (Test-Path $settingsPath) { $curJson = Get-Content $settingsPath | ConvertFrom-Json }
if (Test-Path $settingsLocalPath) {
    $localJson = Get-Content $settingsLocalPath | ConvertFrom-Json
    if ($localJson.enabledPlugins) { $curJson.enabledPlugins = $localJson.enabledPlugins }
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
$skillsDir = "$syncDir\skills"
if (Test-Path $skillsDir) {
    $dirs = Get-ChildItem $skillsDir -Directory
    if ($dirs.Count -gt 0) {
        $dirs | ForEach-Object {
            $gitDir = Join-Path $_.FullName ".git"
            $pipFlag = ""
            if (Test-Path $gitDir) {
                $remote = ""
                try { $remote = (git -C $_.FullName remote get-url origin 2>&1) -join " " } catch {}
                $branch = ""
                try { $branch = (git -C $_.FullName branch --show-current 2>&1) -join " " } catch {}
                $mt = (Get-Item $gitDir).LastWriteTime.ToString("MM-dd HH:mm")
                Write-Host "  [OK] $($_.Name) | $remote | $branch | $mt"
            } else {
                Write-Host "  [OK] $($_.Name) (no .git, likely pip)"
            }
        }
    } else {
        Write-Host "  [--] No skills installed"
    }
} else {
    Write-Host "  [--] No skills directory"
}

# === 7. Sync log ===
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
