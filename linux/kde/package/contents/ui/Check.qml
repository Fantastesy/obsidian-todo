// Kaestchen wie unter Windows: abgerundet, offen mit hellem Rahmen, abgehakt lila mit Haken
import QtQuick
import org.kde.kirigami as Kirigami
import "../code/palette.js" as P

Rectangle {
    id: box
    property bool checked: false
    property int size: Kirigami.Units.gridUnit
    signal toggled()

    implicitWidth: size
    implicitHeight: size
    radius: size / 4
    color: checked ? P.check : (hov.hovered ? P.hover : "transparent")
    border.width: checked ? 0 : 1.5
    border.color: P.box

    // Haken selbst gezeichnet (Symbol-Icons werden nicht ueberall weiss eingefaerbt)
    Canvas {
        anchors.fill: parent
        visible: box.checked
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = "white";
            ctx.lineWidth = Math.max(1.5, width / 8);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(width * 0.24, height * 0.52);
            ctx.lineTo(width * 0.43, height * 0.70);
            ctx.lineTo(width * 0.77, height * 0.32);
            ctx.stroke();
        }
        onWidthChanged: requestPaint()
        onVisibleChanged: requestPaint()
    }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: box.toggled() }
}
