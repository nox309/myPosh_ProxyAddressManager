# Bootstrap und Modul-Preflight

Der aktuelle Stand setzt das erste Inkrement aus dem Root-Plan um: Beim Start der App werden alle externen PowerShell-Module geprueft, die spaeter aktiv durch die Anwendung geladen werden.

Die Bootstrap-Schicht ist bewusst allgemeingueltig aufgebaut und nicht auf das aktuelle Entwicklungssystem zugeschnitten. Welche Module geprueft werden, bestimmt allein die Konfiguration unter `config/appsettings.json`.

## Verhalten

- `ProxyAddressManager.ps1` laedt zuerst `src/Bootstrap/ProxyAddressManager.Bootstrap.psm1` und danach die GUI-Schicht.
- Vor dem eigentlichen Modul-Preflight werden Windows sowie PowerShell 7 als Laufzeitvoraussetzungen geprueft.
- Danach wird `config/appsettings.json` eingelesen.
- Alle Eintraege unter `bootstrap.moduleRequirements` mit `requiredAtStartup = true` werden der Reihe nach geprueft.
- Das Logging-Modul wird immer zuerst behandelt.
- Fehlt ein per PSGallery installierbares Modul, fragt die App aktiv nach einer Installation fuer `CurrentUser`.
- Fehlen die Befehle `Find-PSResource` oder `Install-PSResource`, bricht die App mit einem klaren Hinweis auf `Microsoft.PowerShell.PSResourceGet` ab.
- Fehlt ein Modul mit `Manual`-Strategie, bricht die App mit einer klaren Handlungsanweisung ab.
- Es gibt bewusst keinen stillen Fallback.

## Aktuell hinterlegte Startmodule

- `myPosh_write-log` / `myPosh_Write-Log`
- `ActiveDirectory`

## Lokaler Plan

Die Datei `PLAN.md` im Repository-Root ist die lokale Arbeitsplanung fuer weitere Sessions. Sie ist absichtlich in `.gitignore` eingetragen, damit sie im Repo verfuegbar bleibt, aber nicht versehentlich committed wird.
