$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.Preview.psm1'

Import-Module -Name $modulePath -Force

Describe 'New-PamRecipientPreview' {
    BeforeEach {
        $script:user = [pscustomobject]@{
            DistinguishedName = 'CN=Max Mustermann,OU=Users,DC=contoso,DC=com'
            GivenName = 'Max'
            Surname = 'Mustermann'
            SamAccountName = 'mmustermann'
            Mail = 'max.mustermann@contoso.com'
            ProxyAddresses = @(
                'SMTP:max.mustermann@contoso.com',
                'smtp:mmustermann@contoso.com',
                'X500:/o=Contoso/ou=Exchange Administrative Group/cn=Recipients/cn=Max.Mustermann'
            )
        }

        $script:rule = [pscustomobject]@{
            name = 'Standard Users'
            primaryAddressTemplate = '%GivenName%.%Surname%'
            aliasTemplates = @(
                '%SamAccountName%',
                '%FirstN(1,GivenName)%.%Surname%'
            )
            domainRules = [pscustomobject]@{
                primaryDomain = 'contoso.com'
                aliasDomains = @(
                    'contoso.com',
                    'corp.contoso.com'
                )
            }
            normalizationRules = [pscustomobject]@{
                toLower = $true
                replaceUmlauts = $true
                removeInvalidChars = $true
                collapseDots = $true
                trimEdgeDots = $true
            }
        }
    }

    It 'builds a preview with primary mail and alias proxy addresses' {
        $result = New-PamRecipientPreview -UserObject $script:user -Rule $script:rule

        $result.AppliedRule | Should Be 'Standard Users'
        $result.ProposedMail | Should Be 'max.mustermann@contoso.com'
        $result.ProposedProxyAddresses[0] | Should Be 'SMTP:max.mustermann@contoso.com'
        ($result.ProposedProxyAddresses -contains 'smtp:mmustermann@contoso.com') | Should Be $true
        ($result.ProposedProxyAddresses -contains 'smtp:m.mustermann@corp.contoso.com') | Should Be $true
    }

    It 'deduplicates aliases and drops aliases equal to the primary address' {
        $rule = [pscustomobject]@{
            name = 'Duplicate Rule'
            primaryAddressTemplate = '%GivenName%.%Surname%'
            aliasTemplates = @(
                '%GivenName%.%Surname%',
                '%SamAccountName%',
                '%SamAccountName%'
            )
            domainRules = [pscustomobject]@{
                primaryDomain = 'contoso.com'
                aliasDomains = @('contoso.com')
            }
            normalizationRules = $script:rule.normalizationRules
        }

        $result = New-PamRecipientPreview -UserObject $script:user -Rule $rule

        @($result.ProposedProxyAddresses).Count | Should Be 2
        $result.ProposedProxyAddresses[1] | Should Be 'smtp:mmustermann@contoso.com'
        @($result.Warnings).Count | Should Be 1
    }

    It 'preserves non-smtp current proxy addresses in the model' {
        $result = New-PamRecipientPreview -UserObject $script:user -Rule $script:rule

        @($result.PreservedNonSmtpProxyAddresses).Count | Should Be 1
        $result.PreservedNonSmtpProxyAddresses[0] | Should Match '^X500:'
    }

    It 'keeps full-address templates without appending domains' {
        $rule = [pscustomobject]@{
            name = 'Explicit Address Rule'
            primaryAddressTemplate = 'custom.primary@contoso.net'
            aliasTemplates = @(
                'alias.one@contoso.net'
            )
            domainRules = [pscustomobject]@{
                primaryDomain = 'contoso.com'
                aliasDomains = @('contoso.com')
            }
            normalizationRules = $script:rule.normalizationRules
        }

        $result = New-PamRecipientPreview -UserObject $script:user -Rule $rule

        $result.ProposedMail | Should Be 'custom.primary@contoso.net'
        $result.ProposedProxyAddresses[1] | Should Be 'smtp:alias.one@contoso.net'
    }

    It 'throws when the rule cannot produce a valid primary address' {
        $rule = [pscustomobject]@{
            name = 'Broken Rule'
            primaryAddressTemplate = '%MissingProperty%'
            aliasTemplates = @()
            domainRules = [pscustomobject]@{
                primaryDomain = 'contoso.com'
                aliasDomains = @('contoso.com')
            }
            normalizationRules = $script:rule.normalizationRules
        }

        $thrown = $false

        try {
            New-PamRecipientPreview -UserObject $script:user -Rule $rule | Out-Null
        }
        catch {
            $thrown = $true
            $_.Exception.Message | Should Match 'primaere SMTP-Adresse'
        }

        $thrown | Should Be $true
    }
}
