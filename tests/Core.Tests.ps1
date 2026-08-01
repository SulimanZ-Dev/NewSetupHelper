Describe 'Suliman App Hub Core' {
    BeforeAll {
        $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'modules\SulimanAppHub.Core.psm1'
        $env:SULIMAN_APP_HUB_DATA = Join-Path $TestDrive 'data'
        Import-Module $modulePath -Force
    }

    Context 'Catalog' {
        It 'loads built-in apps, repositories, and profiles' {
            $catalog = Get-SahCatalog
            if (@($catalog.apps).Count -le 15) { throw 'Expected more than 15 built-in apps.' }
            if (@($catalog.repositories).Count -ne 5) { throw 'Expected 5 built-in repositories.' }
            if (@($catalog.profiles).Count -ne 5) { throw 'Expected 5 built-in profiles.' }
        }

        It 'contains the three Suliman release apps' {
            $ids = @((Get-SahCatalog).apps | ForEach-Object { $_.id })
            if ($ids -notcontains 'budget') { throw 'Budget is missing from the catalog.' }
            if ($ids -notcontains 'livssystem') { throw 'Livssystem is missing from the catalog.' }
            if ($ids -notcontains 'vault') { throw 'Vault is missing from the catalog.' }
        }

        It 'returns the expected development profile' {
            $ids = @(Get-SahProfileApps -ProfileId 'development' | ForEach-Object { $_.id })
            if ($ids -notcontains 'git') { throw 'Git is missing from the development profile.' }
            if ($ids -notcontains 'vscode') { throw 'VS Code is missing from the development profile.' }
            if ($ids -notcontains 'nodejs') { throw 'Node.js is missing from the development profile.' }
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
            if ($asset.name -ne 'App_9.9.9_x64-setup.exe') { throw "Unexpected release asset: $($asset.name)" }
        }

        It 'accepts only trusted HTTPS GitHub release URLs' {
            if (-not (Test-SahTrustedGitHubUrl -Url 'https://github.com/owner/repo/releases/download/v1/app.exe' -Repository 'owner/repo')) { throw 'A valid GitHub release URL was rejected.' }
            if (Test-SahTrustedGitHubUrl -Url 'http://github.com/owner/repo/releases/download/v1/app.exe' -Repository 'owner/repo') { throw 'An insecure GitHub URL was accepted.' }
            if (Test-SahTrustedGitHubUrl -Url 'https://example.com/app.exe' -Repository 'owner/repo') { throw 'A non-GitHub URL was accepted.' }
        }

        It 'handles releases without checksum assets' {
            $release = [pscustomobject]@{ assets = @([pscustomobject]@{ name = 'app.exe' }) }
            if ($null -ne (Get-SahChecksumAsset -Release $release)) { throw 'Unexpected checksum asset returned.' }
        }
    }

    Context 'Configuration and history' {
        It 'creates a valid default configuration' {
            $config = Get-SahConfig
            if ($config.language -ne 'sv') { throw "Unexpected default language: $($config.language)" }
            if (-not $config.verifyChecksums) { throw 'Checksum verification should be enabled by default.' }
        }

        It 'records an operation with a troubleshooting id' {
            $record = Add-SahHistory -Action 'Test' -Target 'Core' -Success $true
            if ($record.operationId.Length -ne 10) { throw 'The troubleshooting id should contain 10 characters.' }
            if (@(Get-SahHistory).Count -le 0) { throw 'The history record was not persisted.' }
        }
    }

    AfterAll {
        Remove-Module SulimanAppHub.Core -ErrorAction SilentlyContinue
        Remove-Item Env:\SULIMAN_APP_HUB_DATA -ErrorAction SilentlyContinue
    }
}
