$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.Diff.psm1'

Import-Module -Name $modulePath -Force

Describe 'New-PamRecipientDiff' {
    It 'reports mail and proxy changes from a preview object' {
        $preview = [pscustomobject]@{
            CurrentMail = 'max.mustermann@contoso.com'
            ProposedMail = 'max.mustermann@corp.contoso.com'
            CurrentProxyAddresses = @(
                'SMTP:max.mustermann@contoso.com',
                'smtp:mmustermann@contoso.com',
                'X500:/o=Contoso/ou=Exchange Administrative Group/cn=Recipients/cn=Max.Mustermann'
            )
            ProposedProxyAddresses = @(
                'SMTP:max.mustermann@corp.contoso.com',
                'smtp:mmustermann@corp.contoso.com'
            )
            PreservedNonSmtpProxyAddresses = @(
                'X500:/o=Contoso/ou=Exchange Administrative Group/cn=Recipients/cn=Max.Mustermann'
            )
        }

        $result = New-PamRecipientDiff -PreviewObject $preview

        $result.HasChanges | Should Be $true
        $result.Mail.IsChanged | Should Be $true
        $result.ProxyAddresses.IsChanged | Should Be $true
        ($result.ChangedProperties -contains 'Mail') | Should Be $true
        ($result.ChangedProperties -contains 'ProxyAddresses') | Should Be $true
        ($result.ProxyAddresses.AddedSmtp -contains 'SMTP:max.mustermann@corp.contoso.com') | Should Be $true
        ($result.ProxyAddresses.RemovedSmtp -contains 'SMTP:max.mustermann@contoso.com') | Should Be $true
        @($result.ProxyAddresses.PreservedNonSmtp).Count | Should Be 1
    }

    It 'does not report a change when only smtp casing differs' {
        $preview = [pscustomobject]@{
            CurrentMail = 'max.mustermann@contoso.com'
            ProposedMail = 'MAX.MUSTERMANN@CONTOSO.COM'
            CurrentProxyAddresses = @(
                'SMTP:max.mustermann@contoso.com',
                'smtp:mmustermann@contoso.com'
            )
            ProposedProxyAddresses = @(
                'smtp:MAX.MUSTERMANN@CONTOSO.COM',
                'SMTP:MMUSTERMANN@CONTOSO.COM'
            )
            PreservedNonSmtpProxyAddresses = @()
        }

        $result = New-PamRecipientDiff -PreviewObject $preview

        $result.HasChanges | Should Be $false
        $result.Mail.IsChanged | Should Be $false
        $result.ProxyAddresses.IsChanged | Should Be $false
    }

    It 'keeps preserved non-smtp values in the proposed proxy set' {
        $preview = [pscustomobject]@{
            CurrentMail = 'max.mustermann@contoso.com'
            ProposedMail = 'max.mustermann@contoso.com'
            CurrentProxyAddresses = @(
                'SMTP:max.mustermann@contoso.com',
                'X500:/o=Contoso/ou=Exchange Administrative Group/cn=Recipients/cn=Max.Mustermann'
            )
            ProposedProxyAddresses = @(
                'SMTP:max.mustermann@contoso.com'
            )
            PreservedNonSmtpProxyAddresses = @(
                'X500:/o=Contoso/ou=Exchange Administrative Group/cn=Recipients/cn=Max.Mustermann'
            )
        }

        $result = New-PamRecipientDiff -PreviewObject $preview

        $result.ProxyAddresses.IsChanged | Should Be $false
        ($result.ProxyAddresses.Proposed -contains 'X500:/o=Contoso/ou=Exchange Administrative Group/cn=Recipients/cn=Max.Mustermann') | Should Be $true
    }
}
