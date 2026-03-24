Set-StrictMode -Version Latest

function Get-PamNormalizationRuleValue {
    [CmdletBinding()]
    param(
        [psobject]$NormalizationRules,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [bool]$DefaultValue = $false
    )

    if ($null -eq $NormalizationRules) {
        return $DefaultValue
    }

    foreach ($property in $NormalizationRules.PSObject.Properties) {
        if ($property.Name -ieq $PropertyName) {
            if ($null -eq $property.Value) {
                return $DefaultValue
            }

            return [bool]$property.Value
        }
    }

    return $DefaultValue
}

function ConvertTo-PamSeparatorNormalizedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    return ([regex]::Replace($Value, '[\s_/,;:\\]+', '.'))
}

function ConvertTo-PamUmlautNormalizedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    $normalizedValue = $Value
    $normalizedValue = $normalizedValue.Replace([string][char]0x00C4, 'Ae')
    $normalizedValue = $normalizedValue.Replace([string][char]0x00D6, 'Oe')
    $normalizedValue = $normalizedValue.Replace([string][char]0x00DC, 'Ue')
    $normalizedValue = $normalizedValue.Replace([string][char]0x00E4, 'ae')
    $normalizedValue = $normalizedValue.Replace([string][char]0x00F6, 'oe')
    $normalizedValue = $normalizedValue.Replace([string][char]0x00FC, 'ue')
    $normalizedValue = $normalizedValue.Replace([string][char]0x00DF, 'ss')

    return $normalizedValue
}

function ConvertTo-PamAsciiFoldedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    $decomposedValue = $Value.Normalize([Text.NormalizationForm]::FormD)
    $builder = [System.Text.StringBuilder]::new()

    foreach ($character in $decomposedValue.ToCharArray()) {
        $unicodeCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
        if ($unicodeCategory -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }

    return $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function ConvertTo-PamNormalizedAddressLocalPart {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [psobject]$NormalizationRules
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return ''
    }

    $toLower = Get-PamNormalizationRuleValue -NormalizationRules $NormalizationRules -PropertyName 'toLower'
    $replaceUmlauts = Get-PamNormalizationRuleValue -NormalizationRules $NormalizationRules -PropertyName 'replaceUmlauts'
    $removeInvalidChars = Get-PamNormalizationRuleValue -NormalizationRules $NormalizationRules -PropertyName 'removeInvalidChars'
    $collapseDots = Get-PamNormalizationRuleValue -NormalizationRules $NormalizationRules -PropertyName 'collapseDots'
    $trimEdgeDots = Get-PamNormalizationRuleValue -NormalizationRules $NormalizationRules -PropertyName 'trimEdgeDots'

    $normalizedValue = $Value

    if ($replaceUmlauts) {
        $normalizedValue = ConvertTo-PamUmlautNormalizedValue -Value $normalizedValue
    }

    if ($removeInvalidChars -or $collapseDots -or $trimEdgeDots) {
        $normalizedValue = ConvertTo-PamSeparatorNormalizedValue -Value $normalizedValue
    }

    if ($removeInvalidChars) {
        $normalizedValue = ConvertTo-PamAsciiFoldedValue -Value $normalizedValue
        $normalizedValue = [regex]::Replace($normalizedValue, '[^A-Za-z0-9.-]', '')
    }

    if ($collapseDots) {
        $normalizedValue = [regex]::Replace($normalizedValue, '\.{2,}', '.')
    }

    if ($trimEdgeDots) {
        $normalizedValue = $normalizedValue.Trim('.')
    }

    if ($toLower) {
        $normalizedValue = $normalizedValue.ToLowerInvariant()
    }

    return $normalizedValue
}

Export-ModuleMember -Function @(
    'ConvertTo-PamNormalizedAddressLocalPart'
)
