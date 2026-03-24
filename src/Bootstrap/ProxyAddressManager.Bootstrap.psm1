Set-StrictMode -Version Latest

$loggingModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.Logging.psm1'
$configurationModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Configuration\ProxyAddressManager.Configuration.psm1'
Import-Module -Name $loggingModulePath -Force
Import-Module -Name $configurationModulePath -Force

function Get-PamBootstrapCallbacks {
    [CmdletBinding()]
    param(
        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = [ordered]@{
        GetInstalledModules = {
            param([string[]]$ModuleNames)
            @(Get-Module -ListAvailable -Name $ModuleNames | Sort-Object Version -Descending)
        }
        GetCommand = {
            param([string]$CommandName)
            Get-Command -Name $CommandName -ErrorAction SilentlyContinue
        }
        FindPackage = {
            param([string]$PackageName, [string]$Repository)
            Find-PSResource -Name $PackageName -Repository $Repository -ErrorAction Stop
        }
        InstallPackage = {
            param([string]$PackageName, [string]$Repository, [string]$Scope)
            Install-PSResource -Name $PackageName -Repository $Repository -Scope $Scope -ErrorAction Stop
        }
        ImportModule = {
            param([string]$ModulePath)
            Import-Module -Name $ModulePath -ErrorAction Stop
        }
        PromptForApproval = {
            param([string]$PromptMessage)
            Confirm-PamAction -PromptMessage $PromptMessage
        }
    }

    if ($null -ne $Callbacks) {
        foreach ($property in $Callbacks.PSObject.Properties) {
            $resolvedCallbacks[$property.Name] = $property.Value
        }
    }

    return [pscustomobject]$resolvedCallbacks
}

function Assert-PamRuntimePrerequisites {
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Stop-PamExecution -Message 'ProxyAddressManager unterstuetzt derzeit nur Windows, da die Anwendung PowerShell 7 mit WPF voraussetzt.'
    }

    if ($PSVersionTable.PSEdition -ne 'Core') {
        Stop-PamExecution -Message "ProxyAddressManager benoetigt PowerShell 7 (PSEdition 'Core'). Aktuell erkannt: '$($PSVersionTable.PSEdition)'."
    }

    if ($PSVersionTable.PSVersion -lt [version]'7.0.0') {
        Stop-PamExecution -Message "ProxyAddressManager benoetigt mindestens PowerShell 7.0. Aktuell erkannt: $($PSVersionTable.PSVersion)."
    }
}

function Get-PamBootstrapConfiguration {
    [CmdletBinding()]
    param(
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $resolvedAppRoot = $AppRoot
    if ([string]::IsNullOrWhiteSpace($resolvedAppRoot)) {
        $resolvedAppRoot = Split-Path -Path (Split-Path -Path $ConfigPath -Parent) -Parent
    }

    return (Get-PamAppConfiguration -AppRoot $resolvedAppRoot -ConfigPath $ConfigPath)
}

function Confirm-PamAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PromptMessage
    )

    while ($true) {
        $answer = Read-Host "$PromptMessage [J/N]"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            Write-Host 'Bitte J oder N eingeben.' -ForegroundColor Yellow
            continue
        }

        switch -Regex ($answer.Trim()) {
            '^(j|ja|y|yes)$' { return $true }
            '^(n|nein|no)$' { return $false }
            default { Write-Host 'Bitte J oder N eingeben.' -ForegroundColor Yellow }
        }
    }
}

function Get-PamInstalledModuleCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$ModuleRequirement,

        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = Get-PamBootstrapCallbacks -Callbacks $Callbacks
    $moduleNames = @($ModuleRequirement.moduleNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($moduleNames.Count -eq 0) {
        Stop-PamExecution -Message "Die Moduldefinition '$($ModuleRequirement.id)' enthaelt keine moduleNames."
    }

    $availableModules = @(& $resolvedCallbacks.GetInstalledModules $moduleNames | Sort-Object Version -Descending)
    if ($availableModules.Count -eq 0) {
        return $null
    }

    return $availableModules[0]
}

function Install-PamModuleRequirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$ModuleRequirement,

        [scriptblock]$ApprovalCallback,

        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = Get-PamBootstrapCallbacks -Callbacks $Callbacks
    $displayName = if ($ModuleRequirement.displayName) { $ModuleRequirement.displayName } else { $ModuleRequirement.id }

    switch ($ModuleRequirement.installStrategy) {
        'PSResource' {
            $packageName = if ($ModuleRequirement.packageName) { $ModuleRequirement.packageName } else { $ModuleRequirement.moduleNames[0] }
            $repository = if ($ModuleRequirement.repository) { $ModuleRequirement.repository } else { 'PSGallery' }
            $scope = if ($ModuleRequirement.scope) { $ModuleRequirement.scope } else { 'CurrentUser' }

            $findPsResourceCommand = & $resolvedCallbacks.GetCommand 'Find-PSResource'
            $installPsResourceCommand = & $resolvedCallbacks.GetCommand 'Install-PSResource'
            if ($null -eq $findPsResourceCommand -or $null -eq $installPsResourceCommand) {
                Stop-PamExecution -Message "Fuer die Installation von '$displayName' werden 'Find-PSResource' und 'Install-PSResource' aus 'Microsoft.PowerShell.PSResourceGet' benoetigt."
            }

            if ($ApprovalCallback) {
                $approval = & $ApprovalCallback $ModuleRequirement $packageName $repository $scope
            }
            else {
                $approval = & $resolvedCallbacks.PromptForApproval "Das erforderliche Modul '$displayName' fehlt. Soll '$packageName' aus '$repository' fuer '$scope' installiert werden?"
            }

            if (-not $approval) {
                Stop-PamExecution -Message "Die Installation des erforderlichen Moduls '$displayName' wurde abgelehnt." -ConsoleMessage "Installation abgelehnt: $displayName"
            }

            $resource = & $resolvedCallbacks.FindPackage $packageName $repository
            if ($null -eq $resource) {
                Stop-PamExecution -Message "Das Modulpaket '$packageName' wurde im Repository '$repository' nicht gefunden."
            }

            Write-PamLog -Level 'Information' -Message "Installiere Modul '$displayName' aus '$repository' im Scope '$scope'." -ConsoleMessage "Installiere Modul: $displayName"
            & $resolvedCallbacks.InstallPackage $packageName $repository $scope
            return
        }
        'Manual' {
            $instructions = if ($ModuleRequirement.instructions) { $ModuleRequirement.instructions } else { 'Bitte stelle das Modul manuell bereit.' }
            Stop-PamExecution -Message "Das erforderliche Modul '$displayName' ist nicht installiert. $instructions" -ConsoleMessage "Modul fehlt: $displayName"
        }
        default {
            Stop-PamExecution -Message "Die Installationsstrategie '$($ModuleRequirement.installStrategy)' fuer '$displayName' wird nicht unterstuetzt."
        }
    }
}

function Import-PamModuleRequirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$ModuleRequirement,

        [Parameter(Mandatory)]
        [psobject]$ModuleCandidate,

        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = Get-PamBootstrapCallbacks -Callbacks $Callbacks
    $modulePath = if ($ModuleCandidate.Path) { $ModuleCandidate.Path } else { $ModuleCandidate.Name }
    & $resolvedCallbacks.ImportModule $modulePath

    foreach ($commandName in @($ModuleRequirement.requiredCommands)) {
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }

        $command = & $resolvedCallbacks.GetCommand $commandName
        if ($null -eq $command) {
            Stop-PamExecution -Message "Das Modul '$($ModuleRequirement.displayName)' wurde importiert, aber der erforderliche Befehl '$commandName' ist nicht verfuegbar."
        }
    }

    return $ModuleCandidate
}

function Assert-PamModuleRequirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$ModuleRequirement,

        [scriptblock]$ApprovalCallback,

        [pscustomobject]$Callbacks
    )

    $displayName = if ($ModuleRequirement.displayName) { $ModuleRequirement.displayName } else { $ModuleRequirement.id }
    Write-PamLog -Level 'Information' -Message "Pruefe erforderliches Modul: $displayName" -ConsoleMessage "Modulpruefung: $displayName"

    $moduleCandidate = Get-PamInstalledModuleCandidate -ModuleRequirement $ModuleRequirement -Callbacks $Callbacks
    if ($null -eq $moduleCandidate) {
        Install-PamModuleRequirement -ModuleRequirement $ModuleRequirement -ApprovalCallback $ApprovalCallback -Callbacks $Callbacks
        $moduleCandidate = Get-PamInstalledModuleCandidate -ModuleRequirement $ModuleRequirement -Callbacks $Callbacks
    }

    if ($null -eq $moduleCandidate) {
        Stop-PamExecution -Message "Das erforderliche Modul '$displayName' konnte nicht gefunden oder installiert werden."
    }

    $importedModule = Import-PamModuleRequirement -ModuleRequirement $ModuleRequirement -ModuleCandidate $moduleCandidate -Callbacks $Callbacks
    if ($ModuleRequirement.id -eq 'logging') {
        Reset-PamExternalWriteLogCache
        Write-PamLog -Level 'Information' -Message "Das Logging-Modul '$displayName' wurde erfolgreich importiert." -ConsoleMessage 'Logging aktiv'
    }
    else {
        Write-PamLog -Level 'Information' -Message "Das Modul '$displayName' wurde erfolgreich importiert." -ConsoleMessage "Modul geladen: $displayName"
    }

    return $importedModule
}

function Start-ProxyAddressManagerBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [scriptblock]$ApprovalCallback,

        [pscustomobject]$Callbacks
    )

    if (-not (Test-Path -Path $AppRoot -PathType Container)) {
        Stop-PamExecution -Message "Der AppRoot ist ungueltig: $AppRoot"
    }

    Initialize-PamLogging -AppRoot $AppRoot
    Write-PamLog -Level 'Information' -Message "Bootstrap wird gestartet fuer AppRoot '$AppRoot'." -ConsoleMessage 'Bootstrap-Start'
    Assert-PamRuntimePrerequisites

    $config = Get-PamBootstrapConfiguration -AppRoot $AppRoot -ConfigPath $ConfigPath
    $moduleRequirements = @($config.bootstrap.moduleRequirements | Where-Object { $_.requiredAtStartup -eq $true })
    $orderedRequirements = @($moduleRequirements | Sort-Object order, id)

    foreach ($moduleRequirement in $orderedRequirements) {
        Assert-PamModuleRequirement -ModuleRequirement $moduleRequirement -ApprovalCallback $ApprovalCallback -Callbacks $Callbacks | Out-Null
    }

    Write-PamLog -Level 'Information' -Message 'Bootstrap wurde erfolgreich abgeschlossen.' -ConsoleMessage 'Bootstrap abgeschlossen'

    return [pscustomobject]@{
        AppRoot = $AppRoot
        ConfigPath = $ConfigPath
        CheckedModules = @($orderedRequirements.id)
    }
}

Export-ModuleMember -Function @(
    'Assert-PamModuleRequirement',
    'Assert-PamRuntimePrerequisites',
    'Confirm-PamAction',
    'Get-PamBootstrapCallbacks',
    'Get-PamBootstrapConfiguration',
    'Get-PamInstalledModuleCandidate',
    'Import-PamModuleRequirement',
    'Install-PamModuleRequirement',
    'Start-ProxyAddressManagerBootstrap'
)
