$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Engine\ProxyAddressManager.TemplateResolver.psm1'

Import-Module -Name $modulePath -Force

Describe 'Resolve-PamTemplateExpressionAst' {
    BeforeEach {
        $script:user = [pscustomobject]@{
            GivenName = 'Max'
            Surname = 'Mustermann'
            SamAccountName = 'mmustermann'
            DisplayName = 'Max Mustermann'
            department = 'Sales Team'
            EmptyValue = ''
        }
    }

    It 'resolves an attribute value from the user object' {
        $ast = [pscustomobject]@{
            Kind = 'Attribute'
            Name = 'GivenName'
        }

        $result = Resolve-PamTemplateExpressionAst -Ast $ast -UserObject $script:user

        $result | Should Be 'Max'
    }

    It 'resolves FirstN against a user property' {
        $ast = [pscustomobject]@{
            Kind = 'Function'
            Name = 'FirstN'
            Arguments = @(
                [pscustomobject]@{
                    Kind = 'NumberLiteral'
                    Value = 1
                },
                [pscustomobject]@{
                    Kind = 'Attribute'
                    Name = 'GivenName'
                }
            )
        }

        $result = Resolve-PamTemplateExpressionAst -Ast $ast -UserObject $script:user

        $result | Should Be 'M'
    }

    It 'resolves Replace with string literals' {
        $ast = [pscustomobject]@{
            Kind = 'Function'
            Name = 'Replace'
            Arguments = @(
                [pscustomobject]@{
                    Kind = 'Attribute'
                    Name = 'DisplayName'
                },
                [pscustomobject]@{
                    Kind = 'StringLiteral'
                    Value = ' '
                },
                [pscustomobject]@{
                    Kind = 'StringLiteral'
                    Value = '-'
                }
            )
        }

        $result = Resolve-PamTemplateExpressionAst -Ast $ast -UserObject $script:user

        $result | Should Be 'Max-Mustermann'
    }

    It 'resolves Remove with string literals' {
        $ast = [pscustomobject]@{
            Kind = 'Function'
            Name = 'Remove'
            Arguments = @(
                [pscustomobject]@{
                    Kind = 'Attribute'
                    Name = 'DisplayName'
                },
                [pscustomobject]@{
                    Kind = 'StringLiteral'
                    Value = ' '
                }
            )
        }

        $result = Resolve-PamTemplateExpressionAst -Ast $ast -UserObject $script:user

        $result | Should Be 'MaxMustermann'
    }

    It 'returns an empty string for missing or empty source values' {
        $missingAst = [pscustomobject]@{
            Kind = 'Attribute'
            Name = 'MissingProperty'
        }
        $emptyAst = [pscustomobject]@{
            Kind = 'Function'
            Name = 'FirstN'
            Arguments = @(
                [pscustomobject]@{
                    Kind = 'NumberLiteral'
                    Value = 1
                },
                [pscustomobject]@{
                    Kind = 'Attribute'
                    Name = 'EmptyValue'
                }
            )
        }

        (Resolve-PamTemplateExpressionAst -Ast $missingAst -UserObject $script:user) | Should Be ''
        (Resolve-PamTemplateExpressionAst -Ast $emptyAst -UserObject $script:user) | Should Be ''
    }
}

Describe 'Resolve-PamTemplateTokens and Resolve-PamTemplate' {
    BeforeEach {
        $script:user = [pscustomobject]@{
            GivenName = 'Max'
            Surname = 'Mustermann'
            SamAccountName = 'mmustermann'
            DisplayName = 'Max Mustermann'
        }
    }

    It 'resolves a tokenized template into resolved segments' {
        $tokens = @(
            [pscustomobject]@{
                Index = 0
                Type = 'Expression'
                RawText = '%GivenName%'
                Ast = [pscustomobject]@{
                    Kind = 'Attribute'
                    Name = 'GivenName'
                }
            },
            [pscustomobject]@{
                Index = 1
                Type = 'Literal'
                RawText = '.'
                Value = '.'
            },
            [pscustomobject]@{
                Index = 2
                Type = 'Expression'
                RawText = '%Surname%'
                Ast = [pscustomobject]@{
                    Kind = 'Attribute'
                    Name = 'Surname'
                }
            }
        )

        $resolvedTokens = Resolve-PamTemplateTokens -Tokens $tokens -UserObject $script:user

        @($resolvedTokens).Count | Should Be 3
        $resolvedTokens[0].ResolvedValue | Should Be 'Max'
        $resolvedTokens[1].ResolvedValue | Should Be '.'
        $resolvedTokens[2].ResolvedValue | Should Be 'Mustermann'
    }

    It 'resolves a full template to a final string' {
        $result = Resolve-PamTemplate -Template '%FirstN(1,GivenName)%.%Surname%@contoso.com' -UserObject $script:user

        $result | Should Be 'M.Mustermann@contoso.com'
    }

    It 'resolves SamAccountName directly' {
        $result = Resolve-PamTemplate -Template '%SamAccountName%' -UserObject $script:user

        $result | Should Be 'mmustermann'
    }
}
