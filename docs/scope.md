# Scope-Auswertung

Das zehnte Inkrement fuehrt die deterministische Scope-Auswertung fuer Regeln ein.

## Modul

- `src/Engine/ProxyAddressManager.Scope.psm1`

## Oeffentliche Funktionen

- `Test-PamScopeAttributeFilter`
- `Test-PamRecipientScope`

## Semantik

- Zwischen den Scope-Dimensionen `organizationalUnits`, `groups` und `attributeFilters` gilt ein logisches AND.
- Innerhalb von `organizationalUnits` gilt OR: eine passende OU reicht.
- Innerhalb von `groups` gilt OR: eine direkte Gruppenmitgliedschaft reicht.
- Innerhalb von `attributeFilters` gilt AND: alle Filter muessen passen.
- Leere Scope-Dimensionen schraenken den Match nicht ein.

## Unterstuetzte Attributoperatoren

- `eq`
- `ne`
- `contains`
- `startswith`
- `endswith`

## Gruppenlogik

- V1 arbeitet nur mit direkter Gruppenmitgliedschaft.
- Bevorzugt wird `MemberOf`; wenn diese Eigenschaft fehlt, wird auf `Groups` als einfache Fallback-Liste geschaut.

## Ziel fuer die naechsten Inkremente

- Inkrement 11 kann jetzt die erste passende aktive Regel nach Prioritaet bestimmen.
- Zusammen mit Inkrement 12 wird daraus die erste echte read-only Preview gegen AD-Benutzer und eigene Regeln.
