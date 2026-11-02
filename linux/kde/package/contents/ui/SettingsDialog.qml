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

PlasmaCore.Dialog {
    id: dlg
    property var app
    readonly property var cfg: Plasmoid.configuration

    location: PlasmaCore.Types.Floating
    type: PlasmaCore.Dialog.Normal
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false
    backgroundHints: PlasmaCore.Types.NoBackground

    function open() {
        visible = true;
        x = Screen.virtualX + Math.round((Screen.width - width) / 2);
        y = Screen.virtualY + Math.round((Screen.height - height) / 2);
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
        Layout.topMargin: Kirigami.Units.largeSpacing
        PC3.Label {
            text: s.caption
            color: P.accent(dlg.cfg.accent)
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.15
            font.bold: true
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
    component Small: PC3.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: P.done
        font: Kirigami.Theme.smallFont
    }


    mainItem: Rectangle {
        id: body
        width: Kirigami.Units.gridUnit * 50
        // auf kleinen Bildschirmen scrollbar statt abgeschnitten
        height: Math.min(content.implicitHeight + Kirigami.Units.largeSpacing * 3, Screen.desktopAvailableHeight - Kirigami.Units.gridUnit * 3)
        color: P.formBg
        radius: Kirigami.Units.gridUnit * 0.75
        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.inherit: false
        Keys.onEscapePressed: dlg.visible = false

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
                DragHandler { target: null; onActiveChanged: if (active) dlg.startSystemMove() }
                HoverHandler { cursorShape: Qt.SizeAllCursor }
                PC3.Label {
                    text: "Einstellungen"
                    color: P.text
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.5
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
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
                    Setting {
                        caption: "Anzeige"
                        options: [["Seitenleiste", "sidebar"], ["Desktop", "desktop"], ["Beides", "both"]]
                        current: dlg.cfg.mode
                        onPicked: v => dlg.cfg.mode = v
                    }
                    Small { text: "Seitenleiste: gleitet am Bildschirmrand herein. Desktop: liegt auf dem Hintergrund. Beides: liegt auf dem Desktop und gleitet am Rand als Seitenleiste herein." }
                    Setting {
                        caption: "Seite"
                        options: [["Rechts", "right"], ["Links", "left"]]
                        current: dlg.cfg.side
                        onPicked: v => dlg.cfg.side = v
                    }
                    Setting {
                        caption: "Breite"
                        options: [["Schmal", 380], ["Normal", 460], ["Breit", 560]]
                        current: dlg.cfg.listWidth
                        onPicked: v => dlg.cfg.listWidth = v
                    }
                    Setting {
                        caption: "Schriftgröße"
                        options: [["Klein", 0.9], ["Normal", 1], ["Groß", 1.15]]
                        current: dlg.cfg.fontScale
                        onPicked: v => dlg.cfg.fontScale = v
                    }
                    Setting {
                        caption: "Akzentfarbe"
                        dots: true
                        options: P.ACCENT_NAMES.map(function (n) { return [n, n]; })
                        current: dlg.cfg.accent
                        onPicked: v => dlg.cfg.accent = v
                    }
                    Setting {
                        caption: "Hintergrund"
                        options: [["Durchsichtig", 150], ["Leicht", 190], ["Normal", 218], ["Deckend", 250]]
                        current: dlg.cfg.opacity
                        onPicked: v => dlg.cfg.opacity = v
                    }
                }
                // ----- rechte Spalte: Verhalten -----
                ColumnLayout {
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 0
                    Setting {
                        caption: "Tempo der Seitenleiste"
                        options: [["Schnell", "fast"], ["Normal", "normal"], ["Gemütlich", "slow"]]
                        current: dlg.cfg.speed
                        onPicked: v => dlg.cfg.speed = v
                    }
                    Setting {
                        caption: "Beim Anmelden/Aufwachen einblenden"
                        options: [["Aus", 0], ["5 s", 5], ["10 s", 10], ["20 s", 20]]
                        current: dlg.cfg.revealPerItem
                        onPicked: v => dlg.cfg.revealPerItem = v
                    }
                    Small { text: "Sekunden pro offenem Punkt (höchstens 2 Minuten)." }
                    Setting {
                        caption: "Erinnerungen"
                        options: [["Aus", "aus"], ["Pünktlich", 0], ["5 Min vorher", 5], ["15 Min vorher", 15]]
                        current: dlg.cfg.remindOn ? dlg.cfg.remindLead : "aus"
                        onPicked: v => { if (v === "aus") dlg.cfg.remindOn = false; else { dlg.cfg.remindOn = true; dlg.cfg.remindLead = v; } }
                    }
                    Setting {
                        caption: "Tastenkürzel für neuen Punkt"
                        options: [["Meta+Shift+T", "Meta+Shift+T"], ["Strg+Alt+N", "Ctrl+Alt+N"], ["Strg+Shift+Leer", "Ctrl+Shift+Space"], ["Aus", ""]]
                        current: dlg.app.hotkey
                        onPicked: v => dlg.app.setHotkey(v)
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
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.15
                font.bold: true
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
                    color: P.note
                    text: "<b><font color='#FFFFFF'>" + modelData[0] + ":</font></b> " + modelData[1]
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
