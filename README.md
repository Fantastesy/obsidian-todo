# Obsidian Todo

Eine Todo-Liste für den Windows-Desktop, die direkt als Markdown in deinem [Obsidian](https://obsidian.md)-Vault gespeichert wird. Angezeigt wird sie mit [Rainmeter](https://www.rainmeter.net).

- Punkte abhaken, bearbeiten, löschen – alles landet als normale Obsidian-Checkbox (`- [ ] …`) in `Todo.md`
- Fälligkeitsdatum, Uhrzeit mit Windows-Erinnerung („Erledigt“ / „In 15 Min nochmal“)
- Wiederkehrende Punkte (täglich, werktags, wöchentlich, monatlich, individuell)
- Notizen, Links, Dateien und Unteraufgaben pro Punkt
- Archiv für erledigte Punkte (`Todo-Archiv.md`)
- Tastenkürzel **Strg+Alt+T** (bzw. Win+Shift+T) für einen neuen Punkt, von überall – Enter speichert sofort

## Installation

1. `ObsidianTodo-Setup.exe` aus den [Releases](../../releases/latest) herunterladen und starten.
2. Speicherort wählen, Vault auswählen (oder neuen anlegen) – fertig.

Der Installer
- installiert Rainmeter mit, falls es fehlt (offizielle Version, fragt einmal nach Adminrechten),
- installiert auf Wunsch Obsidian mit,
- findet vorhandene Vaults und eine vorhandene `Todo.md` und verwendet sie weiter,
- funktioniert auch mit portablem Rainmeter.

Windows zeigt beim ersten Start evtl. „Der Computer wurde durch Windows geschützt“, weil das Setup nicht kostenpflichtig signiert ist: **Weitere Informationen → Trotzdem ausführen**.

## Updates

Die Liste prüft beim Start und danach alle 6 Stunden, ob es ein neues Release gibt, und aktualisiert sich dann selbst im Hintergrund. Die SHA-256-Prüfsumme des Downloads wird dabei kontrolliert. Einstellungen und Todo-Liste bleiben erhalten.

## Deinstallation

Über Windows-Einstellungen → Apps. `Todo.md` und `Todo-Archiv.md` in deinem Vault bleiben erhalten.

## Selbst bauen

Voraussetzungen: Windows 10/11, [Inno Setup 7](https://jrsoftware.org/isinfo.php).

```powershell
powershell -File build.ps1            # -> dist\ObsidianTodo-Setup.exe
```

| Ordner | Inhalt |
|---|---|
| `src/build-skin.ps1` | erzeugt die Rainmeter-Dateien (`Todo.ini`, Formular, Hilfe) |
| `src/todo.lua`, `src/form.lua` | Logik der Liste und des Formulars |
| `src/hotkey.cs` | kleines Programm für das globale Tastenkürzel |
| `src/notify.ps1`, `src/toast-action.vbs` | Windows-Erinnerungen und deren Knöpfe |
| `src/update.ps1` | automatische Updates über GitHub-Releases |
| `installer/` | Inno-Setup-Skript und Hilfsskript für Erkennung/Einrichtung |

Für ein Release: Version in `VERSION` erhöhen, `build.ps1 -Repo <besitzer>/<repo>` ausführen, Release mit Tag `v<VERSION>` anlegen und `dist\ObsidianTodo-Setup.exe` anhängen.

## Lizenz

MIT – siehe [LICENSE](LICENSE). Rainmeter (GPL-2.0) und Obsidian werden nicht mitgeliefert, sondern bei Bedarf von den offiziellen Quellen geladen.
