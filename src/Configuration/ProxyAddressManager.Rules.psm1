Set-StrictMode -Version Latest

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
        throw "Regel #$Index in '$RulesPath' enthaelt keinen gueltigen Namen."
    }

    if ($null -eq $Rule.enabled) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein enabled-Feld."
    }

    if ($null -eq $Rule.priority) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein priority-Feld."
    }

    if ($null -eq $Rule.scope) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt keinen scope-Abschnitt."
    }

    if ([string]::IsNullOrWhiteSpace($Rule.primaryAddressTemplate)) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein primaryAddressTemplate."
    }

    if ($null -eq $Rule.aliasTemplates) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein aliasTemplates-Feld."
    }

    if ($null -eq $Rule.domainRules -or [string]::IsNullOrWhiteSpace($Rule.domainRules.primaryDomain)) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt keine gueltigen domainRules.primaryDomain."
    }

    if ($null -eq $Rule.normalizationRules) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt keinen normalizationRules-Abschnitt."
    }

    if ($null -eq $Rule.overrides) {
        throw "Regel '$($Rule.name)' in '$RulesPath' enthaelt kein overrides-Feld."
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
        throw "Die Regeldatei enthaelt kein schemaVersion-Feld: $RulesPath"
    }

    if ($null -eq $RulesConfiguration.rules) {
        throw "Die Regeldatei enthaelt kein rules-Feld: $RulesPath"
    }

    $rules = @($RulesConfiguration.rules)
    $seenPriorities = @{}

    for ($index = 0; $index -lt $rules.Count; $index++) {
        $rule = $rules[$index]
        Assert-PamRuleDefinition -Rule $rule -Index ($index + 1) -RulesPath $RulesPath

        $priorityKey = [string]$rule.priority
        if ($seenPriorities.ContainsKey($priorityKey)) {
            throw "Die Regeldatei '$RulesPath' enthaelt die doppelte Prioritaet '$priorityKey' fuer '$($seenPriorities[$priorityKey])' und '$($rule.name)'."
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

    if (-not (Test-Path -Path $RulesPath -PathType Leaf)) {
        throw "Die Regeldatei wurde nicht gefunden: $RulesPath"
    }

    $rulesConfiguration = Get-Content -Path $RulesPath -Raw | ConvertFrom-Json -Depth 20
    Assert-PamRulesConfiguration -RulesConfiguration $rulesConfiguration -RulesPath $RulesPath

    $rulesConfiguration | Add-Member -MemberType NoteProperty -Name rulesPath -Value ([System.IO.Path]::GetFullPath($RulesPath)) -Force
    return $rulesConfiguration
}

Export-ModuleMember -Function @(
    'Assert-PamRuleDefinition',
    'Assert-PamRulesConfiguration',
    'Get-PamRulesConfiguration'
)
