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
    property bool debugEdge: false      // nur fuer Tests: Streifen rot zeigen

    function show() { if (active) { leaveTimer.stop(); shown = true; } }
    function hide() { leaveTimer.stop(); revealTimer.stop(); revealing = false; shown = false; }
    // Maus am Rand
    // solange die Maus am Rand bleibt, bleibt die Liste offen; erst wenn sie Rand und Liste verlaesst, hinaus
    property bool onEdge: false
    function edgeHit() { onEdge = true; leaveTimer.stop(); show(); }
    function edgeLeft() { onEdge = false; if (shown && !mouseInside && !revealing) leaveTimer.restart(); }
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
    function revealEnd() { revealing = false; if (!mouseInside && !onEdge) leaveTimer.restart(); }

    onActiveChanged: { if (!active) hide(); placeEdge(); }
    onOnLeftChanged: placeEdge()
    onAreaChanged: placeEdge()
    // Plasma uebernimmt die Position eines offenen Fensters erst beim naechsten Erscheinen:
    // Streifen kurz ausblenden und an der neuen Stelle wieder zeigen
    function placeEdge() {
        edge.visible = false;
        if (active) edgeTimer.restart();
    }
    Timer { id: edgeTimer; interval: 50; onTriggered: edge.visible = side.active }
    Component.onCompleted: placeEdge()

    // ---------- Animation (selbst gemacht wie unter Windows; KWins Gleiten ist nicht ueberall an) ----------
    // slide: 0 = draussen, 1 = ganz drin. Dauer je nach Tempo.
    readonly property int slideMs: Plasmoid.configuration.speed === "fast" ? 130
        : Plasmoid.configuration.speed === "slow" ? 380 : 220
    property real slide: 0
    Behavior on slide {
        NumberAnimation { duration: side.slideMs; easing.type: side.shown ? Easing.OutCubic : Easing.InCubic }
    }
    onShownChanged: slide = shown ? 1 : 0

    Timer {
        id: leaveTimer
        interval: side.leaveMs
        // waehrend in der Liste getippt wird oder ein Dateidialog offen ist, nicht wegfahren
        onTriggered: if (side.app.editing) restart(); else if (!side.mouseInside && !side.onEdge && !side.revealing) side.shown = false
    }
    Timer { id: revealTimer; onTriggered: side.revealEnd() }

    // ---------- Rand-Streifen ----------
    PlasmaCore.Dialog {
        id: edge
        visible: false
        type: PlasmaCore.Dialog.Notification
        // kein Qt.WindowStaysOnTopHint: damit macht libplasma ein Dock-Fenster daraus, das KWin beim
        // Abmelden nicht schliessen kann ("Plasma-Arbeitsflaechenbereich hat sich nicht beendet").
        // Als Benachrichtigungs-Fenster liegt es trotzdem ueber normalen Fenstern.
        flags: Qt.WindowDoesNotAcceptFocus | Qt.FramelessWindowHint
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: false
        x: side.onLeft ? side.gx : side.gx + side.area.width - 1
        // nur der mittlere Teil des Rands: oben und unten je 20 % frei (Ecken loesen nichts aus)
        y: side.gy + Math.floor(side.area.height * 0.2)
        mainItem: Item {
            width: 1
            height: side.area.height - 2 * Math.floor(side.area.height * 0.2)
            // fast durchsichtig: ganz durchsichtige Flaechen bemerkt die Maus nicht ueberall
            Rectangle { anchors.fill: parent; color: side.debugEdge ? "red" : "#02000000" }
            HoverHandler { onHoveredChanged: hovered ? side.edgeHit() : side.edgeLeft() }
        }
    }

    // ---------- Panel ----------
    // Das Fenster reicht bis an den Bildschirmrand; darin gleitet die Liste von aussen herein.
    readonly property int panelW: Plasmoid.configuration.listWidth + margin
    readonly property Item panelItem: panel.mainItem   // nur fuer Tests (Bild der Liste)
    PlasmaCore.Dialog {
        id: panel
        visible: side.shown || side.slide > 0
        type: PlasmaCore.Dialog.Notification
        // kein Qt.WindowStaysOnTopHint, siehe Rand-Streifen
        flags: Qt.FramelessWindowHint
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: false
        x: side.onLeft ? side.gx : side.gx + side.area.width - side.panelW
        y: side.gy + side.margin
        mainItem: Item {
            width: side.panelW
            height: side.area.height - 2 * side.margin
            clip: true
            // ganzes Panel-Fenster (bis an den Bildschirmrand) zaehlt als "Maus in der Liste"
            HoverHandler { onHoveredChanged: hovered ? side.enter() : side.leave() }
            // sichtbarer Kasten nur so hoch wie die Eintraege; das Fenster darum bleibt bildschirmhoch,
            // damit die Liste offen bleibt, wenn die Maus vom Rand (Bildschirmmitte) hinauf faehrt
            TodoView {
                width: Plasmoid.configuration.listWidth
                height: Math.min(implicitHeight, parent.height)
                // drin: margin vom Rand; draussen: ganz hinter dem Rand
                x: side.onLeft
                    ? side.margin - (Plasmoid.configuration.listWidth + side.margin) * (1 - side.slide)
                    : (Plasmoid.configuration.listWidth + side.margin) * (1 - side.slide)
                app: side.app
                inPanel: true
            }
        }
    }
}