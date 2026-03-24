Set-StrictMode -Version Latest

function Get-PamScopePropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    foreach ($property in $UserObject.PSObject.Properties) {
        if ($property.Name -ieq $PropertyName) {
            return $property.Value
        }
    }

    return $null
}

function ConvertTo-PamScopeStringValues {
    [CmdletBinding()]
    param(
        $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @($Value)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value | ForEach-Object { [string]$_ })
    }

    return @([string]$Value)
}

function Test-PamOrganizationalUnitScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [string[]]$OrganizationalUnits
    )

    $configuredOus = @($OrganizationalUnits | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($configuredOus.Count -eq 0) {
        return [pscustomobject]@{
            IsMatch = $true
            MatchedValues = @()
            EvaluatedValues = @()
        }
    }

    $distinguishedName = [string](Get-PamScopePropertyValue -UserObject $UserObject -PropertyName 'DistinguishedName')
    if ([string]::IsNullOrWhiteSpace($distinguishedName)) {
        return [pscustomobject]@{
            IsMatch = $false
            MatchedValues = @()
            EvaluatedValues = $configuredOus
        }
    }

    $matchedOus = @($configuredOus | Where-Object { $distinguishedName.EndsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })

    return [pscustomobject]@{
        IsMatch = $matchedOus.Count -gt 0
        MatchedValues = $matchedOus
        EvaluatedValues = $configuredOus
    }
}

function Get-PamUserDirectGroupMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    $memberOfValues = @(ConvertTo-PamScopeStringValues (Get-PamScopePropertyValue -UserObject $UserObject -PropertyName 'MemberOf'))
    if ($memberOfValues.Count -gt 0) {
        return @($memberOfValues)
    }

    return @(ConvertTo-PamScopeStringValues (Get-PamScopePropertyValue -UserObject $UserObject -PropertyName 'Groups'))
}

function Test-PamGroupScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [string[]]$Groups
    )

    $configuredGroups = @($Groups | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($configuredGroups.Count -eq 0) {
        return [pscustomobject]@{
            IsMatch = $true
            MatchedValues = @()
            EvaluatedValues = @()
        }
    }

    $userGroups = @(Get-PamUserDirectGroupMembership -UserObject $UserObject)
    $matchedGroups = foreach ($configuredGroup in $configuredGroups) {
        foreach ($userGroup in $userGroups) {
            if ([string]$userGroup -ieq $configuredGroup) {
                $configuredGroup
                break
            }
        }
    }

    return [pscustomobject]@{
        IsMatch = @($matchedGroups).Count -gt 0
        MatchedValues = @($matchedGroups)
        EvaluatedValues = $configuredGroups
    }
}

function Test-PamScopeAttributeFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [psobject]$Filter
    )

    if ([string]::IsNullOrWhiteSpace([string]$Filter.attribute)) {
        throw 'Ein Attributfilter enthaelt kein gueltiges attribute-Feld.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$Filter.operator)) {
        throw "Der Attributfilter fuer '$($Filter.attribute)' enthaelt keinen gueltigen operator."
    }

    $operator = ([string]$Filter.operator).ToLowerInvariant()
    $expectedValue = [string]$Filter.value
    $userValues = @(ConvertTo-PamScopeStringValues (Get-PamScopePropertyValue -UserObject $UserObject -PropertyName ([string]$Filter.attribute)))

    $isMatch = switch ($operator) {
        'eq' {
            (@($userValues | Where-Object { $_ -ieq $expectedValue }).Count -gt 0)
            break
        }
        'ne' {
            (@($userValues | Where-Object { $_ -ieq $expectedValue }).Count -eq 0)
            break
        }
        'contains' {
            (@($userValues | Where-Object { $_.IndexOf($expectedValue, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0)
            break
        }
        'startswith' {
            (@($userValues | Where-Object { $_.StartsWith($expectedValue, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0)
            break
        }
        'endswith' {
            (@($userValues | Where-Object { $_.EndsWith($expectedValue, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0)
            break
        }
        default {
            throw "Der Attributfilter-Operator '$($Filter.operator)' wird nicht unterstuetzt."
        }
    }

    return [pscustomobject]@{
        IsMatch = $isMatch
        Attribute = [string]$Filter.attribute
        Operator = [string]$Filter.operator
        ExpectedValue = $expectedValue
        ActualValues = @($userValues)
    }
}

function Test-PamRecipientScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [psobject]$Scope
    )

    $organizationalUnitResult = Test-PamOrganizationalUnitScope -UserObject $UserObject -OrganizationalUnits @($Scope.organizationalUnits)
    $groupResult = Test-PamGroupScope -UserObject $UserObject -Groups @($Scope.groups)

    $attributeFilterResults = @()
    foreach ($filter in @($Scope.attributeFilters)) {
        $attributeFilterResults += Test-PamScopeAttributeFilter -UserObject $UserObject -Filter $filter
    }

    $attributeFilterMatch = $true
    if ($attributeFilterResults.Count -gt 0) {
        $attributeFilterMatch = (@($attributeFilterResults | Where-Object { -not $_.IsMatch }).Count -eq 0)
    }

    return [pscustomobject]@{
        IsMatch = $organizationalUnitResult.IsMatch -and $groupResult.IsMatch -and $attributeFilterMatch
        OrganizationalUnitMatch = $organizationalUnitResult.IsMatch
        GroupMatch = $groupResult.IsMatch
        AttributeFilterMatch = $attributeFilterMatch
        MatchedOrganizationalUnits = @($organizationalUnitResult.MatchedValues)
        MatchedGroups = @($groupResult.MatchedValues)
        AttributeFilters = $attributeFilterResults
    }
}

Export-ModuleMember -Function @(
    'Test-PamRecipientScope',
    'Test-PamScopeAttributeFilter'
)
