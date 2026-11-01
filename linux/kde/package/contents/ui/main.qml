// Obsidian Todo - KDE-Plasma-Widget.
// Liest/schreibt die Todo.md ueber kleine Shell-Befehle (cat/base64/mv), weil QML selbst keine Dateien schreiben kann.
// Pfade kommen aus ~/.config/obsidian-todo/config (schreibt das Setup).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "../code/todo.js" as Core

PlasmoidItem {
    id: root

    // ---------- Einstellungen ----------
    property string todoFile: ""
    property string archiveFile: ""
    property string vaultName: ""
    property string home: ""
    property bool configMissing: false
    property bool hasNotifySend: false

    // ---------- Zustand ----------
    property var model: null          // Ergebnis von Core.parse
    property string lastContent: ""
    property bool fileMissing: false
    property var rows: []              // aufbereitete Punkte fuer die Ansicht
    property var openNotes: ({})       // Text eines Punkts -> Notizen aufgeklappt
    property bool collapsed: false
    property int maxItems: 15
    property var reminderState: ({ notified: {}, snoozed: {} })
    property bool busy: false
    property var queue: []
    // waehrend in der Liste getippt wird, nicht neu aufbauen (sonst verschwindet das Eingabefeld)
    property bool editing: false
    property bool pendingRebuild: false
    onEditingChanged: if (!editing && pendingRebuild) rebuildRows()

    Plasmoid.icon: "checkbox"
    // eigener dunkler, durchsichtiger Hintergrund wie unter Windows statt Plasma-Rahmen
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: "Obsidian Todo"
    toolTipSubText: model ? model.openCount + " offen" : ""
    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 10
    // Desktop und senkrechte Seitenleiste: ganze Liste; waagerechte Leiste: Symbol mit Zahl
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? compactRepresentation : fullRepresentation
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // ---------- Einblenden beim Anmelden / Aufwachen / Entsperren ----------
    // In der Seitenleiste (automatisch ausblenden) faehrt KDE die Leiste heraus, solange das Widget
    // "Aufmerksamkeit" meldet: 10 Sekunden pro offenem Punkt, hoechstens 2 Minuten.
    property bool revealed: false
    property bool startupRevealDone: false
    function reveal() {
        if (!model || model.openCount === 0) return;
        revealTimer.interval = Math.min(120, 10 * model.openCount) * 1000;
        revealed = true;
        Plasmoid.status = PlasmaCore.Types.RequiresAttentionStatus;
        revealTimer.restart();
    }
    function hideReveal() {
        revealTimer.stop();
        revealed = false;
        Plasmoid.status = PlasmaCore.Types.ActiveStatus;
    }
    Timer { id: revealTimer; onTriggered: root.hideReveal() }

    // Aufwachen: waehrend Standby laufen keine Timer -> grosse Luecke zwischen zwei Durchlaeufen
    property double lastTick: Date.now()
    property string lastLocked: ""
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            var now = Date.now();
            if (now - root.lastTick > 60000) root.reveal();
            root.lastTick = now;
            // Entsperren: LockedHint der Sitzung wechselt von yes auf no
            root.run('loginctl show-session "${XDG_SESSION_ID:-self}" -p LockedHint --value 2>/dev/null', function (code, out) {
                var locked = out.trim();
                if (root.lastLocked === "yes" && locked === "no") root.reveal();
                if (locked) root.lastLocked = locked;
            });
        }
    }

    // ---------- Rechtsklick-Menue ----------
    function runSetup(args) {
        // abgekoppelt starten: beim Umschalten wird dieses Widget selbst entfernt
        run('s="${XDG_DATA_HOME:-$HOME/.local/share}/obsidian-todo/setup.sh"; [ -f "$s" ] && setsid bash "$s" ' + args + ' >/dev/null 2>&1 < /dev/null &');
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action { text: "Neuer Punkt"; icon.name: "list-add"; onTriggered: root.openForm(null) },
        PlasmaCore.Action { text: "In Obsidian öffnen"; icon.name: "document-open"; onTriggered: root.openInObsidian() },
        PlasmaCore.Action { isSeparator: true },
        PlasmaCore.Action { text: "Anzeige: Seitenleiste rechts"; icon.name: "view-split-left-right"; onTriggered: root.runSetup("--mode panel") },
        PlasmaCore.Action { text: "Anzeige: auf dem Desktop"; icon.name: "user-desktop"; onTriggered: root.runSetup("--mode desktop") },
        PlasmaCore.Action { text: "Anzeige: beides"; icon.name: "view-list-details"; onTriggered: root.runSetup("--mode both") },
        PlasmaCore.Action { isSeparator: true },
        PlasmaCore.Action { text: "Obsidian To-do entfernen …"; icon.name: "edit-delete"; onTriggered: root.runSetup("--uninstall") }
    ]

    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: "checkbox"
        }
        PC3.Label {
            visible: root.model && root.model.openCount > 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: root.model ? root.model.openCount : ""
            font.pixelSize: Math.max(8, parent.height * 0.4)
            font.bold: true
        }
    }

    fullRepresentation: TodoView {
        app: root
    }

    FormDialog {
        id: form
        app: root
    }

    // Tastenkuerzel des Widgets (Setup traegt Meta+Shift+T ein) -> neuer Punkt
    Connections {
        target: Plasmoid
        function onActivated() { root.openForm(null) }
    }

    // ---------- Shell-Befehle ----------
    P5Support.DataSource {
        id: exec
        engine: "executable"
        property var callbacks: ({})
        onNewData: (sourceName, data) => {
            var cb = callbacks[sourceName];
            delete callbacks[sourceName];
            disconnectSource(sourceName);
            if (cb) cb(data["exit code"], data["stdout"] || "", data["stderr"] || "");
        }
    }
    property int execCounter: 0
    function run(cmd, cb) {
        execCounter++;
        var key = cmd + " # " + execCounter;   // jede Quelle braucht einen eigenen Namen
        exec.callbacks[key] = cb || null;
        exec.connectSource(key);
    }
    function q(s) { return Core.shq(s); }

    function readFile(path, cb) {
        run('f=' + q(path) + '; if [ -f "$f" ]; then base64 -w0 "$f"; else echo __MISSING__; fi', function (code, out) {
            if (code !== 0) return cb(null);
            out = out.trim();
            cb(out === "__MISSING__" ? null : Core.fromBase64(out));
        });
    }
    function writeFile(path, content, cb) {
        var tmp = path + ".obsidian-todo.tmp";
        run('printf %s ' + q(Core.toBase64(content)) + ' | base64 -d > ' + q(tmp) + ' && mv -f ' + q(tmp) + ' ' + q(path),
            function (code) { cb(code === 0); });
    }

    // ---------- Einstellungen laden ----------
    function loadConfig() {
        run('printf "HOME=%s\\n" "$HOME"; cat "$HOME/.config/obsidian-todo/config" 2>/dev/null; command -v notify-send >/dev/null && echo NOTIFY=1; printf "TEST=%s\\n" "$OBSIDIAN_TODO_TEST"',
            function (code, out) {
                var cfg = {};
                out.split("\n").forEach(function (l) {
                    var i = l.indexOf("=");
                    if (i > 0) cfg[l.substring(0, i).trim()] = l.substring(i + 1).trim();
                });
                home = cfg.HOME || "";
                todoFile = cfg.TODO_FILE || "";
                archiveFile = cfg.ARCHIVE_FILE || "";
                vaultName = cfg.VAULT_NAME || "";
                hasNotifySend = cfg.NOTIFY === "1";
                configMissing = todoFile === "";
                refresh();
                // nur fuer automatische Tests: OBSIDIAN_TODO_TEST=new|edit oeffnet das Formular
                if (cfg.TEST) testTimer.mode = cfg.TEST;
            });
    }

    // ---------- Lesen / Anzeigen ----------
    function refresh() {
        if (configMissing || busy || todoFile === "") return;
        readFile(todoFile, function (c) {
            if (busy) return;
            if (c === null) { fileMissing = true; return; }
            fileMissing = false;
            if (c === lastContent && model) return;
            setContent(c);
            // abgehakte wiederkehrende Punkte (auch aus Obsidian) weiterschieben
            if (Core.rollRecurring(model, new Date())) enqueue(function (m) { return rollOp(m); });
        });
    }

    function setContent(c) {
        lastContent = c;
        model = Core.parse(c);
        rebuildRows();
        // nach der Anmeldung einmal einblenden
        if (!startupRevealDone) { startupRevealDone = true; reveal(); }
    }

    function dueInfo(text, done) {
        var d = Core.dueOf(text);
        if (!d) return { label: "", state: "" };
        return Core.dueLabel(d, done, Core.timeOf(text));
    }

    function rebuildRows() {
        if (editing) { pendingRebuild = true; return; }
        pendingRebuild = false;
        if (!model) { rows = []; return; }
        var out = [];
        var shown = model.display.slice(0, maxItems);
        shown.forEach(function (t) {
            var di = dueInfo(t.text, t.done);
            var subsDone = 0;
            var subs = t.subs.map(function (s) {
                if (s.done) subsDone++;
                var sd = dueInfo(s.text, s.done);
                return { line: s.line, orig: model.lines[s.line], done: s.done, title: Core.taskText(s.text),
                         dueLabel: sd.label, dueState: sd.state };
            });
            var notes = t.notes.map(function (n, k) {
                return { line: t.noteLines[k], orig: model.lines[t.noteLines[k]], text: Core.noteText(n),
                         link: Core.linkOf(n, vaultName, home) || "" };
            });
            out.push({ key: t.text, line: t.line, orig: model.lines[t.line], done: t.done, title: Core.taskText(t.text),
                       dueLabel: di.label, dueState: di.state, repeat: !!Core.ruleOf(t.text),
                       subs: subs, subsDone: subsDone, notes: notes, open: !!openNotes[t.text] });
        });
        rows = out;
    }

    Timer {
        interval: 2000; running: !root.configMissing; repeat: true
        onTriggered: root.refresh()
    }
    // jede Minute neu zeichnen (heute 15:00 wird rechtzeitig rot) und Erinnerungen pruefen
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: false
        onTriggered: { root.rebuildRows(); root.checkReminders(); }
    }

    // ---------- Aenderungen (nacheinander, jeweils auf frisch gelesener Datei) ----------
    // op(model) aendert model.lines und gibt zurueck:
    //   false/undefined = nichts zu tun, true = Todo speichern,
    //   { archive: [bloecke], after: function(model) } = erst Archiv schreiben, dann after() und Todo speichern
    function enqueue(op) {
        queue.push(op);
        if (!busy) nextOp();
    }
    function nextOp() {
        if (queue.length === 0) { busy = false; return; }
        busy = true;
        var op = queue.shift();
        readFile(todoFile, function (c) {
            if (c === null) { fileMissing = true; return nextOp(); }
            var m = Core.parse(c);
            var r = op(m);
            if (!r) { setContent(c); return nextOp(); }
            var saveTodo = function () {
                var nc = Core.serialize(m);
                writeFile(todoFile, nc, function (ok) {
                    if (ok) setContent(nc);
                    nextOp();
                });
            };
            if (r === true) return saveTodo();
            // erst ins Archiv, nur bei Erfolg die Todo.md aendern
            readFile(archiveFile, function (ac) {
                writeFile(archiveFile, Core.appendArchive(ac || "", r.archive, new Date()), function (ok) {
                    if (!ok) return nextOp();
                    r.after(m);
                    saveTodo();
                });
            });
        });
    }

    function rollOp(m) {
        var r = Core.rollRecurring(m, new Date());
        if (!r) return false;
        return { archive: r.blocks, after: function (mm) { Core.applyChanges(mm, r.changes); } };
    }

    function toggle(line, orig) {
        enqueue(function (m) {
            var t = Core.findTask(m, line, orig);
            if (!t) return false;
            Core.flip(m, t.line, new Date());
            // wiederkehrend: gleich weiterschieben (nach dem Speichern als eigene Aenderung)
            if (Core.ruleOf(t.text)) enqueue(function (mm) { return rollOp(mm); });
            return true;
        });
    }
    function toggleSub(taskLine, taskOrig, line, orig) {
        enqueue(function (m) {
            var t = Core.findTask(m, taskLine, taskOrig);
            if (!t) return false;
            var ln = Core.findChild(m, t, line, orig);
            if (ln < 0) return false;
            Core.flip(m, ln, new Date());
            return true;
        });
    }
    function toggleNotes(key) {
        var e = openNotes;
        if (e[key]) delete e[key]; else e[key] = true;
        openNotes = e;
        rebuildRows();
    }
    function cleanup() {
        enqueue(function (m) {
            var r = Core.cleanup(m, new Date());
            if (!r) return false;
            return { archive: r.blocks, after: function (mm) { Core.removeLines(mm, r.remove); } };
        });
    }
    // Notiz / Unteraufgabe / Datei hinzufuegen
    function addChild(taskLine, taskOrig, kind, text) {
        text = Core.trim(text || "");
        if (!text) return;
        enqueue(function (m) {
            var t = Core.findTask(m, taskLine, taskOrig);
            if (!t) return false;
            Core.addChild(m, t, kind, text, new Date());
            if (kind !== "sub") { var e = openNotes; e[t.text] = true; openNotes = e; }
            return true;
        });
    }
    // Notiz / Unteraufgabe aendern (leer = loeschen)
    function editChild(taskLine, taskOrig, line, orig, text) {
        enqueue(function (m) {
            var t = Core.findTask(m, taskLine, taskOrig);
            if (!t) return false;
            var ln = Core.findChild(m, t, line, orig);
            if (ln < 0) return false;
            Core.editChild(m, ln, text, new Date());
            return true;
        });
    }
    function childInput(line) { return model ? Core.childInput(model, line) : ""; }

    // ---------- Formular ----------
    function openForm(row) {
        if (row) {
            var t = model ? Core.findTask(model, row.line, row.orig) : null;
            if (!t) return;
            form.openEdit(Core.formOf(t), row.line, row.orig);
        } else {
            form.openNew();
        }
    }
    function saveForm(mode, line, orig, values) {
        enqueue(function (m) {
            if (mode === "new") {
                var text = Core.addTask(m, values, new Date());
                if (values.notes && values.notes.length) { var e = openNotes; e[text] = true; openNotes = e; }
                return true;
            }
            var t = Core.findTask(m, line, orig);
            if (!t) return false;
            var wasOpen = openNotes[t.text];
            var nt = Core.editTask(m, t, values);
            if (wasOpen) { var e2 = openNotes; e2[nt] = true; openNotes = e2; }
            return true;
        });
    }
    function deleteTask(line, orig) {
        enqueue(function (m) {
            var t = Core.findTask(m, line, orig);
            if (!t) return false;
            var block = Core.blockOf(m, t, "-", new Date());
            return { archive: [block], after: function (mm) {
                var t2 = Core.findTask(mm, line, orig);
                if (t2) Core.removeTask(mm, t2);
            } };
        });
    }

    // ---------- Oeffnen ----------
    function openInObsidian(path) {
        Qt.openUrlExternally("obsidian://open?path=" + encodeURIComponent(path || todoFile));
    }
    function openLink(url) { if (url) Qt.openUrlExternally(url); }

    // ---------- Erinnerungen ----------
    function checkReminders() {
        if (!model) return;
        Core.dueReminders(model, reminderState, new Date()).forEach(function (r) {
            var body = r.title + " (" + r.time + ")";
            if (hasNotifySend) {
                run('notify-send -a "Obsidian Todo" -i checkbox -u critical --action=done=Erledigt --action=snooze="In 15 Min nochmal" --wait "Todo fällig" ' + q(body),
                    function (code, out) {
                        var a = out.trim();
                        if (a === "done") doneByKey(r.key);
                        else if (a === "snooze") reminderState.snoozed[r.key] = Date.now() + 15 * 60000;
                    });
            } else {
                run('kdialog --title "Todo fällig" --passivepopup ' + q(body) + ' 60');
            }
        });
    }
    function doneByKey(key) {
        enqueue(function (m) {
            for (var i = 0; i < m.display.length; i++) {
                var t = m.display[i];
                if (t.text === key && !t.done) {
                    Core.flip(m, t.line, new Date());
                    if (Core.ruleOf(t.text)) enqueue(function (mm) { return rollOp(mm); });
                    return true;
                }
            }
            return false;
        });
    }

    // ---------- Automatische Updates (update.sh prueft selbst hoechstens alle 6 Stunden) ----------
    function checkUpdate() {
        run('u="$HOME/.local/share/obsidian-todo/update.sh"; [ -x "$u" ] && "$u" >/dev/null 2>&1; true');
    }
    Timer {
        interval: 6 * 3600 * 1000; running: true; repeat: true
        onTriggered: root.checkUpdate()
    }
    Timer {
        interval: 60000; running: true; repeat: false
        onTriggered: root.checkUpdate()
    }

    Timer {
        id: testTimer
        property string mode: ""
        interval: 1500; running: mode !== ""
        onTriggered: {
            if (mode === "add") root.saveForm("new", -1, "", { title: "Testpunkt", date: "", time: "15:00", rule: "", notes: ["https://kde.org"] });
            else if (mode === "toggle") root.toggle(root.rows[0].line, root.rows[0].orig);
            else if (mode === "cleanup") root.cleanup();
            else if (mode === "grab") root.fullRepresentationItem.grabToImage(function (r) { r.saveToFile(root.home + "/grab.png"); });
            else root.openForm(mode === "edit" && root.rows.length ? root.rows[0] : null);
        }
    }

    Component.onCompleted: loadConfig()
}
