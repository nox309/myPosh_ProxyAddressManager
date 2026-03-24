# App-Konfiguration

Das dritte Inkrement fuehrt einen zentralen Loader fuer `config/appsettings.json` ein. Damit werden App-Settings nicht mehr mehrfach direkt aus JSON gelesen, sondern einmal validiert und fuer Bootstrap sowie GUI aufbereitet.

## Verhalten

- `src/Configuration/ProxyAddressManager.Configuration.psm1` ist die zentrale Schicht fuer `appsettings.json`.
- Relative Pfade aus dem Abschnitt `paths` werden immer gegen den App-Root aufgeloest.
- Der Loader ergaenzt die geladenen Daten um:
  - `appRoot`
  - `configPath`
  - `resolvedPaths`

## Aktuelle Pfade

- `rulesConfiguration`
- `defaultExportDirectory`
- `sampleUsersFile`
- `sampleRulesFile`

## Ziel

Weitere Inkremente sollen nur noch mit dem validierten Konfigurationsobjekt arbeiten und keine Dateipfade mehr ad hoc zusammensetzen.
