[CmdletBinding()]
param(
    [switch]$SkipModulePreflight,
    [switch]$NoGui,
    [switch]$SmokeTestGui
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$bootstrapModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\Bootstrap\ProxyAddressManager.Bootstrap.psm1'
$guiModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'src\Gui\ProxyAddressManager.Gui.psm1'
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'config\appsettings.json'

Import-Module -Name $bootstrapModulePath -Force
Import-Module -Name $guiModulePath -Force

if (-not $SkipModulePreflight) {
    Start-ProxyAddressManagerBootstrap -AppRoot $PSScriptRoot -ConfigPath $configPath | Out-Null
}

if ($SmokeTestGui) {
    Test-PamGuiShell -AppRoot $PSScriptRoot -ConfigPath $configPath | Out-Null
    Write-Host 'GUI-Smoke-Test erfolgreich abgeschlossen.' -ForegroundColor Green
    return
}

if ($NoGui) {
    return
}

Show-PamMainWindow -AppRoot $PSScriptRoot -ConfigPath $configPath | Out-Null
