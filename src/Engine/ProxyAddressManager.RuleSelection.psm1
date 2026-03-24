Set-StrictMode -Version Latest

$scopeModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.Scope.psm1'
Import-Module -Name $scopeModulePath -Force

function Get-PamSortedRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Rules
    )

    return @($Rules | Sort-Object @{ Expression = { [int]$_.priority } }, @{ Expression = { [string]$_.name } })
}

function Test-PamRuleIsEnabled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Rule
    )

    return ([bool]$Rule.enabled)
}

function Test-PamRuleMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [psobject]$Rule
    )

    $isEnabled = Test-PamRuleIsEnabled -Rule $Rule
    if (-not $isEnabled) {
        return [pscustomobject]@{
            RuleName = [string]$Rule.name
            Priority = [int]$Rule.priority
            Enabled = $false
            IsMatch = $false
            ScopeResult = $null
        }
    }

    $scopeResult = Test-PamRecipientScope -UserObject $UserObject -Scope $Rule.scope

    return [pscustomobject]@{
        RuleName = [string]$Rule.name
        Priority = [int]$Rule.priority
        Enabled = $true
        IsMatch = [bool]$scopeResult.IsMatch
        ScopeResult = $scopeResult
    }
}

function Select-PamApplicableRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [object[]]$Rules
    )

    $sortedRules = @(Get-PamSortedRules -Rules $Rules)
    $evaluations = New-Object System.Collections.Generic.List[object]
    $selectedRule = $null
    $selectedEvaluation = $null

    foreach ($rule in $sortedRules) {
        $evaluation = Test-PamRuleMatch -UserObject $UserObject -Rule $rule
        $evaluations.Add($evaluation)

        if ($null -eq $selectedRule -and $evaluation.IsMatch) {
            $selectedRule = $rule
            $selectedEvaluation = $evaluation
        }
    }

    return [pscustomobject]@{
        SelectedRule = $selectedRule
        SelectedRuleName = if ($null -ne $selectedRule) { [string]$selectedRule.name } else { $null }
        SelectedPriority = if ($null -ne $selectedRule) { [int]$selectedRule.priority } else { $null }
        SelectionReason = if ($null -ne $selectedRule) { 'FirstMatchingEnabledRuleByPriority' } else { 'NoMatchingEnabledRule' }
        Evaluation = $selectedEvaluation
        RuleEvaluations = $evaluations.ToArray()
    }
}

Export-ModuleMember -Function @(
    'Get-PamSortedRules',
    'Select-PamApplicableRule',
    'Test-PamRuleIsEnabled',
    'Test-PamRuleMatch'
)
