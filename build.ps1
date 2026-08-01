[CmdletBinding()]
param(
    [string]$Version = '3.0.0',
    [switch]$SkipTests,
    [string]$CertificateThumbprint = ''
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'

if (-not $SkipTests) { & (Join-Path $root 'scripts\Test.ps1') }

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    throw 'PS2EXE is required. Install it with: Install-Module ps2exe -Scope CurrentUser'
}

$resolvedDist = [IO.Path]::GetFullPath($dist)
$resolvedRoot = [IO.Path]::GetFullPath($root)
if (-not $resolvedDist.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid dist path.' }
if (Test-Path -LiteralPath $resolvedDist) { Remove-Item -LiteralPath $resolvedDist -Recurse -Force }
New-Item -ItemType Directory -Path $resolvedDist -Force | Out-Null

$module = Join-Path $root 'modules\SulimanAppHub.Core.psm1'
$catalog = Join-Path $root 'data\catalog.json'
$configExample = Join-Path $root 'data\hub-config.example.json'
$terminalScript = Join-Path $root 'SulimanAppHub.Terminal.ps1'
$guiScript = Join-Path $root 'SulimanAppHub.ps1'

$runtimeFiles = @{
    '.\modules\SulimanAppHub.Core.psm1' = $module
    '.\data\catalog.json' = $catalog
    '.\data\hub-config.example.json' = $configExample
}

$terminalExe = Join-Path $resolvedDist 'SulimanAppHub.Terminal.exe'
Invoke-ps2exe -inputFile $terminalScript -outputFile $terminalExe -embedFiles $runtimeFiles -title 'Suliman App Hub Terminal' -description 'Terminal edition of Suliman App Hub' -product 'Suliman App Hub' -company 'SulimanZ-Dev' -version "$Version.0" -x64

$guiRuntime = @{}
foreach ($key in $runtimeFiles.Keys) { $guiRuntime[$key] = $runtimeFiles[$key] }
$guiRuntime['.\SulimanAppHub.Terminal.ps1'] = $terminalScript
$guiExe = Join-Path $resolvedDist 'SulimanAppHub.exe'
Invoke-ps2exe -inputFile $guiScript -outputFile $guiExe -embedFiles $guiRuntime -title 'Suliman App Hub' -description 'Windows app and repository management hub' -product 'Suliman App Hub' -company 'SulimanZ-Dev' -version "$Version.0" -x64 -STA -noConsole -DPIAware -supportOS

$legacyRuntime = @{}
foreach ($key in $runtimeFiles.Keys) { $legacyRuntime[$key] = $runtimeFiles[$key] }
$legacyRuntime['.\SulimanAppHub.Terminal.ps1'] = $terminalScript
$legacyRuntime['.\SulimanAppHub.ps1'] = $guiScript
$legacyExe = Join-Path $resolvedDist 'SpicetifySetupHelper.exe'
Invoke-ps2exe -inputFile (Join-Path $root 'spicetify-app.ps1') -outputFile $legacyExe -embedFiles $legacyRuntime -title 'Spicetify PC Setup Helper' -description 'PC setup, Spicetify tools, and Suliman App Hub launcher' -product 'Spicetify PC Setup Helper' -company 'SulimanZ-Dev' -version "$Version.0" -x64

Copy-Item -LiteralPath $legacyExe -Destination (Join-Path $root 'SpicetifySetupHelper.exe') -Force
Copy-Item -LiteralPath $module -Destination (Join-Path $resolvedDist 'SulimanAppHub.Core.psm1') -Force
Copy-Item -LiteralPath $catalog -Destination (Join-Path $resolvedDist 'catalog.json') -Force
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $resolvedDist -Force

if ($CertificateThumbprint) {
    $certificate = Get-Item -LiteralPath "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction Stop
    foreach ($file in Get-ChildItem -LiteralPath $resolvedDist -Filter '*.exe') {
        $signature = Set-AuthenticodeSignature -LiteralPath $file.FullName -Certificate $certificate -HashAlgorithm SHA256
        if ($signature.Status -ne 'Valid') { throw "Signing failed for $($file.Name): $($signature.StatusMessage)" }
    }
    Copy-Item -LiteralPath $legacyExe -Destination (Join-Path $root 'SpicetifySetupHelper.exe') -Force
}

$checksums = foreach ($file in Get-ChildItem -LiteralPath $resolvedDist -Filter '*.exe') {
    $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
    '{0} *{1}' -f $hash.Hash.ToLowerInvariant(), $file.Name
}
$checksumPath = Join-Path $resolvedDist 'SHA256SUMS.txt'
$checksums | Set-Content -LiteralPath $checksumPath -Encoding ASCII

$zipPath = Join-Path $resolvedDist "SulimanAppHub-$Version-Windows-x64.zip"
$zipItems = Get-ChildItem -LiteralPath $resolvedDist | Where-Object { $_.FullName -ne $zipPath }
Compress-Archive -Path $zipItems.FullName -DestinationPath $zipPath -Force

Write-Host "Build completed: $resolvedDist" -ForegroundColor Green
Get-ChildItem -LiteralPath $resolvedDist | Select-Object Name, Length
