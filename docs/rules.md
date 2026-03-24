# Regeldatei

Das vierte Inkrement fuehrt einen eigenen Loader fuer `config/rules.json` ein. Die Datei wird frueh validiert, damit fehlerhafte Richtlinien nicht erst spaeter in GUI oder Engine auffallen.

## Validierung

- `schemaVersion` muss vorhanden sein.
- `rules` muss vorhanden sein.
- Jede Regel braucht die Basisfelder fuer:
  - Name
  - enabled
  - priority
  - scope
  - primaryAddressTemplate
  - aliasTemplates
  - domainRules.primaryDomain
  - normalizationRules
  - overrides
- Prioritaeten muessen eindeutig sein.

## Modul

- `src/Configuration/ProxyAddressManager.Rules.psm1`

## Standarddatei

- `config/rules.json` enthaelt jetzt eine erste gueltige Beispielregel als lokales Start- und Test-Setup.
