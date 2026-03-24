# Normalisierung

Das siebte Inkrement fuegt eine eigene Pipeline fuer den E-Mail-Local-Part hinzu, damit Template-Ergebnisse konsistent bereinigt werden koennen.

## Modul

- `src/Engine/ProxyAddressManager.Normalization.psm1`

## Oeffentliche Funktionen

- `ConvertTo-PamNormalizedAddressLocalPart`

## Verhalten

- Die Funktion arbeitet auf dem Local-Part vor dem spaeteren Domain-Anbau.
- Deutsche Umlaute und `ß` koennen nach den Regel-Flags explizit ersetzt werden.
- Separatoren wie Leerzeichen, Unterstriche, Slash, Backslash, Komma, Semikolon und Doppelpunkt werden bei aktivierter Bereinigung auf Punkte vereinheitlicht.
- Nicht erlaubte Zeichen werden entfernt, waehrend Buchstaben, Ziffern, Punkt und Bindestrich erhalten bleiben.
- Mehrfachpunkte koennen zusammengezogen und fuehrende oder endende Punkte entfernt werden.
- Wenn `replaceUmlauts` deaktiviert ist, werden Akzentzeichen vor dem Entfernen ungueltiger Zeichen auf ihre ASCII-Basis zurueckgefuehrt.

## Beispiel

- `Jörg__Müller / Vertrieb..Team` -> `joerg.mueller.vertrieb.team`
