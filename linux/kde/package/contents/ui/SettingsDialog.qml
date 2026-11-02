// Einstellungen (Zahnrad) - gleiche Aufteilung und Auswahl wie das Windows-Einstellungen-Fenster
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/palette.js" as P

// normales randloses Fenster (kein Plasma-Dialog): nur so laesst KDE es an der Titelzeile verschieben
Window {
    id: dlg
    property var app
    readonly property var cfg: Plasmoid.configuration

    title: "Obsidian Todo – Einstellungen"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    width: body.width
    height: body.height

    // ---------- Tastenkuerzel aufnehmen ----------
    property bool recording: false
    property string recPreview: ""
    function niceKey(k) {
        if (!k) return "keins";
        return k.replace(/Ctrl/g, "Strg").replace(/Space/g, "Leertaste");
    }
    function startRecording() {
        recording = true;
        recPreview = "";
        requestActivate();
        body.forceActiveFocus();
    }
    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F35) return "F" + (k - Qt.Key_F1 + 1);
        if (k === Qt.Key_Space) return "Space";
        return "";
    }
    function recordKey(e) {
        if (!recording) return false;
        if (e.key === Qt.Key_Escape) { recording = false; return true; }
        var mods = [];
        if (e.modifiers & Qt.ControlModifier) mods.push("Ctrl");
        if (e.modifiers & Qt.AltModifier) mods.push("Alt");
        if (e.modifiers & Qt.ShiftModifier) mods.push("Shift");
        if (e.modifiers & Qt.MetaModifier) mods.push("Meta");
        var name = keyName(e.key);
        if (!name) { recPreview = mods.length ? niceKey(mods.join("+")) + "+ …" : ""; return true; }
        var strong = (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) || name.charAt(0) === "F" && name.length > 1;
        if (!strong) { recPreview = "Mit Strg/Alt/Meta"; return true; }
        mods.push(name);
        app.setHotkey(mods.join("+"));
        recording = false;
        return true;
    }
    onVisibleChanged: if (!visible) recording = false

    function open() {
        visible = true;
        raise();
        requestActivate();
    }

    // Ueberschrift + Knoepfe einer Einstellung
    component Setting: ColumnLayout {
        id: s
        property string caption: ""
        property var options: []          // [[Beschriftung, Wert], ...]
        property var current
        property bool dots: false         // Akzentfarben als Farbpunkte
        signal picked(var value)
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing * 3
        PC3.Label {
            text: s.caption
            color: P.accent(dlg.cfg.accent)
            font.weight: Font.DemiBold
        }
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 1.5
            Repeater {
                model: s.options
                delegate: Chip {
                    readonly property bool isSel: String(modelData[1]) === String(s.current)
                    text: s.dots ? "●" : modelData[0]
                    textColor: s.dots ? P.check(modelData[1]) : (isSel ? P.text : P.note)
                    selected: isSel && !s.dots
                    // Farbpunkte: ausgewaehlter bekommt einen hellen Ring
                    border.color: s.dots && isSel ? "#E6FFFFFF" : (selected ? P.check(dlg.cfg.accent) : P.chipStroke)
                    border.width: s.dots && isSel ? 2 : 1
                    fontScale: s.dots ? 1.3 : 1.0
                    onClicked: s.picked(modelData[1])
                }
            }
        }
    }
    component Group: PC3.Label {
        Layout.topMargin: Kirigami.Units.smallSpacing * 2
        color: P.done
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        font.weight: Font.DemiBold
        font.letterSpacing: 1.5
    }
    component Small: PC3.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: P.done
        font: Kirigami.Theme.smallFont
    }


    Rectangle {
        id: body
        width: Kirigami.Units.gridUnit * 46
        // auf kleinen Bildschirmen scrollbar statt abgeschnitten
        height: Math.min(content.implicitHeight + Kirigami.Units.largeSpacing * 3, Screen.desktopAvailableHeight - Kirigami.Units.gridUnit * 3)
        color: P.formBg
        radius: Kirigami.Units.gridUnit * 0.75
        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.inherit: false
        focus: true
        Keys.onPressed: e => { if (dlg.recordKey(e)) e.accepted = true; else if (e.key === Qt.Key_Escape) dlg.visible = false; }

        FileDialog {
            id: fileDialog
            title: "Todo-Datei wählen (vorhandene auswählen oder neuen Namen eingeben)"
            fileMode: FileDialog.SaveFile
            options: FileDialog.DontConfirmOverwrite
            nameFilters: ["Markdown (*.md)"]
            defaultSuffix: "md"
            onAccepted: dlg.app.chooseTodo(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing * 1.5
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            PC3.ScrollBar.vertical: PC3.ScrollBar { id: sb; policy: flick.contentHeight > flick.height ? PC3.ScrollBar.AlwaysOn : PC3.ScrollBar.AlwaysOff }
        ColumnLayout {
            id: content
            width: flick.width - (sb.policy === PC3.ScrollBar.AlwaysOn ? sb.width + Kirigami.Units.smallSpacing * 2 : 0)
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                // an der Titelzeile ziehen = Fenster verschieben (KDE uebernimmt das Ziehen)
                PC3.Label {
                    text: "Einstellungen"
                    color: P.text
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.3
                    font.weight: Font.DemiBold
                }
                // Titelzeile ziehen = Fenster verschieben
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    MouseArea {
                        anchors.fill: parent
                        anchors.leftMargin: -Kirigami.Units.gridUnit * 10   // auch ueber dem Titel
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeAllCursor
                        onPressed: dlg.startSystemMove()
                    }
                }
                Chip { iconButton: true; iconName: "window-close"; textColor: P.done; onClicked: dlg.visible = false }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.gridUnit * 2
                // ----- linke Spalte: Aussehen -----
                ColumnLayout {
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 0
                    Group { text: "AUSSEHEN" }
                    Setting {
                        caption: "Anzeige"
                        options: [["Seitenleiste", "sidebar"], ["Desktop", "desktop"], ["Beides", "both"]]
                        current: dlg.cfg.mode
                        onPicked: v => dlg.cfg.mode = v
                    }
                    Small { text: "Seitenleiste: gleitet am Bildschirmrand herein. Desktop: liegt auf dem Hintergrund. Beides: liegt auf dem Desktop und gleitet am Rand als Seitenleiste herein." }
                    Setting {
                        caption: "Seite"
                        options: [["Links", "left"], ["Rechts", "right"]]
                        current: dlg.cfg.side
                        onPicked: v => dlg.cfg.side = v
                    }
                    Setting {
                        caption: "Breite"
                        options: [["Breit", 560], ["Normal", 460], ["Schmal", 380]]
                        current: dlg.cfg.listWidth
                        onPicked: v => dlg.cfg.listWidth = v
                    }
                    Setting {
                        caption: "Schriftgröße"
                        options: [["Groß", 1.15], ["Normal", 1], ["Klein", 0.9]]
                        current: dlg.cfg.fontScale
                        onPicked: v => dlg.cfg.fontScale = v
                    }
                    Setting {
                        caption: "Hintergrund"
                        options: [["Deckend", 250], ["Normal", 218], ["Leicht", 190], ["Durchsichtig", 150]]
                        current: dlg.cfg.opacity
                        onPicked: v => dlg.cfg.opacity = v
                    }
                    Setting {
                        caption: "Akzentfarbe"
                        dots: true
                        options: P.ACCENT_NAMES.map(function (n) { return [n, n]; })
                        current: dlg.cfg.accent
                        onPicked: v => dlg.cfg.accent = v
                    }
                }
                // ----- rechte Spalte: Verhalten -----
                ColumnLayout {
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 0
                    Group { text: "VERHALTEN" }
                    Setting {
                        caption: "Tempo der Seitenleiste"
                        options: [["Schnell", "fast"], ["Normal", "normal"], ["Gemütlich", "slow"]]
                        current: dlg.cfg.speed
                        onPicked: v => dlg.cfg.speed = v
                    }
                    Setting {
                        caption: "Beim Anmelden/Aufwachen einblenden"
                        options: [["20 s", 20], ["10 s", 10], ["5 s", 5], ["Aus", 0]]
                        current: dlg.cfg.revealPerItem
                        onPicked: v => dlg.cfg.revealPerItem = v
                    }
                    Small { text: "Sekunden pro offenem Punkt (höchstens 2 Minuten)." }
                    Setting {
                        caption: "Erinnerungen"
                        options: [["15 Min vorher", 15], ["5 Min vorher", 5], ["Pünktlich", 0], ["Aus", "aus"]]
                        current: dlg.cfg.remindOn ? dlg.cfg.remindLead : "aus"
                        onPicked: v => { if (v === "aus") dlg.cfg.remindOn = false; else { dlg.cfg.remindOn = true; dlg.cfg.remindLead = v; } }
                    }
                    // Tastenkuerzel: aktuelles anzeigen, "Aendern ..." nimmt die naechste Tastenkombination auf
                    Setting { caption: "Tastenkürzel für neuen Punkt"; options: [] }
                    RowLayout {
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing * 1.5
                        Chip {
                            selected: true
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 7.5
                            text: dlg.recording ? (dlg.recPreview || "Tasten drücken …") : dlg.niceKey(dlg.app.hotkey)
                            onClicked: dlg.startRecording()
                        }
                        Chip { text: "Ändern …"; onClicked: dlg.startRecording() }
                        Chip { text: "Zurücksetzen"; onClicked: { dlg.recording = false; dlg.app.setHotkey("Meta+Shift+T"); } }
                    }
                    Small {
                        text: dlg.recording ? "Jetzt die neue Kombination drücken (mit Strg, Alt oder Meta) · Esc = abbrechen"
                                            : "Ändern: anklicken und die neue Kombination drücken (Esc = abbrechen)."
                    }
                    Setting {
                        caption: "Todo-Datei"
                        options: []
                    }
                    Small { text: dlg.app.todoFile; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                    Chip {
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        text: "Andere Datei wählen …"
                        onClicked: fileDialog.open()
                    }
                    Setting {
                        caption: "Automatische Updates"
                        options: [["An", true], ["Aus", false]]
                        current: dlg.cfg.autoUpdate
                        onPicked: v => dlg.cfg.autoUpdate = v
                    }
                }
            }

            // ----- Kurzhilfe ueber die ganze Breite -----
            PC3.Label {
                Layout.topMargin: Kirigami.Units.gridUnit * 1.5
                text: "So funktioniert's"
                color: P.accent(dlg.cfg.accent)
                font.weight: Font.DemiBold
            }
            Repeater {
                model: [
                    ["Klick", "Punkt abhaken (nochmal klicken = rückgängig)"],
                    ["Rechtsklick", "Punkt bearbeiten oder löschen"],
                    ["+ Neuer Punkt", "neuen Punkt anlegen, überall auch mit dem Tastenkürzel (siehe oben)"],
                    ["Enter", "speichert den Punkt sofort (Datum vorher wählen oder später ergänzen)"],
                    ["Titel „Todo“", "Liste in Obsidian öffnen"],
                    ["Seitenleiste", "Maus an den Bildschirmrand – die Liste gleitet herein"],
                    ["Anmelden, Aufwachen, Entsperren", "die Liste kommt kurz von selbst"],
                    ["Farben", "orange = heute fällig, rot = überfällig"],
                    ["Verschieben auf dem Desktop", "Rechtsklick auf den Desktop → Bearbeitungsmodus"],
                    ["Entfernen", "Rechtsklick auf die Liste oder im Startmenü „Obsidian To-do entfernen“"]
                ]
                delegate: PC3.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font: Kirigami.Theme.smallFont
                    color: P.note
                    text: "<font color='#FFFFFF'>" + modelData[0] + ":</font> " + modelData[1]
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                PC3.Label {
                    text: "Archiv öffnen ↗"
                    color: P.accent(dlg.cfg.accent)
                    font.weight: Font.DemiBold
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: dlg.app.openInObsidian(dlg.app.archiveFile) }
                }
                Item { Layout.fillWidth: true }
                PC3.Label { text: "Version " + dlg.app.version; color: P.done; font: Kirigami.Theme.smallFont }
            }
        }
        }
    }
}
