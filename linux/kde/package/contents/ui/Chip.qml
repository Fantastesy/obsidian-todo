// Knopf im Windows-Stil: abgerundete Flaeche, ausgewaehlt lila
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/palette.js" as P

Rectangle {
    id: chip
    property bool selected: false
    property alias text: label.text
    property string iconName: ""
    property color textColor: selected ? P.text : P.note
    property bool flat: false        // nur beim Drueberfahren sichtbar (Symbol-Knoepfe)
    property color fill: selected ? P.check : (hov.hovered ? P.chipHover : (flat ? "transparent" : P.chip))
    property bool bold: selected
    signal clicked()

    implicitWidth: row.implicitWidth + (label.visible ? Kirigami.Units.largeSpacing * 2 : Kirigami.Units.smallSpacing * 3)
    implicitHeight: Kirigami.Units.gridUnit * 1.8
    radius: Kirigami.Units.gridUnit * 0.4
    color: fill

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            visible: chip.iconName !== ""
            source: chip.iconName
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            color: chip.textColor
            isMask: true
        }
        PC3.Label {
            id: label
            color: chip.textColor
            font.bold: chip.bold
            visible: text !== ""
        }
    }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.clicked() }
}
