Set-StrictMode -Version Latest

$loggingModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Bootstrap\ProxyAddressManager.Logging.psm1'
$tokenizerModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ProxyAddressManager.TemplateTokenizer.psm1'
Import-Module -Name $loggingModulePath -Force
Import-Module -Name $tokenizerModulePath -Force

function ConvertTo-PamTemplateScalarValue {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [string]) {
        return $Value
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $values = @($Value)
        if ($values.Count -eq 0) {
            return ''
        }

        return [string]::Join(',', @($values | ForEach-Object { [string]$_ }))
    }

    return [string]$Value
}

function Get-PamTemplateUserPropertyValue {
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    foreach ($property in $UserObject.PSObject.Properties) {
        if ($property.Name -ieq $PropertyName) {
            return $property.Value
        }
    }

    return $null
}

function ConvertTo-PamTemplateIntegerValue {
    param(
        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$FunctionName
    )

    $parsedValue = 0
    if (-not [int]::TryParse($Value, [ref]$parsedValue)) {
        Stop-PamExecution -Message "Die Funktion '$FunctionName' erwartet fuer das erste Argument einen Integer-Wert."
    }

    if ($parsedValue -lt 0) {
        Stop-PamExecution -Message "Die Funktion '$FunctionName' erwartet einen nicht-negativen Integer-Wert."
    }

    return $parsedValue
}

function Resolve-PamTemplateExpressionAst {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Ast,

        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    Write-PamLog -Level 'Debug' -Message "AST-Knoten wird aufgeloest: $($Ast.Kind)"
    switch ($Ast.Kind) {
        'Attribute' {
            return (ConvertTo-PamTemplateScalarValue (Get-PamTemplateUserPropertyValue -UserObject $UserObject -PropertyName $Ast.Name))
        }
        'StringLiteral' {
            return (ConvertTo-PamTemplateScalarValue $Ast.Value)
        }
        'NumberLiteral' {
            return (ConvertTo-PamTemplateScalarValue $Ast.Value)
        }
        'Function' {
            switch -Regex ($Ast.Name) {
                '^(?i:firstn)$' {
                    $count = ConvertTo-PamTemplateIntegerValue -Value (Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[0] -UserObject $UserObject) -FunctionName $Ast.Name
                    $source = Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[1] -UserObject $UserObject
                    if ([string]::IsNullOrEmpty($source) -or $count -eq 0) {
                        return ''
                    }

                    if ($source.Length -le $count) {
                        return $source
                    }

                    return $source.Substring(0, $count)
                }
                '^(?i:replace)$' {
                    $source = Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[0] -UserObject $UserObject
                    $oldValue = Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[1] -UserObject $UserObject
                    $newValue = Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[2] -UserObject $UserObject

                    if ([string]::IsNullOrEmpty($source) -or [string]::IsNullOrEmpty($oldValue)) {
                        return $source
                    }

                    return $source.Replace($oldValue, $newValue)
                }
                '^(?i:remove)$' {
                    $source = Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[0] -UserObject $UserObject
                    $removeValue = Resolve-PamTemplateExpressionAst -Ast $Ast.Arguments[1] -UserObject $UserObject

                    if ([string]::IsNullOrEmpty($source) -or [string]::IsNullOrEmpty($removeValue)) {
                        return $source
                    }

                    return $source.Replace($removeValue, '')
                }
                default {
                    Stop-PamExecution -Message "Die Funktion '$($Ast.Name)' wird im Resolver nicht unterstuetzt."
                }
            }
        }
        default {
            Stop-PamExecution -Message "Der AST-Knotentyp '$($Ast.Kind)' wird im Resolver nicht unterstuetzt."
        }
    }
}

function Resolve-PamTemplateTokens {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Tokens,

        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    $resolvedTokens = New-Object System.Collections.Generic.List[object]

    foreach ($token in $Tokens) {
        if ($token.Type -eq 'Literal') {
            $resolvedValue = ConvertTo-PamTemplateScalarValue $token.Value
        }
        elseif ($token.Type -eq 'Expression') {
            $resolvedValue = Resolve-PamTemplateExpressionAst -Ast $token.Ast -UserObject $UserObject
        }
        else {
            Stop-PamExecution -Message "Der Token-Typ '$($token.Type)' wird im Resolver nicht unterstuetzt."
        }

        $resolvedTokens.Add([pscustomobject]@{
                Index = $token.Index
                Type = $token.Type
                RawText = $token.RawText
                ResolvedValue = $resolvedValue
            })
    }

    return $resolvedTokens.ToArray()
}

function Resolve-PamTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    Write-PamLog -Level 'Debug' -Message "Template wird aufgeloest: $Template"
    $tokens = Get-PamTemplateTokens -Template $Template
    $resolvedTokens = Resolve-PamTemplateTokens -Tokens $tokens -UserObject $UserObject

    Write-PamLog -Level 'Debug' -Message "Template erfolgreich aufgeloest: $Template"
    return [string]::Concat(@($resolvedTokens | ForEach-Object { $_.ResolvedValue }))
}

Export-ModuleMember -Function @(
    'Resolve-PamTemplate',
    'Resolve-PamTemplateExpressionAst',
    'Resolve-PamTemplateTokens'
)
