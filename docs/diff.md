# Diff-Modell

Das dreizehnte Inkrement fuehrt ein echtes Ist/Soll-Diff fuer `mail` und `proxyAddresses` auf Basis des Preview-Modells ein.

## Modul

- `src/Engine/ProxyAddressManager.Diff.psm1`

## Oeffentliche Funktionen

- `New-PamRecipientDiff`

## Verhalten

- Das Diff arbeitet auf einem Preview-Objekt mit aktuellen und vorgeschlagenen Werten.
- `mail` wird case-insensitive verglichen.
- `proxyAddresses` werden als Mengen case-insensitive verglichen.
- In das vorgeschlagene Proxy-Set gehen sowohl die neu berechneten SMTP-Werte als auch die erhaltenen Nicht-SMTP-Werte ein.
- Das Diff liefert getrennt:
  - geaenderte Eigenschaften
  - Mail-Vorher/Nachher
  - Proxy-Vorher/Nachher
  - hinzugefuegte und entfernte Proxy-Werte
  - SMTP-spezifische Add/Remove-Listen

## Ziel fuer die naechsten Inkremente

- Inkrement 14 kann diese Diff-Daten direkt in die GUI binden.
- Damit wird die Read-only-Preview fuer echte Benutzer deutlich sichtbarer und praxisnaeher.
