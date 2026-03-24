Set-StrictMode -Version Latest

$loggingModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Bootstrap\ProxyAddressManager.Logging.psm1'
Import-Module -Name $loggingModulePath -Force

function Resolve-PamAppPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        Stop-PamExecution -Message 'Es wurde ein leerer Pfadwert uebergeben.'
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $AppRoot -ChildPath $PathValue))
}

function Assert-PamAppConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($Configuration.schemaVersion)) {
        Stop-PamExecution -Message "Die App-Konfiguration enthaelt kein schemaVersion-Feld: $ConfigPath"
    }

    if ($null -eq $Configuration.application -or [string]::IsNullOrWhiteSpace($Configuration.application.name)) {
        Stop-PamExecution -Message "Die App-Konfiguration enthaelt keinen gueltigen application.name-Wert: $ConfigPath"
    }

    if ($null -eq $Configuration.bootstrap -or $null -eq $Configuration.bootstrap.moduleRequirements) {
        Stop-PamExecution -Message "Die App-Konfiguration enthaelt keine gueltigen bootstrap.moduleRequirements: $ConfigPath"
    }

    if ($null -eq $Configuration.gui) {
        Stop-PamExecution -Message "Die App-Konfiguration enthaelt keinen gui-Abschnitt: $ConfigPath"
    }
}

function Get-PamAppConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    Initialize-PamLogging -AppRoot $AppRoot
    Write-PamLog -Level 'Debug' -Message "App-Konfiguration wird geladen: $ConfigPath"

    if (-not (Test-Path -Path $AppRoot -PathType Container)) {
        Stop-PamExecution -Message "Der AppRoot ist ungueltig: $AppRoot"
    }

    if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
        Stop-PamExecution -Message "Die App-Konfiguration wurde nicht gefunden: $ConfigPath"
    }

    $configuration = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -Depth 20
    Set-PamLoggingConfiguration -AppRoot $AppRoot -LoggingConfiguration $configuration.logging
    Assert-PamAppConfiguration -Configuration $configuration -ConfigPath $ConfigPath

    $resolvedPaths = [ordered]@{}
    if ($null -ne $configuration.paths) {
        foreach ($property in $configuration.paths.PSObject.Properties) {
            if ([string]::IsNullOrWhiteSpace([string]$property.Value)) {
                continue
            }

            $resolvedPaths[$property.Name] = Resolve-PamAppPath -AppRoot $AppRoot -PathValue ([string]$property.Value)
        }
    }

    $configuration | Add-Member -MemberType NoteProperty -Name appRoot -Value ([System.IO.Path]::GetFullPath($AppRoot)) -Force
    $configuration | Add-Member -MemberType NoteProperty -Name configPath -Value ([System.IO.Path]::GetFullPath($ConfigPath)) -Force
    $configuration | Add-Member -MemberType NoteProperty -Name resolvedPaths -Value ([pscustomobject]$resolvedPaths) -Force

    Write-PamLog -Level 'Debug' -Message "App-Konfiguration erfolgreich geladen: $ConfigPath"

    return $configuration
}

Export-ModuleMember -Function @(
    'Assert-PamAppConfiguration',
    'Get-PamAppConfiguration',
    'Resolve-PamAppPath'
)
