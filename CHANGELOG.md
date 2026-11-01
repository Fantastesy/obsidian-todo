# Änderungen

## 1.1.0 – 1. November 2026

### Windows
- Die Liste kommt beim Anmelden, Aufwachen und Entsperren kurz nach vorne (10 Sekunden pro offenem Punkt, höchstens 2 Minuten), mit „Ausblenden ✕“ oben rechts. Ist die Todo.md direkt nach dem Hochfahren noch nicht lesbar (z. B. Cloud-Ordner), wird das Einblenden nachgeholt.
- Breite einstellbar im Hilfe-Fenster (schmal / normal / breit); bleibt bei Updates erhalten.
- „Obsidian To-do entfernen“ im Startmenü.
- Das Setup erkennt eine vorhandene Installation oder eine von Hand eingerichtete Liste und übernimmt die Todo-Liste, ohne erneut nach dem Vault zu fragen.
- Ein bereits laufendes (auch portables) Rainmeter wird zuverlässig erkannt; es wird nie ein zweites installiert.
- Bei einer Erstinstallation sitzt die Liste oben rechts auf dem Desktop.

### Linux (KDE Plasma 6)
- Neue Anzeige „Seitenleiste“: ein unsichtbarer Streifen am rechten Bildschirmrand. Fährt die Maus an den Rand, kommt er herein und die Liste klappt daneben auf; Maus weg → zu.
- Beim Anmelden, Aufwachen und Entsperren klappt die Liste kurz von selbst auf, mit „Ausblenden“.
- Anzeige umschaltbar per Rechtsklick auf die Liste: Seitenleiste, Desktop oder beides.
- „Obsidian To-do entfernen“ im Startmenü und im Rechtsklick-Menü.
- Gleicher Look wie unter Windows (dunkel, halbdurchsichtig, lila Kästchen).

### Beide
- Setup-Dateien tragen die Versionsnummer im Namen; die automatischen Updates erkennen sie trotzdem.
- Lizenz: PolyForm Noncommercial 1.0.0 (frei nutzbar, nicht kommerziell).

**Hinweis für Linux-Nutzer von 1.0.0:** 1.0.0 kennt nur den alten Dateinamen ohne Versionsnummer und findet 1.1.0 deshalb nicht von selbst. Bitte einmal von Hand installieren (siehe unten); danach kommen Updates wieder automatisch.

## 1.0.0 – 1. November 2026

Erste Version: Windows (Rainmeter) mit Setup und automatischen Updates, Linux als KDE-Plasma-6-Widget.

---

## Installation

**Windows:** `ObsidianTodo-Setup-<version>.exe` aus den [Releases](../../releases/latest) herunterladen und starten. Windows zeigt evtl. „Der Computer wurde durch Windows geschützt“ → „Weitere Informationen“ → „Trotzdem ausführen“.

**Linux (KDE Plasma 6):** `ObsidianTodo-KDE-Setup-<version>.sh` aus den [Releases](../../releases/latest) herunterladen, dann im Terminal:

```bash
chmod +x ObsidianTodo-KDE-Setup-*.sh
./ObsidianTodo-KDE-Setup-*.sh
```

Danach aktualisieren sich beide Versionen automatisch.
