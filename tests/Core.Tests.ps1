Describe 'Suliman App Hub Core' {
    $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'modules\SulimanAppHub.Core.psm1'
    $env:SULIMAN_APP_HUB_DATA = Join-Path $TestDrive 'data'
    Import-Module $modulePath -Force

    Context 'Catalog' {
        It 'loads built-in apps, repositories, and profiles' {
            $catalog = Get-SahCatalog
            @($catalog.apps).Count | Should BeGreaterThan 15
            @($catalog.repositories).Count | Should Be 5
            @($catalog.profiles).Count | Should Be 5
        }

        It 'contains the three Suliman release apps' {
            $ids = @((Get-SahCatalog).apps | ForEach-Object { $_.id })
            ($ids -contains 'budget') | Should Be $true
            ($ids -contains 'livssystem') | Should Be $true
            ($ids -contains 'vault') | Should Be $true
        }

        It 'returns the expected development profile' {
            $ids = @(Get-SahProfileApps -ProfileId 'development' | ForEach-Object { $_.id })
            ($ids -contains 'git') | Should Be $true
            ($ids -contains 'vscode') | Should Be $true
            ($ids -contains 'nodejs') | Should Be $true
        }
    }

    Context 'GitHub release safety' {
        It 'prefers a setup asset and ignores checksum files' {
            $release = [pscustomobject]@{
                tag_name = 'v9.9.9'
                assets = @(
                    [pscustomobject]@{ name = 'SHA256SUMS.txt'; browser_download_url = 'https://github.com/owner/repo/releases/download/v9.9.9/SHA256SUMS.txt' },
                    [pscustomobject]@{ name = 'app-portable.exe'; browser_download_url = 'https://github.com/owner/repo/releases/download/v9.9.9/app-portable.exe' },
                    [pscustomobject]@{ name = 'App_9.9.9_x64-setup.exe'; browser_download_url = 'https://github.com/owner/repo/releases/download/v9.9.9/App_9.9.9_x64-setup.exe' },
                    [pscustomobject]@{ name = 'App_9.9.9_x64.msi'; browser_download_url = 'https://github.com/owner/repo/releases/download/v9.9.9/App_9.9.9_x64.msi' }
                )
            }
            $asset = Select-SahReleaseAsset -Release $release
            $asset.name | Should Be 'App_9.9.9_x64-setup.exe'
        }

        It 'accepts only trusted HTTPS GitHub release URLs' {
            Test-SahTrustedGitHubUrl -Url 'https://github.com/owner/repo/releases/download/v1/app.exe' -Repository 'owner/repo' | Should Be $true
            Test-SahTrustedGitHubUrl -Url 'http://github.com/owner/repo/releases/download/v1/app.exe' -Repository 'owner/repo' | Should Be $false
            Test-SahTrustedGitHubUrl -Url 'https://example.com/app.exe' -Repository 'owner/repo' | Should Be $false
        }

        It 'handles releases without checksum assets' {
            $release = [pscustomobject]@{ assets = @([pscustomobject]@{ name = 'app.exe' }) }
            Get-SahChecksumAsset -Release $release | Should BeNullOrEmpty
        }
    }

    Context 'Configuration and history' {
        It 'creates a valid default configuration' {
            $config = Get-SahConfig
            $config.language | Should Be 'sv'
            $config.verifyChecksums | Should Be $true
        }

        It 'records an operation with a troubleshooting id' {
            $record = Add-SahHistory -Action 'Test' -Target 'Core' -Success $true
            $record.operationId.Length | Should Be 10
            @(Get-SahHistory).Count | Should BeGreaterThan 0
        }
    }

    AfterAll {
        Remove-Module SulimanAppHub.Core -ErrorAction SilentlyContinue
        Remove-Item Env:\SULIMAN_APP_HUB_DATA -ErrorAction SilentlyContinue
    }
}
