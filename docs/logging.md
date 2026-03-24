# Logging

Die Anwendung verwendet jetzt eine gemeinsame Logging-Schicht in `src/Bootstrap/ProxyAddressManager.Logging.psm1`.

## Ziele

- Log-Level fuer Datei und Konsole getrennt steuern
- vor jedem `throw` zuerst einen `Error`-Log schreiben
- Konsolenausgabe auf Key-Informationen begrenzen
- vorhandenes `Write-Log`-Modul weiter nutzen, wenn es verfuegbar ist

## Aktuelles Verhalten

- Die App schreibt immer in eine lokale Logdatei.
- Standardpfad:
  - `output/logs/ProxyAddressManager.log`
- Wenn das externe Modul `myPosh_write-log` bereits verfuegbar ist, werden Eintraege optional dorthin gespiegelt.
- Die Konsole zeigt nur Meldungen ab `consoleMinimumLevel`.
- Die Datei bekommt Meldungen ab `fileMinimumLevel`.

## Konfiguration

`config/appsettings.json` enthaelt jetzt einen Abschnitt `logging`:

```json
"logging": {
  "path": "output/logs/ProxyAddressManager.log",
  "fileMinimumLevel": "Debug",
  "consoleMinimumLevel": "Information",
  "mirrorToWriteLog": true
}
```

## Verwendete Levels

- `Debug`
- `Information`
- `Warning`
- `Error`

## Oeffentliche Funktionen

- `Initialize-PamLogging`
- `Set-PamLoggingConfiguration`
- `Write-PamLog`
- `Stop-PamExecution`
