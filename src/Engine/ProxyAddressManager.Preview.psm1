Set-StrictMode -Version Latest

$templateResolverModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.TemplateResolver.psm1'
$normalizationModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.Normalization.psm1'
$diffModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.Diff.psm1'
Import-Module -Name $templateResolverModulePath -Force
Import-Module -Name $normalizationModulePath -Force
Import-Module -Name $diffModulePath -Force

function Get-PamPreviewPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$InputObject,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Name -ieq $PropertyName) {
            return $property.Value
        }
    }

    return $null
}

function Get-PamPreviewIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    foreach ($propertyName in @('SamAccountName', 'UserPrincipalName', 'DistinguishedName')) {
        $value = Get-PamPreviewPropertyValue -InputObject $UserObject -PropertyName $propertyName
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }

    return $null
}

function Test-PamResolvedTemplateIsFullAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResolvedTemplate
    )

    return ($ResolvedTemplate.Contains('@'))
}

function Get-PamPreviewUniqueValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Values
    )

    $uniqueValues = New-Object System.Collections.Generic.List[string]

    foreach ($value in $Values) {
        $stringValue = [string]$value
        if ([string]::IsNullOrWhiteSpace($stringValue)) {
            continue
        }

        $exists = $false
        foreach ($existingValue in $uniqueValues) {
            if ($existingValue -ieq $stringValue) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            $uniqueValues.Add($stringValue)
        }
    }

    return $uniqueValues.ToArray()
}

function Resolve-PamPreviewSmtpAddresses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Templates,

        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [psobject]$NormalizationRules,

        [string[]]$Domains
    )

    $resolvedAddresses = New-Object System.Collections.Generic.List[string]

    foreach ($template in @($Templates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $resolvedTemplate = Resolve-PamTemplate -Template $template -UserObject $UserObject
        if ([string]::IsNullOrWhiteSpace($resolvedTemplate)) {
            continue
        }

        if (Test-PamResolvedTemplateIsFullAddress -ResolvedTemplate $resolvedTemplate) {
            $resolvedAddresses.Add($resolvedTemplate)
            continue
        }

        $localPart = ConvertTo-PamNormalizedAddressLocalPart -Value $resolvedTemplate -NormalizationRules $NormalizationRules
        if ([string]::IsNullOrWhiteSpace($localPart)) {
            continue
        }

        foreach ($domain in @($Domains | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $resolvedAddresses.Add("$localPart@$domain")
        }
    }

    return (Get-PamPreviewUniqueValues -Values $resolvedAddresses.ToArray())
}

function Get-PamProxyAddressBuckets {
    [CmdletBinding()]
    param(
        [object[]]$ProxyAddresses
    )

    $smtpAddresses = New-Object System.Collections.Generic.List[string]
    $nonSmtpAddresses = New-Object System.Collections.Generic.List[string]

    foreach ($proxyAddress in @($ProxyAddresses)) {
        $stringValue = [string]$proxyAddress
        if ([string]::IsNullOrWhiteSpace($stringValue)) {
            continue
        }

        if ($stringValue.StartsWith('SMTP:', [System.StringComparison]::OrdinalIgnoreCase)) {
            $smtpAddresses.Add($stringValue)
        }
        else {
            $nonSmtpAddresses.Add($stringValue)
        }
    }

    return [pscustomobject]@{
        Smtp = $smtpAddresses.ToArray()
        NonSmtp = $nonSmtpAddresses.ToArray()
    }
}

function New-PamRecipientPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [psobject]$Rule
    )

    $warnings = New-Object System.Collections.Generic.List[string]
    $primaryDomain = [string](Get-PamPreviewPropertyValue -InputObject $Rule.domainRules -PropertyName 'primaryDomain')
    $aliasDomains = @(
        Get-PamPreviewPropertyValue -InputObject $Rule.domainRules -PropertyName 'aliasDomains'
    )

    if ([string]::IsNullOrWhiteSpace($primaryDomain)) {
        throw "Die Regel '$($Rule.name)' enthaelt keinen gueltigen primaryDomain-Wert."
    }

    $currentMail = [string](Get-PamPreviewPropertyValue -InputObject $UserObject -PropertyName 'Mail')
    $currentProxyAddresses = @(
        Get-PamPreviewPropertyValue -InputObject $UserObject -PropertyName 'ProxyAddresses'
    )
    $proxyAddressBuckets = Get-PamProxyAddressBuckets -ProxyAddresses $currentProxyAddresses

    $resolvedPrimaryAddresses = @(Resolve-PamPreviewSmtpAddresses -Templates @([string]$Rule.primaryAddressTemplate) -UserObject $UserObject -NormalizationRules $Rule.normalizationRules -Domains @($primaryDomain))
    if ($resolvedPrimaryAddresses.Count -eq 0) {
        throw "Die Regel '$($Rule.name)' konnte keine gueltige primaere SMTP-Adresse fuer '$((Get-PamPreviewIdentity -UserObject $UserObject))' erzeugen."
    }

    $proposedMail = [string]$resolvedPrimaryAddresses[0]
    if ($resolvedPrimaryAddresses.Count -gt 1) {
        $warnings.Add("Die Regel '$($Rule.name)' hat mehr als eine primaere Adresse erzeugt. Es wird nur '$proposedMail' verwendet.")
    }

    $effectiveAliasDomains = @($aliasDomains | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($effectiveAliasDomains.Count -eq 0) {
        $effectiveAliasDomains = @($primaryDomain)
    }

    $resolvedAliasAddresses = @(Resolve-PamPreviewSmtpAddresses -Templates @($Rule.aliasTemplates) -UserObject $UserObject -NormalizationRules $Rule.normalizationRules -Domains $effectiveAliasDomains)
    $deduplicatedAliases = New-Object System.Collections.Generic.List[string]

    foreach ($aliasAddress in $resolvedAliasAddresses) {
        if ($aliasAddress -ieq $proposedMail) {
            $warnings.Add("Alias '$aliasAddress' wurde verworfen, weil er der primaeren Adresse entspricht.")
            continue
        }

        $exists = $false
        foreach ($existingAlias in $deduplicatedAliases) {
            if ($existingAlias -ieq $aliasAddress) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            $deduplicatedAliases.Add($aliasAddress)
        }
    }

    $proposedProxyAddresses = @(
        "SMTP:$proposedMail"
    ) + @($deduplicatedAliases | ForEach-Object { "smtp:$_" })

    $preview = [pscustomobject]@{
        Identity = Get-PamPreviewIdentity -UserObject $UserObject
        AppliedRule = [string]$Rule.name
        CurrentMail = $currentMail
        ProposedMail = $proposedMail
        CurrentProxyAddresses = @($currentProxyAddresses)
        ProposedProxyAddresses = @($proposedProxyAddresses)
        PreservedNonSmtpProxyAddresses = @($proxyAddressBuckets.NonSmtp)
        Warnings = $warnings.ToArray()
    }

    $diff = New-PamRecipientDiff -PreviewObject $preview
    $preview | Add-Member -MemberType NoteProperty -Name Changes -Value @($diff.ChangedProperties) -Force
    $preview | Add-Member -MemberType NoteProperty -Name Diff -Value $diff -Force

    return $preview
}

Export-ModuleMember -Function @(
    'New-PamRecipientPreview'
)
