# spicetify-app.ps1 - PC Setup and Spicetify Helper
# Personal toolkit for Spicetify, app installs, and new-PC setup.

$ScriptVersion = '2.0'
$ScriptGitHubUrl = 'https://github.com/Wooting2HEEHEE/spicetify-pc-setup-helper'
$ErrorActionPreference = 'Continue'
$script:running = $true
$script:SleepTimerJobName = 'SpicetifyHelperSleepTimer'

$ScriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ThemeConfigPath = Join-Path $ScriptDirectory 'spicetify-helper-config.json'
$LogPath = Join-Path $env:TEMP 'spicetify-helper-log.txt'
$SessionStart = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Add-Content -Path $LogPath -Value "=== Session started: $SessionStart ==="

$script:ThemePresets = [ordered]@{
    Hacker = @{
        Background = 'Black'; Foreground = 'Green'; Accent = 'Green'; Border = 'DarkGreen'; Muted = 'DarkGray'
        Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Prompt = 'Green'
    }
    Alert = @{
        Background = 'Black'; Foreground = 'DarkRed'; Accent = 'Red'; Border = 'DarkRed'; Muted = 'DarkRed'
        Success = 'DarkRed'; Warning = 'Red'; Error = 'Red'; Prompt = 'Red'
    }
    Classic = @{
        Background = 'Black'; Foreground = 'White'; Accent = 'Cyan'; Border = 'DarkCyan'; Muted = 'DarkGray'
        Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Prompt = 'Cyan'
    }
    Ocean = @{
        Background = 'Black'; Foreground = 'Cyan'; Accent = 'Cyan'; Border = 'DarkCyan'; Muted = 'DarkGray'
        Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Prompt = 'Cyan'
    }
    Amber = @{
        Background = 'Black'; Foreground = 'DarkYellow'; Accent = 'Yellow'; Border = 'DarkYellow'; Muted = 'DarkGray'
        Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Prompt = 'DarkYellow'
    }
}
$script:CurrentThemeName = 'Classic'
$script:Theme = $script:ThemePresets[$script:CurrentThemeName]

#region Logging

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $line
}

Write-Log -Message "Script v$ScriptVersion started"

#endregion Logging

#region UI Helpers

function Get-ThemeColor {
    param([string]$Role = 'Foreground')

    if ($script:Theme.ContainsKey($Role)) { return $script:Theme[$Role] }
    return $script:Theme.Foreground
}

function Write-ThemedHost {
    param(
        [string]$Text = '',
        [string]$Role = 'Foreground',
        [switch]$NoNewline
    )

    Write-Host $Text -ForegroundColor (Get-ThemeColor $Role) -NoNewline:$NoNewline
}

function Save-ThemeConfig {
    $config = [ordered]@{
        Theme = $script:CurrentThemeName
    }

    try {
        $config | ConvertTo-Json | Set-Content -LiteralPath $ThemeConfigPath -Encoding UTF8
    }
    catch {
        Write-Log -Message "Theme config save failed: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Set-ActiveTheme {
    param(
        [string]$Name,
        [switch]$Persist
    )

    if (-not $script:ThemePresets.Contains($Name)) {
        $Name = 'Classic'
    }

    $script:CurrentThemeName = $Name
    $script:Theme = $script:ThemePresets[$Name]

    try {
        $Host.UI.RawUI.BackgroundColor = $script:Theme.Background
        $Host.UI.RawUI.ForegroundColor = $script:Theme.Foreground
    }
    catch {
        Write-Log -Message "Console theme apply failed: $($_.Exception.Message)" -Level 'WARN'
    }

    if ($Persist) { Save-ThemeConfig }
}

function Load-ThemeConfig {
    if (-not (Test-Path -LiteralPath $ThemeConfigPath)) { return $false }

    try {
        $config = Get-Content -LiteralPath $ThemeConfigPath -Raw | ConvertFrom-Json
        if ($config.Theme -and $script:ThemePresets.Contains($config.Theme)) {
            Set-ActiveTheme -Name $config.Theme
            return $true
        }
    }
    catch {
        Write-Log -Message "Theme config load failed: $($_.Exception.Message)" -Level 'WARN'
    }

    return $false
}

function Select-Theme {
    param([switch]$FirstRun)

    while ($true) {
        Write-Banner
        if ($FirstRun) {
            Write-ThemedHost '  Pick a console theme to start.' 'Accent'
        }
        else {
            Write-ThemedHost '  CHANGE THEME' 'Accent'
        }
        Write-ThemedHost '  -----------------------------------------------------' 'Muted'
        $names = @($script:ThemePresets.Keys)
        for ($i = 0; $i -lt $names.Count; $i++) {
            $marker = if ($names[$i] -eq $script:CurrentThemeName) { ' *' } else { '  ' }
            Write-ThemedHost ("  [{0}] {1}{2}" -f ($i + 1), $names[$i], $marker) 'Foreground'
        }
        Write-ThemedHost ''
        $choice = Read-MenuChoice -Prompt 'Theme number'
        $index = 0
        if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $names.Count) {
            Set-ActiveTheme -Name $names[$index - 1] -Persist
            Write-Banner
            Write-ThemedHost "  Theme changed to $script:CurrentThemeName." 'Success'
            if (-not $FirstRun) { Pause-Script }
            return
        }

        Write-ThemedHost '  Invalid theme choice.' 'Error'
        Pause-Script
    }
}

function Write-Banner {
    Clear-Host
    Write-ThemedHost ''
    Write-ThemedHost '  +======================================================+' 'Border'
    Write-ThemedHost '  |                                                      |' 'Border'
    Write-ThemedHost '  |' 'Border' -NoNewline
    Write-ThemedHost '     SPICETIFY + PC SETUP HELPER' 'Accent' -NoNewline
    Write-ThemedHost '              |' 'Border'
    Write-ThemedHost '  |' 'Border' -NoNewline
    Write-ThemedHost '     Install fast. Customize Spotify. Own your PC.' 'Muted' -NoNewline
    Write-ThemedHost '   |' 'Border'
    Write-ThemedHost '  |                                                      |' 'Border'
    Write-ThemedHost '  +======================================================+' 'Border'
    Write-ThemedHost ''
}

function Write-Step {
    param(
        [int]$Number,
        [int]$Total,
        [string]$Message
    )
    Write-ThemedHost "  [$Number/$Total] " 'Border' -NoNewline
    Write-ThemedHost $Message 'Foreground'
}

function Write-StatusLine {
    param(
        [string]$Label,
        [bool]$Ok,
        [string]$Detail = ''
    )

    $icon = if ($Ok) { '[OK]' } else { '[!!]' }
    $role = if ($Ok) { 'Success' } else { 'Warning' }

    Write-ThemedHost "  $icon " $role -NoNewline
    Write-ThemedHost $Label 'Foreground' -NoNewline
    if ($Detail) {
        Write-ThemedHost " - $Detail" 'Muted'
    }
    else {
        Write-ThemedHost ''
    }
}

function Write-OpResult {
    param(
        [string]$Label,
        [bool]$Success
    )

    if ($Success) {
        Write-ThemedHost "  OK   $Label" 'Success'
        Write-Log -Message "$Label - OK"
    }
    else {
        Write-ThemedHost "  FAIL $Label" 'Error'
        Write-Log -Message "$Label - FAILED" -Level 'ERROR'
    }
}

function Pause-Script {
    Write-ThemedHost ''
    Read-Host 'Press Enter to continue' | Out-Null
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $hint = if ($DefaultYes) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "$Prompt [$hint]"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultYes
    }

    return $answer -match '^[Yy]'
}

function Read-MenuChoice {
    param([string]$Prompt = 'Choice')
    return (Read-Host "  $Prompt").Trim()
}

function Read-PositiveInteger {
    param([string]$Prompt)

    while ($true) {
        $raw = Read-Host $Prompt
        $parsed = 0
        if ([int]::TryParse($raw, [ref]$parsed) -and $parsed -gt 0) {
            return $parsed
        }
        Write-ThemedHost '  Enter a positive whole number.' 'Error'
    }
}

function Get-ScriptLastUpdated {
    $path = $PSCommandPath
    if (-not $path) { $path = $MyInvocation.MyCommand.Path }
    if ($path -and (Test-Path -LiteralPath $path)) {
        return (Get-Item -LiteralPath $path).LastWriteTime.ToString('yyyy-MM-dd')
    }
    return 'unknown'
}

#endregion UI Helpers

#region Core Helpers

function Test-IsAdmin {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Assert-AdminForSystemChanges {
    if (Test-IsAdmin) { return $true }

    Write-Host ''
    Write-Host '  Administrator rights are required for this action.' -ForegroundColor Red
    Write-Host '  Re-run the script as Administrator and try again.' -ForegroundColor Yellow
    Write-Log -Message 'Admin required but not elevated' -Level 'WARN'
    Pause-Script
    return $false
}

function Test-CommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Assert-CommandAvailable {
    param([string]$Name)

    if (-not (Test-CommandAvailable $Name)) {
        Write-Host ''
        Write-Host "  $Name was not found. Install it and make sure it is in PATH." -ForegroundColor Red
        Write-Log -Message "$Name not found in PATH" -Level 'WARN'
        Pause-Script
        return $false
    }

    return $true
}

function Invoke-External {
    param(
        [string]$Label,
        [scriptblock]$Action,
        [switch]$IgnoreExitCode
    )

    Write-Host ''
    Write-Host "  $Label..." -ForegroundColor Yellow
    Write-Log -Message $Label

    try {
        & $Action
        if (-not $IgnoreExitCode -and $null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw "Exit code $LASTEXITCODE"
        }
        Write-Host '  Done.' -ForegroundColor Green
        Write-Log -Message "$Label - success"
        return $true
    }
    catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Message "$Label - failed: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Invoke-Spicetify {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$CloseSpotifyFirst
    )

    if (-not (Assert-CommandAvailable 'spicetify')) { return $false }

    if ($CloseSpotifyFirst) {
        Stop-SpotifyIfRunning | Out-Null
    }

    return Invoke-External -Label ("Running: spicetify " + ($Arguments -join ' ')) -Action {
        & spicetify @Arguments
    }
}

function Stop-SpotifyIfRunning {
    $processes = Get-Process -Name 'Spotify' -ErrorAction SilentlyContinue
    if (-not $processes) { return $false }

    Write-Host '  Closing Spotify...' -ForegroundColor Yellow
    Write-Log -Message 'Closing Spotify process'
    $processes | Stop-Process -Force
    Start-Sleep -Seconds 2
    return $true
}

function Get-SpicetifyDataPath {
    if (Test-CommandAvailable 'spicetify') {
        $path = (& spicetify path userdata 2>$null | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
            return $path
        }
    }

    $fallback = Join-Path $env:APPDATA 'spicetify'
    if (Test-Path $fallback) { return $fallback }
    return $fallback
}

function Get-ThemesPath {
    if (-not (Test-CommandAvailable 'spicetify')) { return $null }

    $path = (& spicetify path -s root 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) { return $null }
    return $path
}

function Open-BrowserFallback {
    param(
        [string]$Url,
        [string]$AppName
    )

    Write-Host "  Opening $AppName download page in browser..." -ForegroundColor Yellow
    Write-Log -Message "Browser fallback for $AppName : $Url"
    try {
        Start-Process $Url
        return $true
    }
    catch {
        Write-Host "  Could not open browser: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Message "Browser fallback failed for $AppName" -Level 'ERROR'
        return $false
    }
}

function Install-WithWinget {
    param(
        [string]$Id,
        [string]$Name,
        [string[]]$FallbackIds = @(),
        [string]$FallbackUrl = ''
    )

    if (-not (Test-CommandAvailable 'winget')) {
        Write-Host "  winget is not available for $Name." -ForegroundColor Yellow
        Write-Log -Message "winget unavailable for $Name" -Level 'WARN'
        if ($FallbackUrl) { return Open-BrowserFallback -Url $FallbackUrl -AppName $Name }
        return $false
    }

    $idsToTry = @($Id) + $FallbackIds
    foreach ($tryId in $idsToTry) {
        Write-Log -Message "winget install attempt: $tryId ($Name)"
        $ok = Invoke-External -Label "Installing $Name via winget ($tryId)" -Action {
            & winget install -e --id $tryId --accept-package-agreements --accept-source-agreements --silent
        }

        if ($ok) { return $true }
        Write-Host "  winget install failed for $tryId" -ForegroundColor Yellow
    }

    if ($FallbackUrl) {
        Open-BrowserFallback -Url $FallbackUrl -AppName $Name | Out-Null
    }

    return $false
}

function Install-FromGitHubExe {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$AppName,
        [string]$FallbackUrl = ''
    )

    $ok = Invoke-External -Label "Downloading $AppName installer" -Action {
        $installer = Join-Path $env:TEMP $FileName
        Invoke-WebRequest -Uri $Url -OutFile $installer -UseBasicParsing
        Start-Process $installer
    }

    if (-not $ok -and $FallbackUrl) {
        Open-BrowserFallback -Url $FallbackUrl -AppName $AppName | Out-Null
    }

    return $ok
}

function Set-RegistryDword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value,
        [switch]$CreatePath
    )

    try {
        if ($CreatePath -and -not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
        return $true
    }
    catch {
        Write-Log -Message "Registry write failed: $Path\$Name - $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Remove-RegistryValue {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        if (Test-Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
        }
        return $true
    }
    catch {
        Write-Log -Message "Registry remove failed: $Path\$Name - $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Prompt-DefaultBrowser {
    if (Read-YesNo -Prompt '  Set as default browser?' -DefaultYes $false) {
        Write-Log -Message 'Opening default apps settings'
        Start-Process 'ms-settings:defaultapps'
    }
}

#endregion Core Helpers

#region Menus

function Show-MainMenu {
    Write-Banner
    Write-ThemedHost '========================================' 'Border'
    Write-ThemedHost '   SPICETIFY + PC SETUP HELPER' 'Accent'
    Write-ThemedHost '========================================' 'Border'
    Write-ThemedHost '  [1] New PC Setup Wizard' 'Foreground'
    Write-ThemedHost '  [2] System Status Check' 'Foreground'
    Write-ThemedHost '  [3] Spicetify Tools     -->' 'Foreground'
    Write-ThemedHost '  [4] Install Apps        -->' 'Foreground'
    Write-ThemedHost '  [5] App & Repo Installer -->' 'Foreground'
    Write-ThemedHost '  [6] Windows Privacy     -->' 'Foreground'
    Write-ThemedHost '  [7] Power and Sleep     -->' 'Foreground'
    Write-ThemedHost '  [8] Utilities           -->' 'Foreground'
    Write-ThemedHost '  [9] Settings / Theme' 'Foreground'
    Write-ThemedHost '  [0] Exit' 'Muted'
    Write-ThemedHost '========================================' 'Border'
    Write-ThemedHost ''
}

function Show-AppRepoInstallerMenu {
    Write-Banner
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '   APP & REPO INSTALLER' 'Accent'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '  [1] Install selected apps' 'Foreground'
    Write-ThemedHost '  [2] Clone selected GitHub repos' 'Foreground'
    Write-ThemedHost '  [3] Change theme' 'Foreground'
    Write-ThemedHost '  [0] Back to Main Menu' 'Muted'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost ''
}

function Show-SpicetifyMenu {
    Write-Banner
    Write-ThemedHost '  SPICETIFY TOOLS' 'Accent'
    Write-ThemedHost '  -----------------------------------------------------' 'Muted'
    Write-ThemedHost '   1   Install Spicetify CLI' 'Foreground'
    Write-ThemedHost '   2   Install Spicetify Marketplace' 'Foreground'
    Write-ThemedHost '   3   Upgrade Spicetify CLI' 'Foreground'
    Write-ThemedHost '   4   Apply Config' 'Foreground'
    Write-ThemedHost '   5   Restore Spotify to Original' 'Foreground'
    Write-ThemedHost '   6   Restart Spotify' 'Foreground'
    Write-ThemedHost '   7   Block Spotify Updates' 'Foreground'
    Write-ThemedHost '   8   Unblock Spotify Updates' 'Foreground'
    Write-ThemedHost '   9   After Spotify Update (backup + apply)' 'Foreground'
    Write-ThemedHost '  10   Open Config Directory' 'Foreground'
    Write-ThemedHost '  11   Backup Vanilla Spotify Files' 'Foreground'
    Write-ThemedHost '  12   Clear Spicetify Backup' 'Foreground'
    Write-ThemedHost '  13   Apply a Theme' 'Foreground'
    Write-ThemedHost '  14   Remove an Extension' 'Foreground'
    Write-ThemedHost '  15   List Theme and Extensions' 'Foreground'
    Write-ThemedHost '  16   Check Spicetify Version' 'Foreground'
    Write-ThemedHost '  17   Enable DevTools' 'Foreground'
    Write-ThemedHost '  18   Export Config (ZIP)' 'Foreground'
    Write-ThemedHost '  19   Import Config (ZIP)' 'Foreground'
    Write-ThemedHost '   0   Back to Main Menu' 'Muted'
    Write-ThemedHost '  -----------------------------------------------------' 'Muted'
    Write-ThemedHost ''
}

function Show-AppsMenu {
    Write-Banner
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '   INSTALL APPS' 'Accent'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '-- Music and Social --' 'Muted'
    Write-ThemedHost '  [1]  Spotify' 'Foreground'
    Write-ThemedHost '  [2]  BetterDiscord' 'Foreground'
    Write-ThemedHost '  [3]  Vencord' 'Foreground'
    Write-ThemedHost '-- Remote and Network --' 'Muted'
    Write-ThemedHost '  [4]  AweSun Remote Desktop' 'Foreground'
    Write-ThemedHost '  [5]  OFF Helper (Phone-to-PC shutdown)' 'Foreground'
    Write-ThemedHost '  [6]  LANDrop' 'Foreground'
    Write-ThemedHost '-- Browsers --' 'Muted'
    Write-ThemedHost '  [7]  Firefox' 'Foreground'
    Write-ThemedHost '  [8]  Brave' 'Foreground'
    Write-ThemedHost '  [9]  Google Chrome' 'Foreground'
    Write-ThemedHost '-- Gaming --' 'Muted'
    Write-ThemedHost ' [10]  Steam' 'Foreground'
    Write-ThemedHost ' [11]  Epic Games Launcher' 'Foreground'
    Write-ThemedHost '-- Dev Tools --' 'Muted'
    Write-ThemedHost ' [12]  Git' 'Foreground'
    Write-ThemedHost ' [13]  VS Code' 'Foreground'
    Write-ThemedHost ' [14]  Node.js LTS' 'Foreground'
    Write-ThemedHost ' [15]  Windows Terminal' 'Foreground'
    Write-ThemedHost ' [16]  7-Zip' 'Foreground'
    Write-ThemedHost '-- Batch --' 'Muted'
    Write-ThemedHost ' [17]  Install ALL Dev Tools (12-16 at once)' 'Foreground'
    Write-ThemedHost ' [18]  Install ALL Gaming Launchers (10-11 at once)' 'Foreground'
    Write-ThemedHost ''
    Write-ThemedHost '  [0]  Back to Main Menu' 'Muted'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost ''
}

function Show-PrivacyMenu {
    Write-Banner
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '   WINDOWS PRIVACY AND TWEAKS' 'Accent'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '  [1]  Disable Telemetry and Data Collection' 'Foreground'
    Write-ThemedHost '  [2]  Remove Common Bloatware' 'Foreground'
    Write-ThemedHost '  [3]  Disable Windows Ads and Suggestions' 'Foreground'
    Write-ThemedHost '  [4]  Disable Bing Search in Start Menu' 'Foreground'
    Write-ThemedHost '  [5]  Disable Activity History and Location' 'Foreground'
    Write-ThemedHost '  [6]  Disable Cortana' 'Foreground'
    Write-ThemedHost '  [7]  Apply ALL Privacy Tweaks (1-6 at once)' 'Foreground'
    Write-ThemedHost '  [8]  Restore Windows Defaults (undo tweaks)' 'Foreground'
    Write-ThemedHost '  [0]  Back to Main Menu' 'Muted'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost ''
}

function Show-PowerMenu {
    Write-Banner
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '   POWER AND SLEEP TOOLS' 'Accent'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '  [1]  Set Shutdown Timer' 'Foreground'
    Write-ThemedHost '  [2]  Set Sleep Timer' 'Foreground'
    Write-ThemedHost '  [3]  Cancel Any Active Timer' 'Foreground'
    Write-ThemedHost '  [4]  Switch Power Plan' 'Foreground'
    Write-ThemedHost '  [5]  Show Current Power Plan' 'Foreground'
    Write-ThemedHost '  [0]  Back to Main Menu' 'Muted'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost ''
}

function Show-UtilitiesMenu {
    Write-Banner
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '   UTILITIES' 'Accent'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost '  [1]  Run Chris Titus Tech Win Script' 'Foreground'
    Write-ThemedHost '  [2]  Open Ninite Website' 'Foreground'
    Write-ThemedHost '  [3]  Update All Installed Apps (winget upgrade --all)' 'Foreground'
    Write-ThemedHost '  [4]  Check Script Version / Open GitHub' 'Foreground'
    Write-ThemedHost '  [5]  View Session Log' 'Foreground'
    Write-ThemedHost '  [0]  Back to Main Menu' 'Muted'
    Write-ThemedHost '==============================' 'Border'
    Write-ThemedHost ''
}

#endregion Menus

#region Status and Wizard

function Show-SystemStatus {
    Write-Banner
    Write-Host '  SYSTEM STATUS' -ForegroundColor Cyan
    Write-Host '  -----------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    Write-Log -Message 'System status check'

    $hasSpotify = Test-CommandAvailable 'spicetify'
    $spotifyPath = $null
    if ($hasSpotify) {
        $spotifyPath = (& spicetify path 2>$null | Out-String).Trim()
    }
    $spotifyInstalled = -not [string]::IsNullOrWhiteSpace($spotifyPath) -and (Test-Path $spotifyPath)

    Write-StatusLine -Label 'Spicetify CLI' -Ok $hasSpotify -Detail $(if ($hasSpotify) {
            (& spicetify -v 2>$null | Out-String).Trim()
        } else { 'Not installed' })

    Write-StatusLine -Label 'Spotify' -Ok $spotifyInstalled -Detail $(if ($spotifyInstalled) { $spotifyPath } else { 'Not detected' })

    Write-StatusLine -Label 'winget' -Ok (Test-CommandAvailable 'winget')
    Write-StatusLine -Label 'Admin rights' -Ok (Test-IsAdmin)
    Write-StatusLine -Label 'Script version' -Ok $true -Detail "v$ScriptVersion"

    if ($hasSpotify) {
        $theme = (& spicetify config current_theme 2>$null | Out-String).Trim()
        $extensions = (& spicetify config extensions 2>$null | Out-String).Trim()
        $dataPath = Get-SpicetifyDataPath

        Write-Host ''
        Write-Host '  Config' -ForegroundColor Cyan
        Write-StatusLine -Label 'Data folder' -Ok (Test-Path $dataPath) -Detail $dataPath
        Write-StatusLine -Label 'Current theme' -Ok (-not [string]::IsNullOrWhiteSpace($theme)) -Detail $(if ($theme) { $theme } else { 'None set' })

        if ($extensions) {
            Write-Host '  Extensions:' -ForegroundColor DarkGray
            $extensions -split '\|' | ForEach-Object {
                $ext = $_.Trim()
                if ($ext) { Write-Host "    - $ext" -ForegroundColor DarkGray }
            }
        }
        else {
            Write-StatusLine -Label 'Extensions' -Ok $false -Detail 'None enabled'
        }
    }

    Write-Host ''
    Pause-Script
}

function Start-NewPCWizard {
    Write-Banner
    Write-Host '  NEW PC SETUP WIZARD' -ForegroundColor Cyan
    Write-Host '  Walks you through the usual setup chain.' -ForegroundColor DarkGray
    Write-Host '  -----------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    Write-Log -Message 'New PC Setup Wizard started'

    $totalSteps = 6

    Write-Step -Number 1 -Total $totalSteps -Message 'Install Spotify (if missing)'
    $spotifyOk = $false
    if (Test-CommandAvailable 'spicetify') {
        $spotifyExe = (& spicetify path 2>$null | Out-String).Trim()
        $spotifyOk = -not [string]::IsNullOrWhiteSpace($spotifyExe) -and (Test-Path $spotifyExe)
    }

    if ($spotifyOk) {
        Write-Host '       Spotify already detected.' -ForegroundColor Green
    }
    elseif (Read-YesNo -Prompt '       Install Spotify via winget?' -DefaultYes $true) {
        $null = Install-Spotify -Silent
    }
    else {
        Write-Host '       Skipped - install Spotify manually before continuing.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Step -Number 2 -Total $totalSteps -Message 'Install Spicetify CLI'
    if (Test-CommandAvailable 'spicetify') {
        Write-Host '       Spicetify CLI already installed.' -ForegroundColor Green
    }
    elseif (Read-YesNo -Prompt '       Install Spicetify now?' -DefaultYes $true) {
        $null = Install-Spicetify -Silent
    }
    else {
        Write-Host '       Cannot continue without Spicetify CLI.' -ForegroundColor Red
        Pause-Script
        return
    }

    if (-not (Test-CommandAvailable 'spicetify')) {
        Write-Host '       Spicetify still not available. Open a new terminal and re-run the wizard.' -ForegroundColor Red
        Pause-Script
        return
    }

    Write-Host ''
    Write-Step -Number 3 -Total $totalSteps -Message 'Import saved config (optional)'
    if (Read-YesNo -Prompt '       Import a Spicetify ZIP backup?' -DefaultYes $false) {
        $null = Import-SpicetifyConfig -Silent
    }

    Write-Host ''
    Write-Step -Number 4 -Total $totalSteps -Message 'First-time apply (backup + apply + devtools)'
    if (Read-YesNo -Prompt '       Run backup, apply, and enable DevTools?' -DefaultYes $true) {
        Stop-SpotifyIfRunning | Out-Null
        $null = Invoke-Spicetify -Arguments @('backup', 'apply', 'enable-devtools') -CloseSpotifyFirst
    }

    Write-Host ''
    Write-Step -Number 5 -Total $totalSteps -Message 'Block Spotify updates'
    if (Read-YesNo -Prompt '       Block Spotify auto-updates?' -DefaultYes $true) {
        $null = Invoke-Spicetify -Arguments @('spotify-updates', 'block')
    }

    Write-Host ''
    Write-Step -Number 6 -Total $totalSteps -Message 'Spicetify Marketplace (optional)'
    if (Read-YesNo -Prompt '       Install Spicetify Marketplace?' -DefaultYes $true) {
        $null = Install-SpicetifyMarketplace -Silent
    }

    Write-Host ''
    Write-Host '  Wizard complete. Restarting Spotify...' -ForegroundColor Cyan
    $null = Invoke-Spicetify -Arguments @('restart')

    Write-Host ''
    Write-Host '  All done. Enjoy your customized Spotify.' -ForegroundColor Green
    Write-Log -Message 'New PC Setup Wizard completed'
    Pause-Script
}

#endregion Status and Wizard

#region Spicetify Actions

function Install-Spicetify {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }

    $ok = Invoke-External -Label 'Installing Spicetify CLI' -Action {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/spicetify/cli/main/install.ps1' | Invoke-Expression
    }

    if (-not $ok) {
        if (-not $Silent) { Pause-Script }
        return $false
    }

    if (-not (Test-CommandAvailable 'spicetify')) {
        $localSpicetify = Join-Path $env:LOCALAPPDATA 'spicetify\spicetify.exe'
        if (Test-Path $localSpicetify) {
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($userPath -notlike "*$env:LOCALAPPDATA\spicetify*") {
                [Environment]::SetEnvironmentVariable('PATH', "$userPath;$env:LOCALAPPDATA\spicetify", 'User')
            }
            $env:PATH = "$env:PATH;$env:LOCALAPPDATA\spicetify"
        }
    }

    if (Test-CommandAvailable 'spicetify') {
        Write-Host ''
        if (Read-YesNo -Prompt '  Run first-time setup now (backup + apply + block updates)?' -DefaultYes $true) {
            Stop-SpotifyIfRunning | Out-Null
            $null = Invoke-Spicetify -Arguments @('backup', 'apply') -CloseSpotifyFirst
            if (Read-YesNo -Prompt '  Block Spotify updates?' -DefaultYes $true) {
                $null = Invoke-Spicetify -Arguments @('spotify-updates', 'block')
            }
        }

        if (Read-YesNo -Prompt '  Install Spicetify Marketplace?' -DefaultYes $true) {
            $null = Install-SpicetifyMarketplace -Silent
        }
    }

    if (-not $Silent) { Pause-Script }
    return $true
}

function Install-SpicetifyMarketplace {
    param([switch]$Silent)

    if (-not (Assert-CommandAvailable 'spicetify')) { return $false }
    if (-not $Silent) { Write-Banner }

    $ok = Invoke-External -Label 'Installing Spicetify Marketplace' -Action {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.ps1' | Invoke-Expression
    }

    if ($ok) {
        $null = Invoke-Spicetify -Arguments @('apply')
    }

    if (-not $Silent) { Pause-Script }
    return $ok
}

function Upgrade-Spicetify {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('upgrade')
    Pause-Script
}

function Apply-Config {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('apply') -CloseSpotifyFirst
    Pause-Script
}

function Restore-Spotify {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('restore') -CloseSpotifyFirst
    Pause-Script
}

function Restart-Spotify {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('restart')
    Pause-Script
}

function Block-Updates {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('spotify-updates', 'block')
    Pause-Script
}

function Unblock-Updates {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('spotify-updates', 'unblock')
    Pause-Script
}

function Repair-AfterSpotifyUpdate {
    Write-Banner
    Write-Host '  Re-applies Spicetify after a Spotify client update.' -ForegroundColor DarkGray
    Write-Host ''
    Stop-SpotifyIfRunning | Out-Null
    $null = Invoke-Spicetify -Arguments @('backup', 'apply') -CloseSpotifyFirst
    Pause-Script
}

function Open-Config {
    Write-Banner
    if (-not (Assert-CommandAvailable 'spicetify')) { return }
    Write-Host '  Opening Spicetify config directory...' -ForegroundColor Yellow
    Write-Log -Message 'Opening spicetify config-dir'
    & spicetify config-dir
    Pause-Script
}

function Backup-Config {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('backup') -CloseSpotifyFirst
    Pause-Script
}

function Clear-Backup {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('clear')
    Pause-Script
}

function Install-Theme {
    Write-Banner

    if (-not (Assert-CommandAvailable 'spicetify')) { return }

    $themesPath = Get-ThemesPath
    $themes = @()

    if ($themesPath) {
        $themes = Get-ChildItem -Path $themesPath -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name |
            Select-Object -ExpandProperty Name
    }

    if ($themes.Count -gt 0) {
        Write-Host '  Available themes:' -ForegroundColor Cyan
        for ($i = 0; $i -lt $themes.Count; $i++) {
            Write-Host ("  {0,2}. {1}" -f ($i + 1), $themes[$i]) -ForegroundColor White
        }
        Write-Host ''
        $pick = Read-Host '  Pick a number (or type a theme name manually)'

        if ($pick -match '^\d+$') {
            $index = [int]$pick - 1
            if ($index -ge 0 -and $index -lt $themes.Count) {
                $theme = $themes[$index]
            }
            else {
                Write-Host '  Invalid number.' -ForegroundColor Red
                Pause-Script
                return
            }
        }
        else {
            $theme = $pick.Trim()
        }
    }
    else {
        Write-Host '  No themes folder found. Enter a theme name manually:' -ForegroundColor Yellow
        $theme = Read-Host '  Theme Name'
    }

    if ([string]::IsNullOrWhiteSpace($theme)) {
        Write-Host '  No theme entered.' -ForegroundColor Red
        Pause-Script
        return
    }

    $null = Invoke-Spicetify -Arguments @('config', 'current_theme', $theme) -CloseSpotifyFirst
    $null = Invoke-Spicetify -Arguments @('apply')
    Write-Host "  Theme '$theme' applied." -ForegroundColor Green
    Pause-Script
}

function Remove-Extension {
    Write-Banner

    if (-not (Assert-CommandAvailable 'spicetify')) { return }

    $raw = (& spicetify config extensions 2>$null | Out-String).Trim()
    $extensions = @()
    if ($raw) {
        $extensions = $raw -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    if ($extensions.Count -gt 0) {
        Write-Host '  Enabled extensions:' -ForegroundColor Cyan
        for ($i = 0; $i -lt $extensions.Count; $i++) {
            Write-Host ("  {0,2}. {1}" -f ($i + 1), $extensions[$i]) -ForegroundColor White
        }
        Write-Host ''
        $pick = Read-Host '  Pick a number to remove (or type the filename)'

        if ($pick -match '^\d+$') {
            $index = [int]$pick - 1
            if ($index -lt 0 -or $index -ge $extensions.Count) {
                Write-Host '  Invalid number.' -ForegroundColor Red
                Pause-Script
                return
            }
            $extension = $extensions[$index]
        }
        else {
            $extension = $pick.Trim()
        }
    }
    else {
        Write-Host '  No extensions are currently enabled.' -ForegroundColor Yellow
        $extension = Read-Host '  Extension filename to remove (e.g. myExt.js)'
    }

    if ([string]::IsNullOrWhiteSpace($extension)) {
        Write-Host '  No extension entered.' -ForegroundColor Red
        Pause-Script
        return
    }

    if ($extension -notmatch '\.js$') {
        $extension = "$extension.js"
    }

    $removeToken = "$extension-"
    $null = Invoke-Spicetify -Arguments @('config', 'extensions', $removeToken) -CloseSpotifyFirst
    $null = Invoke-Spicetify -Arguments @('apply')
    Write-Host "  Extension '$extension' removed." -ForegroundColor Green
    Pause-Script
}

function Show-ThemeAndExtensions {
    Write-Banner

    if (-not (Assert-CommandAvailable 'spicetify')) { return }

    $theme = (& spicetify config current_theme 2>$null | Out-String).Trim()
    $scheme = (& spicetify config color_scheme 2>$null | Out-String).Trim()
    $extensions = (& spicetify config extensions 2>$null | Out-String).Trim()

    Write-Host '  Current theme : ' -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($theme) { $theme } else { '(none)' })
    Write-Host '  Color scheme  : ' -NoNewline -ForegroundColor Cyan
    Write-Host $(if ($scheme) { $scheme } else { '(default)' })
    Write-Host ''
    Write-Host '  Extensions:' -ForegroundColor Cyan

    if ($extensions) {
        $extensions -split '\|' | ForEach-Object {
            $ext = $_.Trim()
            if ($ext) { Write-Host "    - $ext" -ForegroundColor White }
        }
    }
    else {
        Write-Host '    (none enabled)' -ForegroundColor DarkGray
    }

    Pause-Script
}

function Check-Version {
    Write-Banner
    if (-not (Assert-CommandAvailable 'spicetify')) { return }
    Write-Host '  Spicetify version:' -ForegroundColor Cyan
    Write-Log -Message 'Checking spicetify version'
    & spicetify -v
    Pause-Script
}

function Enable-DevTools {
    Write-Banner
    $null = Invoke-Spicetify -Arguments @('enable-devtools') -CloseSpotifyFirst
    Write-Host '  Press Ctrl+Shift+I inside Spotify to open DevTools.' -ForegroundColor DarkGray
    Pause-Script
}

function Export-SpicetifyConfig {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }

    $dataPath = Get-SpicetifyDataPath
    if (-not (Test-Path $dataPath)) {
        Write-Host "  Spicetify data folder not found: $dataPath" -ForegroundColor Red
        if (-not $Silent) { Pause-Script }
        return $false
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
    $defaultZip = Join-Path ([Environment]::GetFolderPath('Desktop')) "spicetify-backup_$timestamp.zip"

    if ($Silent) {
        $zipPath = $defaultZip
    }
    else {
        Write-Host "  Default export path: $defaultZip" -ForegroundColor DarkGray
        $custom = Read-Host '  Press Enter to use default, or type a full path'
        $zipPath = if ([string]::IsNullOrWhiteSpace($custom)) { $defaultZip } else { $custom.Trim() }
    }

    $zipDir = Split-Path $zipPath -Parent
    if (-not (Test-Path $zipDir)) {
        New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    }

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    $ok = Invoke-External -Label "Exporting config to $zipPath" -Action {
        Compress-Archive -Path (Join-Path $dataPath '*') -DestinationPath $zipPath -Force
    }

    if ($ok) {
        Write-Host "  Backup saved to: $zipPath" -ForegroundColor Green
    }

    if (-not $Silent) { Pause-Script }
    return $ok
}

function Import-SpicetifyConfig {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }

    $zipPath = Read-Host '  Path to Spicetify ZIP backup'

    $zipPath = $zipPath.Trim().Trim('"')
    if (-not (Test-Path $zipPath)) {
        Write-Host '  File not found.' -ForegroundColor Red
        if (-not $Silent) { Pause-Script }
        return $false
    }

    $dataPath = Get-SpicetifyDataPath
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
    $safetyBackup = "$dataPath.bak_$timestamp"

    Stop-SpotifyIfRunning | Out-Null

    if (Test-Path $dataPath) {
        Write-Host "  Saving current config to $safetyBackup" -ForegroundColor Yellow
        Copy-Item -Path $dataPath -Destination $safetyBackup -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
    }

    $tempDir = Join-Path $env:TEMP "spicetify-import_$timestamp"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }

    $ok = Invoke-External -Label 'Extracting backup' -Action {
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
    }

    if (-not $ok) {
        if (-not $Silent) { Pause-Script }
        return $false
    }

    $sourceDir = $tempDir
    $nested = Get-ChildItem -Path $tempDir -Directory -ErrorAction SilentlyContinue
    if ($nested.Count -eq 1 -and -not (Test-Path (Join-Path $tempDir 'config-xpui.ini'))) {
        $sourceDir = $nested[0].FullName
    }

    Invoke-External -Label 'Copying config into place' -Action {
        Copy-Item -Path (Join-Path $sourceDir '*') -Destination $dataPath -Recurse -Force
    } | Out-Null

    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-CommandAvailable 'spicetify') {
        $null = Invoke-Spicetify -Arguments @('apply') -CloseSpotifyFirst
    }

    Write-Host '  Config imported successfully.' -ForegroundColor Green
    if (-not $Silent) { Pause-Script }
    return $true
}

#endregion Spicetify Actions

#region App Installers

function Install-Spotify {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }

    $installed = Install-WithWinget -Id 'Spotify.Spotify' -Name 'Spotify' -FallbackUrl 'https://www.spotify.com/download/windows/'
    if (-not $installed -and -not $Silent) {
        Write-Host '  Check browser for Spotify download.' -ForegroundColor Yellow
    }

    if (-not $Silent) { Pause-Script }
    return $installed
}

function Install-BetterDiscord {
    Write-Banner
    $null = Install-FromGitHubExe `
        -Url 'https://github.com/BetterDiscord/Installer/releases/latest/download/BetterDiscord-Windows.exe' `
        -FileName 'BetterDiscord-Windows.exe' `
        -AppName 'BetterDiscord' `
        -FallbackUrl 'https://github.com/BetterDiscord/Installer/releases/latest'
    Write-Host '  BetterDiscord installer launched.' -ForegroundColor Green
    Pause-Script
}

function Install-Vencord {
    Write-Banner
    $null = Install-FromGitHubExe `
        -Url 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstaller.exe' `
        -FileName 'VencordInstaller.exe' `
        -AppName 'Vencord' `
        -FallbackUrl 'https://github.com/Vencord/Installer/releases/latest'
    Write-Host '  Vencord installer launched.' -ForegroundColor Green
    Pause-Script
}

function Install-Landrop {
    Write-Banner
    $null = Install-WithWinget `
        -Id 'LANDrop.LANDrop' `
        -Name 'LANDrop' `
        -FallbackIds @('CoolPlayLin.Installer.LANDrop', 'SkyArc.LANDrop') `
        -FallbackUrl 'https://landrop.app/'
    Pause-Script
}

function Install-AweSun {
    Write-Banner
    Write-Host '  AweSun is a free remote desktop app - control your PC from anywhere.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  [1] Auto-install via winget' -ForegroundColor White
    Write-Host '  [2] Open download page' -ForegroundColor White
    Write-Host ''

    $choice = Read-MenuChoice -Prompt 'Select option'
    Write-Log -Message "AweSun install option: $choice"

    if ($choice -eq '2') {
        Open-BrowserFallback -Url 'https://awesun.aweray.com/en/download' -AppName 'AweSun' | Out-Null
        Pause-Script
        return
    }

    if (-not (Test-CommandAvailable 'winget')) {
        Write-Host '  winget not available. Opening download page...' -ForegroundColor Yellow
        Open-BrowserFallback -Url 'https://awesun.aweray.com/en/download' -AppName 'AweSun' | Out-Null
        Pause-Script
        return
    }

    Write-Host '  Trying winget install Oray.AweSun...' -ForegroundColor Yellow
    & winget install -e --id Oray.AweSun --accept-package-agreements --accept-source-agreements --silent
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Host '  winget install failed. Opening download page...' -ForegroundColor Yellow
        Write-Log -Message 'AweSun winget failed, using browser fallback' -Level 'WARN'
        Open-BrowserFallback -Url 'https://awesun.aweray.com/en/download' -AppName 'AweSun' | Out-Null
    }
    else {
        Write-Host '  AweSun install command completed.' -ForegroundColor Green
        Write-Log -Message 'AweSun winget install completed'
    }

    Pause-Script
}

function Install-OffHelper {
    Write-Banner
    Write-Host '  OFF lets you shut down or sleep this PC from your phone (iOS/Android).' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  [1] Auto-download and extract' -ForegroundColor White
    Write-Host '  [2] Open website' -ForegroundColor White
    Write-Host ''

    $choice = Read-MenuChoice -Prompt 'Select option'
    Write-Log -Message "OFF Helper install option: $choice"

    if ($choice -eq '2') {
        Open-BrowserFallback -Url 'https://www.bridgetech.io/Off.html' -AppName 'OFF Helper' | Out-Null
        Pause-Script
        return
    }

    $zipPath = Join-Path $env:TEMP 'OffWindows_Latest.zip'
    $extractPath = Join-Path $env:TEMP 'OffHelper'

    $ok = Invoke-External -Label 'Downloading OFF Helper' -Action {
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Invoke-WebRequest -Uri 'https://www.bridgetech.io/OffWindows_Latest.zip' -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    }

    if (-not $ok) {
        Write-Host '  Download or extract failed. Opening website...' -ForegroundColor Yellow
        Open-BrowserFallback -Url 'https://www.bridgetech.io/Off.html' -AppName 'OFF Helper' | Out-Null
        Pause-Script
        return
    }

    $exe = Get-ChildItem -Path $extractPath -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object -First 1

    if ($exe) {
        Write-Host "  Launching: $($exe.FullName)" -ForegroundColor Green
        Write-Log -Message "OFF Helper launched: $($exe.FullName)"
        Start-Process $exe.FullName
        Write-Host ''
        Write-Host '  Reminder: Install the OFF app on your phone and set a password in Helper settings.' -ForegroundColor Cyan
    }
    else {
        Write-Host '  No .exe found after extraction. Opening website...' -ForegroundColor Yellow
        Open-BrowserFallback -Url 'https://www.bridgetech.io/Off.html' -AppName 'OFF Helper' | Out-Null
    }

    Pause-Script
}

function Install-Firefox {
    Write-Banner
    $null = Install-WithWinget -Id 'Mozilla.Firefox' -Name 'Firefox' -FallbackUrl 'https://www.mozilla.org/firefox/'
    Prompt-DefaultBrowser
    Pause-Script
}

function Install-Brave {
    Write-Banner
    if (Test-CommandAvailable 'winget') {
        Invoke-External -Label 'Verifying Brave winget package ID' -Action {
            & winget show BraveSoftware.Brave --accept-source-agreements
        } | Out-Null
    }
    $null = Install-WithWinget -Id 'BraveSoftware.Brave' -Name 'Brave' -FallbackUrl 'https://laptop-updates.brave.com/download/BRV010?bitness=64'
    Prompt-DefaultBrowser
    Pause-Script
}

function Install-Chrome {
    Write-Banner
    $null = Install-WithWinget -Id 'Google.Chrome' -Name 'Google Chrome' -FallbackUrl 'https://www.google.com/chrome/'
    Prompt-DefaultBrowser
    Pause-Script
}

function Install-Steam {
    Write-Banner
    $null = Install-WithWinget -Id 'Valve.Steam' -Name 'Steam' -FallbackUrl 'https://store.steampowered.com/about/'
    Pause-Script
}

function Install-EpicGames {
    Write-Banner
    $null = Install-WithWinget -Id 'EpicGames.EpicGamesLauncher' -Name 'Epic Games Launcher' -FallbackUrl 'https://store.epicgames.com/download'
    Pause-Script
}

function Install-Git {
    Write-Banner
    $null = Install-WithWinget -Id 'Git.Git' -Name 'Git' -FallbackUrl 'https://git-scm.com/download/win'
    Pause-Script
}

function Install-VSCode {
    Write-Banner
    $null = Install-WithWinget -Id 'Microsoft.VisualStudioCode' -Name 'VS Code' -FallbackUrl 'https://code.visualstudio.com/download'
    Pause-Script
}

function Install-NodeJs {
    Write-Banner
    $null = Install-WithWinget -Id 'OpenJS.NodeJS.LTS' -Name 'Node.js LTS' -FallbackUrl 'https://nodejs.org/'
    Pause-Script
}

function Install-WindowsTerminal {
    Write-Banner
    $null = Install-WithWinget -Id 'Microsoft.WindowsTerminal' -Name 'Windows Terminal' -FallbackUrl 'https://apps.microsoft.com/store/detail/windows-terminal/9N0DX20HK701'
    Pause-Script
}

function Install-7Zip {
    Write-Banner
    $null = Install-WithWinget -Id '7zip.7zip' -Name '7-Zip' -FallbackUrl 'https://www.7-zip.org/'
    Pause-Script
}

function Install-AppBatch {
    param(
        [array]$Apps,
        [string]$BatchName
    )

    Write-Banner
    Write-Host "  $BatchName" -ForegroundColor Cyan
    Write-Log -Message "Batch install started: $BatchName"

    foreach ($app in $Apps) {
        Write-Host ''
        Write-Host "  --- $($app.Name) ---" -ForegroundColor DarkGray
        Install-WithWinget -Id $app.Id -Name $app.Name -FallbackUrl $app.Url | Out-Null
    }

    Write-Host ''
    Write-Host '  Batch install finished.' -ForegroundColor Green
    Write-Log -Message "Batch install finished: $BatchName"
    Pause-Script
}

function Install-AllDevTools {
    Install-AppBatch -BatchName 'Installing all dev tools (Git, VS Code, Node.js, Terminal, 7-Zip)' -Apps @(
        @{ Id = 'Git.Git'; Name = 'Git'; Url = 'https://git-scm.com/download/win' }
        @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code'; Url = 'https://code.visualstudio.com/download' }
        @{ Id = 'OpenJS.NodeJS.LTS'; Name = 'Node.js LTS'; Url = 'https://nodejs.org/' }
        @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal'; Url = 'https://apps.microsoft.com/store/detail/windows-terminal/9N0DX20HK701' }
        @{ Id = '7zip.7zip'; Name = '7-Zip'; Url = 'https://www.7-zip.org/' }
    )
}

function Install-AllGamingLaunchers {
    Install-AppBatch -BatchName 'Installing Steam and Epic Games Launcher' -Apps @(
        @{ Id = 'Valve.Steam'; Name = 'Steam'; Url = 'https://store.steampowered.com/about/' }
        @{ Id = 'EpicGames.EpicGamesLauncher'; Name = 'Epic Games Launcher'; Url = 'https://store.epicgames.com/download' }
    )
}

#endregion App Installers

#region App and Repo Installer

<#
NO STALE VERSION RULE FOR THIS MODULE
- Do not hardcode pinned app versions, tag names, dated files, or versioned download links.
- Prefer winget package IDs with no version argument so winget resolves the current release.
- For GitHub-hosted installers, only use the permanent /releases/latest/download/<asset> redirect.
- If a vendor does not expose a direct latest download, open the provided permanent download page instead.
#>

function Get-AppRepoInstallItems {
    return @(
        @{ Key = 'budget'; Name = 'Budget (packaged app)'; Type = 'BudgetApp'; Notes = 'Resolves the latest Budget Windows installer from GitHub Releases at install time.' }
        @{ Key = 'brave'; Name = 'Brave Browser'; Type = 'Winget'; Id = 'BraveSoftware.Brave'; FallbackUrl = 'https://laptop-updates.brave.com/download/BRV010?bitness=64'; Notes = 'Verifies winget package ID before install; uses Brave stable endpoint only if winget cannot install.' }
        @{ Key = 'teams'; Name = 'Microsoft Teams'; Type = 'Winget'; Id = 'Microsoft.Teams'; Notes = 'Installs latest available Teams package from winget.' }
        @{ Key = 'vencord'; Name = 'Vencord'; Type = 'GitHubExe'; Url = 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstaller.exe'; FileName = 'VencordInstaller.exe'; Notes = 'Downloads latest GUI installer, launches it, then removes the temp exe after it exits.' }
        @{ Key = 'betterdiscord'; Name = 'BetterDiscord'; Type = 'BetterDiscord'; Url = 'https://github.com/BetterDiscord/Installer/releases/latest/download/BetterDiscord-Windows.exe'; FileName = 'BetterDiscord-Windows.exe'; Notes = 'Closes Discord first, then runs the latest installer silently with /S.' }
        @{ Key = 'insta360'; Name = 'Insta360 Link2 Pro'; Type = 'BrowserPage'; Url = 'https://www.insta360.com/download/insta360-link2pro'; Notes = 'Opens vendor download page; this one requires a manual download click.' }
    )
}

function Get-AppRepoRepos {
    return @(
        @{ Name = 'SulimanZ-Dev/Budget'; Url = 'https://github.com/SulimanZ-Dev/Budget.git'; SupportsPackagedApp = $true; Notes = 'Choose clone source or install latest packaged app after selecting.' }
        @{ Name = 'SulimanZ-Dev/NewSetupHelper'; Url = 'https://github.com/SulimanZ-Dev/NewSetupHelper.git' }
        @{ Name = 'SulimanZ-Dev/SalaryCalculatorLager'; Url = 'https://github.com/SulimanZ-Dev/SalaryCalculatorLager.git' }
    )
}

function Select-ChecklistItems {
    param(
        [array]$Items,
        [string]$Title,
        [string]$NameProperty = 'Name'
    )

    Write-Banner
    Write-ThemedHost "  $Title" 'Accent'
    Write-ThemedHost '  -----------------------------------------------------' 'Muted'
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-ThemedHost ("  [{0}] {1}" -f ($i + 1), $Items[$i].$NameProperty) 'Foreground'
        if ($Items[$i].Notes) {
            Write-ThemedHost ("      {0}" -f $Items[$i].Notes) 'Muted'
        }
    }
    Write-ThemedHost ''
    Write-ThemedHost '  Enter numbers separated by commas, or type all.' 'Muted'
    $raw = Read-MenuChoice -Prompt 'Select'

    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    if ($raw -match '^(?i)all$') { return @($Items) }

    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($part in ($raw -split ',')) {
        $index = 0
        if ([int]::TryParse($part.Trim(), [ref]$index) -and $index -ge 1 -and $index -le $Items.Count) {
            $item = $Items[$index - 1]
            if (-not $selected.Contains($item)) { $selected.Add($item) }
        }
        else {
            Write-ThemedHost "  Ignored invalid selection: $part" 'Warning'
        }
    }

    return $selected.ToArray()
}

function Invoke-WingetLatestInstall {
    param(
        [string]$Id,
        [string]$Name,
        [string]$FallbackUrl = '',
        [switch]$VerifyFirst
    )

    if (-not (Test-CommandAvailable 'winget')) {
        Write-ThemedHost "  winget not found. Cannot install $Name via winget." 'Error'
        if ($FallbackUrl) {
            Write-ThemedHost "  Opening fallback URL for $Name." 'Warning'
            return (Open-BrowserFallback -Url $FallbackUrl -AppName $Name)
        }
        return $false
    }

    if ($VerifyFirst) {
        $shown = Invoke-External -Label "Verifying winget ID $Id" -Action {
            & winget show $Id --accept-source-agreements
        }
        if (-not $shown -and $FallbackUrl) {
            Write-ThemedHost "  Package ID verification failed for $Name; opening fallback URL." 'Warning'
            return (Open-BrowserFallback -Url $FallbackUrl -AppName $Name)
        }
        elseif (-not $shown) {
            return $false
        }
    }

    return (Invoke-External -Label "Installing $Name via winget ($Id)" -Action {
        & winget install $Id --silent --accept-package-agreements --accept-source-agreements
    })
}

function Invoke-DownloadedInstaller {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$Name,
        [string[]]$ArgumentList = @(),
        [switch]$Wait
    )

    $installer = Join-Path $env:TEMP $FileName
    try {
        Write-ThemedHost "  Downloading $Name from $Url" 'Warning'
        Invoke-WebRequest -Uri $Url -OutFile $installer -UseBasicParsing -ErrorAction Stop
        $processArgs = @{
            FilePath = $installer
        }
        if ($ArgumentList.Count -gt 0) { $processArgs.ArgumentList = $ArgumentList }
        if ($Wait) { $processArgs.Wait = $true }
        Start-Process @processArgs
        Write-ThemedHost "  $Name installer completed/launched." 'Success'
        return $true
    }
    catch {
        Write-ThemedHost "  $Name failed: $($_.Exception.Message)" 'Error'
        Write-Log -Message "$Name installer failed: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
    finally {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-BudgetReleaseInstallerAsset {
    <#
    Budget does not have a confirmed stable release asset filename. Unlike Vencord and BetterDiscord,
    do not replace this with a guessed /latest/download/<filename> URL. Resolve the latest release via
    GitHub's API and use the browser_download_url returned for the current .exe asset.
    #>
    $apiUrl = 'https://api.github.com/repos/SulimanZ-Dev/Budget/releases/latest'

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'Spicetify-PC-Setup-Helper' } -ErrorAction Stop
        if (-not $release.assets) {
            throw 'latest release has no assets'
        }

        $exeAssets = @($release.assets | Where-Object { $_.name -match '\.exe$' })
        if ($exeAssets.Count -eq 0) {
            throw 'latest release has no .exe asset'
        }

        $preferred = @($exeAssets | Where-Object { $_.name -match '(?i)(setup|install)' } | Select-Object -First 1)
        if ($preferred.Count -gt 0) {
            return $preferred[0]
        }

        return $exeAssets[0]
    }
    catch {
        throw "Could not resolve latest Budget release: $($_.Exception.Message)"
    }
}

function Install-BudgetApp {
    $asset = $null
    try {
        Write-ThemedHost '  Resolving latest Budget release from GitHub...' 'Warning'
        $asset = Resolve-BudgetReleaseInstallerAsset
    }
    catch {
        Write-ThemedHost "  $($_.Exception.Message)" 'Error'
        Write-Log -Message $_.Exception.Message -Level 'ERROR'
        return $false
    }

    $safeFileName = Split-Path -Leaf $asset.name
    if ([string]::IsNullOrWhiteSpace($safeFileName)) { $safeFileName = 'BudgetInstaller.exe' }
    $installer = Join-Path $env:TEMP $safeFileName

    try {
        Write-ThemedHost "  Downloading Budget installer: $($asset.name)" 'Warning'
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer -UseBasicParsing -ErrorAction Stop

        Write-ThemedHost '  Running Budget installer silently...' 'Warning'
        $silentProcess = Start-Process -FilePath $installer -ArgumentList '/S' -Wait -PassThru
        if ($silentProcess.ExitCode -eq 0) {
            Write-ThemedHost '  Budget installer completed silently.' 'Success'
            return $true
        }

        Write-ThemedHost "  Silent install returned exit code $($silentProcess.ExitCode). Launching interactive installer instead." 'Warning'
        Start-Process -FilePath $installer -Wait
        Write-ThemedHost '  Budget interactive installer closed.' 'Success'
        return $true
    }
    catch {
        Write-ThemedHost "  Budget install failed: $($_.Exception.Message)" 'Error'
        Write-Log -Message "Budget install failed: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
    finally {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-AppRepoAppInstall {
    param([hashtable]$App)

    switch ($App.Type) {
        'BudgetApp' {
            return (Install-BudgetApp)
        }
        'Winget' {
            return (Invoke-WingetLatestInstall -Id $App.Id -Name $App.Name -FallbackUrl $App.FallbackUrl -VerifyFirst:($App.Key -eq 'brave'))
        }
        'GitHubExe' {
            return (Invoke-DownloadedInstaller -Url $App.Url -FileName $App.FileName -Name $App.Name -Wait)
        }
        'BetterDiscord' {
            Get-Process -Name 'Discord' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            return (Invoke-DownloadedInstaller -Url $App.Url -FileName $App.FileName -Name $App.Name -ArgumentList @('/S') -Wait)
        }
        'BrowserPage' {
            # Insta360 does not publish a direct latest installer endpoint, so open the permanent vendor page for manual download.
            return (Open-BrowserFallback -Url $App.Url -AppName $App.Name)
        }
        default {
            Write-ThemedHost "  Unknown app type for $($App.Name)." 'Error'
            return $false
        }
    }
}

function Start-AppRepoAppInstaller {
    $apps = Get-AppRepoInstallItems
    $selected = @(Select-ChecklistItems -Items $apps -Title 'Select apps to install')
    if ($selected.Count -eq 0) {
        Write-ThemedHost '  No apps selected.' 'Warning'
        Pause-Script
        return
    }

    Write-Banner
    Write-ThemedHost '  INSTALL SUMMARY' 'Accent'
    Write-ThemedHost '  -----------------------------------------------------' 'Muted'
    foreach ($app in $selected) {
        Write-ThemedHost "  - $($app.Name)" 'Foreground'
        Write-ThemedHost "    $($app.Notes)" 'Muted'
    }
    Write-ThemedHost ''
    if (-not (Read-YesNo -Prompt '  Install these apps now?' -DefaultYes $false)) {
        Write-ThemedHost '  Cancelled. Nothing was installed.' 'Warning'
        Pause-Script
        return
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($app in $selected) {
        Write-ThemedHost ''
        Write-ThemedHost "  --- $($app.Name) ---" 'Muted'
        $ok = Invoke-AppRepoAppInstall -App $app
        $results.Add(@{ Name = $app.Name; Success = $ok })
    }

    Write-ThemedHost ''
    Write-ThemedHost '  FINAL APP INSTALL SUMMARY' 'Accent'
    foreach ($result in $results) {
        Write-OpResult -Label $result.Name -Success $result.Success
    }
    Pause-Script
}

function Ensure-GitAvailableForClone {
    if (Test-CommandAvailable 'git') {
        Invoke-External -Label 'Checking git version' -Action { & git --version } | Out-Null
        return $true
    }

    Write-ThemedHost '  git was not found. Git is required before cloning repositories.' 'Error'
    if (-not (Read-YesNo -Prompt '  Install Git via winget now?' -DefaultYes $true)) {
        return $false
    }

    $installed = Invoke-WingetLatestInstall -Id 'Git.Git' -Name 'Git'
    if (-not $installed) { return $false }

    Write-ThemedHost '  Re-checking git availability...' 'Warning'
    if (Test-CommandAvailable 'git') {
        Invoke-External -Label 'Checking git version' -Action { & git --version } | Out-Null
        return $true
    }

    Write-ThemedHost '  Git installed, but git is not available in this terminal yet. Open a new terminal and try again.' 'Error'
    return $false
}

function Select-BudgetRepoMode {
    while ($true) {
        Write-Banner
        Write-ThemedHost '  Budget install mode' 'Accent'
        Write-ThemedHost '  -----------------------------------------------------' 'Muted'
        Write-ThemedHost '  [1] Clone source (git clone)' 'Foreground'
        Write-ThemedHost '  [2] Install packaged app (latest GitHub Release EXE)' 'Foreground'
        Write-ThemedHost ''

        switch (Read-MenuChoice -Prompt 'Select mode') {
            '1' { return 'Clone' }
            '2' { return 'Install' }
            default {
                Write-ThemedHost '  Invalid choice.' 'Error'
                Pause-Script
            }
        }
    }
}

function Start-AppRepoRepoClone {

    $repos = Get-AppRepoRepos
    $selected = @(Select-ChecklistItems -Items $repos -Title 'Select GitHub repo actions')
    if ($selected.Count -eq 0) {
        Write-ThemedHost '  No repos selected.' 'Warning'
        Pause-Script
        return
    }

    $actions = New-Object System.Collections.Generic.List[object]
    foreach ($repo in $selected) {
        if ($repo.SupportsPackagedApp) {
            $mode = Select-BudgetRepoMode
            if ($mode -eq 'Install') {
                $actions.Add(@{
                    Type = 'BudgetApp'
                    Name = 'SulimanZ-Dev/Budget (packaged app)'
                    Detail = 'Will download and install the latest Budget release from GitHub.'
                })
            }
            else {
                $actions.Add(@{
                    Type = 'Clone'
                    Name = $repo.Name
                    Url = $repo.Url
                    Detail = "Will clone $($repo.Url)."
                })
            }
        }
        else {
            $actions.Add(@{
                Type = 'Clone'
                Name = $repo.Name
                Url = $repo.Url
                Detail = "Will clone $($repo.Url)."
            })
        }
    }

    $cloneActions = @($actions | Where-Object { $_.Type -eq 'Clone' })
    $dest = ''
    if ($cloneActions.Count -gt 0) {
        if (-not (Ensure-GitAvailableForClone)) {
            Pause-Script
            return
        }

        $defaultDest = Join-Path $HOME 'Source'
        $dest = Read-Host "  Destination folder [$defaultDest]"
        if ([string]::IsNullOrWhiteSpace($dest)) { $dest = $defaultDest }
        $dest = [Environment]::ExpandEnvironmentVariables($dest)
    }

    Write-Banner
    Write-ThemedHost '  REPO ACTION SUMMARY' 'Accent'
    Write-ThemedHost '  -----------------------------------------------------' 'Muted'
    if ($cloneActions.Count -gt 0) {
        Write-ThemedHost "  Clone destination: $dest" 'Foreground'
    }
    foreach ($action in $actions) {
        Write-ThemedHost "  - $($action.Name)" 'Foreground'
        Write-ThemedHost "    $($action.Detail)" 'Muted'
    }
    Write-ThemedHost ''
    if (-not (Read-YesNo -Prompt '  Run these repo actions now?' -DefaultYes $false)) {
        Write-ThemedHost '  Cancelled. Nothing was cloned or installed.' 'Warning'
        Pause-Script
        return
    }

    if ($cloneActions.Count -gt 0) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($action in $actions) {
        if ($action.Type -eq 'BudgetApp') {
            $ok = Install-BudgetApp
        }
        else {
            $ok = Invoke-External -Label "Cloning $($action.Name)" -Action {
                & git -C $dest clone $($action.Url)
            }
        }
        $results.Add(@{ Name = $action.Name; Success = $ok })
    }

    Write-ThemedHost ''
    Write-ThemedHost '  FINAL REPO ACTION SUMMARY' 'Accent'
    foreach ($result in $results) {
        Write-OpResult -Label $result.Name -Success $result.Success
    }
    Pause-Script
}

#endregion App and Repo Installer

#region Privacy Tweaks

function Disable-Telemetry {
    param([switch]$Silent)

    if (-not $Silent -and -not (Assert-AdminForSystemChanges)) { return }
    if ($Silent -and -not (Test-IsAdmin)) { return }

    if (-not $Silent) { Write-Banner }
    Write-Host '  Disabling telemetry and data collection...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: disable telemetry'

    Write-OpResult -Label 'Set AllowTelemetry = 0' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -CreatePath
    )

    try {
        Stop-Service -Name 'DiagTrack' -Force -ErrorAction SilentlyContinue
        Set-Service -Name 'DiagTrack' -StartupType Disabled -ErrorAction SilentlyContinue
        Write-OpResult -Label 'Disable DiagTrack service' -Success $true
    }
    catch {
        Write-OpResult -Label 'Disable DiagTrack service' -Success $false
    }

    try {
        Stop-Service -Name 'dmwappushservice' -Force -ErrorAction SilentlyContinue
        Set-Service -Name 'dmwappushservice' -StartupType Disabled -ErrorAction SilentlyContinue
        Write-OpResult -Label 'Disable dmwappushservice' -Success $true
    }
    catch {
        Write-OpResult -Label 'Disable dmwappushservice' -Success $false
    }

    Write-Host ''
    Write-Host '  Some changes require a restart to take full effect.' -ForegroundColor Yellow
    if (-not $Silent) { Pause-Script }
}

function Remove-BloatwareApps {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }

    $packages = @(
        'Microsoft.BingWeather',
        'Microsoft.BingNews',
        'Microsoft.GetHelp',
        'Microsoft.Getstarted',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.People',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.Xbox.TCUI',
        'Microsoft.XboxApp',
        'Microsoft.XboxGameOverlay',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxIdentityProvider',
        'Microsoft.XboxSpeechToTextOverlay',
        'Microsoft.ZuneMusic',
        'Microsoft.ZuneVideo',
        'Microsoft.YourPhone',
        'Microsoft.WindowsMaps',
        'Microsoft.3DBuilder'
    )

    Write-Host '  The following apps may be removed for the current user:' -ForegroundColor Cyan
    foreach ($pkg in $packages) {
        Write-Host "    - $pkg" -ForegroundColor DarkGray
    }
    Write-Host ''

    if (-not $Silent) {
        if (-not (Read-YesNo -Prompt '  This will uninstall these apps. Continue?' -DefaultYes $false)) {
            return
        }
    }

    Write-Log -Message 'Privacy: remove bloatware'
    foreach ($pkg in $packages) {
        try {
            $installed = Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue
            if ($installed) {
                Remove-AppxPackage -Package $installed.PackageFullName -ErrorAction Stop
                Write-Host "  OK   Removed $pkg" -ForegroundColor Green
                Write-Log -Message "Removed appx: $pkg"
            }
            else {
                Write-Host "  SKIP $pkg (not installed)" -ForegroundColor Yellow
                Write-Log -Message "Skipped appx (not installed): $pkg" -Level 'WARN'
            }
        }
        catch {
            Write-Host "  FAIL $pkg - $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Message "Failed to remove $pkg : $($_.Exception.Message)" -Level 'ERROR'
        }
    }

    if (-not $Silent) { Pause-Script }
}

function Disable-WindowsAds {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }
    Write-Host '  Disabling Windows ads and suggestions...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: disable ads'

    $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $settings = @{
        'RotatingLockScreenOverlaysEnabled' = 0
        'SubscribedContent-338387Enabled'   = 0
        'SubscribedContent-338388Enabled'   = 0
        'SystemPaneSuggestionsEnabled'      = 0
        'SubscribedContent-338389Enabled'   = 0
        'SoftLandingEnabled'                  = 0
    }

    foreach ($key in $settings.Keys) {
        Write-OpResult -Label "Set $key = $($settings[$key])" -Success (
            Set-RegistryDword -Path $cdm -Name $key -Value $settings[$key]
        )
    }

    Write-Host ''
    Write-Host '  Some changes require a restart to take full effect.' -ForegroundColor Yellow
    if (-not $Silent) { Pause-Script }
}

function Disable-BingInStartMenu {
    param([switch]$Silent)

    if (-not $Silent) { Write-Banner }
    Write-Host '  Disabling Bing search suggestions in Start Menu...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: disable Bing in Start'

    $path = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
    Write-OpResult -Label 'DisableSearchBoxSuggestions = 1' -Success (
        Set-RegistryDword -Path $path -Name 'DisableSearchBoxSuggestions' -Value 1 -CreatePath
    )

    Write-Host ''
    Write-Host '  Some changes require a restart to take full effect.' -ForegroundColor Yellow
    if (-not $Silent) { Pause-Script }
}

function Disable-ActivityAndLocation {
    param([switch]$Silent)

    if (-not $Silent -and -not (Assert-AdminForSystemChanges)) { return }
    if ($Silent -and -not (Test-IsAdmin)) { return }

    if (-not $Silent) { Write-Banner }
    Write-Host '  Disabling activity history and location...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: disable activity and location'

    Write-OpResult -Label 'EnableActivityFeed = 0' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableActivityFeed' -Value 0 -CreatePath
    )
    Write-OpResult -Label 'PublishUserActivities = 0' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -CreatePath
    )
    Write-OpResult -Label 'DisableLocation = 1' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1 -CreatePath
    )

    Write-Host ''
    Write-Host '  Some changes require a restart to take full effect.' -ForegroundColor Yellow
    if (-not $Silent) { Pause-Script }
}

function Disable-Cortana {
    param([switch]$Silent)

    if (-not $Silent -and -not (Assert-AdminForSystemChanges)) { return }
    if ($Silent -and -not (Test-IsAdmin)) { return }

    if (-not $Silent) { Write-Banner }
    Write-Host '  Disabling Cortana...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: disable Cortana'

    Write-OpResult -Label 'AllowCortana = 0' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 -CreatePath
    )

    Write-Host ''
    Write-Host '  Some changes require a restart to take full effect.' -ForegroundColor Yellow
    if (-not $Silent) { Pause-Script }
}

function Apply-AllPrivacyTweaks {
    Write-Banner
    Write-Host '  Applying all privacy tweaks (1-6)...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: apply all tweaks'

    if (-not (Read-YesNo -Prompt '  Apply all privacy tweaks now?' -DefaultYes $false)) {
        return
    }

    if (Test-IsAdmin) {
        Disable-Telemetry -Silent
        Disable-ActivityAndLocation -Silent
        Disable-Cortana -Silent
    }
    else {
        Write-Host '  Skipping HKLM tweaks (telemetry, activity, Cortana) - not admin.' -ForegroundColor Yellow
        Write-Log -Message 'Skipped HKLM privacy tweaks - not admin' -Level 'WARN'
    }

    if (Read-YesNo -Prompt '  Include bloatware removal (option 2)?' -DefaultYes $false) {
        Remove-BloatwareApps -Silent
    }

    Disable-WindowsAds -Silent
    Disable-BingInStartMenu -Silent

    Write-Host ''
    Write-Host '  All available privacy tweaks applied.' -ForegroundColor Green
    Write-Host '  Some changes require a restart to take full effect.' -ForegroundColor Yellow
    Pause-Script
}

function Restore-PrivacyDefaults {
    if (-not (Read-YesNo -Prompt '  This will undo all privacy tweaks. Continue?' -DefaultYes $false)) {
        return
    }

    if (-not (Assert-AdminForSystemChanges)) { return }

    Write-Banner
    Write-Host '  Restoring Windows privacy defaults...' -ForegroundColor Cyan
    Write-Log -Message 'Privacy: restore defaults'

    Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' | Out-Null
    Write-OpResult -Label 'Remove AllowTelemetry policy' -Success $true

    try {
        Set-Service -Name 'DiagTrack' -StartupType Automatic -ErrorAction SilentlyContinue
        Write-OpResult -Label 'Re-enable DiagTrack' -Success $true
    }
    catch {
        Write-OpResult -Label 'Re-enable DiagTrack' -Success $false
    }

    try {
        Set-Service -Name 'dmwappushservice' -StartupType Manual -ErrorAction SilentlyContinue
        Write-OpResult -Label 'Re-enable dmwappushservice' -Success $true
    }
    catch {
        Write-OpResult -Label 'Re-enable dmwappushservice' -Success $false
    }

    $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($name in @(
            'RotatingLockScreenOverlaysEnabled',
            'SubscribedContent-338387Enabled',
            'SubscribedContent-338388Enabled',
            'SystemPaneSuggestionsEnabled',
            'SubscribedContent-338389Enabled',
            'SoftLandingEnabled'
        )) {
        Write-OpResult -Label "Restore $name" -Success (Set-RegistryDword -Path $cdm -Name $name -Value 1)
    }

    Write-OpResult -Label 'DisableSearchBoxSuggestions = 0' -Success (
        Set-RegistryDword -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 0 -CreatePath
    )

    Write-OpResult -Label 'EnableActivityFeed = 1' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableActivityFeed' -Value 1 -CreatePath
    )
    Write-OpResult -Label 'PublishUserActivities = 1' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 1 -CreatePath
    )
    Write-OpResult -Label 'DisableLocation = 0' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 0 -CreatePath
    )
    Write-OpResult -Label 'AllowCortana = 1' -Success (
        Set-RegistryDword -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 1 -CreatePath
    )

    Write-Host ''
    Write-Host '  Defaults restored. A restart is recommended.' -ForegroundColor Green
    Pause-Script
}

#endregion Privacy Tweaks

#region Power and Sleep

function Set-ShutdownTimer {
    Write-Banner
    $minutes = Read-PositiveInteger -Prompt '  Shut down in how many minutes? '
    $seconds = $minutes * 60

    Write-Log -Message "Shutdown timer set: $minutes minutes"
    $ok = Invoke-External -Label "Scheduling shutdown in $minutes minutes" -Action {
        shutdown /s /t $seconds /c "Scheduled by spicetify-app.ps1"
    }

    if ($ok) {
        Write-Host "  PC will shut down in $minutes minutes. Cancel with Power menu option [3]." -ForegroundColor Cyan
    }
    Pause-Script
}

function Set-SleepTimer {
    Write-Banner
    $minutes = Read-PositiveInteger -Prompt '  Sleep in how many minutes? '
    $delay = $minutes * 60

    Get-Job -Name $script:SleepTimerJobName -ErrorAction SilentlyContinue | Stop-Job -ErrorAction SilentlyContinue
    Get-Job -Name $script:SleepTimerJobName -ErrorAction SilentlyContinue | Remove-Job -ErrorAction SilentlyContinue

    Write-Log -Message "Sleep timer set: $minutes minutes"
    Start-Job -Name $script:SleepTimerJobName -ScriptBlock {
        param($Seconds)
        Start-Sleep -Seconds $Seconds
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Application]::SetSuspendState(
            [System.Windows.Forms.PowerState]::Suspend,
            $false,
            $false
        )
    } -ArgumentList $delay | Out-Null

    Write-Host "  PC will sleep in $minutes minutes. Cancel with Power menu option [3]." -ForegroundColor Cyan
    Pause-Script
}

function Cancel-PowerTimers {
    Write-Banner
    Write-Log -Message 'Cancel power timers'

    $shutdownCancelled = $false
    try {
        shutdown /a
        if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq 0) {
            $shutdownCancelled = $true
            Write-Host '  Shutdown timer cancelled.' -ForegroundColor Green
        }
    }
    catch {
        Write-Host '  No shutdown timer was active.' -ForegroundColor Yellow
    }

    $jobs = Get-Job -Name $script:SleepTimerJobName -ErrorAction SilentlyContinue
    if ($jobs) {
        $jobs | Stop-Job -ErrorAction SilentlyContinue
        $jobs | Remove-Job -ErrorAction SilentlyContinue
        Write-Host '  Sleep timer job stopped.' -ForegroundColor Green
        Write-Log -Message 'Sleep timer job cancelled'
    }
    elseif (-not $shutdownCancelled) {
        Write-Host '  No active timer found.' -ForegroundColor Yellow
    }

    Pause-Script
}

function Switch-PowerPlan {
    Write-Banner
    Write-Host '  [1] Balanced (default)' -ForegroundColor White
    Write-Host '  [2] High Performance' -ForegroundColor White
    Write-Host '  [3] Power Saver' -ForegroundColor White
    Write-Host '  [4] Ultimate Performance' -ForegroundColor White
    Write-Host ''

    $choice = Read-MenuChoice -Prompt 'Select power plan'
    $plans = @{
        '1' = @{ Name = 'Balanced';             Guid = '381b4222-f694-41f0-9685-ff5bb260df2e' }
        '2' = @{ Name = 'High Performance';     Guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
        '3' = @{ Name = 'Power Saver';          Guid = 'a1841308-3541-4fab-bc81-f71556f20b4a' }
        '4' = @{ Name = 'Ultimate Performance'; Guid = 'e9a42b02-d5df-448d-aa00-03f14749eb61' }
    }

    if (-not $plans.ContainsKey($choice)) {
        Write-Host '  Invalid choice.' -ForegroundColor Red
        Pause-Script
        return
    }

    $plan = $plans[$choice]
    Write-Log -Message "Switch power plan: $($plan.Name)"

    if ($choice -eq '4') {
        $dupOk = Invoke-External -Label 'Enabling Ultimate Performance plan' -Action {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
        } -IgnoreExitCode

        if (-not $dupOk) {
            Write-Host '  Ultimate Performance not available on this edition.' -ForegroundColor Yellow
            Pause-Script
            return
        }
    }

    $null = Invoke-External -Label "Activating $($plan.Name)" -Action {
        powercfg /setactive $($plan.Guid)
    }

    Pause-Script
}

function Show-CurrentPowerPlan {
    Write-Banner
    Write-Log -Message 'Show current power plan'

    $output = (powercfg /getactivescheme 2>&1 | Out-String).Trim()
    if ($output -match 'Power Scheme GUID:\s*[a-f0-9-]+\s*\((.+)\)') {
        Write-Host "  Active plan: $($Matches[1])" -ForegroundColor Cyan
    }
    else {
        Write-Host "  $output" -ForegroundColor White
    }

    Pause-Script
}

#endregion Power and Sleep

#region Utilities

function Run-ChrisTitus {
    Write-Banner
    Write-Host '  WARNING: This downloads and runs a third-party script from the internet.' -ForegroundColor Yellow
    Write-Host '  It can install many apps and change system settings. Use only if you trust it.' -ForegroundColor DarkGray
    Write-Host ''

    if (-not (Read-YesNo -Prompt '  Continue with Chris Titus Tech win script?' -DefaultYes $false)) {
        return
    }

    if (-not (Test-IsAdmin)) {
        Write-Host '  Relaunching as Administrator...' -ForegroundColor Yellow
        Write-Log -Message 'Relaunching Chris Titus script as admin'
        Start-Process powershell.exe -Verb RunAs -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-Command',
            "irm 'https://christitus.com/win' | iex"
        )
        Pause-Script
        return
    }

    $null = Invoke-External -Label 'Running Chris Titus Tech win script' -Action {
        Invoke-RestMethod -Uri 'https://christitus.com/win' | Invoke-Expression
    }

    Pause-Script
}

function Open-Ninite {
    Write-Banner
    $null = Invoke-External -Label 'Opening Ninite' -Action {
        Start-Process 'https://ninite.com'
    }
    Pause-Script
}

function Update-AllWingetApps {
    Write-Banner

    if (-not (Assert-CommandAvailable 'winget')) { return }

    if (-not (Read-YesNo -Prompt '  This will update all winget-managed apps. Continue?' -DefaultYes $false)) {
        return
    }

    Write-Host ''
    Write-Host '  Running winget upgrade --all (live output)...' -ForegroundColor Cyan
    Write-Log -Message 'winget upgrade --all started'

    & winget upgrade --all --accept-source-agreements --accept-package-agreements
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Host "  winget finished with exit code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Log -Message "winget upgrade --all exit code $LASTEXITCODE" -Level 'WARN'
    }
    else {
        Write-Host '  winget upgrade completed.' -ForegroundColor Green
        Write-Log -Message 'winget upgrade --all completed'
    }

    Pause-Script
}

function Show-ScriptVersionInfo {
    Write-Banner
    $lastUpdated = Get-ScriptLastUpdated
    Write-Host "  Current version: v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "  Last updated:    $lastUpdated" -ForegroundColor White
    Write-Host "  Log file:        $LogPath" -ForegroundColor DarkGray
    Write-Host ''

    if (Read-YesNo -Prompt "  Open GitHub page ($ScriptGitHubUrl)?" -DefaultYes $false) {
        Write-Log -Message "Opening script GitHub: $ScriptGitHubUrl"
        Start-Process $ScriptGitHubUrl
    }

    Pause-Script
}

function Open-SessionLog {
    Write-Banner
    Write-Log -Message 'Opening session log in Notepad'
    if (-not (Test-Path $LogPath)) {
        Add-Content -Path $LogPath -Value '=== Log file created ==='
    }
    Start-Process notepad.exe -ArgumentList $LogPath
    Pause-Script
}

#endregion Utilities

#region Menu Loops

function Enter-SpicetifyMenu {
    $stay = $true
    while ($stay -and $script:running) {
        Show-SpicetifyMenu
        switch (Read-MenuChoice) {
            '1'  { Install-Spicetify }
            '2'  { Install-SpicetifyMarketplace }
            '3'  { Upgrade-Spicetify }
            '4'  { Apply-Config }
            '5'  { Restore-Spotify }
            '6'  { Restart-Spotify }
            '7'  { Block-Updates }
            '8'  { Unblock-Updates }
            '9'  { Repair-AfterSpotifyUpdate }
            '10' { Open-Config }
            '11' { Backup-Config }
            '12' { Clear-Backup }
            '13' { Install-Theme }
            '14' { Remove-Extension }
            '15' { Show-ThemeAndExtensions }
            '16' { Check-Version }
            '17' { Enable-DevTools }
            '18' { Export-SpicetifyConfig }
            '19' { Import-SpicetifyConfig }
            '0'  { $stay = $false }
            default {
                Write-Host '  Invalid choice.' -ForegroundColor Red
                Pause-Script
            }
        }
    }
}

function Enter-AppsMenu {
    $stay = $true
    while ($stay -and $script:running) {
        Show-AppsMenu
        switch (Read-MenuChoice) {
            '1'  { Install-Spotify }
            '2'  { Install-BetterDiscord }
            '3'  { Install-Vencord }
            '4'  { Install-AweSun }
            '5'  { Install-OffHelper }
            '6'  { Install-Landrop }
            '7'  { Install-Firefox }
            '8'  { Install-Brave }
            '9'  { Install-Chrome }
            '10' { Install-Steam }
            '11' { Install-EpicGames }
            '12' { Install-Git }
            '13' { Install-VSCode }
            '14' { Install-NodeJs }
            '15' { Install-WindowsTerminal }
            '16' { Install-7Zip }
            '17' { Install-AllDevTools }
            '18' { Install-AllGamingLaunchers }
            '0'  { $stay = $false }
            default {
                Write-Host '  Invalid choice.' -ForegroundColor Red
                Pause-Script
            }
        }
    }
}

function Enter-AppRepoInstallerMenu {
    $stay = $true
    while ($stay -and $script:running) {
        Show-AppRepoInstallerMenu
        switch (Read-MenuChoice) {
            '1' { Start-AppRepoAppInstaller }
            '2' { Start-AppRepoRepoClone }
            '3' { Select-Theme }
            '0' { $stay = $false }
            default {
                Write-ThemedHost '  Invalid choice.' 'Error'
                Pause-Script
            }
        }
    }
}

function Enter-PrivacyMenu {
    $stay = $true
    while ($stay -and $script:running) {
        Show-PrivacyMenu
        switch (Read-MenuChoice) {
            '1' { Disable-Telemetry }
            '2' { Remove-BloatwareApps }
            '3' { Disable-WindowsAds }
            '4' { Disable-BingInStartMenu }
            '5' { Disable-ActivityAndLocation }
            '6' { Disable-Cortana }
            '7' { Apply-AllPrivacyTweaks }
            '8' { Restore-PrivacyDefaults }
            '0' { $stay = $false }
            default {
                Write-Host '  Invalid choice.' -ForegroundColor Red
                Pause-Script
            }
        }
    }
}

function Enter-PowerMenu {
    $stay = $true
    while ($stay -and $script:running) {
        Show-PowerMenu
        switch (Read-MenuChoice) {
            '1' { Set-ShutdownTimer }
            '2' { Set-SleepTimer }
            '3' { Cancel-PowerTimers }
            '4' { Switch-PowerPlan }
            '5' { Show-CurrentPowerPlan }
            '0' { $stay = $false }
            default {
                Write-Host '  Invalid choice.' -ForegroundColor Red
                Pause-Script
            }
        }
    }
}

function Enter-UtilitiesMenu {
    $stay = $true
    while ($stay -and $script:running) {
        Show-UtilitiesMenu
        switch (Read-MenuChoice) {
            '1' { Run-ChrisTitus }
            '2' { Open-Ninite }
            '3' { Update-AllWingetApps }
            '4' { Show-ScriptVersionInfo }
            '5' { Open-SessionLog }
            '0' { $stay = $false }
            default {
                Write-Host '  Invalid choice.' -ForegroundColor Red
                Pause-Script
            }
        }
    }
}

#endregion Menu Loops

#region Main

$themeLoaded = Load-ThemeConfig
if (-not $themeLoaded) {
    Select-Theme -FirstRun
}

while ($script:running) {
    Show-MainMenu
    switch (Read-MenuChoice) {
        '1' { Start-NewPCWizard }
        '2' { Show-SystemStatus }
        '3' { Enter-SpicetifyMenu }
        '4' { Enter-AppsMenu }
        '5' { Enter-AppRepoInstallerMenu }
        '6' { Enter-PrivacyMenu }
        '7' { Enter-PowerMenu }
        '8' { Enter-UtilitiesMenu }
        '9' { Select-Theme }
        '0' { $script:running = $false }
        default {
            Write-ThemedHost '  Invalid choice.' 'Error'
            Pause-Script
        }
    }
}

Write-Banner
Write-ThemedHost '  See you next time.' 'Accent'
Write-ThemedHost ''
Write-Log -Message 'Session ended'

#endregion Main
