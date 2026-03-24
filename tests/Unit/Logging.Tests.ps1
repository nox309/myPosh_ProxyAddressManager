$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Bootstrap\ProxyAddressManager.Logging.psm1'

Import-Module -Name $modulePath -Force

Describe 'Write-PamLog' {
    BeforeEach {
        $script:testRoot = Join-Path -Path $env:TEMP -ChildPath "pam-logging-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testRoot | Out-Null

        Initialize-PamLogging -AppRoot $script:testRoot
        Set-PamLoggingConfiguration -AppRoot $script:testRoot -LoggingConfiguration ([pscustomobject]@{
                path = 'logs\test.log'
                fileMinimumLevel = 'Information'
                consoleMinimumLevel = 'Error'
                mirrorToWriteLog = $false
            })
    }

    AfterEach {
        if (Test-Path -Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force
        }
    }

    It 'writes messages at or above the file log level' {
        Write-PamLog -Level 'Information' -Message 'Info message'
        Write-PamLog -Level 'Debug' -Message 'Debug message'

        $logPath = Join-Path -Path $script:testRoot -ChildPath 'logs\test.log'
        $content = Get-Content -Path $logPath -Raw

        $content | Should Match 'Info message'
        $content | Should Not Match 'Debug message'
    }
}

Describe 'Stop-PamExecution' {
    BeforeEach {
        $script:testRoot = Join-Path -Path $env:TEMP -ChildPath "pam-stop-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:testRoot | Out-Null

        Initialize-PamLogging -AppRoot $script:testRoot
        Set-PamLoggingConfiguration -AppRoot $script:testRoot -LoggingConfiguration ([pscustomobject]@{
                path = 'logs\test.log'
                fileMinimumLevel = 'Debug'
                consoleMinimumLevel = 'Error'
                mirrorToWriteLog = $false
            })
    }

    AfterEach {
        if (Test-Path -Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force
        }
    }

    It 'writes an error log before throwing' {
        $didThrow = $false

        try {
            Stop-PamExecution -Message 'Stop message'
        }
        catch {
            $didThrow = $true
        }

        $didThrow | Should Be $true

        $logPath = Join-Path -Path $script:testRoot -ChildPath 'logs\test.log'
        $content = Get-Content -Path $logPath -Raw

        $content | Should Match 'Stop message'
        $content | Should Match '\[Error\]'
    }
}
