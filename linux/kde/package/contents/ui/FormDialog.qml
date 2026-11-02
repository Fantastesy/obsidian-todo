// Formular fuer neue Punkte und "bearbeiten" - gleiche Moeglichkeiten und gleicher Look wie unter Windows
import QtQuick
import org.kde.plasma.plasmoid
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/todo.js" as Core
import "../code/palette.js" as P

PlasmaCore.Dialog {
    id: dlg
    property var app

    // Formularwerte
    property string mode: "new"
    property int line: -1
    property string orig: ""
    property string date: ""          // JJJJ-MM-TT oder ""
    property string time: ""          // HH:MM oder ""
    property string rule: ""
    property var notes: []
    property string errorText: ""
    property bool confirmDelete: false

    // Kalender / Uhrzeit / eigene Wiederholung
    property bool calOpen: false
    property int calYear: 2026
    property int calMonth: 0          // 0 = Januar
    property bool otherTime: false
    property bool custOpen: false
    property int custN: 1
    property int custUnit: 0
    property var custDays: [false, false, false, false, false, false, false]   // Mo..So

    readonly property var times: ["09:00", "12:00", "15:00", "18:00", "21:00"]
    readonly property var standardRules: ["", "täglich", "werktags", "wöchentlich", "monatlich"]
    readonly property var ruleNames: ["Nie", "Täglich", "Werktags", "Wöchentlich", "Monatlich"]
    readonly property var units: ["Tage", "Wochen", "Monate", "Jahre"]
    readonly property var unit1: ["täglich", "wöchentlich", "monatlich", "jährlich"]
    readonly property var wds: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    location: PlasmaCore.Types.Floating
    type: PlasmaCore.Dialog.Normal
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false
    backgroundHints: PlasmaCore.Types.NoBackground

    // ---------- Oeffnen ----------
    function reset() {
        errorText = ""; confirmDelete = false; calOpen = false; otherTime = false; custOpen = false;
        custN = 1; custUnit = 0; custDays = [false, false, false, false, false, false, false];
    }
    function openNew() {
        reset();
        mode = "new"; line = -1; orig = "";
        titleField.text = ""; date = ""; time = ""; rule = ""; notes = [];
        showDialog();
    }
    function openEdit(values, ln, o) {
        reset();
        mode = "edit"; line = ln; orig = o;
        titleField.text = values.title; date = values.date; time = values.time; rule = values.rule;
        notes = values.notes.slice();
        otherTime = time !== "" && times.indexOf(time) < 0;
        if (otherTime) otherField.text = time;
        if (rule !== "" && standardRules.indexOf(rule) < 0) loadCustom(rule);
        showDialog();
    }
    function showDialog() {
        var d = Core.fromIso(date) || Core.today();
        calYear = d.getFullYear(); calMonth = d.getMonth();
        visible = true;
        // mittig auf dem Bildschirm, auf dem das Fenster erscheint (nicht ueber alle Monitore)
        x = Screen.virtualX + Math.round((Screen.width - width) / 2);
        y = Screen.virtualY + Math.round((Screen.height - height) / 3);
        requestActivate();
        titleField.forceActiveFocus();
    }

    // ---------- Wiederholung ----------
    function loadCustom(r) {
        custN = 1; custUnit = 0;
        var days = [false, false, false, false, false, false, false];
        var k = unit1.indexOf(r);
        if (k >= 0) custUnit = k;
        var m = /^alle (\d+) (\S+)$/.exec(r);
        if (m) { custN = +m[1]; custUnit = Math.max(0, units.indexOf(m[2])); }
        else (r.match(/[A-Za-z]{2}/g) || []).forEach(function (d) { var i = wds.indexOf(d); if (i >= 0) days[i] = true; });
        custDays = days;
    }
    function customRule() {
        var days = [];
        for (var k = 0; k < 7; k++) if (custDays[k]) days.push(wds[k]);
        if (days.length) return days.join(",");
        if (custN === 1) return unit1[custUnit];
        return "alle " + custN + " " + units[custUnit];
    }
    function applyCustom() { rule = customRule(); }

    // ---------- Speichern ----------
    function parseTime(s) {
        var m = /^(\d\d?)[:.]?(\d\d)$/.exec(Core.trim(s)) || /^(\d\d?)$/.exec(Core.trim(s));
        if (!m) return null;
        var h = +m[1], mi = m[2] !== undefined ? +m[2] : 0;
        if (h > 23 || mi > 59) return null;
        return (h < 10 ? "0" : "") + h + ":" + (mi < 10 ? "0" : "") + mi;
    }
    function currentForm() { return { date: date, time: otherTime ? (parseTime(otherField.text) || "") : time, rule: rule }; }
    function save() {
        var title = Core.trim(titleField.text);
        if (title === "") {
            errorText = "Bitte zuerst eintragen, was zu tun ist.";
            titleField.forceActiveFocus();
            return;
        }
        if (otherTime) {
            var t = parseTime(otherField.text);
            if (otherField.text !== "" && !t) { errorText = "„" + otherField.text + "“ ist keine Uhrzeit – bitte z. B. 15:30 eingeben."; return; }
            time = t || "";
        }
        var values = { title: title, date: date, time: time, rule: rule,
                       notes: notes.map(function (n) { return Core.trim(n); }).filter(function (n) { return n !== ""; }) };
        app.saveForm(mode, line, orig, values);
        visible = false;
    }

    mainItem: Rectangle {
        id: panel
        color: P.formBg
        radius: Kirigami.Units.gridUnit * 0.75
        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.inherit: false
        implicitWidth: Kirigami.Units.gridUnit * 30
        implicitHeight: content.implicitHeight + Kirigami.Units.gridUnit * 2
        Keys.onEscapePressed: dlg.visible = false

        FileDialog {
            id: fileDialog
            title: "Datei anhängen"
            fileMode: FileDialog.OpenFiles
            onAccepted: {
                var n = dlg.notes.slice();
                selectedFiles.forEach(function (u) { n.push(decodeURIComponent(u.toString().replace(/^file:\/\//, ""))); });
                dlg.notes = n;
            }
        }

        component Caption: PC3.Label {
            color: P.done
            font.weight: Font.DemiBold
            Layout.topMargin: Kirigami.Units.largeSpacing
        }
        component Field: PC3.TextField {
            color: P.text
            topPadding: Kirigami.Units.smallSpacing * 2
            bottomPadding: Kirigami.Units.smallSpacing * 2
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.largeSpacing
            placeholderTextColor: P.done
            background: Rectangle {
                radius: Kirigami.Units.gridUnit * 0.4
                color: P.field
                border.width: 1
                border.color: parent.activeFocus ? P.check(Plasmoid.configuration.accent) : P.fieldBorder
            }
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                // an der Titelzeile ziehen = Fenster verschieben (KDE uebernimmt das Ziehen)
                DragHandler { target: null; onActiveChanged: if (active) dlg.startSystemMove() }
                HoverHandler { cursorShape: Qt.SizeAllCursor }
                PC3.Label {
                    text: dlg.mode === "edit" ? "Punkt bearbeiten" : "Neuer Punkt"
                    color: P.text
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.45
                    font.bold: true
                    Layout.fillWidth: true
                }
                Chip { flat: true; iconName: "window-close"; textColor: P.done; onClicked: dlg.visible = false }
            }

            Caption { text: "Was ist zu tun?"; Layout.topMargin: Kirigami.Units.smallSpacing }
            Field {
                id: titleField
                Layout.fillWidth: true
                placeholderText: "Hier eintippen – Enter speichert"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.15
                font.weight: Font.DemiBold
                onAccepted: dlg.save()               // Enter = sofort speichern
                onTextChanged: if (text !== "") dlg.errorText = ""
            }

            // ---------- Datum ----------
            Caption { text: "Fällig am" }
            Flow {
                id: dateFlow
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                readonly property string t0: Core.iso(Core.today())
                readonly property string t1: Core.iso(Core.addDays(Core.today(), 1))
                readonly property string t7: Core.iso(Core.addDays(Core.today(), 7))
                readonly property bool other: dlg.date !== "" && [t0, t1, t7].indexOf(dlg.date) < 0
                Chip { text: "Kein Datum"; selected: dlg.date === ""; onClicked: { dlg.date = ""; dlg.calOpen = false } }
                Chip { text: "Heute"; selected: dlg.date === dateFlow.t0; onClicked: { dlg.date = dateFlow.t0; dlg.calOpen = false } }
                Chip { text: "Morgen"; selected: dlg.date === dateFlow.t1; onClicked: { dlg.date = dateFlow.t1; dlg.calOpen = false } }
                Chip { text: "In 1 Woche"; selected: dlg.date === dateFlow.t7; onClicked: { dlg.date = dateFlow.t7; dlg.calOpen = false } }
                Chip {
                    iconName: "view-calendar"
                    text: dateFlow.other ? Core.dotDate(Core.fromIso(dlg.date)) + Core.fromIso(dlg.date).getFullYear() : "Datum wählen"
                    selected: dateFlow.other || dlg.calOpen
                    onClicked: dlg.calOpen = !dlg.calOpen
                }
            }

            // Kalender
            ColumnLayout {
                visible: dlg.calOpen
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                RowLayout {
                    Layout.fillWidth: true
                    Chip { flat: true; iconName: "go-previous"; textColor: P.note; onClicked: { if (dlg.calMonth === 0) { dlg.calMonth = 11; dlg.calYear-- } else dlg.calMonth-- } }
                    PC3.Label { text: Core.MONTHS[dlg.calMonth] + " " + dlg.calYear; color: P.text; font.bold: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                    Chip { flat: true; iconName: "go-next"; textColor: P.note; onClicked: { if (dlg.calMonth === 11) { dlg.calMonth = 0; dlg.calYear++ } else dlg.calMonth++ } }
                }
                QQC2.DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: Qt.locale("de_DE")
                    delegate: PC3.Label { text: shortName; horizontalAlignment: Text.AlignHCenter; color: P.done; font: Kirigami.Theme.smallFont }
                }
                QQC2.MonthGrid {
                    Layout.fillWidth: true
                    month: dlg.calMonth
                    year: dlg.calYear
                    locale: Qt.locale("de_DE")
                    delegate: Rectangle {
                        required property var model
                        readonly property string dayIso: Core.iso(Core.dayOf(model.year, model.month + 1, model.day))
                        readonly property bool sel: dayIso === dlg.date
                        implicitHeight: Kirigami.Units.gridUnit * 1.7
                        radius: Kirigami.Units.gridUnit * 0.4
                        color: sel ? P.check(Plasmoid.configuration.accent) : (dayHover.hovered ? P.chipHover : "transparent")
                        border.width: model.today && !sel ? 1 : 0
                        border.color: P.accent(Plasmoid.configuration.accent)
                        opacity: model.month === dlg.calMonth ? 1 : 0.3
                        HoverHandler { id: dayHover; cursorShape: Qt.PointingHandCursor }
                        PC3.Label {
                            anchors.centerIn: parent
                            text: model.day
                            color: parent.sel ? P.text : (model.today ? P.accent(Plasmoid.configuration.accent) : P.note)
                            font.bold: parent.sel
                        }
                    }
                    onClicked: (d) => { dlg.date = Core.iso(Core.dayOf(d.getFullYear(), d.getMonth() + 1, d.getDate())); dlg.calOpen = false }
                }
            }

            // ---------- Uhrzeit ----------
            Caption { text: "Uhrzeit (mit Erinnerung)" }
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Chip { text: "Keine"; selected: dlg.time === "" && !dlg.otherTime; onClicked: { dlg.time = ""; dlg.otherTime = false } }
                Repeater {
                    model: dlg.times
                    delegate: Chip { text: modelData; selected: dlg.time === modelData && !dlg.otherTime; onClicked: { dlg.time = modelData; dlg.otherTime = false } }
                }
                Chip {
                    text: "Andere"; selected: dlg.otherTime
                    onClicked: { dlg.otherTime = true; otherField.text = dlg.time; otherField.forceActiveFocus() }
                }
                Field {
                    id: otherField
                    visible: dlg.otherTime
                    width: Kirigami.Units.gridUnit * 5
                    placeholderText: "15:30"
                    onAccepted: dlg.save()
                }
            }

            // ---------- Wiederholen ----------
            Caption { text: "Wiederholen" }
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: dlg.ruleNames.length
                    delegate: Chip {
                        text: dlg.ruleNames[index]
                        selected: dlg.rule === dlg.standardRules[index] && !dlg.custOpen
                        onClicked: { dlg.rule = dlg.standardRules[index]; dlg.custOpen = false }
                    }
                }
                Chip {
                    text: "Individuell …"
                    selected: dlg.custOpen || (dlg.rule !== "" && dlg.standardRules.indexOf(dlg.rule) < 0)
                    onClicked: { dlg.custOpen = !dlg.custOpen; if (dlg.custOpen) { if (dlg.rule !== "") dlg.loadCustom(dlg.rule); dlg.applyCustom() } }
                }
            }
            ColumnLayout {
                visible: dlg.custOpen
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Label { text: "Alle"; color: P.note; height: Kirigami.Units.gridUnit * 1.8; verticalAlignment: Text.AlignVCenter }
                    Chip { text: "−"; onClicked: { if (dlg.custN > 1) dlg.custN--; dlg.custDays = [false, false, false, false, false, false, false]; dlg.applyCustom() } }
                    PC3.Label { text: dlg.custN; color: P.text; font.bold: true; width: Kirigami.Units.gridUnit * 1.5; height: Kirigami.Units.gridUnit * 1.8; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    Chip { text: "+"; onClicked: { if (dlg.custN < 99) dlg.custN++; dlg.custDays = [false, false, false, false, false, false, false]; dlg.applyCustom() } }
                    Repeater {
                        model: dlg.units
                        delegate: Chip {
                            text: modelData
                            selected: dlg.custUnit === index && dlg.custDays.indexOf(true) < 0
                            onClicked: { dlg.custUnit = index; dlg.custDays = [false, false, false, false, false, false, false]; dlg.applyCustom() }
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Label { text: "oder an:"; color: P.note; height: Kirigami.Units.gridUnit * 1.8; verticalAlignment: Text.AlignVCenter }
                    Repeater {
                        model: dlg.wds
                        delegate: Chip {
                            text: modelData
                            selected: dlg.custDays[index]
                            onClicked: { var d = dlg.custDays.slice(); d[index] = !d[index]; dlg.custDays = d; dlg.applyCustom() }
                        }
                    }
                }
            }

            // ---------- Zusammenfassung ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                implicitHeight: summaryLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.gridUnit * 0.4
                color: P.soft(Plasmoid.configuration.accent)
                PC3.Label {
                    id: summaryLabel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Kirigami.Units.largeSpacing
                    wrapMode: Text.Wrap
                    text: dlg.errorText !== "" ? dlg.errorText : Core.summary(dlg.currentForm())
                    color: dlg.errorText !== "" ? P.over : P.accent(Plasmoid.configuration.accent)
                }
            }

            // ---------- Notizen ----------
            Caption { text: "Notizen, Links, Dateien" }
            Repeater {
                model: dlg.notes.length
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Field {
                        Layout.fillWidth: true
                        text: dlg.notes[index]
                        onTextEdited: { var n = dlg.notes; n[index] = text; }
                    }
                    Chip {
                        flat: true; iconName: "edit-delete-remove"; textColor: P.done
                        onClicked: { var n = dlg.notes.slice(); n.splice(index, 1); dlg.notes = n }
                    }
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Chip { iconName: "list-add"; text: "Notiz / Link"; onClicked: { var n = dlg.notes.slice(); n.push(""); dlg.notes = n } }
                Chip { iconName: "mail-attachment"; text: "Datei"; onClicked: fileDialog.open() }
            }

            // ---------- Knoepfe ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit
                Chip {
                    visible: dlg.mode === "edit"
                    text: dlg.confirmDelete ? "Wirklich löschen?" : "Löschen"
                    textColor: P.danger
                    fill: dlg.confirmDelete ? "#3CFF7373" : P.chip
                    onClicked: {
                        if (!dlg.confirmDelete) { dlg.confirmDelete = true; return; }
                        dlg.app.deleteTask(dlg.line, dlg.orig);
                        dlg.visible = false;
                    }
                }
                Item { Layout.fillWidth: true }
                Chip { text: "Abbrechen"; onClicked: dlg.visible = false }
                Chip { text: "Speichern"; selected: true; onClicked: dlg.save() }
            }
        }
    }
}
