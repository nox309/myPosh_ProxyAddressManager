$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Directory\ProxyAddressManager.ActiveDirectory.psm1'

Import-Module -Name $modulePath -Force

Describe 'Assert-PamActiveDirectoryCommandAvailable' {
    It 'accepts an already available Get-ADUser command' {
        $callbacks = [pscustomobject]@{
            GetCommand = {
                param($CommandName)
                if ($CommandName -eq 'Get-ADUser') {
                    return [pscustomobject]@{ Name = 'Get-ADUser' }
                }

                return $null
            }
            ImportModule = {
                param($ModuleName)
                throw 'should not be called'
            }
        }

        { Assert-PamActiveDirectoryCommandAvailable -Callbacks $callbacks } | Should Not Throw
    }

    It 'throws a clear error when the AD module cannot be imported' {
        $callbacks = [pscustomobject]@{
            GetCommand = { param($CommandName) $null }
            ImportModule = { param($ModuleName) throw 'RSAT not installed' }
        }

        $thrown = $false

        try {
            Assert-PamActiveDirectoryCommandAvailable -Callbacks $callbacks | Out-Null
        }
        catch {
            $thrown = $true
            $_.Exception.Message | Should Match 'read-only AD-Provider'
            $_.Exception.Message | Should Match 'RSAT not installed'
        }

        $thrown | Should Be $true
    }
}

Describe 'New-PamAdUserQueryParameters' {
    It 'builds a default list query when no filter is provided' {
        $parameters = New-PamAdUserQueryParameters

        $parameters.Filter | Should Be '*'
        @($parameters.Properties).Count | Should Not Be 0
    }

    It 'prefers identity over generic filters' {
        $query = [pscustomobject]@{
            Identity = 'mmustermann'
            Filter = 'SamAccountName -like "*"'
        }

        $parameters = New-PamAdUserQueryParameters -Query $query -RequestedProperties @('Title')

        $parameters.Identity | Should Be 'mmustermann'
        $parameters.ContainsKey('Filter') | Should Be $false
        ($parameters.Properties -contains 'Title') | Should Be $true
    }
}

Describe 'New-PamActiveDirectoryRecipientProvider' {
    BeforeEach {
        $script:lastParameters = $null
        $script:callbacks = [pscustomobject]@{
            GetCommand = {
                param($CommandName)
                if ($CommandName -eq 'Get-ADUser') {
                    return [pscustomobject]@{ Name = 'Get-ADUser' }
                }

                return $null
            }
            ImportModule = {
                param($ModuleName)
            }
            InvokeGetAdUser = {
                param($Parameters)

                $script:lastParameters = $Parameters

                if ($Parameters.ContainsKey('Identity')) {
                    if ($Parameters.Identity -ieq 'mmustermann') {
                        return [pscustomobject]@{
                            DistinguishedName = 'CN=Max Mustermann,OU=Users,DC=contoso,DC=com'
                            GivenName = 'Max'
                            Surname = 'Mustermann'
                            SamAccountName = 'mmustermann'
                            Department = 'Sales'
                            Mail = 'max.mustermann@contoso.com'
                            ProxyAddresses = @(
                                'SMTP:max.mustermann@contoso.com',
                                'smtp:mmustermann@contoso.com'
                            )
                            UserPrincipalName = 'max.mustermann@contoso.com'
                            Enabled = $true
                            Title = 'Account Manager'
                        }
                    }

                    throw 'Cannot find an object with identity: unknown'
                }

                return @(
                    [pscustomobject]@{
                        DistinguishedName = 'CN=Max Mustermann,OU=Users,DC=contoso,DC=com'
                        GivenName = 'Max'
                        Surname = 'Mustermann'
                        SamAccountName = 'mmustermann'
                        Department = 'Sales'
                        Mail = 'max.mustermann@contoso.com'
                        ProxyAddresses = @(
                            'SMTP:max.mustermann@contoso.com',
                            'smtp:mmustermann@contoso.com'
                        )
                        UserPrincipalName = 'max.mustermann@contoso.com'
                        Enabled = $true
                    },
                    [pscustomobject]@{
                        DistinguishedName = 'CN=Franziska Beispiel,OU=Users,DC=contoso,DC=com'
                        GivenName = 'Franziska'
                        Surname = 'Beispiel'
                        SamAccountName = 'fbeispiel'
                        Department = 'HR'
                        Mail = 'franziska.beispiel@contoso.com'
                        ProxyAddresses = @(
                            'SMTP:franziska.beispiel@contoso.com'
                        )
                        UserPrincipalName = 'franziska.beispiel@contoso.com'
                        Enabled = $true
                    }
                )
            }
        }
    }

    It 'creates a read-only AD provider with metadata' {
        $provider = New-PamActiveDirectoryRecipientProvider -Callbacks $script:callbacks

        $provider.Metadata.ProviderKind | Should Be 'ActiveDirectory'
        $provider.Metadata.ReadOnly | Should Be $true
        $provider.Metadata.IdentityProperty | Should Be 'SamAccountName'
    }

    It 'loads recipients via Get-ADUser and maps them to plain objects' {
        $provider = New-PamActiveDirectoryRecipientProvider -DefaultProperties @('Title') -Callbacks $script:callbacks
        $query = [pscustomobject]@{
            SearchBase = 'OU=Users,DC=contoso,DC=com'
            Filter = 'Enabled -eq $true'
            ResultSetSize = 50
        }

        $result = @(& $provider.GetRecipients $query)

        @($result).Count | Should Be 2
        $result[0].SamAccountName | Should Be 'mmustermann'
        $result[0].ProxyAddresses.Count | Should Be 2
        $script:lastParameters.SearchBase | Should Be 'OU=Users,DC=contoso,DC=com'
        $script:lastParameters.Filter | Should Be 'Enabled -eq $true'
        $script:lastParameters.ResultSetSize | Should Be 50
        ($script:lastParameters.Properties -contains 'Title') | Should Be $true
    }

    It 'loads a single recipient by identity and returns null when not found' {
        $provider = New-PamActiveDirectoryRecipientProvider -Callbacks $script:callbacks

        $match = & $provider.GetRecipientByIdentity 'mmustermann'
        $missing = & $provider.GetRecipientByIdentity 'unknown'

        $match.Mail | Should Be 'max.mustermann@contoso.com'
        $missing | Should Be $null
    }
}
