$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.Normalization.psm1'

Import-Module -Name $modulePath -Force

Describe 'ConvertTo-PamNormalizedAddressLocalPart' {
    It 'normalizes umlauts, separators, dots and casing in one pipeline' {
        $rules = [pscustomobject]@{
            toLower = $true
            replaceUmlauts = $true
            removeInvalidChars = $true
            collapseDots = $true
            trimEdgeDots = $true
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value '  Jörg__Müller / Vertrieb..Team  ' -NormalizationRules $rules

        $result | Should Be 'joerg.mueller.vertrieb.team'
    }

    It 'replaces German umlauts and sz before invalid characters are removed' {
        $rules = [pscustomobject]@{
            toLower = $true
            replaceUmlauts = $true
            removeInvalidChars = $true
            collapseDots = $true
            trimEdgeDots = $true
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value 'Jörg.Straße' -NormalizationRules $rules

        $result | Should Be 'joerg.strasse'
    }

    It 'keeps hyphens but removes other invalid characters' {
        $rules = [pscustomobject]@{
            toLower = $true
            replaceUmlauts = $true
            removeInvalidChars = $true
            collapseDots = $true
            trimEdgeDots = $true
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value "Anna-Lena O'Brian (EMEA)" -NormalizationRules $rules

        $result | Should Be 'anna-lena.obrian.emea'
    }

    It 'can run without lowercasing' {
        $rules = [pscustomobject]@{
            toLower = $false
            replaceUmlauts = $true
            removeInvalidChars = $true
            collapseDots = $true
            trimEdgeDots = $true
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value 'Max.Mustermann' -NormalizationRules $rules

        $result | Should Be 'Max.Mustermann'
    }

    It 'uses ASCII folding when umlaut replacement is disabled' {
        $rules = [pscustomobject]@{
            toLower = $true
            replaceUmlauts = $false
            removeInvalidChars = $true
            collapseDots = $true
            trimEdgeDots = $true
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value 'Jörg' -NormalizationRules $rules

        $result | Should Be 'jorg'
    }

    It 'returns an empty string for null input' {
        $rules = [pscustomobject]@{
            toLower = $true
            replaceUmlauts = $true
            removeInvalidChars = $true
            collapseDots = $true
            trimEdgeDots = $true
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value $null -NormalizationRules $rules

        $result | Should Be ''
    }

    It 'leaves values unchanged when no rules are enabled' {
        $rules = [pscustomobject]@{
            toLower = $false
            replaceUmlauts = $false
            removeInvalidChars = $false
            collapseDots = $false
            trimEdgeDots = $false
        }

        $result = ConvertTo-PamNormalizedAddressLocalPart -Value 'Max Mustermann' -NormalizationRules $rules

        $result | Should Be 'Max Mustermann'
    }
}
