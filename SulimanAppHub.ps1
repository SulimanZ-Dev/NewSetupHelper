[CmdletBinding()]
param()

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
$script:CancelRequested = $false
$script:LastFailedApps = @()
$script:AllApps = @()
$script:Catalog = $null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modulePath = Join-Path $script:Root 'modules\SulimanAppHub.Core.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    [System.Windows.Forms.MessageBox]::Show("Core module not found: $modulePath", 'Suliman App Hub') | Out-Null
    exit 1
}

Import-Module $modulePath -Force
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Colors = @{
    Background = [Drawing.Color]::FromArgb(12, 12, 12)
    Surface = [Drawing.Color]::FromArgb(24, 24, 24)
    SurfaceAlt = [Drawing.Color]::FromArgb(34, 34, 34)
    Border = [Drawing.Color]::FromArgb(76, 20, 20)
    Accent = [Drawing.Color]::FromArgb(190, 0, 0)
    AccentHover = [Drawing.Color]::FromArgb(225, 15, 15)
    Text = [Drawing.Color]::FromArgb(238, 238, 238)
    Muted = [Drawing.Color]::FromArgb(155, 155, 155)
    Success = [Drawing.Color]::FromArgb(60, 180, 105)
    Warning = [Drawing.Color]::FromArgb(238, 176, 45)
    Error = [Drawing.Color]::FromArgb(235, 35, 35)
}

$script:Text = @{
    sv = @{
        Dashboard = 'Oversikt'; Apps = 'Appar'; Profiles = 'Profiler'; Repositories = 'Repositories'; Backup = 'Backup'; Diagnostics = 'Diagnostik'; History = 'Historik'; Settings = 'Installningar'
        Install = 'Installera'; Update = 'Uppdatera'; Uninstall = 'Avinstallera'; Refresh = 'Uppdatera status'; Cancel = 'Avbryt ko'; Retry = 'Forsok igen'; Search = 'Sok appar...'
        UpdateAll = 'Uppdatera allt'; OpenTerminal = 'Oppna terminalversion'; CheckUpdates = 'Sok helper-uppdatering'; Ready = 'Redo'; Confirm = 'Bekrafta'; Yes = 'Ja'; No = 'Nej'
    }
    en = @{
        Dashboard = 'Overview'; Apps = 'Apps'; Profiles = 'Profiles'; Repositories = 'Repositories'; Backup = 'Backup'; Diagnostics = 'Diagnostics'; History = 'History'; Settings = 'Settings'
        Install = 'Install'; Update = 'Update'; Uninstall = 'Uninstall'; Refresh = 'Refresh status'; Cancel = 'Cancel queue'; Retry = 'Retry'; Search = 'Search apps...'
        UpdateAll = 'Update everything'; OpenTerminal = 'Open terminal edition'; CheckUpdates = 'Check helper update'; Ready = 'Ready'; Confirm = 'Confirm'; Yes = 'Yes'; No = 'No'
    }
}

$script:Config = Get-SahConfig
$script:Language = if ($script:Text.ContainsKey([string]$script:Config.language)) { [string]$script:Config.language } else { 'sv' }
function T([string]$Key) { return $script:Text[$script:Language][$Key] }

function New-HubButton {
    param([string]$Text, [int]$Width = 130, [switch]$Primary, [switch]$Danger)
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = 34
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $script:Colors.Border
    $button.Font = New-Object Drawing.Font('Segoe UI', 9)
    $button.Cursor = 'Hand'
    if ($Primary) { $button.BackColor = $script:Colors.Accent; $button.ForeColor = [Drawing.Color]::White }
    elseif ($Danger) { $button.BackColor = [Drawing.Color]::FromArgb(70, 12, 12); $button.ForeColor = $script:Colors.Error }
    else { $button.BackColor = $script:Colors.SurfaceAlt; $button.ForeColor = $script:Colors.Text }
    return $button
}

function New-HubLabel {
    param([string]$Text, [float]$Size = 9, [switch]$Bold, [Drawing.Color]$Color = $script:Colors.Text)
    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $true
    $style = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $label.Font = New-Object Drawing.Font('Segoe UI', $Size, $style)
    $label.ForeColor = $Color
    return $label
}

function Set-HubStatus {
    param([string]$Message, [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Kind = 'Info')
    $script:StatusLabel.Text = $Message
    $script:StatusLabel.ForeColor = switch ($Kind) { 'Success' { $script:Colors.Success } 'Warning' { $script:Colors.Warning } 'Error' { $script:Colors.Error } default { $script:Colors.Text } }
    [Windows.Forms.Application]::DoEvents()
}

function Confirm-Hub {
    param([string]$Message)
    return [Windows.Forms.MessageBox]::Show($Message, (T 'Confirm'), 'YesNo', 'Warning') -eq 'Yes'
}

function Initialize-Grid {
    param([Windows.Forms.DataGridView]$Grid)
    $Grid.BackgroundColor = $script:Colors.Background
    $Grid.BorderStyle = 'None'
    $Grid.GridColor = $script:Colors.Border
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.ColumnHeadersDefaultCellStyle.BackColor = $script:Colors.SurfaceAlt
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:Colors.Text
    $Grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $script:Colors.SurfaceAlt
    $Grid.DefaultCellStyle.BackColor = $script:Colors.Surface
    $Grid.DefaultCellStyle.ForeColor = $script:Colors.Text
    $Grid.DefaultCellStyle.SelectionBackColor = [Drawing.Color]::FromArgb(80, 12, 12)
    $Grid.DefaultCellStyle.SelectionForeColor = [Drawing.Color]::White
    $Grid.RowHeadersVisible = $false
    $Grid.AllowUserToAddRows = $false
    $Grid.AllowUserToDeleteRows = $false
    $Grid.AllowUserToResizeRows = $false
    $Grid.SelectionMode = 'FullRowSelect'
    $Grid.MultiSelect = $true
    $Grid.AutoSizeColumnsMode = 'Fill'
    $Grid.Font = New-Object Drawing.Font('Segoe UI', 9)
    $Grid.ColumnHeadersHeight = 34
    $Grid.RowTemplate.Height = 30
}

function Get-SelectedApps {
    $selected = @()
    foreach ($row in $script:AppsGrid.Rows) {
        if ([bool]$row.Cells['Selected'].Value) {
            $id = [string]$row.Cells['Id'].Value
            $app = @($script:AllApps | Where-Object { $_.id -eq $id } | Select-Object -First 1)
            if ($app.Count -gt 0) { $selected += ,$app[0] }
        }
    }
    return $selected
}

function Update-AppsGrid {
    param([switch]$Remote)
    $search = [string]$script:SearchBox.Text
    $category = [string]$script:CategoryBox.SelectedItem
    $script:AppsGrid.Rows.Clear()
    $apps = @($script:AllApps | Where-Object {
        (-not $search -or $_.name -like "*$search*" -or $_.id -like "*$search*") -and
        ($category -eq 'Alla' -or $category -eq 'All' -or $_.category -eq $category)
    })
    $index = 0
    foreach ($app in $apps) {
        Set-HubStatus -Message "Kontrollerar $($app.name)..."
        $status = Get-SahAppStatus -App $app -CheckRemote:$Remote
        $statusText = if ($status.UpdateAvailable) { 'Uppdatering finns' } elseif ($status.Installed) { 'Installerad' } else { 'Ej installerad' }
        [void]$script:AppsGrid.Rows.Add($false, $app.id, $app.name, $app.category, $status.Source, $status.InstalledVersion, $status.LatestVersion, $statusText)
        $index++
        if ($index % 3 -eq 0) { [Windows.Forms.Application]::DoEvents() }
    }
    Set-HubStatus -Message (T 'Ready') -Kind 'Success'
}

function Invoke-AppQueue {
    param([ValidateSet('Install', 'Update', 'Uninstall')][string]$Mode, [array]$Apps)
    if ($Apps.Count -eq 0) { Set-HubStatus -Message 'Valj minst en app.' -Kind 'Warning'; return }
    $confirmation = "$Mode $($Apps.Count) app(ar)?"
    if ($Mode -in @('Install', 'Update')) {
        $releaseDetails = @()
        foreach ($githubApp in @($Apps | Where-Object { $_.kind -eq 'GitHub' })) {
            try {
                $release = Get-SahLatestRelease -Repository $githubApp.repository
                $notes = ([string]$release.body -replace "`r?`n", ' ').Trim()
                if ($notes.Length -gt 240) { $notes = $notes.Substring(0, 240) + '...' }
                $releaseDetails += "$($githubApp.name) $($release.tag_name): $notes"
            }
            catch { $releaseDetails += "$($githubApp.name): release notes kunde inte hamtas." }
        }
        if ($releaseDetails.Count -gt 0) { $confirmation += "`r`n`r`nSenaste release notes:`r`n" + ($releaseDetails -join "`r`n`r`n") }
    }
    if (-not (Confirm-Hub -Message $confirmation)) { return }
    if ($Apps.Count -ge 3 -or $Mode -eq 'Uninstall') { New-SahRestorePoint -Description "Before Suliman App Hub $Mode" | Out-Null }
    $script:CancelRequested = $false
    $script:LastFailedApps = @()
    $script:ProgressBar.Value = 0
    $script:ProgressBar.Maximum = $Apps.Count
    for ($i = 0; $i -lt $Apps.Count; $i++) {
        if ($script:CancelRequested) { Set-HubStatus -Message 'Kon avbrots efter aktuell app.' -Kind 'Warning'; break }
        $app = $Apps[$i]
        Set-HubStatus -Message "[$($i + 1)/$($Apps.Count)] $Mode $($app.name)..."
        [Windows.Forms.Application]::DoEvents()
        $postActions = @()
        if ($script:ShortcutCheck.Checked) { $postActions += 'Shortcut' }
        if ($script:PinCheck.Checked) { $postActions += 'PinToTaskbar' }
        if ($script:LaunchCheck.Checked) { $postActions += 'Launch' }
        if ($script:SettingsCheck.Checked) { $postActions += 'Settings' }
        $result = switch ($Mode) { 'Install' { Install-SahApp -App $app -PostActions $postActions } 'Update' { Update-SahApp -App $app } 'Uninstall' { Uninstall-SahApp -App $app } }
        if (-not $result.Success) { $script:LastFailedApps += ,$app; Set-HubStatus -Message "$($app.name): $($result.Message)" -Kind 'Error' }
        else { Set-HubStatus -Message "$($app.name): klar" -Kind 'Success' }
        $script:ProgressBar.Value = $i + 1
        [Windows.Forms.Application]::DoEvents()
    }
    $script:RetryButton.Enabled = $script:LastFailedApps.Count -gt 0
    Update-AppsGrid
}

function Refresh-Repositories {
    $script:RepoGrid.Rows.Clear()
    foreach ($repo in @(Get-SahRepositoryInventory)) {
        [void]$script:RepoGrid.Rows.Add($repo.Name, $repo.Branch, $(if ($repo.Dirty) { 'Lokala andringar' } else { 'Ren' }), $repo.Path, $repo.Remote)
        $script:RepoGrid.Rows[$script:RepoGrid.Rows.Count - 1].Tag = $repo
    }
}

function Get-SelectedRepository {
    if ($script:RepoGrid.SelectedRows.Count -eq 0) { return $null }
    return $script:RepoGrid.SelectedRows[0].Tag
}

function Refresh-History {
    $script:HistoryGrid.Rows.Clear()
    foreach ($item in @(Get-SahHistory -Limit 300)) {
        [void]$script:HistoryGrid.Rows.Add($item.timestamp, $item.action, $item.target, $item.success, $item.version, $item.message, $item.operationId)
    }
}

function Refresh-Diagnostics {
    $diagnostics = Get-SahSystemDiagnostics
    $script:DiagnosticsBox.Text = ($diagnostics | Format-List | Out-String).Trim()
    $script:DashboardInfo.Text = "Windows: $($diagnostics.Windows) $($diagnostics.Build)`r`nRAM: $($diagnostics.RamGB) GB`r`nLedigt diskutrymme: $($diagnostics.FreeDiskGB) GB`r`nwinget: $($diagnostics.Winget)`r`nGit: $($diagnostics.Git)`r`nNode: $($diagnostics.Node)`r`nSpicetify: $($diagnostics.Spicetify)`r`nDrivrutinsproblem: $($diagnostics.DriverErrors)"
}

$form = New-Object Windows.Forms.Form
$form.Text = "Suliman App Hub v$script:HubVersion"
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object Drawing.Size(1220, 790)
$form.MinimumSize = New-Object Drawing.Size(980, 650)
$form.BackColor = $script:Colors.Background
$form.ForeColor = $script:Colors.Text
$form.Font = New-Object Drawing.Font('Segoe UI', 9)

$header = New-Object Windows.Forms.Panel
$header.Dock = 'Top'; $header.Height = 72; $header.BackColor = $script:Colors.Surface
$title = New-HubLabel -Text 'SULIMAN APP HUB' -Size 18 -Bold -Color $script:Colors.Accent
$title.Location = New-Object Drawing.Point(22, 13)
$subtitle = New-HubLabel -Text 'Apps, repositories, backup och systemverktyg' -Size 9 -Color $script:Colors.Muted
$subtitle.Location = New-Object Drawing.Point(24, 45)
$terminalButton = New-HubButton -Text (T 'OpenTerminal') -Width 180
$terminalButton.Anchor = 'Top,Right'; $terminalButton.Location = New-Object Drawing.Point(1000, 18)
$header.Controls.AddRange(@($title, $subtitle, $terminalButton))
$form.Controls.Add($header)

$footer = New-Object Windows.Forms.Panel
$footer.Dock = 'Bottom'; $footer.Height = 42; $footer.BackColor = $script:Colors.Surface
$script:StatusLabel = New-HubLabel -Text (T 'Ready') -Size 9 -Color $script:Colors.Text
$script:StatusLabel.Location = New-Object Drawing.Point(18, 13)
$script:ProgressBar = New-Object Windows.Forms.ProgressBar
$script:ProgressBar.Anchor = 'Top,Right'; $script:ProgressBar.Size = New-Object Drawing.Size(290, 16); $script:ProgressBar.Location = New-Object Drawing.Point(890, 13)
$footer.Controls.AddRange(@($script:StatusLabel, $script:ProgressBar))
$form.Controls.Add($footer)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Dock = 'Fill'; $tabs.Padding = New-Object Drawing.Point(18, 7); $tabs.BackColor = $script:Colors.Background
$tabs.Font = New-Object Drawing.Font('Segoe UI', 9)
$tabs.DrawMode = 'OwnerDrawFixed'; $tabs.SizeMode = 'Fixed'; $tabs.ItemSize = New-Object Drawing.Size(112, 30)
$tabs.Add_DrawItem({
    param($sender, $eventArgs)
    $selected = $eventArgs.Index -eq $sender.SelectedIndex
    $background = if ($selected) { $script:Colors.Accent } else { $script:Colors.Surface }
    $foreground = if ($selected) { [Drawing.Color]::White } else { $script:Colors.Text }
    $brush = New-Object Drawing.SolidBrush($background)
    try {
        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics, $sender.TabPages[$eventArgs.Index].Text, $sender.Font, $eventArgs.Bounds, $foreground, $flags)
    }
    finally { $brush.Dispose() }
})
$form.Controls.Add($tabs)
$tabs.BringToFront()

function New-HubTab([string]$Name) {
    $tab = New-Object Windows.Forms.TabPage
    $tab.Text = $Name; $tab.BackColor = $script:Colors.Background; $tab.ForeColor = $script:Colors.Text; $tab.Padding = New-Object Windows.Forms.Padding(18)
    $tabs.TabPages.Add($tab) | Out-Null
    return $tab
}

# Dashboard
$dashboardTab = New-HubTab (T 'Dashboard')
$dashTitle = New-HubLabel -Text 'Kontrollcenter' -Size 16 -Bold -Color $script:Colors.Text
$dashTitle.Location = New-Object Drawing.Point(24, 24)
$dashText = New-HubLabel -Text 'Hantera dina appar och repositories fran samma motor som terminalversionen.' -Size 10 -Color $script:Colors.Muted
$dashText.Location = New-Object Drawing.Point(26, 58)
$script:DashboardInfo = New-Object Windows.Forms.TextBox
$script:DashboardInfo.Location = New-Object Drawing.Point(28, 105); $script:DashboardInfo.Size = New-Object Drawing.Size(560, 280); $script:DashboardInfo.Multiline = $true; $script:DashboardInfo.ReadOnly = $true
$script:DashboardInfo.BackColor = $script:Colors.Surface; $script:DashboardInfo.ForeColor = $script:Colors.Text; $script:DashboardInfo.BorderStyle = 'FixedSingle'; $script:DashboardInfo.Font = New-Object Drawing.Font('Consolas', 10)
$updateAllButton = New-HubButton -Text (T 'UpdateAll') -Width 170 -Primary
$updateAllButton.Location = New-Object Drawing.Point(630, 105)
$checkHelperButton = New-HubButton -Text (T 'CheckUpdates') -Width 190
$checkHelperButton.Location = New-Object Drawing.Point(630, 151)
$restorePointButton = New-HubButton -Text 'Skapa aterstallningspunkt' -Width 190
$restorePointButton.Location = New-Object Drawing.Point(630, 197)
$dashboardTab.Controls.AddRange(@($dashTitle, $dashText, $script:DashboardInfo, $updateAllButton, $checkHelperButton, $restorePointButton))

# Apps
$appsTab = New-HubTab (T 'Apps')
$appsFilter = New-Object Windows.Forms.Panel; $appsFilter.Dock = 'Top'; $appsFilter.Height = 46; $appsFilter.BackColor = $script:Colors.Background
$script:SearchBox = New-Object Windows.Forms.TextBox
$searchLabel = New-HubLabel -Text 'Sok:' -Size 9 -Color $script:Colors.Muted; $searchLabel.Location = New-Object Drawing.Point(0, 7)
$script:SearchBox.Location = New-Object Drawing.Point(40, 4); $script:SearchBox.Width = 230; $script:SearchBox.BackColor = $script:Colors.SurfaceAlt; $script:SearchBox.ForeColor = $script:Colors.Text; $script:SearchBox.BorderStyle = 'FixedSingle'
$categoryLabel = New-HubLabel -Text 'Kategori:' -Size 9 -Color $script:Colors.Muted; $categoryLabel.Location = New-Object Drawing.Point(286, 7)
$script:CategoryBox = New-Object Windows.Forms.ComboBox
$script:CategoryBox.Location = New-Object Drawing.Point(352, 3); $script:CategoryBox.Width = 170; $script:CategoryBox.DropDownStyle = 'DropDownList'; $script:CategoryBox.BackColor = $script:Colors.SurfaceAlt; $script:CategoryBox.ForeColor = $script:Colors.Text
$appsFilter.Controls.AddRange(@($searchLabel,$script:SearchBox,$categoryLabel,$script:CategoryBox))
$script:AppsGrid = New-Object Windows.Forms.DataGridView
$script:AppsGrid.Dock = 'Fill'
Initialize-Grid $script:AppsGrid
$selectedColumn = New-Object Windows.Forms.DataGridViewCheckBoxColumn -Property @{ Name = 'Selected'; HeaderText = ''; Width = 42; AutoSizeMode = 'None' }
[void]$script:AppsGrid.Columns.Add($selectedColumn)
[void]$script:AppsGrid.Columns.Add('Id', 'ID'); $script:AppsGrid.Columns['Id'].Visible = $false
foreach ($column in @(@('Name','Namn',130),@('Category','Kategori',75),@('Source','Kalla',45),@('Current','Installerad',60),@('Latest','Senaste',60),@('Status','Status',80))) { [void]$script:AppsGrid.Columns.Add($column[0],$column[1]); $script:AppsGrid.Columns[$column[0]].AutoSizeMode = 'Fill'; $script:AppsGrid.Columns[$column[0]].FillWeight = $column[2]; $script:AppsGrid.Columns[$column[0]].MinimumWidth = 72 }
$appsButtons = New-Object Windows.Forms.FlowLayoutPanel
$appsButtons.Dock = 'Bottom'; $appsButtons.Height = 82; $appsButtons.FlowDirection = 'LeftToRight'; $appsButtons.WrapContents = $true; $appsButtons.Padding = New-Object Windows.Forms.Padding(0,8,0,0)
$installButton = New-HubButton -Text (T 'Install') -Primary
$updateButton = New-HubButton -Text (T 'Update')
$uninstallButton = New-HubButton -Text (T 'Uninstall') -Danger
$refreshButton = New-HubButton -Text (T 'Refresh') -Width 150
$cancelButton = New-HubButton -Text (T 'Cancel') -Width 120 -Danger
$script:RetryButton = New-HubButton -Text (T 'Retry') -Width 110; $script:RetryButton.Enabled = $false
$script:ShortcutCheck = New-Object Windows.Forms.CheckBox; $script:ShortcutCheck.Text = 'Genvag'; $script:ShortcutCheck.AutoSize = $true; $script:ShortcutCheck.ForeColor = $script:Colors.Text; $script:ShortcutCheck.Margin = New-Object Windows.Forms.Padding(12,9,3,3)
$script:PinCheck = New-Object Windows.Forms.CheckBox; $script:PinCheck.Text = 'Fast'; $script:PinCheck.AutoSize = $true; $script:PinCheck.ForeColor = $script:Colors.Text; $script:PinCheck.Margin = New-Object Windows.Forms.Padding(8,9,3,3)
$script:LaunchCheck = New-Object Windows.Forms.CheckBox; $script:LaunchCheck.Text = 'Starta'; $script:LaunchCheck.AutoSize = $true; $script:LaunchCheck.ForeColor = $script:Colors.Text; $script:LaunchCheck.Margin = New-Object Windows.Forms.Padding(8,9,3,3)
$script:SettingsCheck = New-Object Windows.Forms.CheckBox; $script:SettingsCheck.Text = 'Installningar'; $script:SettingsCheck.AutoSize = $true; $script:SettingsCheck.ForeColor = $script:Colors.Text; $script:SettingsCheck.Margin = New-Object Windows.Forms.Padding(8,9,3,3)
$appsButtons.Controls.AddRange(@($installButton,$updateButton,$uninstallButton,$refreshButton,$cancelButton,$script:RetryButton,$script:ShortcutCheck,$script:PinCheck,$script:LaunchCheck,$script:SettingsCheck))
$appsTab.Controls.Add($script:AppsGrid); $appsTab.Controls.Add($appsButtons); $appsTab.Controls.Add($appsFilter)
$appsFilter.BringToFront(); $appsButtons.BringToFront()

# Profiles
$profilesTab = New-HubTab (T 'Profiles')
$profileLabel = New-HubLabel -Text 'Fardiga installationsprofiler' -Size 15 -Bold
$profileLabel.Location = New-Object Drawing.Point(24, 24)
$script:ProfileList = New-Object Windows.Forms.ListBox
$script:ProfileList.Location = New-Object Drawing.Point(26, 68); $script:ProfileList.Size = New-Object Drawing.Size(300, 420); $script:ProfileList.BackColor = $script:Colors.Surface; $script:ProfileList.ForeColor = $script:Colors.Text; $script:ProfileList.BorderStyle = 'FixedSingle'; $script:ProfileList.DisplayMember = 'DisplayName'
$script:ProfileDescription = New-Object Windows.Forms.TextBox
$script:ProfileDescription.Location = New-Object Drawing.Point(360, 68); $script:ProfileDescription.Size = New-Object Drawing.Size(650, 300); $script:ProfileDescription.Multiline = $true; $script:ProfileDescription.ReadOnly = $true; $script:ProfileDescription.BackColor = $script:Colors.Surface; $script:ProfileDescription.ForeColor = $script:Colors.Text; $script:ProfileDescription.BorderStyle = 'FixedSingle'
$installProfileButton = New-HubButton -Text 'Installera vald profil' -Width 190 -Primary
$installProfileButton.Location = New-Object Drawing.Point(360, 390)
$profilesTab.Controls.AddRange(@($profileLabel,$script:ProfileList,$script:ProfileDescription,$installProfileButton))

# Repositories
$reposTab = New-HubTab (T 'Repositories')
$script:RepoGrid = New-Object Windows.Forms.DataGridView
$script:RepoGrid.Location = New-Object Drawing.Point(22, 24); $script:RepoGrid.Anchor = 'Top,Bottom,Left,Right'; $script:RepoGrid.Size = New-Object Drawing.Size(1120, 540)
Initialize-Grid $script:RepoGrid
foreach ($column in @(@('Name','Namn'),@('Branch','Branch'),@('State','Tillstand'),@('Path','Sokvag'),@('Remote','Remote'))) { [void]$script:RepoGrid.Columns.Add($column[0],$column[1]) }
$repoButtons = New-Object Windows.Forms.FlowLayoutPanel
$repoButtons.Location = New-Object Drawing.Point(22, 578); $repoButtons.Anchor = 'Bottom,Left,Right'; $repoButtons.Size = New-Object Drawing.Size(1120, 42)
$cloneButton = New-HubButton -Text 'Klona fran katalog' -Width 160 -Primary
$pullButton = New-HubButton -Text 'git pull' -Width 100
$openRepoButton = New-HubButton -Text 'Oppna mapp' -Width 120
$codeButton = New-HubButton -Text 'VS Code' -Width 100
$repairButton = New-HubButton -Text 'Kontrollera/reparera' -Width 170
$refreshReposButton = New-HubButton -Text (T 'Refresh') -Width 150
$repoButtons.Controls.AddRange(@($cloneButton,$pullButton,$openRepoButton,$codeButton,$repairButton,$refreshReposButton))
$reposTab.Controls.AddRange(@($script:RepoGrid,$repoButtons))

# Backup
$backupTab = New-HubTab (T 'Backup')
$backupTitle = New-HubLabel -Text 'Backup och migrering' -Size 15 -Bold
$backupTitle.Location = New-Object Drawing.Point(24, 24)
$backupInfo = New-HubLabel -Text 'Exportera appar, repositories, Spicetify, installningar och systeminformation till en ZIP.' -Size 10 -Color $script:Colors.Muted
$backupInfo.Location = New-Object Drawing.Point(26, 58)
$exportBackupButton = New-HubButton -Text 'Exportera datorprofil' -Width 190 -Primary; $exportBackupButton.Location = New-Object Drawing.Point(26, 105)
$importBackupButton = New-HubButton -Text 'Aterstall datorprofil' -Width 190; $importBackupButton.Location = New-Object Drawing.Point(230, 105)
$compareBackupButton = New-HubButton -Text 'Jamfor med backup' -Width 180; $compareBackupButton.Location = New-Object Drawing.Point(434, 105)
$exportReportButton = New-HubButton -Text 'Exportera systemrapport' -Width 200; $exportReportButton.Location = New-Object Drawing.Point(628, 105)
$script:BackupOutput = New-Object Windows.Forms.TextBox
$script:BackupOutput.Location = New-Object Drawing.Point(26, 165); $script:BackupOutput.Size = New-Object Drawing.Size(980, 390); $script:BackupOutput.Anchor = 'Top,Bottom,Left,Right'; $script:BackupOutput.Multiline = $true; $script:BackupOutput.ReadOnly = $true; $script:BackupOutput.ScrollBars = 'Vertical'; $script:BackupOutput.BackColor = $script:Colors.Surface; $script:BackupOutput.ForeColor = $script:Colors.Text; $script:BackupOutput.Font = New-Object Drawing.Font('Consolas', 9)
$backupTab.Controls.AddRange(@($backupTitle,$backupInfo,$exportBackupButton,$importBackupButton,$compareBackupButton,$exportReportButton,$script:BackupOutput))

# Diagnostics
$diagnosticsTab = New-HubTab (T 'Diagnostics')
$script:DiagnosticsBox = New-Object Windows.Forms.TextBox
$script:DiagnosticsBox.Location = New-Object Drawing.Point(22, 64); $script:DiagnosticsBox.Size = New-Object Drawing.Size(1000, 520); $script:DiagnosticsBox.Anchor = 'Top,Bottom,Left,Right'; $script:DiagnosticsBox.Multiline = $true; $script:DiagnosticsBox.ReadOnly = $true; $script:DiagnosticsBox.ScrollBars = 'Vertical'; $script:DiagnosticsBox.BackColor = $script:Colors.Surface; $script:DiagnosticsBox.ForeColor = $script:Colors.Text; $script:DiagnosticsBox.Font = New-Object Drawing.Font('Consolas', 10)
$refreshDiagnosticsButton = New-HubButton -Text (T 'Refresh') -Width 150 -Primary; $refreshDiagnosticsButton.Location = New-Object Drawing.Point(22, 18)
$diagnosticsTab.Controls.AddRange(@($script:DiagnosticsBox,$refreshDiagnosticsButton))

# History
$historyTab = New-HubTab (T 'History')
$script:HistoryGrid = New-Object Windows.Forms.DataGridView
$script:HistoryGrid.Location = New-Object Drawing.Point(22, 62); $script:HistoryGrid.Size = New-Object Drawing.Size(1120, 530); $script:HistoryGrid.Anchor = 'Top,Bottom,Left,Right'; Initialize-Grid $script:HistoryGrid
foreach ($column in @(@('When','Tid'),@('Action','Atgard'),@('Target','Mal'),@('Success','OK'),@('Version','Version'),@('Message','Meddelande'),@('Operation','Felsoknings-ID'))) { [void]$script:HistoryGrid.Columns.Add($column[0],$column[1]) }
$refreshHistoryButton = New-HubButton -Text (T 'Refresh') -Width 150 -Primary; $refreshHistoryButton.Location = New-Object Drawing.Point(22, 18)
$openLogButton = New-HubButton -Text 'Oppna logg' -Width 120; $openLogButton.Location = New-Object Drawing.Point(185, 18)
$historyTab.Controls.AddRange(@($script:HistoryGrid,$refreshHistoryButton,$openLogButton))

# Settings
$settingsTab = New-HubTab (T 'Settings')
$settingsTitle = New-HubLabel -Text 'Installningar och egen katalog' -Size 15 -Bold; $settingsTitle.Location = New-Object Drawing.Point(24, 24)
$languageLabel = New-HubLabel -Text 'Sprak'; $languageLabel.Location = New-Object Drawing.Point(26, 78)
$languageBox = New-Object Windows.Forms.ComboBox; $languageBox.Location = New-Object Drawing.Point(190, 74); $languageBox.Width = 180; $languageBox.DropDownStyle = 'DropDownList'; [void]$languageBox.Items.AddRange(@('sv','en')); $languageBox.SelectedItem = $script:Language
$sourceLabel = New-HubLabel -Text 'Repository-mapp'; $sourceLabel.Location = New-Object Drawing.Point(26, 124)
$sourceBox = New-Object Windows.Forms.TextBox; $sourceBox.Location = New-Object Drawing.Point(190, 120); $sourceBox.Width = 520; $sourceBox.Text = [string]$script:Config.sourceRoot
$portableLabel = New-HubLabel -Text 'Portabla appar'; $portableLabel.Location = New-Object Drawing.Point(26, 170)
$portableBox = New-Object Windows.Forms.TextBox; $portableBox.Location = New-Object Drawing.Point(190, 166); $portableBox.Width = 520; $portableBox.Text = [string]$script:Config.portableInstallRoot
$autoUpdateCheck = New-Object Windows.Forms.CheckBox; $autoUpdateCheck.Text = 'Sok automatiskt efter helper-uppdateringar'; $autoUpdateCheck.Location = New-Object Drawing.Point(190, 212); $autoUpdateCheck.AutoSize = $true; $autoUpdateCheck.Checked = [bool]$script:Config.autoCheckUpdates; $autoUpdateCheck.ForeColor = $script:Colors.Text
$checksumCheck = New-Object Windows.Forms.CheckBox; $checksumCheck.Text = 'Verifiera SHA-256 nar checksumma publiceras'; $checksumCheck.Location = New-Object Drawing.Point(190, 246); $checksumCheck.AutoSize = $true; $checksumCheck.Checked = [bool]$script:Config.verifyChecksums; $checksumCheck.ForeColor = $script:Colors.Text
$restoreCheck = New-Object Windows.Forms.CheckBox; $restoreCheck.Text = 'Forsok skapa aterstallningspunkt fore stora andringar'; $restoreCheck.Location = New-Object Drawing.Point(190, 280); $restoreCheck.AutoSize = $true; $restoreCheck.Checked = [bool]$script:Config.createRestorePoint; $restoreCheck.ForeColor = $script:Colors.Text
$saveSettingsButton = New-HubButton -Text 'Spara installningar' -Width 170 -Primary; $saveSettingsButton.Location = New-Object Drawing.Point(190, 330)
$editConfigButton = New-HubButton -Text 'Redigera egna appar och repos' -Width 230; $editConfigButton.Location = New-Object Drawing.Point(375, 330)
$settingsHint = New-HubLabel -Text 'Egna winget-ID:n, GitHub-repositories och profiler laggs till i hub-config.json. Felaktig JSON sakerhetskopieras automatiskt.' -Size 9 -Color $script:Colors.Muted; $settingsHint.Location = New-Object Drawing.Point(190, 385)
$settingsTab.Controls.AddRange(@($settingsTitle,$languageLabel,$languageBox,$sourceLabel,$sourceBox,$portableLabel,$portableBox,$autoUpdateCheck,$checksumCheck,$restoreCheck,$saveSettingsButton,$editConfigButton,$settingsHint))

# Events
$form.Add_Resize({ $terminalButton.Left = $form.ClientSize.Width - $terminalButton.Width - 24; $script:ProgressBar.Left = $form.ClientSize.Width - $script:ProgressBar.Width - 24 })
$terminalButton.Add_Click({
    $terminalExe = Join-Path $script:Root 'SulimanAppHub.Terminal.exe'
    $terminalScript = Join-Path $script:Root 'SulimanAppHub.Terminal.ps1'
    if (Test-Path $terminalExe) { Start-Process $terminalExe }
    elseif (Test-Path $terminalScript) { Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$terminalScript) }
    else { [Windows.Forms.MessageBox]::Show('Terminalversionen hittades inte bredvid appen.') | Out-Null }
})
$script:SearchBox.Add_TextChanged({ Update-AppsGrid })
$script:CategoryBox.Add_SelectedIndexChanged({ Update-AppsGrid })
$installButton.Add_Click({ Invoke-AppQueue -Mode Install -Apps @(Get-SelectedApps) })
$updateButton.Add_Click({ Invoke-AppQueue -Mode Update -Apps @(Get-SelectedApps) })
$uninstallButton.Add_Click({ Invoke-AppQueue -Mode Uninstall -Apps @(Get-SelectedApps) })
$refreshButton.Add_Click({ Update-AppsGrid -Remote })
$cancelButton.Add_Click({ $script:CancelRequested = $true; Set-HubStatus -Message 'Avbryter efter aktuell app...' -Kind 'Warning' })
$script:RetryButton.Add_Click({ Invoke-AppQueue -Mode Install -Apps @($script:LastFailedApps) })
$script:ProfileList.Add_SelectedIndexChanged({
    $profile = $script:ProfileList.SelectedItem
    if ($profile) {
        $apps = @(Get-SahProfileApps -ProfileId $profile.Id)
        $script:ProfileDescription.Text = "$($profile.Description)`r`n`r`nAppar:`r`n- $($apps.name -join "`r`n- ")"
    }
})
$installProfileButton.Add_Click({
    $profile = $script:ProfileList.SelectedItem
    if (-not $profile) { return }
    $apps = @(Get-SahProfileApps -ProfileId $profile.Id)
    Invoke-AppQueue -Mode Install -Apps $apps
})
$refreshReposButton.Add_Click({ Refresh-Repositories })
$pullButton.Add_Click({ $repo = Get-SelectedRepository; if ($repo) { $result = Invoke-SahRepositoryAction -Repository $repo -Action Pull; Set-HubStatus "$($result.Message)" $(if ($result.Success) {'Success'} else {'Error'}); Refresh-Repositories } })
$openRepoButton.Add_Click({ $repo = Get-SelectedRepository; if ($repo) { Invoke-SahRepositoryAction -Repository $repo -Action Open | Out-Null } })
$codeButton.Add_Click({ $repo = Get-SelectedRepository; if ($repo) { $result = Invoke-SahRepositoryAction -Repository $repo -Action Code; Set-HubStatus $result.Message $(if ($result.Success) {'Success'} else {'Error'}) } })
$repairButton.Add_Click({ $repo = Get-SelectedRepository; if ($repo -and (Confirm-Hub 'Kontrollera git-objekt och rensa gamla remote-referenser?')) { $result = Invoke-SahRepositoryAction -Repository $repo -Action Repair; Set-HubStatus $result.Message $(if ($result.Success) {'Success'} else {'Error'}) } })
$cloneButton.Add_Click({
    $available = @($script:Catalog.repositories)
    $picker = New-Object Windows.Forms.Form; $picker.Text = 'Klona repository'; $picker.Size = New-Object Drawing.Size(460,430); $picker.StartPosition = 'CenterParent'; $picker.BackColor = $script:Colors.Background
    $list = New-Object Windows.Forms.CheckedListBox; $list.Dock = 'Fill'; $list.BackColor = $script:Colors.Surface; $list.ForeColor = $script:Colors.Text; $list.CheckOnClick = $true
    foreach ($repo in $available) { [void]$list.Items.Add($repo.name) }
    $ok = New-HubButton -Text 'Klona valda' -Width 130 -Primary; $ok.Dock = 'Bottom'
    $ok.Add_Click({ $picker.DialogResult = 'OK'; $picker.Close() })
    $picker.Controls.Add($list); $picker.Controls.Add($ok)
    if ($picker.ShowDialog($form) -eq 'OK') {
        foreach ($index in $list.CheckedIndices) { $result = Install-SahRepository -Repository $available[$index]; Set-HubStatus "$($available[$index].name): $($result.Message)" $(if($result.Success){'Success'}else{'Error'}) }
        Refresh-Repositories
    }
})
$exportBackupButton.Add_Click({
    $dialog = New-Object Windows.Forms.SaveFileDialog; $dialog.Filter = 'ZIP backup (*.zip)|*.zip'; $dialog.FileName = "Suliman-PC-Backup-$(Get-Date -Format 'yyyyMMdd-HHmm').zip"
    if ($dialog.ShowDialog() -eq 'OK') { Set-HubStatus 'Skapar backup...'; $result = Export-SahComputerProfile -DestinationPath $dialog.FileName; $script:BackupOutput.Text = ($result | Format-List | Out-String); Set-HubStatus $result.Message $(if($result.Success){'Success'}else{'Error'}) }
})
$importBackupButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog; $dialog.Filter = 'ZIP backup (*.zip)|*.zip'
    if ($dialog.ShowDialog() -eq 'OK' -and (Confirm-Hub 'Detta aterstaller Hub-konfiguration, appstatus, winget-appar och Spicetify. Fortsatt?')) { New-SahRestorePoint -Description 'Before Suliman App Hub restore' | Out-Null; $result = Import-SahComputerProfile -BackupPath $dialog.FileName -InstallWingetApps -RestoreSpicetify; $script:BackupOutput.Text = ($result | Format-List | Out-String); Set-HubStatus $result.Message $(if($result.Success){'Success'}else{'Error'}) }
})
$compareBackupButton.Add_Click({ $dialog = New-Object Windows.Forms.OpenFileDialog; $dialog.Filter = 'ZIP backup (*.zip)|*.zip'; if ($dialog.ShowDialog() -eq 'OK') { $result = Compare-SahComputerProfile -BackupPath $dialog.FileName; $script:BackupOutput.Text = ($result | Format-List | Out-String) } })
$exportReportButton.Add_Click({ $dialog = New-Object Windows.Forms.SaveFileDialog; $dialog.Filter = 'JSON (*.json)|*.json'; $dialog.FileName = "Suliman-Systemrapport-$(Get-Date -Format 'yyyyMMdd-HHmm').json"; if ($dialog.ShowDialog() -eq 'OK') { Export-SahSystemReport -Path $dialog.FileName | Out-Null; Set-HubStatus "Rapport skapad: $($dialog.FileName)" -Kind Success } })
$refreshDiagnosticsButton.Add_Click({ Refresh-Diagnostics; Set-HubStatus 'Diagnostik uppdaterad.' -Kind Success })
$refreshHistoryButton.Add_Click({ Refresh-History })
$openLogButton.Add_Click({ Start-Process notepad.exe -ArgumentList (Get-SahPaths).Log })
$saveSettingsButton.Add_Click({
    $script:Config.language = [string]$languageBox.SelectedItem; $script:Config.sourceRoot = $sourceBox.Text; $script:Config.portableInstallRoot = $portableBox.Text; $script:Config.autoCheckUpdates = $autoUpdateCheck.Checked; $script:Config.verifyChecksums = $checksumCheck.Checked; $script:Config.createRestorePoint = $restoreCheck.Checked
    Save-SahConfig -Config $script:Config | Out-Null; Set-HubStatus 'Installningar sparade. Starta om for att byta sprak.' -Kind Success
})
$editConfigButton.Add_Click({ Start-Process notepad.exe -ArgumentList (Get-SahPaths).Config })
$restorePointButton.Add_Click({ $result = New-SahRestorePoint; Set-HubStatus $result.Message $(if($result.Success){'Success'}else{'Warning'}) })
$updateAllButton.Add_Click({
    if (-not (Confirm-Hub 'Uppdatera winget-appar, installerade GitHub-appar och Spicetify?')) { return }
    $script:CancelRequested = $false
    $results = Invoke-SahUpdateAll -HelperVersion $script:HubVersion -HelperEdition Gui -ProgressCallback { param($name,$index,$count) $script:ProgressBar.Maximum=$count; $script:ProgressBar.Value=$index; Set-HubStatus "Uppdaterar $name..." } -CancelCallback { return $script:CancelRequested }
    $failed = @($results | Where-Object { -not $_.Success })
    Set-HubStatus $(if($failed.Count){"Klart med $($failed.Count) fel."}else{'Allt ar uppdaterat.'}) $(if($failed.Count){'Error'}else{'Success'})
})
$checkHelperButton.Add_Click({
    try {
        Set-HubStatus 'Kontrollerar senaste release...'
        $update = Get-SahHelperUpdate -CurrentVersion $script:HubVersion -Edition Gui
        if ($update.UpdateAvailable) {
            $answer = [Windows.Forms.MessageBox]::Show("Version $($update.LatestVersion) finns.`r`n`r`n$($update.Notes)`r`n`r`nInstallera nu?", 'Uppdatering', 'YesNo', 'Information')
            if ($answer -eq 'Yes' -and $script:CurrentExecutable.EndsWith('.exe')) { $result = Start-SahSelfUpdate -Update $update -CurrentExecutable $script:CurrentExecutable; [Windows.Forms.MessageBox]::Show($result.Message) | Out-Null; $form.Close() }
        }
        else { Set-HubStatus 'Du har senaste versionen.' -Kind Success }
    }
    catch { Set-HubStatus $_.Exception.Message -Kind Error }
})

$form.Add_Shown({
    $script:Catalog = Get-SahCatalog
    $script:AllApps = @($script:Catalog.apps | Sort-Object category, name)
    $categories = @('Alla') + @($script:AllApps | ForEach-Object { $_.category } | Sort-Object -Unique)
    [void]$script:CategoryBox.Items.AddRange($categories)
    $script:CategoryBox.SelectedIndex = 0
    foreach ($profile in @($script:Catalog.profiles)) {
        $displayName = if ($script:Language -eq 'sv') { $profile.nameSv } else { $profile.nameEn }
        $description = if ($script:Language -eq 'sv') { $profile.descriptionSv } else { $profile.descriptionEn }
        [void]$script:ProfileList.Items.Add([pscustomobject]@{ Id = $profile.id; DisplayName = $displayName; Description = $description })
    }
    if ($script:ProfileList.Items.Count -gt 0) { $script:ProfileList.SelectedIndex = 0 }
    Refresh-Repositories
    Refresh-History
    Refresh-Diagnostics
    if ($script:Config.autoCheckUpdates) {
        try {
            $update = Get-SahHelperUpdate -CurrentVersion $script:HubVersion -Edition Gui
            if ($update.UpdateAvailable) { Set-HubStatus "Suliman App Hub $($update.LatestVersion) finns. Klicka 'Sok helper-uppdatering'." -Kind Warning }
        }
        catch { Set-HubStatus 'Kunde inte kontrollera helper-uppdatering.' -Kind Warning }
    }
})

[void]$form.ShowDialog()
