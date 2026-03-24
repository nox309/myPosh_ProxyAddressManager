Set-StrictMode -Version Latest

$directoryModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.Directory.psm1'
Import-Module -Name $directoryModulePath -Force

function Get-PamActiveDirectoryProviderCallbacks {
    [CmdletBinding()]
    param(
        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = [ordered]@{
        GetCommand = {
            param([string]$CommandName)
            Get-Command -Name $CommandName -ErrorAction SilentlyContinue
        }
        ImportModule = {
            param([string]$ModuleName)
            Import-Module -Name $ModuleName -ErrorAction Stop
        }
        InvokeGetAdUser = {
            param([hashtable]$Parameters)
            Get-ADUser @Parameters
        }
    }

    if ($null -ne $Callbacks) {
        foreach ($property in $Callbacks.PSObject.Properties) {
            $resolvedCallbacks[$property.Name] = $property.Value
        }
    }

    return [pscustomobject]$resolvedCallbacks
}

function Get-PamAdDefaultPropertyList {
    [CmdletBinding()]
    param()

    return @(
        'DistinguishedName',
        'GivenName',
        'Surname',
        'SamAccountName',
        'Department',
        'Mail',
        'ProxyAddresses',
        'UserPrincipalName',
        'Enabled'
    )
}

function Resolve-PamAdPropertyList {
    [CmdletBinding()]
    param(
        [object[]]$RequestedProperties
    )

    $properties = New-Object System.Collections.Generic.List[string]

    foreach ($propertyName in @(Get-PamAdDefaultPropertyList) + @($RequestedProperties)) {
        if ([string]::IsNullOrWhiteSpace([string]$propertyName)) {
            continue
        }

        $propertyExists = $false
        foreach ($existingProperty in $properties) {
            if ($existingProperty -ieq [string]$propertyName) {
                $propertyExists = $true
                break
            }
        }

        if (-not $propertyExists) {
            $properties.Add([string]$propertyName)
        }
    }

    return $properties.ToArray()
}

function Assert-PamActiveDirectoryCommandAvailable {
    [CmdletBinding()]
    param(
        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = Get-PamActiveDirectoryProviderCallbacks -Callbacks $Callbacks
    $getAdUserCommand = & $resolvedCallbacks.GetCommand 'Get-ADUser'
    if ($null -ne $getAdUserCommand) {
        return $true
    }

    try {
        & $resolvedCallbacks.ImportModule 'ActiveDirectory'
    }
    catch {
        throw "Das ActiveDirectory-Modul ist fuer den read-only AD-Provider nicht verfuegbar. Bitte installiere bzw. importiere die AD PowerShell-Verwaltungstools, bevor du einen Live-AD-Test startest. Details: $($_.Exception.Message)"
    }

    $getAdUserCommand = & $resolvedCallbacks.GetCommand 'Get-ADUser'
    if ($null -eq $getAdUserCommand) {
        throw "Das ActiveDirectory-Modul wurde importiert, aber der erforderliche Befehl 'Get-ADUser' ist weiterhin nicht verfuegbar."
    }

    return $true
}

function ConvertFrom-PamAdRecipient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$AdUser,

        [object[]]$RequestedProperties
    )

    $result = [ordered]@{}
    foreach ($propertyName in Resolve-PamAdPropertyList -RequestedProperties $RequestedProperties) {
        $value = $null

        foreach ($property in $AdUser.PSObject.Properties) {
            if ($property.Name -ieq $propertyName) {
                $value = $property.Value
                break
            }
        }

        if ($null -ne $value -and $value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
            $value = @($value)
        }

        $result[$propertyName] = $value
    }

    return [pscustomobject]$result
}

function New-PamAdUserQueryParameters {
    [CmdletBinding()]
    param(
        [psobject]$Query,

        [object[]]$RequestedProperties
    )

    $parameters = @{
        Properties = @(Resolve-PamAdPropertyList -RequestedProperties $RequestedProperties)
    }

    if ($null -eq $Query) {
        $parameters.Filter = '*'
        return $parameters
    }

    if ($Query.PSObject.Properties.Match('Identity').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Query.Identity)) {
        $parameters.Identity = [string]$Query.Identity
    }
    elseif ($Query.PSObject.Properties.Match('LDAPFilter').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Query.LDAPFilter)) {
        $parameters.LDAPFilter = [string]$Query.LDAPFilter
    }
    elseif ($Query.PSObject.Properties.Match('Filter').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Query.Filter)) {
        $parameters.Filter = [string]$Query.Filter
    }
    else {
        $parameters.Filter = '*'
    }

    if ($Query.PSObject.Properties.Match('SearchBase').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Query.SearchBase)) {
        $parameters.SearchBase = [string]$Query.SearchBase
    }

    if ($Query.PSObject.Properties.Match('SearchScope').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Query.SearchScope)) {
        $parameters.SearchScope = [string]$Query.SearchScope
    }

    if ($Query.PSObject.Properties.Match('ResultSetSize').Count -gt 0 -and $null -ne $Query.ResultSetSize) {
        $parameters.ResultSetSize = $Query.ResultSetSize
    }

    if ($Query.PSObject.Properties.Match('Server').Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Query.Server)) {
        $parameters.Server = [string]$Query.Server
    }

    return $parameters
}

function New-PamActiveDirectoryRecipientProvider {
    [CmdletBinding()]
    param(
        [object[]]$DefaultProperties,

        [string]$Name = 'ActiveDirectoryRecipientProvider',

        [pscustomobject]$Callbacks
    )

    $resolvedCallbacks = Get-PamActiveDirectoryProviderCallbacks -Callbacks $Callbacks
    Assert-PamActiveDirectoryCommandAvailable -Callbacks $resolvedCallbacks | Out-Null
    $resolvedDefaultProperties = @(Resolve-PamAdPropertyList -RequestedProperties $DefaultProperties)

    $metadata = [pscustomobject]@{
        ProviderKind = 'ActiveDirectory'
        IdentityProperty = 'SamAccountName'
        DefaultProperties = $resolvedDefaultProperties
        ReadOnly = $true
    }

    $getRecipientsScript = {
            param($Query)

            $parameters = New-PamAdUserQueryParameters -Query $Query -RequestedProperties $resolvedDefaultProperties
            $results = @(& $resolvedCallbacks.InvokeGetAdUser $parameters)

            return @($results | ForEach-Object {
                    ConvertFrom-PamAdRecipient -AdUser $_ -RequestedProperties $resolvedDefaultProperties
                })
        }.GetNewClosure()

    $getRecipientByIdentityScript = {
            param($Identity)

            $query = [pscustomobject]@{
                Identity = $Identity
            }

            $parameters = New-PamAdUserQueryParameters -Query $query -RequestedProperties $resolvedDefaultProperties

            try {
                $result = & $resolvedCallbacks.InvokeGetAdUser $parameters
            }
            catch {
                if ($_.Exception.Message -match 'Cannot find an object') {
                    return $null
                }

                throw
            }

            if ($null -eq $result) {
                return $null
            }

            return (ConvertFrom-PamAdRecipient -AdUser $result -RequestedProperties $resolvedDefaultProperties)
        }.GetNewClosure()

    return (New-PamRecipientProvider -Name $Name -Metadata $metadata -GetRecipients $getRecipientsScript -GetRecipientByIdentity $getRecipientByIdentityScript)
}

Export-ModuleMember -Function @(
    'Assert-PamActiveDirectoryCommandAvailable',
    'ConvertFrom-PamAdRecipient',
    'Get-PamActiveDirectoryProviderCallbacks',
    'New-PamActiveDirectoryRecipientProvider',
    'New-PamAdUserQueryParameters',
    'Resolve-PamAdPropertyList'
)
