$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Bootstrap\ProxyAddressManager.Logging.psm1'

Import-Module -Name $modulePath -Force

Describe 'Write-PamLog' {
    BeforeEach {
        if (Test-Path Function:\Write-Log) {
            Remove-Item Function:\Write-Log -Force
        }

        $script:capturedLogs = @()
        function global:Write-Log {
            param(
                [string]$Message,
                [string]$StatusLevel,
                [bool]$Console
            )

            $script:capturedLogs += [pscustomobject]@{
                Message = $Message
                StatusLevel = $StatusLevel
                Console = $Console
            }
        }

        Reset-PamExternalWriteLogCache
        Initialize-PamLogging -AppRoot $env:TEMP
        Set-PamLoggingConfiguration -AppRoot $env:TEMP -LoggingConfiguration ([pscustomobject]@{
                fileMinimumLevel = 'Information'
                consoleMinimumLevel = 'Error'
            })
    }

    AfterEach {
        if (Test-Path Function:\Write-Log) {
            Remove-Item Function:\Write-Log -Force
        }

        Reset-PamExternalWriteLogCache
    }

    It 'routes only eligible messages to Write-Log and limits console output' {
        Write-PamLog -Level 'Information' -Message 'Info message'
        Write-PamLog -Level 'Debug' -Message 'Debug message'
        Write-PamLog -Level 'Error' -Message 'Error message'

        @($script:capturedLogs).Count | Should Be 2
        $script:capturedLogs[0].Message | Should Be 'Info message'
        $script:capturedLogs[0].Console | Should Be $false
        $script:capturedLogs[1].Message | Should Be 'Error message'
        $script:capturedLogs[1].Console | Should Be $true
    }
}

Describe 'Stop-PamExecution' {
    BeforeEach {
        if (Test-Path Function:\Write-Log) {
            Remove-Item Function:\Write-Log -Force
        }

        $script:capturedLogs = @()
        function global:Write-Log {
            param(
                [string]$Message,
                [string]$StatusLevel,
                [bool]$Console
            )

            $script:capturedLogs += [pscustomobject]@{
                Message = $Message
                StatusLevel = $StatusLevel
                Console = $Console
            }
        }

        Reset-PamExternalWriteLogCache
        Initialize-PamLogging -AppRoot $env:TEMP
        Set-PamLoggingConfiguration -AppRoot $env:TEMP -LoggingConfiguration ([pscustomobject]@{
                fileMinimumLevel = 'Debug'
                consoleMinimumLevel = 'Error'
            })
    }

    AfterEach {
        if (Test-Path Function:\Write-Log) {
            Remove-Item Function:\Write-Log -Force
        }

        Reset-PamExternalWriteLogCache
    }

    It 'writes via Write-Log before throwing' {
        $didThrow = $false

        try {
            Stop-PamExecution -Message 'Stop message'
        }
        catch {
            $didThrow = $true
        }

        $didThrow | Should Be $true

        @($script:capturedLogs).Count | Should Be 1
        $script:capturedLogs[0].Message | Should Be 'Stop message'
        $script:capturedLogs[0].Console | Should Be $true
    }
}
