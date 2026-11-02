// Seitenleiste wie unter Windows (src/sidebar.lua):
// - ein unsichtbarer, 1 Pixel schmaler Streifen am rechten (oder linken) Rand des Bildschirms, immer im Vordergrund
// - beruehrt die Maus den Rand, gleitet die Liste als bildschirmhohes Panel herein (Gleiten macht KWin)
// - verlaesst die Maus das Panel, gleitet es nach kurzer Zeit wieder hinaus
// Bei "Beides" blendet die Liste auf dem Desktop dabei sanft aus (main.qml, deskOpacity) und danach wieder ein.
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

Item {
    id: side
    property var app

    readonly property string mode: Plasmoid.configuration.mode
    readonly property bool active: mode === "sidebar" || mode === "both"
    readonly property bool onLeft: Plasmoid.configuration.side === "left"
    readonly property int margin: 8
    // Arbeitsbereich des Bildschirms (ohne Leisten), in globalen Koordinaten
    readonly property rect area: Plasmoid.containment && Plasmoid.containment.availableScreenRect.width > 0
        ? Plasmoid.containment.availableScreenRect : Qt.rect(0, 0, Screen.width, Screen.height)
    readonly property int gx: Screen.virtualX + area.x
    readonly property int gy: Screen.virtualY + area.y
    readonly property int leaveMs: Plasmoid.configuration.speed === "fast" ? 300
        : Plasmoid.configuration.speed === "slow" ? 2000 : 1000

    property bool shown: false
    property bool revealing: false
    property bool mouseInside: false

    function show() { if (active) { leaveTimer.stop(); shown = true; } }
    function hide() { leaveTimer.stop(); revealTimer.stop(); revealing = false; shown = false; }
    // Maus am Rand
    function edgeHit() {
        show();
        // falls die Maus gar nicht ins Panel geht, trotzdem wieder hinaus
        if (!mouseInside) leaveTimer.restart();
    }
    function enter() { mouseInside = true; leaveTimer.stop(); }
    function leave() { mouseInside = false; if (shown && !revealing) leaveTimer.restart(); }
    // Einblenden (Anmelden/Aufwachen/Entsperren) fuer so viele Sekunden
    function reveal(seconds) {
        if (!active) return;
        revealing = true;
        show();
        revealTimer.interval = seconds * 1000;
        revealTimer.restart();
    }
    function revealEnd() { revealing = false; if (!mouseInside) leaveTimer.restart(); }

    onActiveChanged: if (!active) hide()

    Timer {
        id: leaveTimer
        interval: side.leaveMs + (side.mouseInside ? 0 : 1000)
        // waehrend in der Liste getippt wird oder ein Dateidialog offen ist, nicht wegfahren
        onTriggered: if (side.app.editing) restart(); else if (!side.mouseInside && !side.revealing) side.shown = false
    }
    Timer { id: revealTimer; onTriggered: side.revealEnd() }

    // ---------- Rand-Streifen ----------
    PlasmaCore.Dialog {
        id: edge
        visible: side.active
        type: PlasmaCore.Dialog.Notification
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: false
        x: side.onLeft ? side.gx : side.gx + side.area.width - 1
        y: side.gy
        mainItem: Item {
            width: 1
            height: side.area.height
            // fast durchsichtig: ganz durchsichtige Flaechen bemerkt die Maus nicht ueberall
            Rectangle { anchors.fill: parent; color: "#02000000" }
            HoverHandler { onHoveredChanged: if (hovered) side.edgeHit() }
        }
    }

    // ---------- Panel ----------
    PlasmaCore.Dialog {
        id: panel
        visible: side.shown
        type: PlasmaCore.Dialog.Notification
        flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
        // KWin laesst das Fenster von dieser Kante hereingleiten
        location: side.onLeft ? PlasmaCore.Types.LeftEdge : PlasmaCore.Types.RightEdge
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: false
        x: side.onLeft ? side.gx + side.margin : side.gx + side.area.width - Plasmoid.configuration.listWidth - side.margin
        y: side.gy + side.margin
        mainItem: Item {
            width: Plasmoid.configuration.listWidth
            height: side.area.height - 2 * side.margin
            TodoView {
                anchors.fill: parent
                app: side.app
                inPanel: true
            }
        }
    }
}
