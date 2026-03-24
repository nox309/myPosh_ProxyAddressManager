[CmdletBinding()]
param(
    [switch]$SkipModulePreflight,
    [switch]$NoGui,
    [switch]$SmokeTestGui
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$loggingModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\Bootstrap\ProxyAddressManager.Logging.psm1'
$bootstrapModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\Bootstrap\ProxyAddressManager.Bootstrap.psm1'
$guiModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\Gui\ProxyAddressManager.Gui.psm1'
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'config\appsettings.json'

$loggingModule = Import-Module -Name $loggingModulePath -Force -PassThru
$invokeLoggingCommand = {
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,

        [hashtable]$Splat
    )

    & $loggingModule {
        param($InnerFunctionName, $InnerSplat)
        & $InnerFunctionName @InnerSplat
    } $FunctionName $Splat
}

& $invokeLoggingCommand 'Initialize-PamLogging' @{ AppRoot = $PSScriptRoot }
Import-Module -Name $bootstrapModulePath -Force
Import-Module -Name $guiModulePath -Force

& $invokeLoggingCommand 'Write-PamLog' @{
    Level = 'Information'
    Message = 'ProxyAddressManager wurde gestartet.'
    ConsoleMessage = 'App-Start'
}

if (-not $SkipModulePreflight) {
    Start-ProxyAddressManagerBootstrap -AppRoot $PSScriptRoot -ConfigPath $configPath | Out-Null
}
else {
    & $invokeLoggingCommand 'Write-PamLog' @{
        Level = 'Warning'
        Message = 'Der Modul-Preflight wurde per Parameter uebersprungen.'
        ConsoleMessage = 'Modul-Preflight uebersprungen'
    }
}

if ($SmokeTestGui) {
    & $invokeLoggingCommand 'Write-PamLog' @{
        Level = 'Information'
        Message = 'GUI-Smoke-Test wird ausgefuehrt.'
        ConsoleMessage = 'GUI-Smoke-Test'
    }
    Test-PamGuiShell -AppRoot $PSScriptRoot -ConfigPath $configPath | Out-Null
    & $invokeLoggingCommand 'Write-PamLog' @{
        Level = 'Information'
        Message = 'GUI-Smoke-Test erfolgreich abgeschlossen.'
        ConsoleMessage = 'GUI-Smoke-Test erfolgreich'
    }
    Write-Host 'GUI-Smoke-Test erfolgreich abgeschlossen.' -ForegroundColor Green
    return
}

if ($NoGui) {
    & $invokeLoggingCommand 'Write-PamLog' @{
        Level = 'Information'
        Message = 'Die App wurde ohne GUI beendet.'
        ConsoleMessage = 'App ohne GUI beendet'
    }
    return
}

& $invokeLoggingCommand 'Write-PamLog' @{
    Level = 'Information'
    Message = 'Die WPF-GUI wird gestartet.'
    ConsoleMessage = 'GUI-Start'
}
Show-PamMainWindow -AppRoot $PSScriptRoot -ConfigPath $configPath | Out-Null
