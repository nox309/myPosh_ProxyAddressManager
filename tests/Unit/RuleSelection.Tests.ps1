$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.RuleSelection.psm1'

Import-Module -Name $modulePath -Force

Describe 'Get-PamSortedRules' {
    It 'sorts rules by ascending priority' {
        $rules = @(
            [pscustomobject]@{ name = 'Rule B'; priority = 200; enabled = $true; scope = @{} },
            [pscustomobject]@{ name = 'Rule A'; priority = 100; enabled = $true; scope = @{} }
        )

        $result = Get-PamSortedRules -Rules $rules

        $result[0].name | Should Be 'Rule A'
        $result[1].name | Should Be 'Rule B'
    }
}

Describe 'Select-PamApplicableRule' {
    BeforeEach {
        $script:user = [pscustomobject]@{
            DistinguishedName = 'CN=Max Mustermann,OU=Users,DC=contoso,DC=com'
            SamAccountName = 'mmustermann'
            Department = 'Sales'
            MemberOf = @(
                'CN=MailPolicy-Standard,OU=Groups,DC=contoso,DC=com'
            )
        }
    }

    It 'selects the first enabled matching rule by ascending priority' {
        $rules = @(
            [pscustomobject]@{
                name = 'Fallback Rule'
                enabled = $true
                priority = 200
                scope = [pscustomobject]@{
                    organizationalUnits = @('OU=Users,DC=contoso,DC=com')
                    groups = @()
                    attributeFilters = @()
                }
            },
            [pscustomobject]@{
                name = 'Sales Rule'
                enabled = $true
                priority = 100
                scope = [pscustomobject]@{
                    organizationalUnits = @('OU=Users,DC=contoso,DC=com')
                    groups = @('CN=MailPolicy-Standard,OU=Groups,DC=contoso,DC=com')
                    attributeFilters = @(
                        [pscustomobject]@{
                            attribute = 'Department'
                            operator = 'eq'
                            value = 'Sales'
                        }
                    )
                }
            }
        )

        $result = Select-PamApplicableRule -UserObject $script:user -Rules $rules

        $result.SelectedRuleName | Should Be 'Sales Rule'
        $result.SelectedPriority | Should Be 100
        $result.SelectionReason | Should Be 'FirstMatchingEnabledRuleByPriority'
        @($result.RuleEvaluations).Count | Should Be 2
    }

    It 'skips disabled rules even when they would match' {
        $rules = @(
            [pscustomobject]@{
                name = 'Disabled Exact Rule'
                enabled = $false
                priority = 100
                scope = [pscustomobject]@{
                    organizationalUnits = @('OU=Users,DC=contoso,DC=com')
                    groups = @('CN=MailPolicy-Standard,OU=Groups,DC=contoso,DC=com')
                    attributeFilters = @()
                }
            },
            [pscustomobject]@{
                name = 'Enabled Fallback'
                enabled = $true
                priority = 200
                scope = [pscustomobject]@{
                    organizationalUnits = @('OU=Users,DC=contoso,DC=com')
                    groups = @()
                    attributeFilters = @()
                }
            }
        )

        $result = Select-PamApplicableRule -UserObject $script:user -Rules $rules

        $result.SelectedRuleName | Should Be 'Enabled Fallback'
        $result.RuleEvaluations[0].Enabled | Should Be $false
        $result.RuleEvaluations[0].IsMatch | Should Be $false
    }

    It 'returns no selected rule when nothing matches' {
        $rules = @(
            [pscustomobject]@{
                name = 'HR Rule'
                enabled = $true
                priority = 100
                scope = [pscustomobject]@{
                    organizationalUnits = @('OU=HR,DC=contoso,DC=com')
                    groups = @()
                    attributeFilters = @(
                        [pscustomobject]@{
                            attribute = 'Department'
                            operator = 'eq'
                            value = 'HR'
                        }
                    )
                }
            }
        )

        $result = Select-PamApplicableRule -UserObject $script:user -Rules $rules

        $result.SelectedRule | Should Be $null
        $result.SelectedRuleName | Should Be $null
        $result.SelectionReason | Should Be 'NoMatchingEnabledRule'
    }

    It 'captures the scope evaluation for the chosen rule' {
        $rules = @(
            [pscustomobject]@{
                name = 'Sales Rule'
                enabled = $true
                priority = 100
                scope = [pscustomobject]@{
                    organizationalUnits = @('OU=Users,DC=contoso,DC=com')
                    groups = @('CN=MailPolicy-Standard,OU=Groups,DC=contoso,DC=com')
                    attributeFilters = @(
                        [pscustomobject]@{
                            attribute = 'Department'
                            operator = 'eq'
                            value = 'Sales'
                        }
                    )
                }
            }
        )

        $result = Select-PamApplicableRule -UserObject $script:user -Rules $rules

        $result.Evaluation.ScopeResult.GroupMatch | Should Be $true
        $result.Evaluation.ScopeResult.AttributeFilterMatch | Should Be $true
    }
}
