// Ein Punkt der Liste: Kaestchen, Text, Termin, Unteraufgaben, aufklappbare Notizen (Windows-Look)
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/palette.js" as P

ColumnLayout {
    id: taskRow
    property var app
    property var row
    // laufende Eingabe direkt in der Liste: '' | 'note' | 'sub' | 'addnote' | 'addsub'
    property string editKind: ""
    property int editLine: -1
    property string editOrig: ""

    spacing: 0

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
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.gridUnit * 0.4
        color: rowHover.hovered ? P.hover : "transparent"
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
            anchors.leftMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            Check {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                checked: taskRow.row.done
                onToggled: taskRow.app.toggle(taskRow.row.line, taskRow.row.orig)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: taskRow.row.title
                    wrapMode: Text.Wrap
                    font.weight: Font.DemiBold
                    font.strikeout: taskRow.row.done
                    color: taskRow.row.done ? P.done : P.text
                }
                RowLayout {
                    visible: taskRow.row.dueLabel !== ""
                    spacing: 3
                    Kirigami.Icon {
                        source: taskRow.row.repeat ? "view-refresh" : "view-calendar"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        color: P.dueColor(taskRow.row.dueState)
                        isMask: true
                    }
                    PC3.Label {
                        text: taskRow.row.dueLabel
                        font: Kirigami.Theme.smallFont
                        color: P.dueColor(taskRow.row.dueState)
                    }
                }
            }
            PC3.Label {
                visible: taskRow.row.subs.length > 0
                text: taskRow.row.subsDone + "/" + taskRow.row.subs.length
                font: Kirigami.Theme.smallFont
                color: P.done
            }
            Chip {
                flat: true
                iconName: "mail-attachment"
                text: taskRow.row.notes.length > 0 ? taskRow.row.notes.length : ""
                textColor: taskRow.row.open ? P.accent : P.done
                bold: false
                opacity: taskRow.row.open || rowHover.hovered || taskRow.row.notes.length > 0 ? 1 : 0.4
                onClicked: taskRow.app.toggleNotes(taskRow.row.key)
            }
        }
    }

    // ---------- Unteraufgaben (immer sichtbar) ----------
    Repeater {
        model: taskRow.row.subs
        delegate: RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit * 1.6
            Layout.topMargin: 2
            visible: !(taskRow.editKind === "sub" && taskRow.editLine === modelData.line)
            spacing: Kirigami.Units.largeSpacing
            Check {
                size: Kirigami.Units.gridUnit * 0.85
                checked: modelData.done
                onToggled: taskRow.app.toggleSub(taskRow.row.line, taskRow.row.orig, modelData.line, modelData.orig)
            }
            PC3.Label {
                Layout.fillWidth: true
                text: modelData.title + (modelData.dueLabel ? "  · " + modelData.dueLabel : "")
                wrapMode: Text.Wrap
                font.strikeout: modelData.done
                color: modelData.done ? P.done : P.note
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
        Layout.leftMargin: Kirigami.Units.gridUnit * 1.6
        Layout.topMargin: 2
        spacing: 3

        Repeater {
            model: taskRow.row.notes
            delegate: PC3.Label {
                Layout.fillWidth: true
                visible: !(taskRow.editKind === "note" && taskRow.editLine === modelData.line)
                text: modelData.text
                wrapMode: Text.Wrap
                font.underline: modelData.link !== ""
                color: modelData.link !== "" ? P.accent : P.note
                HoverHandler { cursorShape: modelData.link !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (point, button) => {
                        if (button === Qt.RightButton) taskRow.startEdit("note", modelData.line, modelData.orig, taskRow.app.childInput(modelData.line));
                        else taskRow.app.openLink(modelData.link);
                    }
                }
            }
        }

        RowLayout {
            visible: taskRow.editKind === ""
            spacing: Kirigami.Units.largeSpacing
            Repeater {
                model: [["+ Notiz", "addnote"], ["+ Unteraufgabe", "addsub"], ["+ Datei", "file"]]
                delegate: PC3.Label {
                    text: modelData[0]
                    color: P.accent
                    font: Kirigami.Theme.smallFont
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: modelData[1] === "file" ? fileDialog.open() : taskRow.startEdit(modelData[1], -1, "", "")
                    }
                }
            }
        }
    }

    // ---------- Eingabefeld fuer Notiz / Unteraufgabe ----------
    PC3.TextField {
        id: editor
        visible: taskRow.editKind !== ""
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit * 1.6
        Layout.topMargin: 2
        color: P.text
        placeholderTextColor: P.done
        topPadding: Kirigami.Units.smallSpacing * 2
        bottomPadding: Kirigami.Units.smallSpacing * 2
        leftPadding: Kirigami.Units.largeSpacing
        placeholderText: taskRow.editKind === "addsub" || taskRow.editKind === "sub" ? "Unteraufgabe (Enter speichert, leer = löschen)" : "Notiz oder Link (Enter speichert, leer = löschen)"
        background: Rectangle { radius: Kirigami.Units.gridUnit * 0.4; color: P.field; border.color: P.check; border.width: 1 }
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
