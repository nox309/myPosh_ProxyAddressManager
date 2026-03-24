# Active-Directory-Provider

Das neunte Inkrement fuehrt einen read-only Recipient-Provider fuer `Get-ADUser` ein, damit echte AD-Daten in spaeteren Preview-Schritten gelesen werden koennen, ohne Schreiboperationen auszufuehren.

## Modul

- `src/Directory/ProxyAddressManager.ActiveDirectory.psm1`

## Oeffentliche Funktionen

- `Get-PamActiveDirectoryProviderCallbacks`
- `Assert-PamActiveDirectoryCommandAvailable`
- `Resolve-PamAdPropertyList`
- `New-PamAdUserQueryParameters`
- `ConvertFrom-PamAdRecipient`
- `New-PamActiveDirectoryRecipientProvider`

## Verhalten

- Der Provider arbeitet read-only und nutzt ausschliesslich `Get-ADUser`.
- Wenn `Get-ADUser` noch nicht verfuegbar ist, versucht das Modul zuerst `Import-Module ActiveDirectory`.
- Wenn das AD-Modul fehlt, wird mit einer klaren Handlungsanweisung abgebrochen.
- Ergebnisse werden auf plain `PSCustomObject`-Recipients reduziert, damit die Engine spaeter nicht direkt an AD-spezifische Objekte gebunden ist.
- Standardmaessig werden die Kernfelder `DistinguishedName`, `GivenName`, `Surname`, `SamAccountName`, `Department`, `Mail`, `ProxyAddresses`, `UserPrincipalName` und `Enabled` geladen.

## Query-Modell

- `Identity` fuer den Einzelabruf
- `Filter` oder `LDAPFilter` fuer Listenabfragen
- `SearchBase`
- `SearchScope`
- `ResultSetSize`
- `Server`

## Ziel fuer die naechsten Inkremente

- Inkrement 10 kann auf derselben Recipient-Menge die Scope-Auswertung gegen OU, Gruppen und Attribute aufsetzen.
- Eigene Regeln gegen echtes AD werden fachlich sinnvoll, sobald nach Scope und Regelzuordnung auch die Preview-Berechnung steht.
