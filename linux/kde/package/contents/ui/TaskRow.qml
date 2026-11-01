// Ein Punkt der Liste: Kaestchen, Text, Termin, Unteraufgaben, aufklappbare Notizen
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: taskRow
    property var app
    property var row
    // laufende Eingabe direkt in der Liste: '' | 'note' | 'sub' | 'addnote' | 'addsub'
    property string editKind: ""
    property int editLine: -1
    property string editOrig: ""

    spacing: 0

    function dueColor(state) {
        if (state === "over") return Kirigami.Theme.negativeTextColor;
        if (state === "today") return Kirigami.Theme.neutralTextColor;
        return Kirigami.Theme.disabledTextColor;
    }
    function startEdit(kind, line, orig, text) {
        editKind = kind; editLine = line; editOrig = orig || "";
        editor.text = text || "";
        app.editing = true;
        editor.forceActiveFocus();
    }
    function finishEdit(save) {
        var kind = editKind, text = editor.text;
        editKind = "";
        app.editing = false;
        if (!save) return;
        if (kind === "addnote") app.addChild(row.line, row.orig, "note", text);
        else if (kind === "addsub") app.addChild(row.line, row.orig, "sub", text);
        else app.editChild(row.line, row.orig, editLine, editOrig, text);
    }

    // ---------- Kopfzeile ----------
    Item {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + Kirigami.Units.smallSpacing

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.highlightColor
            opacity: rowHover.hovered ? 0.12 : 0
        }
        HoverHandler { id: rowHover }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: taskRow.app.openForm(taskRow.row)
        }

        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Kirigami.Units.smallSpacing

            PC3.CheckBox {
                checked: taskRow.row.done
                onToggled: taskRow.app.toggle(taskRow.row.line, taskRow.row.orig)
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: taskRow.row.title
                    wrapMode: Text.Wrap
                    font.strikeout: taskRow.row.done
                    color: taskRow.row.done ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                }
                RowLayout {
                    visible: taskRow.row.dueLabel !== ""
                    spacing: 2
                    Kirigami.Icon {
                        source: taskRow.row.repeat ? "view-refresh" : "view-calendar"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        color: taskRow.dueColor(taskRow.row.dueState)
                        isMask: true
                    }
                    PC3.Label {
                        text: taskRow.row.dueLabel
                        font: Kirigami.Theme.smallFont
                        color: taskRow.dueColor(taskRow.row.dueState)
                    }
                }
            }
            PC3.Label {
                visible: taskRow.row.subs.length > 0
                text: taskRow.row.subsDone + "/" + taskRow.row.subs.length
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
            PC3.ToolButton {
                icon.name: "mail-attachment"
                text: taskRow.row.notes.length > 0 ? taskRow.row.notes.length : ""
                display: taskRow.row.notes.length > 0 ? PC3.AbstractButton.TextBesideIcon : PC3.AbstractButton.IconOnly
                checkable: true
                checked: taskRow.row.open
                opacity: checked || rowHover.hovered || taskRow.row.notes.length > 0 ? 1 : 0.35
                onClicked: taskRow.app.toggleNotes(taskRow.row.key)
                PC3.ToolTip { text: "Notizen, Links und Dateien" }
            }
        }
    }

    // ---------- Unteraufgaben (immer sichtbar) ----------
    Repeater {
        model: taskRow.row.subs
        delegate: RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
            visible: !(taskRow.editKind === "sub" && taskRow.editLine === modelData.line)
            spacing: Kirigami.Units.smallSpacing
            PC3.CheckBox {
                checked: modelData.done
                onToggled: taskRow.app.toggleSub(taskRow.row.line, taskRow.row.orig, modelData.line, modelData.orig)
            }
            PC3.Label {
                Layout.fillWidth: true
                text: modelData.title + (modelData.dueLabel ? "  · " + modelData.dueLabel : "")
                wrapMode: Text.Wrap
                font.strikeout: modelData.done
                color: modelData.done ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: taskRow.startEdit("sub", modelData.line, modelData.orig, taskRow.app.childInput(modelData.line))
                }
            }
        }
    }

    // ---------- Notizen (aufgeklappt) ----------
    ColumnLayout {
        visible: taskRow.row.open
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit * 2
        spacing: 2

        Repeater {
            model: taskRow.row.notes
            delegate: PC3.Label {
                Layout.fillWidth: true
                visible: !(taskRow.editKind === "note" && taskRow.editLine === modelData.line)
                text: modelData.text
                wrapMode: Text.Wrap
                font.underline: modelData.link !== ""
                color: modelData.link !== "" ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor
                HoverHandler { cursorShape: modelData.link !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor }
                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (point, button) => {
                        if (button === Qt.RightButton) taskRow.startEdit("note", modelData.line, modelData.orig, taskRow.app.childInput(modelData.line));
                        else taskRow.app.openLink(modelData.link);
                    }
                }
                PC3.ToolTip { text: "Rechtsklick: bearbeiten (leer = löschen)" }
            }
        }

        RowLayout {
            visible: taskRow.editKind === ""
            spacing: 0
            PC3.ToolButton { text: "+ Notiz"; onClicked: taskRow.startEdit("addnote", -1, "", "") }
            PC3.ToolButton { text: "+ Unteraufgabe"; onClicked: taskRow.startEdit("addsub", -1, "", "") }
            PC3.ToolButton { text: "+ Datei"; onClicked: fileDialog.open() }
        }
    }

    // ---------- Eingabefeld fuer Notiz / Unteraufgabe ----------
    PC3.TextField {
        id: editor
        visible: taskRow.editKind !== ""
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
        placeholderText: taskRow.editKind === "addsub" || taskRow.editKind === "sub" ? "Unteraufgabe (Enter speichert, leer = löschen)" : "Notiz oder Link (Enter speichert, leer = löschen)"
        onAccepted: taskRow.finishEdit(true)
        Keys.onEscapePressed: taskRow.finishEdit(false)
        onActiveFocusChanged: if (!activeFocus && taskRow.editKind !== "") taskRow.finishEdit(false)
    }

    FileDialog {
        id: fileDialog
        title: "Datei an Todo anhängen"
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            selectedFiles.forEach(function (u) {
                var p = decodeURIComponent(u.toString().replace(/^file:\/\//, ""));
                taskRow.app.addChild(taskRow.row.line, taskRow.row.orig, "note", p);
            });
        }
    }
}
