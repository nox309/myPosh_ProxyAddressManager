# Directory-Abstraktion

Das achte Inkrement fuehrt eine kleine Recipient-Provider-Abstraktion ein, damit die Engine spaeter nicht direkt an `Get-ADUser` gekoppelt ist.

## Modul

- `src/Directory/ProxyAddressManager.Directory.psm1`

## Oeffentliche Funktionen

- `New-PamRecipientProvider`
- `Assert-PamRecipientProvider`
- `Get-PamRecipients`
- `Get-PamRecipientByIdentity`
- `New-PamMockRecipientProvider`

## Provider-Vertrag

- Jeder Provider besitzt einen `Name`.
- `GetRecipients` liefert eine Recipient-Menge fuer die Engine.
- `GetRecipientByIdentity` liefert genau einen Recipient oder `$null`.
- `Metadata` kann provider-spezifische Informationen wie Typ, Identity-Feld oder Anzahl enthalten.

## Mock-Provider

- Der Mock-Provider arbeitet auf einer In-Memory-Liste von Benutzern.
- Standard-Identity ist `SamAccountName`.
- Optional kann ein `FilterScript` in der Query uebergeben werden, damit spaetere Engine-Tests gezielt Teilmengen aus dem Datensatz ziehen koennen.

## Ziel fuer die naechsten Inkremente

- Inkrement 9 kann darauf einen read-only Active-Directory-Provider aufsetzen.
- Scope-Auswertung, Regelzuordnung und Preview koennen denselben Vertrag in Unit-Tests gegen den Mock-Provider verwenden.
