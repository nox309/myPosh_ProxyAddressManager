Set-StrictMode -Version Latest

$loggingModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Bootstrap\ProxyAddressManager.Logging.psm1'
Import-Module -Name $loggingModulePath -Force

function New-PamTemplateNode {
    param(
        [Parameter(Mandatory)]
        [string]$Kind,

        [hashtable]$Properties
    )

    $node = [ordered]@{
        Kind = $Kind
    }

    if ($null -ne $Properties) {
        foreach ($key in $Properties.Keys) {
            $node[$key] = $Properties[$key]
        }
    }

    return [pscustomobject]$node
}

function Skip-PamTemplateWhitespace {
    param(
        [Parameter(Mandatory)]
        [string]$Expression,

        [Parameter(Mandatory)]
        [ref]$Position
    )

    while ($Position.Value -lt $Expression.Length -and [char]::IsWhiteSpace($Expression[$Position.Value])) {
        $Position.Value++
    }
}

function Read-PamTemplateIdentifier {
    param(
        [Parameter(Mandatory)]
        [string]$Expression,

        [Parameter(Mandatory)]
        [ref]$Position
    )

    if ($Position.Value -ge $Expression.Length) {
        Stop-PamExecution -Message 'Es wurde ein Bezeichner erwartet, aber das Ausdrucksende wurde erreicht.'
    }

    $start = $Position.Value
    $firstCharacter = $Expression[$Position.Value]
    if (-not ([char]::IsLetter($firstCharacter) -or $firstCharacter -eq '_')) {
        Stop-PamExecution -Message "Ungueltiger Beginn eines Bezeichners an Position $($Position.Value + 1): '$firstCharacter'"
    }

    $Position.Value++
    while ($Position.Value -lt $Expression.Length) {
        $character = $Expression[$Position.Value]
        if (-not ([char]::IsLetterOrDigit($character) -or $character -eq '_')) {
            break
        }

        $Position.Value++
    }

    return $Expression.Substring($start, $Position.Value - $start)
}

function Read-PamTemplateNumberLiteral {
    param(
        [Parameter(Mandatory)]
        [string]$Expression,

        [Parameter(Mandatory)]
        [ref]$Position
    )

    $start = $Position.Value
    while ($Position.Value -lt $Expression.Length -and [char]::IsDigit($Expression[$Position.Value])) {
        $Position.Value++
    }

    $valueText = $Expression.Substring($start, $Position.Value - $start)
    return (New-PamTemplateNode -Kind 'NumberLiteral' -Properties @{
            Value = [int]$valueText
            RawText = $valueText
        })
}

function Read-PamTemplateStringLiteral {
    param(
        [Parameter(Mandatory)]
        [string]$Expression,

        [Parameter(Mandatory)]
        [ref]$Position
    )

    $start = $Position.Value
    $builder = [System.Text.StringBuilder]::new()
    $Position.Value++

    while ($Position.Value -lt $Expression.Length) {
        $character = $Expression[$Position.Value]
        if ($character -eq "'") {
            if (($Position.Value + 1) -lt $Expression.Length -and $Expression[$Position.Value + 1] -eq "'") {
                [void]$builder.Append("'")
                $Position.Value += 2
                continue
            }

            $Position.Value++
            $rawText = $Expression.Substring($start, $Position.Value - $start)
            return (New-PamTemplateNode -Kind 'StringLiteral' -Properties @{
                    Value = $builder.ToString()
                    RawText = $rawText
                })
        }

        [void]$builder.Append($character)
        $Position.Value++
    }

    Stop-PamExecution -Message 'Eine Zeichenkette wurde begonnen, aber nicht geschlossen.'
}

function Get-PamSupportedTemplateFunctionMetadata {
    return @{
        'firstn' = 2
        'replace' = 3
        'remove' = 2
    }
}

function Parse-PamTemplateAstNode {
    param(
        [Parameter(Mandatory)]
        [string]$Expression,

        [Parameter(Mandatory)]
        [ref]$Position
    )

    Skip-PamTemplateWhitespace -Expression $Expression -Position $Position

    if ($Position.Value -ge $Expression.Length) {
        Stop-PamExecution -Message 'Unerwartetes Ausdrucksende.'
    }

    $currentCharacter = $Expression[$Position.Value]

    if ([char]::IsDigit($currentCharacter)) {
        return (Read-PamTemplateNumberLiteral -Expression $Expression -Position $Position)
    }

    if ($currentCharacter -eq "'") {
        return (Read-PamTemplateStringLiteral -Expression $Expression -Position $Position)
    }

    $identifier = Read-PamTemplateIdentifier -Expression $Expression -Position $Position
    Skip-PamTemplateWhitespace -Expression $Expression -Position $Position

    if ($Position.Value -lt $Expression.Length -and $Expression[$Position.Value] -eq '(') {
        $functionMetadata = Get-PamSupportedTemplateFunctionMetadata
        $functionKey = $identifier.ToLowerInvariant()
        if (-not $functionMetadata.ContainsKey($functionKey)) {
            Stop-PamExecution -Message "Die Template-Funktion '$identifier' wird nicht unterstuetzt."
        }

        $Position.Value++
        $arguments = @()
        Skip-PamTemplateWhitespace -Expression $Expression -Position $Position

        if ($Position.Value -lt $Expression.Length -and $Expression[$Position.Value] -eq ')') {
            $Position.Value++
        }
        else {
            while ($true) {
                $arguments += Parse-PamTemplateAstNode -Expression $Expression -Position $Position
                Skip-PamTemplateWhitespace -Expression $Expression -Position $Position

                if ($Position.Value -ge $Expression.Length) {
                    Stop-PamExecution -Message "Die Funktion '$identifier' wurde nicht korrekt geschlossen."
                }

                if ($Expression[$Position.Value] -eq ',') {
                    $Position.Value++
                    continue
                }

                if ($Expression[$Position.Value] -eq ')') {
                    $Position.Value++
                    break
                }

                Stop-PamExecution -Message "Unerwartetes Zeichen in der Argumentliste von '$identifier' an Position $($Position.Value + 1)."
            }
        }

        $expectedArgumentCount = [int]$functionMetadata[$functionKey]
        if ($arguments.Count -ne $expectedArgumentCount) {
            Stop-PamExecution -Message "Die Template-Funktion '$identifier' erwartet $expectedArgumentCount Argument(e), erhalten wurden $($arguments.Count)."
        }

        return (New-PamTemplateNode -Kind 'Function' -Properties @{
                Name = $identifier
                Arguments = @($arguments)
            })
    }

    return (New-PamTemplateNode -Kind 'Attribute' -Properties @{
            Name = $identifier
        })
}

function ConvertTo-PamTemplateExpressionAst {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Expression
    )

    if ([string]::IsNullOrWhiteSpace($Expression)) {
        Stop-PamExecution -Message 'Ein Template-Ausdruck darf nicht leer sein.'
    }

    Write-PamLog -Level 'Debug' -Message "Template-Ausdruck wird geparst: $Expression"
    $position = 0
    $node = Parse-PamTemplateAstNode -Expression $Expression -Position ([ref]$position)
    Skip-PamTemplateWhitespace -Expression $Expression -Position ([ref]$position)

    if ($position -ne $Expression.Length) {
        Stop-PamExecution -Message "Der Template-Ausdruck enthaelt unerwarteten Resttext ab Position $($position + 1)."
    }

    return $node
}

function Get-PamTemplateTokens {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template
    )

    if ([string]::IsNullOrWhiteSpace($Template)) {
        Stop-PamExecution -Message 'Ein Template darf nicht leer sein.'
    }

    Write-PamLog -Level 'Debug' -Message "Template wird tokenisiert: $Template"
    $tokens = New-Object System.Collections.Generic.List[object]
    $literalBuilder = [System.Text.StringBuilder]::new()
    $position = 0
    $tokenIndex = 0

    while ($position -lt $Template.Length) {
        $character = $Template[$position]

        if ($character -eq '%') {
            if ($literalBuilder.Length -gt 0) {
                $tokens.Add([pscustomobject]@{
                        Index = $tokenIndex
                        Type = 'Literal'
                        RawText = $literalBuilder.ToString()
                        Value = $literalBuilder.ToString()
                    })
                $tokenIndex++
                $literalBuilder.Clear() | Out-Null
            }

            $closingPosition = $Template.IndexOf('%', $position + 1)
            if ($closingPosition -lt 0) {
                Stop-PamExecution -Message "Das Template enthaelt einen nicht geschlossenen Platzhalter ab Position $($position + 1)."
            }

            $expressionText = $Template.Substring($position + 1, $closingPosition - $position - 1)
            if ([string]::IsNullOrWhiteSpace($expressionText)) {
                Stop-PamExecution -Message "Das Template enthaelt einen leeren Platzhalter an Position $($position + 1)."
            }

            $tokens.Add([pscustomobject]@{
                    Index = $tokenIndex
                    Type = 'Expression'
                    RawText = $Template.Substring($position, $closingPosition - $position + 1)
                    ExpressionText = $expressionText
                    Ast = ConvertTo-PamTemplateExpressionAst -Expression $expressionText
                })
            $tokenIndex++
            $position = $closingPosition + 1
            continue
        }

        [void]$literalBuilder.Append($character)
        $position++
    }

    if ($literalBuilder.Length -gt 0) {
        $tokens.Add([pscustomobject]@{
                Index = $tokenIndex
                Type = 'Literal'
                RawText = $literalBuilder.ToString()
                Value = $literalBuilder.ToString()
            })
    }

    Write-PamLog -Level 'Debug' -Message "Template erfolgreich tokenisiert: $Template"
    return $tokens.ToArray()
}

Export-ModuleMember -Function @(
    'ConvertTo-PamTemplateExpressionAst',
    'Get-PamTemplateTokens'
)
