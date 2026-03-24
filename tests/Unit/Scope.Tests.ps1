$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.Scope.psm1'

Import-Module -Name $modulePath -Force

Describe 'Test-PamScopeAttributeFilter' {
    BeforeEach {
        $script:user = [pscustomobject]@{
            Department = 'Sales'
            Title = 'Senior Account Manager'
            Company = 'Contoso'
        }
    }

    It 'matches eq case-insensitively' {
        $filter = [pscustomobject]@{
            attribute = 'department'
            operator = 'eq'
            value = 'sales'
        }

        $result = Test-PamScopeAttributeFilter -UserObject $script:user -Filter $filter

        $result.IsMatch | Should Be $true
    }

    It 'matches contains for substring comparisons' {
        $filter = [pscustomobject]@{
            attribute = 'Title'
            operator = 'contains'
            value = 'account'
        }

        $result = Test-PamScopeAttributeFilter -UserObject $script:user -Filter $filter

        $result.IsMatch | Should Be $true
    }

    It 'throws for unsupported operators' {
        $filter = [pscustomobject]@{
            attribute = 'Company'
            operator = 'regex'
            value = 'Contoso'
        }

        $thrown = $false

        try {
            Test-PamScopeAttributeFilter -UserObject $script:user -Filter $filter | Out-Null
        }
        catch {
            $thrown = $true
            $_.Exception.Message | Should Match 'nicht unterstuetzt'
        }

        $thrown | Should Be $true
    }
}

Describe 'Test-PamRecipientScope' {
    BeforeEach {
        $script:user = [pscustomobject]@{
            DistinguishedName = 'CN=Max Mustermann,OU=Users,DC=contoso,DC=com'
            SamAccountName = 'mmustermann'
            Department = 'Sales'
            Title = 'Senior Account Manager'
            MemberOf = @(
                'CN=MailPolicy-Standard,OU=Groups,DC=contoso,DC=com',
                'CN=VPN,OU=Groups,DC=contoso,DC=com'
            )
        }
    }

    It 'matches when OU, group and all attribute filters match' {
        $scope = [pscustomobject]@{
            organizationalUnits = @('OU=Users,DC=contoso,DC=com')
            groups = @('CN=MailPolicy-Standard,OU=Groups,DC=contoso,DC=com')
            attributeFilters = @(
                [pscustomobject]@{
                    attribute = 'Department'
                    operator = 'eq'
                    value = 'Sales'
                },
                [pscustomobject]@{
                    attribute = 'Title'
                    operator = 'contains'
                    value = 'Account'
                }
            )
        }

        $result = Test-PamRecipientScope -UserObject $script:user -Scope $scope

        $result.IsMatch | Should Be $true
        $result.OrganizationalUnitMatch | Should Be $true
        $result.GroupMatch | Should Be $true
        $result.AttributeFilterMatch | Should Be $true
    }

    It 'treats organizational unit lists as OR' {
        $scope = [pscustomobject]@{
            organizationalUnits = @(
                'OU=Admins,DC=contoso,DC=com',
                'OU=Users,DC=contoso,DC=com'
            )
            groups = @()
            attributeFilters = @()
        }

        $result = Test-PamRecipientScope -UserObject $script:user -Scope $scope

        $result.IsMatch | Should Be $true
        @($result.MatchedOrganizationalUnits).Count | Should Be 1
    }

    It 'treats group lists as direct-membership OR' {
        $scope = [pscustomobject]@{
            organizationalUnits = @()
            groups = @(
                'CN=DoesNotExist,OU=Groups,DC=contoso,DC=com',
                'CN=VPN,OU=Groups,DC=contoso,DC=com'
            )
            attributeFilters = @()
        }

        $result = Test-PamRecipientScope -UserObject $script:user -Scope $scope

        $result.IsMatch | Should Be $true
        @($result.MatchedGroups).Count | Should Be 1
    }

    It 'requires all attribute filters to match' {
        $scope = [pscustomobject]@{
            organizationalUnits = @()
            groups = @()
            attributeFilters = @(
                [pscustomobject]@{
                    attribute = 'Department'
                    operator = 'eq'
                    value = 'Sales'
                },
                [pscustomobject]@{
                    attribute = 'Title'
                    operator = 'contains'
                    value = 'Director'
                }
            )
        }

        $result = Test-PamRecipientScope -UserObject $script:user -Scope $scope

        $result.IsMatch | Should Be $false
        $result.AttributeFilterMatch | Should Be $false
    }

    It 'treats empty scope dimensions as non-restrictive' {
        $scope = [pscustomobject]@{
            organizationalUnits = @()
            groups = @()
            attributeFilters = @()
        }

        $result = Test-PamRecipientScope -UserObject $script:user -Scope $scope

        $result.IsMatch | Should Be $true
    }

    It 'supports direct groups from a Groups property fallback' {
        $user = [pscustomobject]@{
            DistinguishedName = 'CN=Franziska Beispiel,OU=Users,DC=contoso,DC=com'
            Department = 'HR'
            Groups = @('CN=HR,OU=Groups,DC=contoso,DC=com')
        }
        $scope = [pscustomobject]@{
            organizationalUnits = @('OU=Users,DC=contoso,DC=com')
            groups = @('CN=HR,OU=Groups,DC=contoso,DC=com')
            attributeFilters = @()
        }

        $result = Test-PamRecipientScope -UserObject $user -Scope $scope

        $result.IsMatch | Should Be $true
    }
}
