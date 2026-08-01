[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failed = $false

Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') } | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failed = $true
        Write-Host "Parser errors in $($_.FullName)" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }
    }
}
if ($failed) { throw 'PowerShell parser validation failed.' }

Get-ChildItem -LiteralPath (Join-Path $root 'data') -Filter '*.json' | ForEach-Object {
    [void](Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json)
}

$pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) { throw 'Pester is required to run tests.' }
Import-Module $pester.Path -Force
$result = Invoke-Pester -Script (Join-Path $root 'tests') -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) Pester test(s) failed." }

Write-Host "Validation passed: $($result.PassedCount) Pester tests." -ForegroundColor Green
