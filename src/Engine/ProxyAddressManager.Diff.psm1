Set-StrictMode -Version Latest

function Get-PamDiffPropertyValue {
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

function Get-PamDiffUniqueValues {
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

function Get-PamProxyAddressDiffBuckets {
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
        Smtp = @(Get-PamDiffUniqueValues -Values $smtpAddresses.ToArray())
        NonSmtp = @(Get-PamDiffUniqueValues -Values $nonSmtpAddresses.ToArray())
    }
}

function Get-PamDiffAddedValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CurrentValues,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProposedValues
    )

    $addedValues = New-Object System.Collections.Generic.List[string]
    $currentUniqueValues = @(Get-PamDiffUniqueValues -Values $CurrentValues)

    foreach ($proposedValue in @(Get-PamDiffUniqueValues -Values $ProposedValues)) {
        $exists = $false
        foreach ($currentValue in $currentUniqueValues) {
            if ($currentValue -ieq $proposedValue) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            $addedValues.Add($proposedValue)
        }
    }

    return $addedValues.ToArray()
}

function New-PamRecipientDiff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$PreviewObject
    )

    $currentMail = [string](Get-PamDiffPropertyValue -InputObject $PreviewObject -PropertyName 'CurrentMail')
    $proposedMail = [string](Get-PamDiffPropertyValue -InputObject $PreviewObject -PropertyName 'ProposedMail')
    $currentProxyAddresses = @(
        Get-PamDiffPropertyValue -InputObject $PreviewObject -PropertyName 'CurrentProxyAddresses'
    )
    $proposedSmtpProxyAddresses = @(
        Get-PamDiffPropertyValue -InputObject $PreviewObject -PropertyName 'ProposedProxyAddresses'
    )
    $preservedNonSmtpProxyAddresses = @(
        Get-PamDiffPropertyValue -InputObject $PreviewObject -PropertyName 'PreservedNonSmtpProxyAddresses'
    )

    $proposedProxyAddresses = @(Get-PamDiffUniqueValues -Values (@($proposedSmtpProxyAddresses) + @($preservedNonSmtpProxyAddresses)))
    $currentBuckets = Get-PamProxyAddressDiffBuckets -ProxyAddresses $currentProxyAddresses
    $proposedBuckets = Get-PamProxyAddressDiffBuckets -ProxyAddresses $proposedProxyAddresses

    $mailChanged = -not ($currentMail -ieq $proposedMail)
    $addedProxyAddresses = @(Get-PamDiffAddedValues -CurrentValues $currentProxyAddresses -ProposedValues $proposedProxyAddresses)
    $removedProxyAddresses = @(Get-PamDiffAddedValues -CurrentValues $proposedProxyAddresses -ProposedValues $currentProxyAddresses)
    $addedSmtpProxyAddresses = @(Get-PamDiffAddedValues -CurrentValues $currentBuckets.Smtp -ProposedValues $proposedBuckets.Smtp)
    $removedSmtpProxyAddresses = @(Get-PamDiffAddedValues -CurrentValues $proposedBuckets.Smtp -ProposedValues $currentBuckets.Smtp)
    $proxyAddressesChanged = ($addedProxyAddresses.Count -gt 0) -or ($removedProxyAddresses.Count -gt 0)

    $changedProperties = New-Object System.Collections.Generic.List[string]
    if ($mailChanged) {
        $changedProperties.Add('Mail')
    }

    if ($proxyAddressesChanged) {
        $changedProperties.Add('ProxyAddresses')
    }

    return [pscustomobject]@{
        HasChanges = $changedProperties.Count -gt 0
        ChangedProperties = $changedProperties.ToArray()
        Mail = [pscustomobject]@{
            IsChanged = $mailChanged
            Current = $currentMail
            Proposed = $proposedMail
        }
        ProxyAddresses = [pscustomobject]@{
            IsChanged = $proxyAddressesChanged
            Current = @(Get-PamDiffUniqueValues -Values $currentProxyAddresses)
            Proposed = $proposedProxyAddresses
            CurrentSmtp = @($currentBuckets.Smtp)
            ProposedSmtp = @($proposedBuckets.Smtp)
            CurrentNonSmtp = @($currentBuckets.NonSmtp)
            ProposedNonSmtp = @($proposedBuckets.NonSmtp)
            Added = $addedProxyAddresses
            Removed = $removedProxyAddresses
            AddedSmtp = $addedSmtpProxyAddresses
            RemovedSmtp = $removedSmtpProxyAddresses
            PreservedNonSmtp = @(Get-PamDiffUniqueValues -Values $preservedNonSmtpProxyAddresses)
        }
    }
}

Export-ModuleMember -Function @(
    'New-PamRecipientDiff'
)
