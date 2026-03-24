# WPF-Grundgeruest

Das zweite Inkrement liefert eine lauffaehige WPF-Shell fuer das Tool. Die Fachlogik ist noch nicht angeschlossen; die Oberflaeche zeigt bewusst Platzhalter, damit Layout, Startpfad und Datenbindung frueh stabilisiert werden koennen.

## Bestandteile

- `src/Gui/MainWindow.xaml` definiert das Hauptfenster.
- `src/Gui/ProxyAddressManager.Gui.psm1` laedt die XAML-Datei, verbindet Startdaten und zeigt das Fenster an.
- `ProxyAddressManager.ps1` startet nach dem Bootstrap direkt die GUI.

## Aktuelle Bereiche

- Kopfbereich mit App-Status
- Sitzungsleiste mit spaeteren Aktionsbuttons
- linke Spalte fuer Konfiguration und Bootstrap-Module
- obere rechte Flaeche fuer die Benutzerliste
- untere rechte Flaeche fuer die Preview

## Smoke-Test

Fuer eine schnelle technische Validierung ohne sichtbaren Dialog kann die Shell mit folgendem Startparameter geladen werden:

```powershell
.\ProxyAddressManager.ps1 -SkipModulePreflight -SmokeTestGui
```

Dabei wird die XAML-Datei geladen, das Fensterobjekt aufgebaut und direkt wieder geschlossen.
