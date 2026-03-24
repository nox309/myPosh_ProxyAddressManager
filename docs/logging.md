# Logging

Die Anwendung verwendet jetzt eine duenne Integrationsschicht in `src/Bootstrap/ProxyAddressManager.Logging.psm1`, die auf das externe Modul `myPosh_write-log` bzw. dessen `Write-Log`-Funktion aufsetzt.

## Ziele

- Log-Level fuer `Write-Log` und Konsole getrennt steuern
- vor jedem `throw` zuerst einen `Error`-Log schreiben
- Konsolenausgabe auf Key-Informationen begrenzen
- `Write-Log` direkt nutzen statt eine eigene Logging-Implementierung zu bauen

## Aktuelles Verhalten

- Die App uebergibt Logs an `Write-Log`, sobald das Modul verfuegbar ist.
- Die eigentliche Dateiablage bleibt damit beim externen Modul und wird nicht von der App selbst nachgebaut.
- Die Konsole zeigt nur Meldungen ab `consoleMinimumLevel`.
- `fileMinimumLevel` steuert, ab welchem Level die App `Write-Log` ueberhaupt aufruft.

## Konfiguration

`config/appsettings.json` enthaelt jetzt einen Abschnitt `logging`:

```json
"logging": {
  "fileMinimumLevel": "Debug",
  "consoleMinimumLevel": "Information"
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
