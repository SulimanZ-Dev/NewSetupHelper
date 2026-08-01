Set-StrictMode -Version 2.0

$script:SahModuleRoot = Split-Path -Parent $PSScriptRoot
$script:SahCatalogPath = Join-Path $script:SahModuleRoot 'data\catalog.json'
$script:SahDataRoot = if ($env:SULIMAN_APP_HUB_DATA) {
    [Environment]::ExpandEnvironmentVariables($env:SULIMAN_APP_HUB_DATA)
}
else {
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SulimanAppHub'
}
$script:SahConfigPath = Join-Path $script:SahDataRoot 'hub-config.json'
$script:SahStatePath = Join-Path $script:SahDataRoot 'state.json'
$script:SahHistoryPath = Join-Path $script:SahDataRoot 'history.jsonl'
$script:SahLogPath = Join-Path $script:SahDataRoot 'hub.log'
$script:SahWingetCache = $null

function Initialize-SahDataRoot {
    if (-not (Test-Path -LiteralPath $script:SahDataRoot)) {
        New-Item -ItemType Directory -Path $script:SahDataRoot -Force | Out-Null
    }
}

function ConvertTo-SahHashtable {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IDictionary]) {
            $result = @{}
            foreach ($key in $InputObject.Keys) { $result[$key] = ConvertTo-SahHashtable $InputObject[$key] }
            return $result
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $items = @()
            foreach ($item in $InputObject) { $items += ,(ConvertTo-SahHashtable $item) }
            return $items
        }
        if ($InputObject -is [psobject] -and @($InputObject.PSObject.Properties).Count -gt 0) {
            $result = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $result[$property.Name] = ConvertTo-SahHashtable $property.Value
            }
            return $result
        }
        return $InputObject
    }
}

function Write-SahLog {
    param([string]$Message, [string]$Level = 'INFO', [string]$OperationId = '')
    Initialize-SahDataRoot
    if (-not $OperationId) { $OperationId = '-' }
    $line = '[{0}] [{1}] [{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $OperationId, $Message
    Add-Content -LiteralPath $script:SahLogPath -Value $line -Encoding UTF8
}

function Get-SahPaths {
    Initialize-SahDataRoot
    return [pscustomobject]@{
        ModuleRoot = $script:SahModuleRoot
        Catalog = $script:SahCatalogPath
        DataRoot = $script:SahDataRoot
        Config = $script:SahConfigPath
        State = $script:SahStatePath
        History = $script:SahHistoryPath
        Log = $script:SahLogPath
    }
}

function Get-SahDefaultConfig {
    return @{
        schemaVersion = 1
        language = 'sv'
        theme = 'Dark'
        autoCheckUpdates = $true
        sourceRoot = '%USERPROFILE%\Source'
        portableInstallRoot = '%LOCALAPPDATA%\Programs\SulimanAppHub'
        createRestorePoint = $true
        verifyChecksums = $true
        customApps = @()
        customRepositories = @()
        customProfiles = @()
    }
}

function Save-SahConfig {
    param([Parameter(Mandatory = $true)][hashtable]$Config)
    Initialize-SahDataRoot
    $Config | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:SahConfigPath -Encoding UTF8
    return $script:SahConfigPath
}

function Get-SahConfig {
    Initialize-SahDataRoot
    $defaults = Get-SahDefaultConfig
    if (-not (Test-Path -LiteralPath $script:SahConfigPath)) {
        Save-SahConfig -Config $defaults | Out-Null
        return $defaults
    }
    try {
        $loaded = ConvertTo-SahHashtable (Get-Content -LiteralPath $script:SahConfigPath -Raw | ConvertFrom-Json)
        foreach ($key in $defaults.Keys) {
            if (-not $loaded.ContainsKey($key)) { $loaded[$key] = $defaults[$key] }
        }
        return $loaded
    }
    catch {
        $backup = "$script:SahConfigPath.invalid-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -LiteralPath $script:SahConfigPath -Destination $backup -Force
        Write-SahLog -Message "Invalid config backed up to ${backup}: $($_.Exception.Message)" -Level 'ERROR'
        Save-SahConfig -Config $defaults | Out-Null
        return $defaults
    }
}

function Get-SahCatalog {
    if (-not (Test-Path -LiteralPath $script:SahCatalogPath)) {
        throw "Catalog not found: $script:SahCatalogPath"
    }
    $catalog = ConvertTo-SahHashtable (Get-Content -LiteralPath $script:SahCatalogPath -Raw | ConvertFrom-Json)
    $config = Get-SahConfig
    $catalog.apps = @($catalog.apps) + @($config.customApps)
    $catalog.repositories = @($catalog.repositories) + @($config.customRepositories)
    $catalog.profiles = @($catalog.profiles) + @($config.customProfiles)
    return $catalog
}

function Get-SahState {
    Initialize-SahDataRoot
    if (-not (Test-Path -LiteralPath $script:SahStatePath)) {
        return @{ schemaVersion = 1; installed = @{}; repositories = @{}; lastUpdateCheck = $null }
    }
    try { return ConvertTo-SahHashtable (Get-Content -LiteralPath $script:SahStatePath -Raw | ConvertFrom-Json) }
    catch { return @{ schemaVersion = 1; installed = @{}; repositories = @{}; lastUpdateCheck = $null } }
}

function Save-SahState {
    param([Parameter(Mandatory = $true)][hashtable]$State)
    Initialize-SahDataRoot
    $State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:SahStatePath -Encoding UTF8
}

function Add-SahHistory {
    param(
        [string]$Action,
        [string]$Target,
        [bool]$Success,
        [string]$Version = '',
        [string]$Message = '',
        [string]$OperationId = ''
    )
    Initialize-SahDataRoot
    if (-not $OperationId) { $OperationId = [Guid]::NewGuid().ToString('N').Substring(0, 10) }
    $record = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        operationId = $OperationId
        action = $Action
        target = $Target
        success = $Success
        version = $Version
        message = $Message
    }
    Add-Content -LiteralPath $script:SahHistoryPath -Value ($record | ConvertTo-Json -Compress) -Encoding UTF8
    Write-SahLog -Message "$Action $Target success=$Success $Message" -Level $(if ($Success) { 'INFO' } else { 'ERROR' }) -OperationId $OperationId
    return [pscustomobject]$record
}

function Get-SahHistory {
    param([int]$Limit = 200)
    if (-not (Test-Path -LiteralPath $script:SahHistoryPath)) { return @() }
    $lines = @(Get-Content -LiteralPath $script:SahHistoryPath | Select-Object -Last $Limit)
    $records = @()
    foreach ($line in $lines) {
        try { $records += ,($line | ConvertFrom-Json) } catch { }
    }
    return @($records | Sort-Object timestamp -Descending)
}

function Test-SahCommand {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-SahExternal {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$Capture,
        [int[]]$SuccessCodes = @(0)
    )
    if ($Capture) {
        $output = & $FilePath @Arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{ Success = $SuccessCodes -contains $exitCode; ExitCode = $exitCode; Output = $output.Trim() }
    }
    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{ Success = $SuccessCodes -contains $exitCode; ExitCode = $exitCode; Output = '' }
}

function Test-SahTrustedGitHubUrl {
    param([string]$Url, [string]$Repository)
    try {
        $uri = [Uri]$Url
        if ($uri.Scheme -ne 'https') { return $false }
        if ($uri.Host -notin @('github.com', 'objects.githubusercontent.com', 'release-assets.githubusercontent.com')) { return $false }
        if ($uri.Host -eq 'github.com' -and $Repository -and $uri.AbsolutePath -notlike "/$Repository/*") { return $false }
        return $true
    }
    catch { return $false }
}

function Get-SahLatestRelease {
    param([Parameter(Mandatory = $true)][string]$Repository)
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Invalid GitHub repository: $Repository" }
    $headers = @{ 'User-Agent' = 'Suliman-App-Hub'; 'Accept' = 'application/vnd.github+json' }
    return Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers -ErrorAction Stop
}

function Select-SahReleaseAsset {
    param(
        [Parameter(Mandatory = $true)]$Release,
        [string[]]$Include = @('(?i)\.(exe|msi|msix|msixbundle|zip)$'),
        [string[]]$Prefer = @('(?i)(setup|install)', '(?i)x64'),
        [string[]]$Exclude = @('(?i)(sha256|checksums?)')
    )
    $assets = @($Release.assets)
    foreach ($pattern in $Include) { $assets = @($assets | Where-Object { $_.name -match $pattern }) }
    foreach ($pattern in $Exclude) { $assets = @($assets | Where-Object { $_.name -notmatch $pattern }) }
    if ($assets.Count -eq 0) { return $null }
    foreach ($pattern in $Prefer) {
        $preferred = @($assets | Where-Object { $_.name -match $pattern })
        if ($preferred.Count -gt 0) { $assets = $preferred }
    }
    return $assets[0]
}

function Get-SahChecksumAsset {
    param([Parameter(Mandatory = $true)]$Release)
    return @($Release.assets | Where-Object { $_.name -match '(?i)(sha256|checksums?).*\.(txt|sha256|sum)$' } | Select-Object -First 1)[0]
}

function Test-SahDownloadedChecksum {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)]$Release,
        [Parameter(Mandatory = $true)]$Asset
    )
    $checksumAsset = Get-SahChecksumAsset -Release $Release
    if ($null -eq $checksumAsset) {
        return [pscustomobject]@{ Status = 'Unavailable'; Valid = $null; Expected = ''; Actual = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash }
    }
    $content = (Invoke-WebRequest -Uri $checksumAsset.browser_download_url -UseBasicParsing -ErrorAction Stop).Content
    $escapedName = [regex]::Escape($Asset.name)
    $match = [regex]::Match($content, "(?im)^([a-f0-9]{64})\s+\*?$escapedName\s*$")
    if (-not $match.Success) {
        return [pscustomobject]@{ Status = 'NotListed'; Valid = $null; Expected = ''; Actual = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash }
    }
    $actual = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expected = $match.Groups[1].Value.ToLowerInvariant()
    return [pscustomobject]@{ Status = $(if ($actual -eq $expected) { 'Verified' } else { 'Mismatch' }); Valid = ($actual -eq $expected); Expected = $expected; Actual = $actual }
}

function Get-SahAuthenticodeStatus {
    param([string]$FilePath)
    if ([IO.Path]::GetExtension($FilePath) -notin @('.exe', '.msi', '.msix', '.msixbundle')) { return 'NotApplicable' }
    try { return (Get-AuthenticodeSignature -LiteralPath $FilePath).Status.ToString() }
    catch { return 'Unknown' }
}

function Get-SahWingetInventory {
    param([switch]$IncludeUpgrades, [switch]$Refresh)
    $cacheIsCurrent = $script:SahWingetCache -and (((Get-Date) - $script:SahWingetCache.Timestamp).TotalSeconds -lt 60)
    if (-not $cacheIsCurrent -or $Refresh) {
        $list = Invoke-SahExternal -FilePath 'winget' -Arguments @('list', '--accept-source-agreements', '--disable-interactivity') -Capture
        $script:SahWingetCache = [pscustomobject]@{ Timestamp = Get-Date; List = $list.Output; Upgrades = '' }
    }
    if ($IncludeUpgrades -and -not $script:SahWingetCache.Upgrades) {
        $upgrade = Invoke-SahExternal -FilePath 'winget' -Arguments @('upgrade', '--accept-source-agreements', '--disable-interactivity') -Capture
        $script:SahWingetCache.Upgrades = $upgrade.Output
    }
    return $script:SahWingetCache
}

function Clear-SahStatusCache {
    $script:SahWingetCache = $null
}

function Get-SahWingetStatus {
    param([Parameter(Mandatory = $true)][string]$PackageId, [switch]$CheckUpgrades)
    if (-not (Test-SahCommand 'winget')) { return [pscustomobject]@{ Installed = $false; Version = ''; Available = ''; UpdateAvailable = $false; Detail = 'winget unavailable' } }
    $inventory = Get-SahWingetInventory -IncludeUpgrades:$CheckUpgrades
    $installed = $inventory.List -match [regex]::Escape($PackageId)
    $version = ''
    if ($installed) {
        $line = @($inventory.List -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($PackageId) } | Select-Object -First 1)
        if ($line.Count -gt 0) {
            $parts = @($line[0] -split '\s{2,}' | Where-Object { $_ })
            if ($parts.Count -ge 3) { $version = $parts[2].Trim() }
        }
    }
    $updateAvailable = $CheckUpgrades -and $installed -and ($inventory.Upgrades -match [regex]::Escape($PackageId))
    $available = ''
    if ($updateAvailable) {
        $line = @($inventory.Upgrades -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($PackageId) } | Select-Object -First 1)
        if ($line.Count -gt 0) {
            $parts = @($line[0] -split '\s{2,}' | Where-Object { $_ })
            if ($parts.Count -ge 4) { $available = $parts[3].Trim() }
        }
    }
    return [pscustomobject]@{ Installed = $installed; Version = $version; Available = $available; UpdateAvailable = $updateAvailable; Detail = $inventory.List }
}

function Get-SahAppStatus {
    param([Parameter(Mandatory = $true)][hashtable]$App, [switch]$CheckRemote)
    if ($App.kind -eq 'Winget') {
        $status = Get-SahWingetStatus -PackageId $App.packageId -CheckUpgrades:$CheckRemote
        return [pscustomobject]@{ Id = $App.id; Name = $App.name; Installed = $status.Installed; InstalledVersion = $status.Version; LatestVersion = $status.Available; UpdateAvailable = $status.UpdateAvailable; Source = 'winget' }
    }
    $state = Get-SahState
    $entry = $null
    if ($state.installed.ContainsKey($App.id)) { $entry = $state.installed[$App.id] }
    $installedVersion = if ($entry) { [string]$entry.version } else { '' }
    $latestVersion = ''
    if ($CheckRemote) {
        try { $latestVersion = [string](Get-SahLatestRelease -Repository $App.repository).tag_name } catch { }
    }
    return [pscustomobject]@{
        Id = $App.id
        Name = $App.name
        Installed = $null -ne $entry
        InstalledVersion = $installedVersion
        LatestVersion = $latestVersion
        UpdateAvailable = ($entry -and $latestVersion -and $installedVersion -ne $latestVersion)
        Source = 'GitHub'
    }
}

function New-SahRestorePoint {
    param([string]$Description = 'Suliman App Hub change')
    $config = Get-SahConfig
    if (-not $config.createRestorePoint) { return [pscustomobject]@{ Success = $true; Skipped = $true; Message = 'Disabled in settings' } }
    try {
        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        return [pscustomobject]@{ Success = $true; Skipped = $false; Message = 'Restore point created' }
    }
    catch {
        Write-SahLog -Message "Restore point unavailable: $($_.Exception.Message)" -Level 'WARN'
        return [pscustomobject]@{ Success = $false; Skipped = $true; Message = $_.Exception.Message }
    }
}

function New-SahShortcut {
    param([string]$TargetPath, [string]$Name, [string]$Arguments = '')
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop "$Name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = Split-Path -Parent $TargetPath
    $shortcut.Save()
    return $shortcutPath
}

function Invoke-SahPostInstallActions {
    param([hashtable]$App, [string]$ExecutablePath = '', [string[]]$Actions = @())
    $results = @()
    foreach ($action in $Actions) {
        try {
            switch ($action) {
                'Shortcut' {
                    if (-not $ExecutablePath) { throw 'No executable path is available for a shortcut.' }
                    $path = New-SahShortcut -TargetPath $ExecutablePath -Name $App.name
                    $results += [pscustomobject]@{ Action = $action; Success = $true; Detail = $path }
                }
                'Launch' {
                    if (-not $ExecutablePath) { throw 'No executable path is available to launch.' }
                    Start-Process -FilePath $ExecutablePath
                    $results += [pscustomobject]@{ Action = $action; Success = $true; Detail = $ExecutablePath }
                }
                'Settings' {
                    Start-Process 'ms-settings:appsfeatures'
                    $results += [pscustomobject]@{ Action = $action; Success = $true; Detail = 'Windows app settings' }
                }
                'PinToTaskbar' {
                    if (-not $ExecutablePath) { throw 'No executable path is available to pin.' }
                    $shell = New-Object -ComObject Shell.Application
                    $folder = $shell.Namespace((Split-Path -Parent $ExecutablePath))
                    $item = $folder.ParseName((Split-Path -Leaf $ExecutablePath))
                    $verb = @($item.Verbs() | Where-Object { ($_.Name -replace '&', '') -match '(?i)(pin to taskbar|fast.*aktivitetsfaltet)' } | Select-Object -First 1)
                    if ($verb.Count -eq 0) { throw 'Windows did not expose a Pin to taskbar action for this app.' }
                    $verb[0].DoIt()
                    $results += [pscustomobject]@{ Action = $action; Success = $true; Detail = 'Taskbar pin requested' }
                }
            }
        }
        catch { $results += [pscustomobject]@{ Action = $action; Success = $false; Detail = $_.Exception.Message } }
    }
    return $results
}

function Install-SahDownloadedAsset {
    param(
        [hashtable]$App,
        [string]$FilePath,
        [string]$Version,
        [string[]]$PostActions = @()
    )
    $extension = [IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    $config = Get-SahConfig
    $executablePath = ''
    if ($App.installMode -eq 'Portable' -or $extension -eq '.zip') {
        $root = [Environment]::ExpandEnvironmentVariables([string]$config.portableInstallRoot)
        $target = Join-Path $root $App.id
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        if ($extension -eq '.zip') {
            Expand-Archive -LiteralPath $FilePath -DestinationPath $target -Force
            $candidate = Get-ChildItem -LiteralPath $target -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candidate) { $executablePath = $candidate.FullName }
        }
        else {
            $name = if ($App.executableName) { $App.executableName } else { Split-Path -Leaf $FilePath }
            $executablePath = Join-Path $target $name
            Copy-Item -LiteralPath $FilePath -Destination $executablePath -Force
        }
    }
    elseif ($extension -eq '.msi') {
        $result = Invoke-SahExternal -FilePath 'msiexec.exe' -Arguments @('/i', $FilePath, '/qn', '/norestart') -SuccessCodes @(0, 3010, 1641)
        if (-not $result.Success) { throw "MSI installer exited with code $($result.ExitCode)" }
    }
    elseif ($extension -in @('.msix', '.msixbundle')) {
        Add-AppxPackage -Path $FilePath -ErrorAction Stop
    }
    elseif ($extension -eq '.exe') {
        $args = @()
        if ($App.silentArgs) { $args = @($App.silentArgs) }
        $processParameters = @{ FilePath = $FilePath; Wait = $true; PassThru = $true }
        if ($args.Count -gt 0) { $processParameters.ArgumentList = $args }
        $process = Start-Process @processParameters
        if ($process.ExitCode -notin @(0, 3010, 1641)) {
            throw "EXE installer exited with code $($process.ExitCode)"
        }
    }
    else { throw "Unsupported release format: $extension" }

    $state = Get-SahState
    $state.installed[$App.id] = @{
        name = $App.name
        version = $Version
        installedAt = (Get-Date).ToString('o')
        kind = $App.kind
        installMode = $App.installMode
        executablePath = $executablePath
        repository = $App.repository
    }
    Save-SahState -State $state
    $postResults = Invoke-SahPostInstallActions -App $App -ExecutablePath $executablePath -Actions $PostActions
    return [pscustomobject]@{ Success = $true; Version = $Version; ExecutablePath = $executablePath; PostActions = $postResults }
}

function Install-SahApp {
    param(
        [Parameter(Mandatory = $true)][hashtable]$App,
        [string[]]$PostActions = @(),
        [int]$RetryCount = 1
    )
    $operationId = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    try {
        if ($App.kind -eq 'Winget') {
            if (-not (Test-SahCommand 'winget')) { throw 'winget is not installed.' }
            $arguments = @('install', '--id', $App.packageId, '--exact', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
            $result = Invoke-SahExternal -FilePath 'winget' -Arguments $arguments -SuccessCodes @(0, -1978335189)
            if (-not $result.Success) { throw "winget exited with code $($result.ExitCode)" }
            Add-SahHistory -Action 'Install' -Target $App.name -Success $true -Message "winget $($App.packageId)" -OperationId $operationId | Out-Null
            Clear-SahStatusCache
            return [pscustomobject]@{ Success = $true; App = $App; Version = ''; Message = 'Installed with winget'; OperationId = $operationId }
        }

        $release = Get-SahLatestRelease -Repository $App.repository
        $include = if ($App.assetInclude) { @($App.assetInclude) } else { @('(?i)\.(exe|msi|msix|msixbundle|zip)$') }
        $prefer = if ($App.assetPrefer) { @($App.assetPrefer) } else { @('(?i)(setup|install)', '(?i)x64') }
        $exclude = if ($App.assetExclude) { @($App.assetExclude) } else { @('(?i)(sha256|checksums?)') }
        $asset = Select-SahReleaseAsset -Release $release -Include $include -Prefer $prefer -Exclude $exclude
        if ($null -eq $asset) { throw 'The latest release has no supported asset.' }
        if (-not (Test-SahTrustedGitHubUrl -Url $asset.browser_download_url -Repository $App.repository)) { throw 'GitHub returned an untrusted download URL.' }

        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SulimanAppHub-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $download = Join-Path $tempRoot (Split-Path -Leaf $asset.name)
        try {
            $attempt = 0
            do {
                $attempt++
                try { Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $download -UseBasicParsing -ErrorAction Stop; $downloaded = $true }
                catch { $downloaded = $false; if ($attempt -gt $RetryCount) { throw } }
            } while (-not $downloaded)

            $config = Get-SahConfig
            $checksum = if ($config.verifyChecksums) { Test-SahDownloadedChecksum -FilePath $download -Release $release -Asset $asset } else { [pscustomobject]@{ Status = 'Disabled'; Valid = $null } }
            if ($checksum.Valid -eq $false) { throw "SHA-256 mismatch for $($asset.name)" }
            $signature = Get-SahAuthenticodeStatus -FilePath $download
            if ($signature -in @('HashMismatch', 'NotTrusted')) { throw "Invalid Authenticode signature: $signature" }
            $installed = Install-SahDownloadedAsset -App $App -FilePath $download -Version $release.tag_name -PostActions $PostActions
            Add-SahHistory -Action 'Install' -Target $App.name -Success $true -Version $release.tag_name -Message "asset=$($asset.name); checksum=$($checksum.Status); signature=$signature" -OperationId $operationId | Out-Null
            return [pscustomobject]@{ Success = $true; App = $App; Version = $release.tag_name; Asset = $asset.name; Checksum = $checksum.Status; Signature = $signature; ExecutablePath = $installed.ExecutablePath; Message = 'Installed'; OperationId = $operationId }
        }
        finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
    catch {
        Add-SahHistory -Action 'Install' -Target $App.name -Success $false -Message $_.Exception.Message -OperationId $operationId | Out-Null
        return [pscustomobject]@{ Success = $false; App = $App; Version = ''; Message = $_.Exception.Message; OperationId = $operationId }
    }
}

function Update-SahApp {
    param([Parameter(Mandatory = $true)][hashtable]$App)
    if ($App.kind -eq 'Winget') {
        $result = Invoke-SahExternal -FilePath 'winget' -Arguments @('upgrade', '--id', $App.packageId, '--exact', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity') -SuccessCodes @(0, -1978335189)
        Add-SahHistory -Action 'Update' -Target $App.name -Success $result.Success -Message "winget exit $($result.ExitCode)" | Out-Null
        Clear-SahStatusCache
        return [pscustomobject]@{ Success = $result.Success; App = $App; Message = "winget exit $($result.ExitCode)" }
    }
    return Install-SahApp -App $App
}

function Get-SahUninstallEntry {
    param([string]$DisplayName)
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    return Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$DisplayName*" } | Select-Object -First 1
}

function Uninstall-SahApp {
    param([Parameter(Mandatory = $true)][hashtable]$App)
    try {
        if ($App.kind -eq 'Winget') {
            $result = Invoke-SahExternal -FilePath 'winget' -Arguments @('uninstall', '--id', $App.packageId, '--exact', '--silent', '--disable-interactivity') -SuccessCodes @(0)
            if (-not $result.Success) { throw "winget exited with code $($result.ExitCode)" }
            Clear-SahStatusCache
        }
        else {
            $state = Get-SahState
            $entry = if ($state.installed.ContainsKey($App.id)) { $state.installed[$App.id] } else { $null }
            if ($entry -and $entry.installMode -eq 'Portable') {
                $target = Split-Path -Parent $entry.executablePath
                $root = [Environment]::ExpandEnvironmentVariables([string](Get-SahConfig).portableInstallRoot)
                $resolvedTarget = [IO.Path]::GetFullPath($target)
                $resolvedRoot = [IO.Path]::GetFullPath($root)
                if (-not $resolvedTarget.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Portable app path is outside the managed install root.' }
                Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
            }
            else {
                $uninstall = Get-SahUninstallEntry -DisplayName $(if ($App.uninstallName) { $App.uninstallName } else { $App.name })
                if (-not $uninstall) { throw 'No registered uninstaller was found.' }
                $command = if ($uninstall.QuietUninstallString) { $uninstall.QuietUninstallString } else { $uninstall.UninstallString }
                Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/s', '/c', $command) -Wait
            }
            if ($state.installed.ContainsKey($App.id)) { $state.installed.Remove($App.id); Save-SahState -State $state }
        }
        Add-SahHistory -Action 'Uninstall' -Target $App.name -Success $true | Out-Null
        return [pscustomobject]@{ Success = $true; App = $App; Message = 'Uninstalled' }
    }
    catch {
        Add-SahHistory -Action 'Uninstall' -Target $App.name -Success $false -Message $_.Exception.Message | Out-Null
        return [pscustomobject]@{ Success = $false; App = $App; Message = $_.Exception.Message }
    }
}

function Get-SahProfileApps {
    param([Parameter(Mandatory = $true)][string]$ProfileId)
    $catalog = Get-SahCatalog
    return @($catalog.apps | Where-Object { @($_.profiles) -contains $ProfileId })
}

function Invoke-SahProfile {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileId,
        [switch]$Quiet,
        [scriptblock]$ProgressCallback,
        [scriptblock]$CancelCallback
    )
    $apps = @(Get-SahProfileApps -ProfileId $ProfileId)
    $results = @()
    for ($i = 0; $i -lt $apps.Count; $i++) {
        if ($CancelCallback -and (& $CancelCallback)) { break }
        if ($ProgressCallback) { & $ProgressCallback $apps[$i].name $i $apps.Count }
        $results += ,(Install-SahApp -App $apps[$i])
    }
    return $results
}

function Get-SahRepositoryInventory {
    $config = Get-SahConfig
    $root = [Environment]::ExpandEnvironmentVariables([string]$config.sourceRoot)
    if (-not (Test-Path -LiteralPath $root)) { return @() }
    $repos = @()
    foreach ($directory in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName '.git'))) { continue }
        $branch = (Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $directory.FullName, 'branch', '--show-current') -Capture).Output
        $status = (Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $directory.FullName, 'status', '--porcelain') -Capture).Output
        $remote = (Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $directory.FullName, 'remote', 'get-url', 'origin') -Capture).Output
        $repos += [pscustomobject]@{ Name = $directory.Name; Path = $directory.FullName; Branch = $branch; Dirty = [bool]$status; Remote = $remote }
    }
    return $repos
}

function Install-SahRepository {
    param([Parameter(Mandatory = $true)][hashtable]$Repository)
    if (-not (Test-SahCommand 'git')) { throw 'git is not installed.' }
    $config = Get-SahConfig
    $root = [Environment]::ExpandEnvironmentVariables([string]$config.sourceRoot)
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $name = ($Repository.repository -split '/')[-1]
    $target = Join-Path $root $name
    if (Test-Path -LiteralPath $target) { return [pscustomobject]@{ Success = $true; Path = $target; Message = 'Already cloned' } }
    $result = Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $root, 'clone', $Repository.url)
    Add-SahHistory -Action 'Clone' -Target $Repository.name -Success $result.Success -Message $target | Out-Null
    return [pscustomobject]@{ Success = $result.Success; Path = $target; Message = "git exit $($result.ExitCode)" }
}

function Invoke-SahRepositoryAction {
    param([Parameter(Mandatory = $true)]$Repository, [ValidateSet('Pull', 'Open', 'Code', 'Repair')][string]$Action)
    try {
        switch ($Action) {
            'Pull' {
                if ($Repository.Dirty) { throw 'Repository has local changes. Pull was not attempted.' }
                $result = Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $Repository.Path, 'pull', '--ff-only')
                if (-not $result.Success) { throw "git pull exited with code $($result.ExitCode)" }
            }
            'Open' { Start-Process explorer.exe -ArgumentList $Repository.Path }
            'Code' {
                if (-not (Test-SahCommand 'code')) { throw 'VS Code command is not available.' }
                Start-Process -FilePath 'code' -ArgumentList $Repository.Path
            }
            'Repair' {
                $fsck = Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $Repository.Path, 'fsck', '--full') -Capture
                if (-not $fsck.Success) { throw $fsck.Output }
                Invoke-SahExternal -FilePath 'git' -Arguments @('-C', $Repository.Path, 'remote', 'prune', 'origin') | Out-Null
            }
        }
        Add-SahHistory -Action "Repo$Action" -Target $Repository.Name -Success $true | Out-Null
        return [pscustomobject]@{ Success = $true; Message = "$Action completed" }
    }
    catch {
        Add-SahHistory -Action "Repo$Action" -Target $Repository.Name -Success $false -Message $_.Exception.Message | Out-Null
        return [pscustomobject]@{ Success = $false; Message = $_.Exception.Message }
    }
}

function Get-SahPrivacySnapshot {
    $items = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled' },
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana' }
    )
    $snapshot = @()
    foreach ($item in $items) {
        $value = $null
        try { $value = (Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction Stop).$($item.Name) } catch { }
        $snapshot += [pscustomobject]@{ Path = $item.Path; Name = $item.Name; Value = $value }
    }
    return $snapshot
}

function Get-SahSystemDiagnostics {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $driverErrors = @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction SilentlyContinue).Count
    return [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        Windows = $os.Caption
        WindowsVersion = $os.Version
        Build = $os.BuildNumber
        Architecture = $os.OSArchitecture
        RamGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
        FreeDiskGB = [math]::Round($systemDrive.FreeSpace / 1GB, 1)
        TotalDiskGB = [math]::Round($systemDrive.Size / 1GB, 1)
        PowerShell = $PSVersionTable.PSVersion.ToString()
        Winget = if (Test-SahCommand 'winget') { (Invoke-SahExternal -FilePath 'winget' -Arguments @('--version') -Capture).Output } else { 'Missing' }
        Git = if (Test-SahCommand 'git') { (Invoke-SahExternal -FilePath 'git' -Arguments @('--version') -Capture).Output } else { 'Missing' }
        Node = if (Test-SahCommand 'node') { (Invoke-SahExternal -FilePath 'node' -Arguments @('--version') -Capture).Output } else { 'Missing' }
        Spicetify = if (Test-SahCommand 'spicetify') { (Invoke-SahExternal -FilePath 'spicetify' -Arguments @('--version') -Capture).Output } else { 'Missing' }
        DriverErrors = $driverErrors
        IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Timestamp = (Get-Date).ToString('o')
    }
}

function Export-SahComputerProfile {
    param([Parameter(Mandatory = $true)][string]$DestinationPath)
    Initialize-SahDataRoot
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SulimanBackup-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        $paths = Get-SahPaths
        foreach ($source in @($paths.Config, $paths.State, $paths.History)) {
            if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $tempRoot -Force }
        }
        $catalog = Get-SahCatalog
        $diagnostics = Get-SahSystemDiagnostics
        $repos = Get-SahRepositoryInventory
        $privacy = Get-SahPrivacySnapshot
        $manifest = [ordered]@{
            schemaVersion = 1
            createdAt = (Get-Date).ToString('o')
            computerName = $env:COMPUTERNAME
            diagnostics = $diagnostics
            repositories = $repos
            privacy = $privacy
            catalogAppIds = @($catalog.apps | ForEach-Object { $_.id })
        }
        $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $tempRoot 'manifest.json') -Encoding UTF8
        if (Test-SahCommand 'winget') {
            & winget export --output (Join-Path $tempRoot 'winget-packages.json') --accept-source-agreements --disable-interactivity 2>$null | Out-Null
        }
        $spicetify = Join-Path $env:APPDATA 'spicetify'
        if (Test-Path -LiteralPath $spicetify) {
            Compress-Archive -Path (Join-Path $spicetify '*') -DestinationPath (Join-Path $tempRoot 'spicetify-config.zip') -Force
        }
        if (Test-Path -LiteralPath $DestinationPath) { Remove-Item -LiteralPath $DestinationPath -Force }
        Compress-Archive -Path (Join-Path $tempRoot '*') -DestinationPath $DestinationPath -Force
        Add-SahHistory -Action 'Backup' -Target $DestinationPath -Success $true | Out-Null
        return [pscustomobject]@{ Success = $true; Path = $DestinationPath; Message = 'Backup created' }
    }
    catch {
        Add-SahHistory -Action 'Backup' -Target $DestinationPath -Success $false -Message $_.Exception.Message | Out-Null
        return [pscustomobject]@{ Success = $false; Path = $DestinationPath; Message = $_.Exception.Message }
    }
    finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

function Compare-SahComputerProfile {
    param([Parameter(Mandatory = $true)][string]$BackupPath)
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SulimanCompare-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $BackupPath -DestinationPath $tempRoot -Force
        $manifest = Get-Content -LiteralPath (Join-Path $tempRoot 'manifest.json') -Raw | ConvertFrom-Json
        $currentRepos = @(Get-SahRepositoryInventory | ForEach-Object { $_.Name })
        $missingRepos = @($manifest.repositories | Where-Object { $currentRepos -notcontains $_.Name } | ForEach-Object { $_.Name })
        return [pscustomobject]@{ SourceComputer = $manifest.computerName; CreatedAt = $manifest.createdAt; MissingRepositories = $missingRepos; Current = Get-SahSystemDiagnostics; Backup = $manifest.diagnostics }
    }
    finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

function Import-SahComputerProfile {
    param([Parameter(Mandatory = $true)][string]$BackupPath, [switch]$InstallWingetApps, [switch]$RestoreSpicetify)
    Initialize-SahDataRoot
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SulimanRestore-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $BackupPath -DestinationPath $tempRoot -Force
        foreach ($name in @('hub-config.json', 'state.json', 'history.jsonl')) {
            $source = Join-Path $tempRoot $name
            if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $script:SahDataRoot $name) -Force }
        }
        if ($InstallWingetApps -and (Test-Path -LiteralPath (Join-Path $tempRoot 'winget-packages.json'))) {
            & winget import --import-file (Join-Path $tempRoot 'winget-packages.json') --accept-source-agreements --accept-package-agreements --disable-interactivity
        }
        if ($RestoreSpicetify -and (Test-Path -LiteralPath (Join-Path $tempRoot 'spicetify-config.zip'))) {
            $spicetify = Join-Path $env:APPDATA 'spicetify'
            New-Item -ItemType Directory -Path $spicetify -Force | Out-Null
            Expand-Archive -LiteralPath (Join-Path $tempRoot 'spicetify-config.zip') -DestinationPath $spicetify -Force
        }
        Add-SahHistory -Action 'Restore' -Target $BackupPath -Success $true | Out-Null
        return [pscustomobject]@{ Success = $true; Message = 'Profile restored' }
    }
    catch {
        Add-SahHistory -Action 'Restore' -Target $BackupPath -Success $false -Message $_.Exception.Message | Out-Null
        return [pscustomobject]@{ Success = $false; Message = $_.Exception.Message }
    }
    finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

function Get-SahHelperUpdate {
    param([string]$CurrentVersion = '0.0.0', [ValidateSet('Gui', 'Terminal')][string]$Edition = 'Gui')
    $catalog = Get-SahCatalog
    $release = Get-SahLatestRelease -Repository $catalog.helperRepository
    $assetPattern = if ($Edition -eq 'Gui') { '(?i)^SulimanAppHub\.exe$' } else { '(?i)^SulimanAppHub\.Terminal\.exe$' }
    $asset = @($release.assets | Where-Object { $_.name -match $assetPattern } | Select-Object -First 1)[0]
    $remoteVersion = ([string]$release.tag_name).TrimStart('v')
    $isNewer = $false
    try { $isNewer = [version]$remoteVersion -gt [version]$CurrentVersion } catch { $isNewer = $remoteVersion -ne $CurrentVersion }
    return [pscustomobject]@{ UpdateAvailable = $isNewer; CurrentVersion = $CurrentVersion; LatestVersion = $remoteVersion; Release = $release; Asset = $asset; Notes = $release.body; Url = $release.html_url }
}

function Start-SahSelfUpdate {
    param([Parameter(Mandatory = $true)]$Update, [Parameter(Mandatory = $true)][string]$CurrentExecutable)
    if (-not $Update.UpdateAvailable) { return [pscustomobject]@{ Success = $true; Message = 'Already current' } }
    if ($null -eq $Update.Asset) { return [pscustomobject]@{ Success = $false; Message = 'The release has no matching executable.' } }
    $download = Join-Path ([IO.Path]::GetTempPath()) ("SulimanAppHub-update-" + [Guid]::NewGuid().ToString('N') + '.exe')
    Invoke-WebRequest -Uri $Update.Asset.browser_download_url -OutFile $download -UseBasicParsing -ErrorAction Stop
    $expectedDigest = [string]$Update.Asset.digest
    if ($expectedDigest -match '^sha256:(.+)$') {
        $actual = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $matches[1].ToLowerInvariant()) { Remove-Item -LiteralPath $download -Force; throw 'Self-update SHA-256 verification failed.' }
    }
    $pidToWait = $PID
    $command = "Wait-Process -Id $pidToWait -ErrorAction SilentlyContinue; Move-Item -LiteralPath '$($download.Replace("'", "''"))' -Destination '$($CurrentExecutable.Replace("'", "''"))' -Force; Start-Process -FilePath '$($CurrentExecutable.Replace("'", "''"))'"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-EncodedCommand', $encoded) -WindowStyle Hidden
    return [pscustomobject]@{ Success = $true; Message = 'Update staged. The app will restart.' }
}

function Invoke-SahUpdateAll {
    param([string]$HelperVersion = '', [string]$HelperEdition = 'Gui', [scriptblock]$ProgressCallback, [scriptblock]$CancelCallback)
    $results = @()
    if (Test-SahCommand 'winget') {
        if ($ProgressCallback) { & $ProgressCallback 'Winget apps' 0 4 }
        $winget = Invoke-SahExternal -FilePath 'winget' -Arguments @('upgrade', '--all', '--silent', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity') -SuccessCodes @(0, -1978335189)
        $results += [pscustomobject]@{ Target = 'Winget apps'; Success = $winget.Success; Message = "exit $($winget.ExitCode)" }
    }
    if (-not ($CancelCallback -and (& $CancelCallback))) {
        if ($ProgressCallback) { & $ProgressCallback 'GitHub apps' 1 4 }
        $catalog = Get-SahCatalog
        foreach ($app in @($catalog.apps | Where-Object { $_.kind -eq 'GitHub' })) {
            $status = Get-SahAppStatus -App $app -CheckRemote
            if ($status.Installed -and $status.UpdateAvailable) { $results += ,(Update-SahApp -App $app) }
        }
    }
    if (-not ($CancelCallback -and (& $CancelCallback))) {
        if ($ProgressCallback) { & $ProgressCallback 'Spicetify' 2 4 }
        if (Test-SahCommand 'spicetify') {
            $spice = Invoke-SahExternal -FilePath 'spicetify' -Arguments @('upgrade')
            $results += [pscustomobject]@{ Target = 'Spicetify'; Success = $spice.Success; Message = "exit $($spice.ExitCode)" }
        }
    }
    if ($HelperVersion -and -not ($CancelCallback -and (& $CancelCallback))) {
        if ($ProgressCallback) { & $ProgressCallback 'Setup Helper' 3 4 }
        try {
            $update = Get-SahHelperUpdate -CurrentVersion $HelperVersion -Edition $HelperEdition
            $results += [pscustomobject]@{ Target = 'Setup Helper'; Success = $true; Message = $(if ($update.UpdateAvailable) { "v$($update.LatestVersion) available" } else { 'Current' }); Update = $update }
        }
        catch { $results += [pscustomobject]@{ Target = 'Setup Helper'; Success = $false; Message = $_.Exception.Message } }
    }
    return $results
}

function Export-SahSystemReport {
    param([Parameter(Mandatory = $true)][string]$Path)
    $report = [ordered]@{
        diagnostics = Get-SahSystemDiagnostics
        applications = @((Get-SahCatalog).apps | ForEach-Object { Get-SahAppStatus -App $_ })
        repositories = Get-SahRepositoryInventory
        privacy = Get-SahPrivacySnapshot
        generatedAt = (Get-Date).ToString('o')
    }
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    return $Path
}

Export-ModuleMember -Function *-Sah*
