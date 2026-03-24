$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.TemplateTokenizer.psm1'

Import-Module -Name $modulePath -Force

Describe 'Get-PamTemplateTokens' {
    It 'tokenizes simple attribute placeholders and literals' {
        $tokens = Get-PamTemplateTokens -Template '%GivenName%.%Surname%'

        @($tokens).Count | Should Be 3
        $tokens[0].Type | Should Be 'Expression'
        $tokens[0].Ast.Kind | Should Be 'Attribute'
        $tokens[0].Ast.Name | Should Be 'GivenName'
        $tokens[1].Type | Should Be 'Literal'
        $tokens[1].Value | Should Be '.'
        $tokens[2].Ast.Name | Should Be 'Surname'
    }

    It 'tokenizes function expressions inside a full address template' {
        $tokens = Get-PamTemplateTokens -Template '%FirstN(1, GivenName)%.%Surname%@contoso.com'

        @($tokens).Count | Should Be 4
        $tokens[0].Ast.Kind | Should Be 'Function'
        $tokens[0].Ast.Name | Should Be 'FirstN'
        $tokens[0].Ast.Arguments[0].Kind | Should Be 'NumberLiteral'
        $tokens[0].Ast.Arguments[0].Value | Should Be 1
        $tokens[0].Ast.Arguments[1].Kind | Should Be 'Attribute'
        $tokens[0].Ast.Arguments[1].Name | Should Be 'GivenName'
        $tokens[3].Value | Should Be '@contoso.com'
    }

    It 'throws for an unclosed placeholder' {
        $didThrow = $false
        $message = $null

        try {
            $null = Get-PamTemplateTokens -Template '%GivenName'
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'nicht geschlossenen Platzhalter'
    }
}

Describe 'ConvertTo-PamTemplateExpressionAst' {
    It 'parses Replace with string literals' {
        $ast = ConvertTo-PamTemplateExpressionAst -Expression "Replace(Surname,' ','-')"

        $ast.Kind | Should Be 'Function'
        $ast.Name | Should Be 'Replace'
        @($ast.Arguments).Count | Should Be 3
        $ast.Arguments[0].Kind | Should Be 'Attribute'
        $ast.Arguments[0].Name | Should Be 'Surname'
        $ast.Arguments[1].Kind | Should Be 'StringLiteral'
        $ast.Arguments[1].Value | Should Be ' '
        $ast.Arguments[2].Value | Should Be '-'
    }

    It 'parses Remove with an attribute and string literal' {
        $ast = ConvertTo-PamTemplateExpressionAst -Expression "Remove(DisplayName,'.')"

        $ast.Kind | Should Be 'Function'
        $ast.Name | Should Be 'Remove'
        $ast.Arguments[0].Name | Should Be 'DisplayName'
        $ast.Arguments[1].Value | Should Be '.'
    }

    It 'throws for unsupported functions' {
        $didThrow = $false
        $message = $null

        try {
            $null = ConvertTo-PamTemplateExpressionAst -Expression 'Unknown(GivenName)'
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'nicht unterstuetzt'
    }

    It 'throws for invalid function arity' {
        $didThrow = $false
        $message = $null

        try {
            $null = ConvertTo-PamTemplateExpressionAst -Expression 'FirstN(1)'
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'erwartet 2 Argument'
    }

    It 'throws for unclosed string literals' {
        $didThrow = $false
        $message = $null

        try {
            $null = ConvertTo-PamTemplateExpressionAst -Expression "Replace(Surname,' ','-)"
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }

        $didThrow | Should Be $true
        $message | Should Match 'nicht geschlossen'
    }
}
