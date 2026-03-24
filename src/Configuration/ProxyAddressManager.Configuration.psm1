Set-StrictMode -Version Latest

function Resolve-PamAppPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw 'Es wurde ein leerer Pfadwert uebergeben.'
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
        throw "Die App-Konfiguration enthaelt kein schemaVersion-Feld: $ConfigPath"
    }

    if ($null -eq $Configuration.application -or [string]::IsNullOrWhiteSpace($Configuration.application.name)) {
        throw "Die App-Konfiguration enthaelt keinen gueltigen application.name-Wert: $ConfigPath"
    }

    if ($null -eq $Configuration.bootstrap -or $null -eq $Configuration.bootstrap.moduleRequirements) {
        throw "Die App-Konfiguration enthaelt keine gueltigen bootstrap.moduleRequirements: $ConfigPath"
    }

    if ($null -eq $Configuration.gui) {
        throw "Die App-Konfiguration enthaelt keinen gui-Abschnitt: $ConfigPath"
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

    if (-not (Test-Path -Path $AppRoot -PathType Container)) {
        throw "Der AppRoot ist ungueltig: $AppRoot"
    }

    if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
        throw "Die App-Konfiguration wurde nicht gefunden: $ConfigPath"
    }

    $configuration = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -Depth 20
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

    return $configuration
}

Export-ModuleMember -Function @(
    'Assert-PamAppConfiguration',
    'Get-PamAppConfiguration',
    'Resolve-PamAppPath'
)
