// Liste der Punkte im Windows-Look: dunkel, halbdurchsichtig, abgerundet
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/palette.js" as P

Rectangle {
    id: view
    property var app
    property bool showHelp: false

    color: P.bg
    radius: Kirigami.Units.gridUnit * 0.75
    // dunkle Farbgruppe, damit Eingabefelder und Texte von Plasma hell auf dunkel erscheinen
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: col.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.preferredWidth: implicitWidth
    // in der Seitenleiste so breit wie die Leiste
    Layout.fillWidth: app && app.inPanel
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredHeight: implicitHeight
    Layout.minimumHeight: implicitHeight

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // ---------- Kopf ----------
        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: "Todo"
                color: P.text
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.45
                font.bold: true
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: view.app.openInObsidian() }
                PC3.ToolTip { text: "In Obsidian öffnen" }
            }
            PC3.Label {
                text: "?"
                color: view.showHelp ? P.accent : P.done
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                Layout.leftMargin: Kirigami.Units.smallSpacing
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: view.showHelp = !view.showHelp }
            }
            Item { Layout.fillWidth: true }
            // nach dem Einblenden (Anmelden/Aufwachen): sofort wieder ausblenden
            Chip {
                visible: view.app.revealed
                text: "Ausblenden"
                onClicked: view.app.hideReveal()
            }
            PC3.Label {
                text: view.app.configMissing ? "nicht eingerichtet"
                    : view.app.fileMissing ? "Datei fehlt"
                    : view.app.model ? view.app.model.openCount + " offen" : ""
                color: view.app.fileMissing || view.app.configMissing ? P.over : P.done
                font.weight: Font.DemiBold
            }
            Chip {
                flat: true
                iconName: view.app.collapsed ? "arrow-down" : "arrow-up"
                textColor: P.done
                onClicked: view.app.collapsed = !view.app.collapsed
            }
        }

        // ---------- Hilfe ----------
        ColumnLayout {
            visible: view.showHelp && !view.app.collapsed
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: 2
            Repeater {
                model: [
                    ["Klick auf das Kästchen", "abhaken (nochmal = rückgängig)"],
                    ["Rechtsklick auf einen Punkt", "bearbeiten oder löschen"],
                    ["+ Neuer Punkt", "auch überall mit Meta+Shift+T"],
                    ["Seitenleiste", "Maus an den rechten Bildschirmrand"],
                    ["Rechtsklick auf das Widget", "Anzeige wählen (Seitenleiste/Desktop) oder entfernen"],
                    ["Verschieben auf dem Desktop", "Rechtsklick auf den Desktop → Bearbeitungsmodus"],
                    ["Enter im Formular", "speichert sofort"],
                    ["Büroklammer", "Notizen, Links, Dateien und Unteraufgaben"],
                    ["Orange / Rot", "heute fällig / überfällig"],
                    ["Titel „Todo“", "Liste in Obsidian öffnen"]
                ]
                delegate: PC3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    color: P.note
                    text: "<b>" + modelData[0] + ":</b> " + modelData[1]
                    font: Kirigami.Theme.smallFont
                }
            }
        }

        PC3.Label {
            visible: view.app.configMissing && !view.app.collapsed
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: P.note
            text: "Noch nicht eingerichtet – bitte das Obsidian-Todo-Setup ausführen."
        }

        // ---------- Punkte ----------
        ColumnLayout {
            visible: !view.app.collapsed && !view.app.configMissing
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: view.app.rows
                delegate: TaskRow {
                    Layout.fillWidth: true
                    app: view.app
                    row: modelData
                }
            }

            PC3.Label {
                id: moreLabel
                readonly property int hidden: view.app.model ? view.app.model.display.length - view.app.rows.length : 0
                visible: (view.app.model && view.app.model.display.length === 0) || hidden > 0
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                color: P.done
                text: moreLabel.hidden > 0 ? "+ " + moreLabel.hidden + " weitere in Obsidian" : "Alles erledigt"
                HoverHandler { cursorShape: moreLabel.hidden > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { onTapped: if (moreLabel.hidden > 0) view.app.openInObsidian() }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                PC3.Label {
                    text: "+ Neuer Punkt"
                    color: P.accent
                    font.bold: true
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: view.app.openForm(null) }
                }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    visible: view.app.model && view.app.model.doneCount > 0
                    text: "Erledigte archivieren"
                    color: P.done
                    font: Kirigami.Theme.smallFont
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: view.app.cleanup() }
                }
            }
        }
    }
}
