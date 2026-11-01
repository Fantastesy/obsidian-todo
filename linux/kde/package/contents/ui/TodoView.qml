// Liste der Punkte (Desktop-Widget bzw. Popup im Panel)
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: view
    property var app
    property bool showHelp: false

    spacing: Kirigami.Units.smallSpacing
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.preferredHeight: implicitHeight

    // ---------- Kopf ----------
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Kirigami.Heading {
            text: "Todo"
            level: 2
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: view.app.openInObsidian() }
            PC3.ToolTip { text: "In Obsidian öffnen" }
        }
        PC3.ToolButton {
            icon.name: "help-contextual"
            display: PC3.AbstractButton.IconOnly
            checkable: true
            checked: view.showHelp
            onToggled: view.showHelp = checked
            PC3.ToolTip { text: "Was die Liste kann" }
        }
        Item { Layout.fillWidth: true }
        PC3.Label {
            text: view.app.configMissing ? "nicht eingerichtet"
                : view.app.fileMissing ? "Datei fehlt"
                : view.app.model ? view.app.model.openCount + " offen" : ""
            color: view.app.fileMissing || view.app.configMissing ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
        }
        PC3.ToolButton {
            icon.name: view.app.collapsed ? "arrow-down" : "arrow-up"
            display: PC3.AbstractButton.IconOnly
            onClicked: view.app.collapsed = !view.app.collapsed
            PC3.ToolTip { text: "Liste ein-/ausklappen" }
        }
    }

    // ---------- Hilfe ----------
    PlasmaExtras.Representation {
        visible: view.showHelp
        Layout.fillWidth: true
        implicitHeight: helpCol.implicitHeight
        ColumnLayout {
            id: helpCol
            width: parent.width
            spacing: 2
            Repeater {
                model: [
                    ["Klick auf das Kästchen", "abhaken (nochmal = rückgängig)"],
                    ["Rechtsklick auf einen Punkt", "bearbeiten oder löschen"],
                    ["+ Neuer Punkt", "auch überall mit Meta+Shift+T"],
                    ["Enter im Formular", "speichert sofort"],
                    ["Büroklammer", "Notizen, Links, Dateien und Unteraufgaben"],
                    ["Orange / Rot", "heute fällig / überfällig"],
                    ["Titel „Todo“", "Liste in Obsidian öffnen"]
                ]
                delegate: PC3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    text: "<b>" + modelData[0] + ":</b> " + modelData[1]
                    font: Kirigami.Theme.smallFont
                }
            }
            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }
        }
    }

    // ---------- Hinweise ----------
    PC3.Label {
        visible: view.app.configMissing && !view.app.collapsed
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        wrapMode: Text.WordWrap
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
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.disabledTextColor
            text: moreLabel.hidden > 0 ? "+ " + moreLabel.hidden + " weitere in Obsidian" : "Alles erledigt"
            HoverHandler { cursorShape: moreLabel.hidden > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { onTapped: if (moreLabel.hidden > 0) view.app.openInObsidian() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            PC3.ToolButton {
                icon.name: "list-add"
                text: "Neuer Punkt"
                onClicked: view.app.openForm(null)
            }
            Item { Layout.fillWidth: true }
            PC3.ToolButton {
                visible: view.app.model && view.app.model.doneCount > 0
                icon.name: "archive-insert"
                text: "Erledigte archivieren"
                onClicked: view.app.cleanup()
            }
        }
    }
}
