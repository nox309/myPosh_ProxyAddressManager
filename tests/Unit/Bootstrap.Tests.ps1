$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Bootstrap\ProxyAddressManager.Bootstrap.psm1'
$configPath = Join-Path -Path $repoRoot -ChildPath 'config\appsettings.json'

Import-Module -Name $modulePath -Force

Describe 'Get-PamBootstrapConfiguration' {
    It 'loads the bootstrap configuration from appsettings.json' {
        $config = Get-PamBootstrapConfiguration -AppRoot $repoRoot -ConfigPath $configPath

        $config.schemaVersion | Should Be '1.0'
        @($config.bootstrap.moduleRequirements).Count | Should Be 2
    }
}

Describe 'Assert-PamModuleRequirement' {
    BeforeEach {
        $script:loggingRequirement = [pscustomobject]@{
            id = 'logging'
            displayName = 'myPosh Write-Log'
            moduleNames = @('myPosh_write-log', 'myPosh_Write-Log')
            requiredCommands = @('Write-Log')
            installStrategy = 'PSResource'
            packageName = 'myPosh_write-log'
            repository = 'PSGallery'
            scope = 'CurrentUser'
        }

        $script:manualRequirement = [pscustomobject]@{
            id = 'activeDirectory'
            displayName = 'Active Directory PowerShell module'
            moduleNames = @('ActiveDirectory')
            requiredCommands = @('Get-ADUser')
            installStrategy = 'Manual'
            instructions = 'Bitte installiere RSAT.'
        }
    }

    It 'imports an already installed module' {
        $script:importedModulePath = $null
        $callbacks = [pscustomobject]@{
            GetInstalledModules = {
                param($moduleNames)
                @(
                    [pscustomobject]@{
                        Name = 'myPosh_write-log'
                        Path = 'C:\Modules\myPosh_write-log\myPosh_write-log.psd1'
                        Version = [version]'1.2.4'
                    }
                )
            }
            GetCommand = {
                param($commandName)
                if ($commandName -eq 'Write-Log') {
                    return [pscustomobject]@{ Name = 'Write-Log' }
                }

                return $null
            }
            ImportModule = {
                param($modulePath)
                $script:importedModulePath = $modulePath
            }
        }

        $result = Assert-PamModuleRequirement -ModuleRequirement $script:loggingRequirement -Callbacks $callbacks

        $result.Name | Should Be 'myPosh_write-log'
        $script:importedModulePath | Should Be 'C:\Modules\myPosh_write-log\myPosh_write-log.psd1'
    }

    It 'installs a PSResource module after confirmation when it is missing' {
        $script:getModuleCallCount = 0
        $script:installedPackageName = $null
        $script:importedModulePath = $null
        $callbacks = [pscustomobject]@{
            GetInstalledModules = {
                param($moduleNames)
                $script:getModuleCallCount++
                if ($script:getModuleCallCount -eq 1) {
                    return @()
                }

                @(
                    [pscustomobject]@{
                        Name = 'myPosh_write-log'
                        Path = 'C:\Modules\myPosh_write-log\myPosh_write-log.psd1'
                        Version = [version]'1.2.4'
                    }
                )
            }
            GetCommand = {
                param($commandName)
                if ($commandName -in @('Find-PSResource', 'Install-PSResource', 'Write-Log')) {
                    return [pscustomobject]@{ Name = $commandName }
                }

                return $null
            }
            FindPackage = {
                param($packageName, $repository)
                [pscustomobject]@{ Name = $packageName; Repository = $repository }
            }
            InstallPackage = {
                param($packageName, $repository, $scope)
                $script:installedPackageName = "$packageName|$repository|$scope"
            }
            ImportModule = {
                param($modulePath)
                $script:importedModulePath = $modulePath
            }
            PromptForApproval = {
                param($promptMessage)
                $true
            }
        }

        $null = Assert-PamModuleRequirement -ModuleRequirement $script:loggingRequirement -Callbacks $callbacks

        $script:installedPackageName | Should Be 'myPosh_write-log|PSGallery|CurrentUser'
        $script:importedModulePath | Should Be 'C:\Modules\myPosh_write-log\myPosh_write-log.psd1'
    }

    It 'aborts when the user declines the installation' {
        $callbacks = [pscustomobject]@{
            GetInstalledModules = {
                param($moduleNames)
                @()
            }
            GetCommand = {
                param($commandName)
                if ($commandName -in @('Find-PSResource', 'Install-PSResource')) {
                    return [pscustomobject]@{ Name = $commandName }
                }

                return $null
            }
            PromptForApproval = {
                param($promptMessage)
                $false
            }
        }

        $didThrow = $false
        $message = $null

        try {
            $null = Assert-PamModuleRequirement -ModuleRequirement $script:loggingRequirement -Callbacks $callbacks
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'abgelehnt'
    }

    It 'fails with a clear error when PSResourceGet commands are unavailable' {
        $callbacks = [pscustomobject]@{
            GetInstalledModules = {
                param($moduleNames)
                @()
            }
            GetCommand = {
                param($commandName)
                $null
            }
        }

        $didThrow = $false
        $message = $null

        try {
            $null = Assert-PamModuleRequirement -ModuleRequirement $script:loggingRequirement -Callbacks $callbacks
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'PSResourceGet'
    }

    It 'fails fast for manually provisioned modules that are missing' {
        $callbacks = [pscustomobject]@{
            GetInstalledModules = {
                param($moduleNames)
                @()
            }
        }

        $didThrow = $false
        $message = $null

        try {
            $null = Assert-PamModuleRequirement -ModuleRequirement $script:manualRequirement -Callbacks $callbacks
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'RSAT'
    }
}
