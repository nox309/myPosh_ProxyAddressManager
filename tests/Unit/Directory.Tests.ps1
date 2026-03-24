$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Directory\ProxyAddressManager.Directory.psm1'

Import-Module -Name $modulePath -Force

Describe 'New-PamRecipientProvider and Assert-PamRecipientProvider' {
    It 'creates a valid provider contract' {
        $provider = New-PamRecipientProvider -Name 'TestProvider' -GetRecipients { param($Query) @() } -GetRecipientByIdentity { param($Identity) $null }

        $provider.Name | Should Be 'TestProvider'
        { Assert-PamRecipientProvider -Provider $provider } | Should Not Throw
    }

    It 'throws when the provider contract is incomplete' {
        $provider = [pscustomobject]@{
            Name = 'BrokenProvider'
            GetRecipients = { param($Query) @() }
        }

        $thrown = $false

        try {
            Assert-PamRecipientProvider -Provider $provider | Out-Null
        }
        catch {
            $thrown = $true
            $_.Exception.Message | Should Match 'GetRecipientByIdentity'
        }

        $thrown | Should Be $true
    }
}

Describe 'New-PamMockRecipientProvider' {
    BeforeEach {
        $script:recipients = @(
            [pscustomobject]@{
                SamAccountName = 'mmustermann'
                DistinguishedName = 'CN=Max Mustermann,OU=Users,DC=contoso,DC=com'
                GivenName = 'Max'
                Surname = 'Mustermann'
                Department = 'Sales'
            },
            [pscustomobject]@{
                SamAccountName = 'fbeispiel'
                DistinguishedName = 'CN=Franziska Beispiel,OU=Users,DC=contoso,DC=com'
                GivenName = 'Franziska'
                Surname = 'Beispiel'
                Department = 'HR'
            }
        )
    }

    It 'returns all recipients via the provider wrapper' {
        $provider = New-PamMockRecipientProvider -Recipients $script:recipients

        $result = Get-PamRecipients -Provider $provider

        @($result).Count | Should Be 2
        $provider.Metadata.ProviderKind | Should Be 'Mock'
        $provider.Metadata.IdentityProperty | Should Be 'SamAccountName'
    }

    It 'can filter recipients with an in-memory filter script' {
        $provider = New-PamMockRecipientProvider -Recipients $script:recipients
        $query = [pscustomobject]@{
            FilterScript = { $_.Department -eq 'Sales' }
        }

        $result = Get-PamRecipients -Provider $provider -Query $query

        @($result).Count | Should Be 1
        $result[0].SamAccountName | Should Be 'mmustermann'
    }

    It 'returns a recipient by identity case-insensitively' {
        $provider = New-PamMockRecipientProvider -Recipients $script:recipients

        $result = Get-PamRecipientByIdentity -Provider $provider -Identity 'MMUSTERMANN'

        $result.GivenName | Should Be 'Max'
    }

    It 'returns null for an unknown identity' {
        $provider = New-PamMockRecipientProvider -Recipients $script:recipients

        $result = Get-PamRecipientByIdentity -Provider $provider -Identity 'unknown'

        $result | Should Be $null
    }

    It 'throws when a mock recipient misses the configured identity property' {
        $invalidRecipients = @(
            [pscustomobject]@{
                GivenName = 'Max'
            }
        )

        $thrown = $false

        try {
            New-PamMockRecipientProvider -Recipients $invalidRecipients | Out-Null
        }
        catch {
            $thrown = $true
            $_.Exception.Message | Should Match 'Identity-Feld'
        }

        $thrown | Should Be $true
    }
}
