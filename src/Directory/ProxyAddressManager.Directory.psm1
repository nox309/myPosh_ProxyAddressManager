Set-StrictMode -Version Latest

function Get-PamRecipientProviderScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Provider,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    foreach ($property in $Provider.PSObject.Properties) {
        if ($property.Name -ieq $PropertyName) {
            return $property.Value
        }
    }

    return $null
}

function Get-PamRecipientIdentityValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Recipient,

        [Parameter(Mandatory)]
        [string]$IdentityProperty
    )

    foreach ($property in $Recipient.PSObject.Properties) {
        if ($property.Name -ieq $IdentityProperty) {
            return $property.Value
        }
    }

    return $null
}

function Assert-PamRecipientProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Provider
    )

    if ([string]::IsNullOrWhiteSpace($Provider.Name)) {
        throw 'Der Recipient-Provider enthaelt keinen gueltigen Namen.'
    }

    if ($Provider.PSObject.Properties.Match('GetRecipients').Count -eq 0) {
        throw "Der Recipient-Provider '$($Provider.Name)' enthaelt keinen gueltigen GetRecipients-ScriptBlock."
    }
    $getRecipients = $Provider.PSObject.Properties['GetRecipients'].Value
    if ($getRecipients -isnot [scriptblock]) {
        throw "Der Recipient-Provider '$($Provider.Name)' enthaelt keinen gueltigen GetRecipients-ScriptBlock."
    }

    if ($Provider.PSObject.Properties.Match('GetRecipientByIdentity').Count -eq 0) {
        throw "Der Recipient-Provider '$($Provider.Name)' enthaelt keinen gueltigen GetRecipientByIdentity-ScriptBlock."
    }
    $getRecipientByIdentity = $Provider.PSObject.Properties['GetRecipientByIdentity'].Value
    if ($getRecipientByIdentity -isnot [scriptblock]) {
        throw "Der Recipient-Provider '$($Provider.Name)' enthaelt keinen gueltigen GetRecipientByIdentity-ScriptBlock."
    }

    return $Provider
}

function New-PamRecipientProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$GetRecipients,

        [Parameter(Mandatory)]
        [scriptblock]$GetRecipientByIdentity,

        [psobject]$Metadata
    )

    $provider = [pscustomobject]@{
        Name = $Name
        GetRecipients = $GetRecipients
        GetRecipientByIdentity = $GetRecipientByIdentity
        Metadata = $Metadata
    }

    Assert-PamRecipientProvider -Provider $provider | Out-Null
    return $provider
}

function Get-PamRecipients {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Provider,

        [psobject]$Query
    )

    Assert-PamRecipientProvider -Provider $Provider | Out-Null
    $getRecipients = Get-PamRecipientProviderScriptBlock -Provider $Provider -PropertyName 'GetRecipients'
    return @(& $getRecipients $Query)
}

function Get-PamRecipientByIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Provider,

        [Parameter(Mandatory)]
        [string]$Identity
    )

    if ([string]::IsNullOrWhiteSpace($Identity)) {
        throw 'Es wurde keine gueltige Identity uebergeben.'
    }

    Assert-PamRecipientProvider -Provider $Provider | Out-Null
    $getRecipientByIdentity = Get-PamRecipientProviderScriptBlock -Provider $Provider -PropertyName 'GetRecipientByIdentity'
    return (& $getRecipientByIdentity $Identity)
}

function New-PamMockRecipientProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Recipients,

        [string]$IdentityProperty = 'SamAccountName',

        [string]$Name = 'MockRecipientProvider'
    )

    if ([string]::IsNullOrWhiteSpace($IdentityProperty)) {
        throw 'Es wurde kein gueltiges IdentityProperty uebergeben.'
    }

    $recipientSnapshot = @($Recipients)

    foreach ($recipient in $recipientSnapshot) {
        if ($recipient.PSObject.Properties.Match($IdentityProperty).Count -eq 0) {
            throw "Mindestens ein Mock-Recipient enthaelt kein gueltiges Identity-Feld '$IdentityProperty'."
        }

        $identityValue = $recipient.PSObject.Properties[$IdentityProperty].Value
        if ([string]::IsNullOrWhiteSpace([string]$identityValue)) {
            throw "Mindestens ein Mock-Recipient enthaelt kein gueltiges Identity-Feld '$IdentityProperty'."
        }
    }

    $metadata = [pscustomobject]@{
        ProviderKind = 'Mock'
        IdentityProperty = $IdentityProperty
        RecipientCount = $recipientSnapshot.Count
    }

    $getRecipientsScript = {
            param($Query)

            $results = @($recipientSnapshot)
            if ($null -eq $Query) {
                return $results
            }

            if ($Query.PSObject.Properties.Match('FilterScript').Count -gt 0 -and $Query.FilterScript -is [scriptblock]) {
                return @($results | Where-Object $Query.FilterScript)
            }

            return $results
        }.GetNewClosure()

    $getRecipientByIdentityScript = {
            param($Identity)

            foreach ($recipient in $recipientSnapshot) {
                if ($recipient.PSObject.Properties.Match($IdentityProperty).Count -eq 0) {
                    continue
                }

                $identityValue = $recipient.PSObject.Properties[$IdentityProperty].Value
                if ($null -ne $identityValue -and [string]$identityValue -ieq $Identity) {
                    return $recipient
                }
            }

            return $null
        }.GetNewClosure()

    return (New-PamRecipientProvider -Name $Name -Metadata $metadata -GetRecipients $getRecipientsScript -GetRecipientByIdentity $getRecipientByIdentityScript)
}

Export-ModuleMember -Function @(
    'Assert-PamRecipientProvider',
    'Get-PamRecipientByIdentity',
    'Get-PamRecipients',
    'New-PamMockRecipientProvider',
    'New-PamRecipientProvider'
)
