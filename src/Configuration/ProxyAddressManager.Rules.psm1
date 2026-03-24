Set-StrictMode -Version Latest

$loggingModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Bootstrap\ProxyAddressManager.Logging.psm1'
Import-Module -Name $loggingModulePath -Force

function Assert-PamRuleDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Rule,

        [Parameter(Mandatory)]
        [int]$Index,

        [Parameter(Mandatory)]
        [string]$RulesPath
    )

    if ([string]::IsNullOrWhiteSpace($Rule.name)) {
        Stop-PamExecution -Message "Regel #$Index in '$RulesPath' enthaelt keinen gueltigen Namen."
    }

    if ($null -eq $Rule.enabled) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein enabled-Feld."
    }

    if ($null -eq $Rule.priority) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein priority-Feld."
    }

    if ($null -eq $Rule.scope) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt keinen scope-Abschnitt."
    }

    if ([string]::IsNullOrWhiteSpace($Rule.primaryAddressTemplate)) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein primaryAddressTemplate."
    }

    if ($null -eq $Rule.aliasTemplates) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein aliasTemplates-Feld."
    }

    if ($null -eq $Rule.domainRules -or [string]::IsNullOrWhiteSpace($Rule.domainRules.primaryDomain)) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt keine gueltigen domainRules.primaryDomain."
    }

    if ($null -eq $Rule.normalizationRules) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt keinen normalizationRules-Abschnitt."
    }

    if ($null -eq $Rule.overrides) {
        Stop-PamExecution -Message "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein overrides-Feld."
    }
}

function Assert-PamRulesConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$RulesConfiguration,

        [Parameter(Mandatory)]
        [string]$RulesPath
    )

    if ([string]::IsNullOrWhiteSpace($RulesConfiguration.schemaVersion)) {
        Stop-PamExecution -Message "Die Regeldatei enthaelt kein schemaVersion-Feld: $RulesPath"
    }

    if ($null -eq $RulesConfiguration.rules) {
        Stop-PamExecution -Message "Die Regeldatei enthaelt kein rules-Feld: $RulesPath"
    }

    $rules = @($RulesConfiguration.rules)
    $seenPriorities = @{}

    for ($index = 0; $index -lt $rules.Count; $index++) {
        $rule = $rules[$index]
        Assert-PamRuleDefinition -Rule $rule -Index ($index + 1) -RulesPath $RulesPath

        $priorityKey = [string]$rule.priority
        if ($seenPriorities.ContainsKey($priorityKey)) {
            Stop-PamExecution -Message "Die Regeldatei '$RulesPath' enthaelt die doppelte Prioritaet '$priorityKey' fuer '$($seenPriorities[$priorityKey])' und '$($rule.name)'."
        }

        $seenPriorities[$priorityKey] = $rule.name
    }
}

function Get-PamRulesConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RulesPath
    )

    Write-PamLog -Level 'Debug' -Message "Regeldatei wird geladen: $RulesPath"
    if (-not (Test-Path -Path $RulesPath -PathType Leaf)) {
        Stop-PamExecution -Message "Die Regeldatei wurde nicht gefunden: $RulesPath"
    }

    $rulesConfiguration = Get-Content -Path $RulesPath -Raw | ConvertFrom-Json -Depth 20
    Assert-PamRulesConfiguration -RulesConfiguration $rulesConfiguration -RulesPath $RulesPath

    $rulesConfiguration | Add-Member -MemberType NoteProperty -Name rulesPath -Value ([System.IO.Path]::GetFullPath($RulesPath)) -Force
    Write-PamLog -Level 'Debug' -Message "Regeldatei erfolgreich geladen: $RulesPath"
    return $rulesConfiguration
}

Export-ModuleMember -Function @(
    'Assert-PamRuleDefinition',
    'Assert-PamRulesConfiguration',
    'Get-PamRulesConfiguration'
)
