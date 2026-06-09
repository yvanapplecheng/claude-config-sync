# install-sync-hook.ps1 — Injects auto-sync SessionStart hook into settings.json
param($SyncDir = "$env:USERPROFILE\.claude")

$settingsPath = Join-Path $SyncDir 'settings.json'
$localPath = Join-Path $SyncDir 'settings.local.json'
$target = if (Test-Path $settingsPath) { $settingsPath } else { $localPath }

if (-not $target -or -not (Test-Path $target)) {
    # No settings file yet — create one
    $target = $settingsPath
    @{ hooks = @{ SessionStart = @() } } | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 $target
    Write-Host "   Created settings.json"
}

$j = Get-Content $target -Raw | ConvertFrom-Json

# Ensure hooks.SessionStart array exists
if (-not $j.hooks) { $j | Add-Member -NotePropertyName hooks -NotePropertyValue @{} -Force }
if (-not $j.hooks.SessionStart) { $j.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue @() -Force }

# Check if hook already exists
$already = $false
foreach ($entry in $j.hooks.SessionStart) {
    foreach ($h in $entry.hooks) {
        if ($h.command -match 'config-sync\.ps1') { $already = $true }
    }
}

if (-not $already) {
    $entry = @{
        matcher = ''
        hooks = @(
            @{
                type = 'command'
                command = "powershell -ExecutionPolicy Bypass -File `"$SyncDir\config-sync.ps1`""
                shell = 'powershell'
                timeout = 120
                async = $false
            }
        )
    }
    $j.hooks.SessionStart = @($entry) + $j.hooks.SessionStart
    $j | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 $target
    Write-Host "   Hook added."
} else {
    Write-Host "   Hook already present."
}
