# Obsidian To-do

Eine Todo-Liste für den Desktop, die direkt als Markdown in deinem [Obsidian](https://obsidian.md)-Vault gespeichert wird – unter **Windows** mit [Rainmeter](https://www.rainmeter.net), unter **Linux** als Widget für **KDE Plasma 6**. Beide nutzen dasselbe Dateiformat, dieselbe `Todo.md` funktioniert also auf beiden Systemen.


- Punkte abhaken, bearbeiten, löschen – alles landet als normale Obsidian-Checkbox (`- [ ] …`) in `Todo.md`
- Fälligkeitsdatum, Uhrzeit mit Windows-Erinnerung („Erledigt“ / „In 15 Min nochmal“)
- Wiederkehrende Punkte (täglich, werktags, wöchentlich, monatlich, individuell)
- Notizen, Links, Dateien und Unteraufgaben pro Punkt
- Archiv für erledigte Punkte (`Todo-Archiv.md`)
- Tastenkürzel für einen neuen Punkt, von überall – Enter speichert sofort (Windows: **Strg+Alt+T** bzw. Win+Shift+T, KDE: **Meta+Shift+T**)

## Installation unter Windows

1. `ObsidianTodo-Setup-<version>.exe` aus den [Releases](../../releases/latest) herunterladen und starten.
2. Speicherort wählen, Vault auswählen (oder neuen anlegen) – fertig.

Der Installer
- installiert Rainmeter mit, falls es fehlt (offizielle Version, fragt einmal nach Adminrechten),
- installiert auf Wunsch Obsidian mit,
- findet vorhandene Vaults und eine vorhandene `Todo.md` und verwendet sie weiter,
- funktioniert auch mit portablem Rainmeter.

Windows zeigt beim ersten Start evtl. „Der Computer wurde durch Windows geschützt“, weil das Setup nicht kostenpflichtig signiert ist: **Weitere Informationen → Trotzdem ausführen**.

## Installation unter Linux (KDE Plasma 6)

Funktioniert auf jeder Distribution mit KDE Plasma 6 (Kubuntu, Fedora KDE, KDE neon, openSUSE, Manjaro/Arch KDE …). `ObsidianTodo-KDE-Setup-<version>.sh` aus den [Releases](../../releases/latest) herunterladen, dann:

```bash
chmod +x ObsidianTodo-KDE-Setup-*.sh
./ObsidianTodo-KDE-Setup-*.sh
```

Das Setup
- findet Obsidian (Paket, Flatpak, Snap oder AppImage) und installiert es auf Wunsch mit (Flatpak, sonst AppImage),
- lässt dich einen vorhandenen Vault wählen oder einen neuen anlegen und verwendet eine vorhandene `Todo.md` weiter,
- installiert das Widget, setzt es oben rechts auf den Desktop und richtet **Meta+Shift+T** als Tastenkürzel ein,
- braucht keine Root-Rechte.

Erinnerungen mit den Knöpfen „Erledigt“ / „In 15 Min nochmal“ brauchen `notify-send` (Paket `libnotify-bin` bzw. `libnotify`). GNOME-Unterstützung ist geplant.

Was sich in welcher Version geändert hat, steht im [CHANGELOG](CHANGELOG.md).

## Updates

Windows und KDE prüfen beim Start und danach alle 6 Stunden, ob es ein neues Release gibt, und aktualisiert sich dann selbst im Hintergrund. Die SHA-256-Prüfsumme des Downloads wird dabei kontrolliert. Einstellungen und Todo-Liste bleiben erhalten.

## Deinstallation

Windows: über Einstellungen → Apps. Linux: Startmenü → „Obsidian To-do entfernen“ oder Rechtsklick auf die Liste. `Todo.md` und `Todo-Archiv.md` in deinem Vault bleiben in beiden Fällen erhalten.

## Selbst bauen

Windows-Setup (Windows 10/11, [Inno Setup 7](https://jrsoftware.org/isinfo.php)):

```powershell
powershell -File build.ps1            # -> dist\ObsidianTodo-Setup-<version>.exe
```

KDE-Setup (Linux oder WSL):

```bash
bash linux/build-kde.sh               # -> dist/ObsidianTodo-KDE-Setup-<version>.sh
node linux/tests/core-test.js         # Tests für die Logik der KDE-Version
```

| Ordner | Inhalt |
|---|---|
| `src/build-skin.ps1` | erzeugt die Rainmeter-Dateien (`Todo.ini`, Formular, Hilfe) |
| `src/todo.lua`, `src/form.lua` | Logik der Liste und des Formulars |
| `src/hotkey.cs` | kleines Programm für das globale Tastenkürzel |
| `src/notify.ps1`, `src/toast-action.vbs` | Windows-Erinnerungen und deren Knöpfe |
| `src/update.ps1` | automatische Updates über GitHub-Releases |
| `installer/` | Inno-Setup-Skript und Hilfsskript für Erkennung/Einrichtung |
| `linux/kde/package/` | KDE-Plasma-Widget (QML); `contents/code/todo.js` ist die Logik im selben Format wie `todo.lua` |
| `linux/kde/setup.sh`, `update.sh` | Linux-Setup und automatische Updates |
| `linux/tests/` | Tests (Logik mit Node, Widget und Setup in WSL/Ubuntu) |

Für ein Release: Version in `VERSION` erhöhen, beide Builds ausführen, Release mit Tag `v<VERSION>` anlegen und `dist\ObsidianTodo-Setup-<version>.exe` sowie `dist/ObsidianTodo-KDE-Setup-<version>.sh` anhängen. Die Updater erkennen die Dateien am Namensanfang (`ObsidianTodo-Setup` bzw. `ObsidianTodo-KDE-Setup`), der bleibt also immer gleich.

## Lizenz

[PolyForm Noncommercial 1.0.0](LICENSE): Du darfst Obsidian To-do kostenlos benutzen, verändern und weitergeben – privat, in der Schule, im Verein oder in anderen nicht-kommerziellen Einrichtungen. **Verkaufen oder kommerziell einsetzen ist nicht erlaubt.** Für eine kommerzielle Nutzung bitte den Urheber über GitHub fragen.

Versionen bis einschließlich Commit `d905f10` (1. November 2026) wurden unter der MIT-Lizenz veröffentlicht; für diese Stände gilt weiterhin MIT.

Rainmeter (GPL-2.0) und Obsidian werden nicht mitgeliefert, sondern bei Bedarf von den offiziellen Quellen geladen.
