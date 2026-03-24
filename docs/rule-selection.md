# Regelzuordnung

Das elfte Inkrement fuehrt die erste deterministische Regelzuordnung fuer einen Recipient ein.

## Modul

- `src/Engine/ProxyAddressManager.RuleSelection.psm1`

## Oeffentliche Funktionen

- `Get-PamSortedRules`
- `Test-PamRuleIsEnabled`
- `Test-PamRuleMatch`
- `Select-PamApplicableRule`

## Semantik

- Regeln werden aufsteigend nach `priority` ausgewertet.
- Deaktivierte Regeln werden nie ausgewaehlt.
- Die erste aktive Regel mit positivem Scope-Match gewinnt.
- Wenn keine aktive Regel matcht, wird kein Treffer geliefert.

## Rueckgabe von `Select-PamApplicableRule`

- `SelectedRule`
- `SelectedRuleName`
- `SelectedPriority`
- `SelectionReason`
- `Evaluation`
- `RuleEvaluations`

## Ziel fuer die naechsten Inkremente

- Inkrement 12 kann jetzt aus der gewaehlten Regel die erste echte Preview fuer primaere SMTP-Adresse und Aliasliste berechnen.
- Zusammen mit dem vorhandenen AD-Read-Provider ist damit der naechste grosse Meilenstein fuer erste echte Read-only-Regeltests in Sicht.
