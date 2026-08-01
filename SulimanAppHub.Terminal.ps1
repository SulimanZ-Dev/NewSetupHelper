[CmdletBinding()]
param(
    [string]$Profile = '',
    [switch]$Quiet,
    [ValidateSet('', 'InstallProfile', 'UpdateAll', 'Diagnostics')]
    [string]$Action = ''
)

$ErrorActionPreference = 'Continue'
$script:HubVersion = '3.0.0'
$script:Root = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    [AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
}
$script:CurrentExecutable = [Environment]::GetCommandLineArgs()[0]
$modulePath = Join-Path $script:Root 'modules\SulimanAppHub.Core.psm1'

if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-Host "Suliman App Hub core module is missing: $modulePath" -ForegroundColor Red
    exit 1
}

Import-Module $modulePath -Force

function Write-HubHeader {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor DarkRed
    Write-Host '                    SULIMAN APP HUB' -ForegroundColor Red
    Write-Host "                 Terminal Edition v$script:HubVersion" -ForegroundColor DarkRed
    Write-Host '============================================================' -ForegroundColor DarkRed
    Write-Host ''
}

function Pause-Hub {
    if (-not $Quiet) { [void](Read-Host 'Tryck Enter for att fortsatta') }
}

function Confirm-HubAction {
    param([string]$Prompt)
    if ($Quiet) { return $true }
    return (Read-Host "$Prompt [j/N]") -match '^(?i)(j|ja|y|yes)$'
}

function Select-HubItems {
    param([array]$Items, [string]$Title, [string]$DisplayProperty = 'name')
    Write-HubHeader
    Write-Host $Title -ForegroundColor Red
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ('  [{0}] {1}' -f ($i + 1), $Items[$i].$DisplayProperty) -ForegroundColor DarkRed
    }
    Write-Host '  Ange nummer separerade med kommatecken, eller all.' -ForegroundColor DarkGray
    $raw = Read-Host 'Val'
    if ($raw -match '^(?i)all$') { return @($Items) }
    $selected = @()
    foreach ($part in $raw -split ',') {
        $number = 0
        if ([int]::TryParse($part.Trim(), [ref]$number) -and $number -ge 1 -and $number -le $Items.Count) {
            $selected += ,$Items[$number - 1]
        }
    }
    return $selected
}

function Show-HubResults {
    param([array]$Results)
    Write-Host ''
    foreach ($result in $Results) {
        $name = if ($result.App) { $result.App.name } elseif ($result.Target) { $result.Target } else { 'Atgard' }
        $color = if ($result.Success) { 'Green' } else { 'Red' }
        Write-Host ('  [{0}] {1}: {2}' -f $(if ($result.Success) { 'OK' } else { 'FEL' }), $name, $result.Message) -ForegroundColor $color
    }
}

function Enter-HubApps {
    $catalog = Get-SahCatalog
    $apps = @($catalog.apps | Sort-Object category, name)
    $selected = @(Select-HubItems -Items $apps -Title 'Valj appar')
    if ($selected.Count -eq 0) { return }
    Write-Host ''
    Write-Host '  [1] Installera' -ForegroundColor DarkRed
    Write-Host '  [2] Uppdatera' -ForegroundColor DarkRed
    Write-Host '  [3] Avinstallera' -ForegroundColor DarkRed
    Write-Host '  [4] Visa installerade versioner' -ForegroundColor DarkRed
    $mode = Read-Host 'Atgard'
    if ($mode -in @('1', '2', '3') -and -not (Confirm-HubAction -Prompt "Utfor atgarden for $($selected.Count) appar?")) { return }
    $results = @()
    foreach ($app in $selected) {
        switch ($mode) {
            '1' { $results += ,(Install-SahApp -App $app) }
            '2' { $results += ,(Update-SahApp -App $app) }
            '3' { $results += ,(Uninstall-SahApp -App $app) }
            '4' {
                $status = Get-SahAppStatus -App $app -CheckRemote
                $message = "Installerad=$($status.Installed), nuvarande=$($status.InstalledVersion), senaste=$($status.LatestVersion)"
                $results += [pscustomobject]@{ Success = $true; App = $app; Message = $message }
            }
        }
    }
    Show-HubResults -Results $results
    Pause-Hub
}

function Enter-HubProfiles {
    $catalog = Get-SahCatalog
    $profiles = @($catalog.profiles)
    $selected = @(Select-HubItems -Items $profiles -Title 'Valj installationsprofil' -DisplayProperty 'nameSv')
    if ($selected.Count -eq 0) { return }
    $profile = $selected[0]
    $apps = @(Get-SahProfileApps -ProfileId $profile.id)
    Write-Host ''
    Write-Host "Profilen innehaller: $($apps.name -join ', ')" -ForegroundColor DarkRed
    if (-not (Confirm-HubAction -Prompt 'Installera profilen?')) { return }
    $results = Invoke-SahProfile -ProfileId $profile.id -Quiet:$Quiet -ProgressCallback {
        param($name, $index, $count)
        Write-Host "  [$($index + 1)/$count] $name" -ForegroundColor DarkRed
    }
    Show-HubResults -Results $results
    Pause-Hub
}

function Enter-HubRepositories {
    Write-HubHeader
    Write-Host '  [1] Klona fran katalogen' -ForegroundColor DarkRed
    Write-Host '  [2] Hantera lokala repositories' -ForegroundColor DarkRed
    $choice = Read-Host 'Val'
    if ($choice -eq '1') {
        $repos = @((Get-SahCatalog).repositories)
        $selected = @(Select-HubItems -Items $repos -Title 'Valj repositories')
        if (-not (Confirm-HubAction -Prompt "Klona $($selected.Count) repositories?")) { return }
        $results = foreach ($repo in $selected) { Install-SahRepository -Repository $repo }
        Show-HubResults -Results $results
    }
    elseif ($choice -eq '2') {
        $repos = @(Get-SahRepositoryInventory)
        if ($repos.Count -eq 0) { Write-Host 'Inga lokala repositories hittades.' -ForegroundColor Yellow; Pause-Hub; return }
        $selected = @(Select-HubItems -Items $repos -Title 'Valj lokala repositories' -DisplayProperty 'Name')
        Write-Host '  [1] git pull --ff-only  [2] Oppna  [3] VS Code  [4] Kontrollera/reparera' -ForegroundColor DarkRed
        $action = switch (Read-Host 'Atgard') { '1' { 'Pull' } '2' { 'Open' } '3' { 'Code' } '4' { 'Repair' } }
        if ($action) {
            $results = foreach ($repo in $selected) { Invoke-SahRepositoryAction -Repository $repo -Action $action }
            Show-HubResults -Results $results
        }
    }
    Pause-Hub
}

function Enter-HubBackup {
    Write-HubHeader
    Write-Host '  [1] Exportera datorprofil till ZIP' -ForegroundColor DarkRed
    Write-Host '  [2] Aterstall datorprofil' -ForegroundColor DarkRed
    Write-Host '  [3] Jamfor dator med backup' -ForegroundColor DarkRed
    Write-Host '  [4] Exportera systemrapport' -ForegroundColor DarkRed
    $choice = Read-Host 'Val'
    switch ($choice) {
        '1' {
            $default = Join-Path ([Environment]::GetFolderPath('Desktop')) ("Suliman-PC-Backup-{0}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
            $path = Read-Host "Sokvag [$default]"
            if (-not $path) { $path = $default }
            $result = Export-SahComputerProfile -DestinationPath $path
            Show-HubResults -Results @($result)
        }
        '2' {
            $path = Read-Host 'Sokvag till backup-ZIP'
            if ((Test-Path -LiteralPath $path) -and (Confirm-HubAction -Prompt 'Aterstall konfiguration och tillstand?')) {
                $result = Import-SahComputerProfile -BackupPath $path -InstallWingetApps -RestoreSpicetify
                Show-HubResults -Results @($result)
            }
        }
        '3' {
            $path = Read-Host 'Sokvag till backup-ZIP'
            if (Test-Path -LiteralPath $path) { Compare-SahComputerProfile -BackupPath $path | Format-List | Out-Host }
        }
        '4' {
            $path = Join-Path ([Environment]::GetFolderPath('Desktop')) ("Suliman-Systemrapport-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
            Export-SahSystemReport -Path $path | Out-Null
            Write-Host "Rapport skapad: $path" -ForegroundColor Green
        }
    }
    Pause-Hub
}

function Show-HubDiagnostics {
    Write-HubHeader
    Get-SahSystemDiagnostics | Format-List | Out-Host
    Pause-Hub
}

function Show-HubHistory {
    Write-HubHeader
    Get-SahHistory -Limit 100 | Format-Table timestamp, action, target, success, version, message -AutoSize -Wrap | Out-Host
    Pause-Hub
}

function Open-HubConfig {
    $paths = Get-SahPaths
    Start-Process notepad.exe -ArgumentList $paths.Config
}

function Invoke-TerminalUpdateAll {
    if (-not (Confirm-HubAction -Prompt 'Uppdatera winget-appar, GitHub-appar, Spicetify och kontrollera helpern?')) { return }
    $results = Invoke-SahUpdateAll -HelperVersion $script:HubVersion -HelperEdition 'Terminal' -ProgressCallback {
        param($name, $index, $count)
        Write-Host "  [$($index + 1)/$count] $name" -ForegroundColor DarkRed
    }
    Show-HubResults -Results $results
    Pause-Hub
}

function Invoke-TerminalSelfUpdate {
    try {
        $update = Get-SahHelperUpdate -CurrentVersion $script:HubVersion -Edition 'Terminal'
        Write-Host "Nuvarande: $($update.CurrentVersion), senaste: $($update.LatestVersion)" -ForegroundColor DarkRed
        if ($update.UpdateAvailable) {
            Write-Host $update.Notes -ForegroundColor DarkGray
            if ((Confirm-HubAction -Prompt 'Installera uppdateringen?') -and $script:CurrentExecutable.EndsWith('.exe')) {
                Start-SahSelfUpdate -Update $update -CurrentExecutable $script:CurrentExecutable | Format-List | Out-Host
            }
        }
        else { Write-Host 'Du har redan senaste versionen.' -ForegroundColor Green }
    }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red }
    Pause-Hub
}

if ($Action) {
    switch ($Action) {
        'InstallProfile' {
            if (-not $Profile) { throw '-Profile is required with -Action InstallProfile.' }
            $results = Invoke-SahProfile -ProfileId $Profile -Quiet:$Quiet
            if (@($results | Where-Object { -not $_.Success }).Count -gt 0) { exit 1 }
            exit 0
        }
        'UpdateAll' {
            $results = Invoke-SahUpdateAll -HelperVersion $script:HubVersion -HelperEdition 'Terminal'
            if (@($results | Where-Object { -not $_.Success }).Count -gt 0) { exit 1 }
            exit 0
        }
        'Diagnostics' { Get-SahSystemDiagnostics | ConvertTo-Json -Depth 5; exit 0 }
    }
}

$terminalRunning = $true
while ($terminalRunning) {
    Write-HubHeader
    Write-Host '  [1] Appar: installera, uppdatera eller avinstallera' -ForegroundColor DarkRed
    Write-Host '  [2] Installationsprofiler' -ForegroundColor DarkRed
    Write-Host '  [3] Repository-hanterare' -ForegroundColor DarkRed
    Write-Host '  [4] Uppdatera allt' -ForegroundColor DarkRed
    Write-Host '  [5] Backup, aterstallning och datorjamforelse' -ForegroundColor DarkRed
    Write-Host '  [6] Systemdiagnostik' -ForegroundColor DarkRed
    Write-Host '  [7] Nedladdningshistorik och logg' -ForegroundColor DarkRed
    Write-Host '  [8] Oppna konfiguration for egna appar/repositories' -ForegroundColor DarkRed
    Write-Host '  [9] Kontrollera uppdatering av Setup Helper' -ForegroundColor DarkRed
    Write-Host '  [0] Tillbaka' -ForegroundColor DarkGray
    switch (Read-Host 'Val') {
        '1' { Enter-HubApps }
        '2' { Enter-HubProfiles }
        '3' { Enter-HubRepositories }
        '4' { Invoke-TerminalUpdateAll }
        '5' { Enter-HubBackup }
        '6' { Show-HubDiagnostics }
        '7' { Show-HubHistory }
        '8' { Open-HubConfig }
        '9' { Invoke-TerminalSelfUpdate }
        '0' { $terminalRunning = $false }
        default { Write-Host 'Ogiltigt val.' -ForegroundColor Red; Pause-Hub }
    }
}
