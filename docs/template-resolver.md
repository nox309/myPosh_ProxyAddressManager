# Template-Resolver

Das sechste Inkrement loest die vom Tokenizer erzeugten Platzhalter und Funktionsausdruecke gegen Benutzerobjekte auf.

## Modul

- `src/Engine/ProxyAddressManager.TemplateResolver.psm1`

## Oeffentliche Funktionen

- `Resolve-PamTemplateExpressionAst`
- `Resolve-PamTemplateTokens`
- `Resolve-PamTemplate`

## Unterstuetzte Aufloesungen

- Attribute wie `GivenName`, `Surname`, `SamAccountName`
- `FirstN(anzahl, quelle)`
- `Replace(quelle, alt, neu)`
- `Remove(quelle, wert)`

## Verhalten

- Fehlende Attribute liefern aktuell einen leeren String.
- Leere Quellwerte propagieren als leerer String weiter.
- `Resolve-PamTemplate` tokenisiert intern und liefert den finalen zusammengebauten String zurueck.

## Beispiele

- `%GivenName%.%Surname%` -> `Max.Mustermann`
- `%FirstN(1,GivenName)%.%Surname%` -> `M.Mustermann`
- `%Replace(DisplayName,' ','-')%` -> `Max-Mustermann`
