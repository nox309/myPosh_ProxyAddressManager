# Template-Tokenizer

Das fuenfte Inkrement fuehrt den ersten Parser fuer Adress-Templates ein. Er zerlegt Template-Strings in Literale und Ausdrucks-Tokens und erstellt fuer Platzhalter eine kleine AST-Struktur.

## Modul

- `src/Engine/ProxyAddressManager.TemplateTokenizer.psm1`

## Unterstuetzte Ausdrucksformen

- Attributplatzhalter:
  - `%GivenName%`
  - `%Surname%`
  - `%SamAccountName%`
- Funktionsausdruecke:
  - `%FirstN(1,GivenName)%`
  - `%Replace(Surname,' ','-')%`
  - `%Remove(DisplayName,'.')%`

## Ergebnisform

- Literal-Token enthalten:
  - `Type = Literal`
  - `Value`
- Ausdrucks-Token enthalten:
  - `Type = Expression`
  - `ExpressionText`
  - `Ast`

## Oeffentliche Funktionen

- `Get-PamTemplateTokens`
- `ConvertTo-PamTemplateExpressionAst`

## AST-Knoten

- `Attribute`
- `Function`
- `NumberLiteral`
- `StringLiteral`

## Hinweis

Der Tokenizer prueft aktuell Syntax, unterstuetzte Funktionsnamen und Argumentanzahl. Die eigentliche Aufloesung gegen Benutzerdaten folgt erst im naechsten Inkrement mit dem Resolver.
