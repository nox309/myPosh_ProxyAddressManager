# WPF-GUI

Die GUI ist inzwischen ueber das reine Shell-Stadium hinaus und zeigt jetzt konfigurierte Beispieldaten, Regelzuordnung und Read-only-Preview direkt im Fenster an.

## Bestandteile

- `src/Gui/MainWindow.xaml` definiert das Hauptfenster.
- `src/Gui/ProxyAddressManager.Gui.psm1` laedt die XAML-Datei, verbindet Konfiguration, Beispielbenutzer, Regeln und Preview-Engine und zeigt das Fenster an.
- `ProxyAddressManager.ps1` startet nach dem Bootstrap direkt die GUI.

## Aktuelle Bereiche und Datenbindung

- Kopfbereich mit App-Status
- Sitzungsleiste mit `Benutzer laden` und `Preview aktualisieren`
- linke Spalte fuer Konfiguration und Bootstrap-Module
- obere rechte Flaeche fuer die Benutzerliste mit Regelstatus
- untere rechte Flaeche fuer die Preview mit aktueller Mail, vorgeschlagener Mail und Aenderungszusammenfassung

## Aktuelles Ladeverhalten

- Die GUI liest `config/appsettings.json`.
- Regeln werden aus der konfigurierten `rules.json` geladen.
- Benutzer werden aktuell aus der konfigurierten Beispieldatei geladen.
- Fuer jeden Benutzer werden Regelzuordnung, Preview und Diff berechnet und direkt im DataGrid angezeigt.
- Wenn das Laden fehlschlaegt, bleibt die GUI startfaehig und zeigt den Fehler im Statusbereich an.

## Smoke-Test

Fuer eine schnelle technische Validierung ohne sichtbaren Dialog kann die Shell mit folgendem Startparameter geladen werden:

```powershell
.\ProxyAddressManager.ps1 -SkipModulePreflight -SmokeTestGui
```

Dabei wird die XAML-Datei geladen, das Fensterobjekt aufgebaut und direkt wieder geschlossen.
