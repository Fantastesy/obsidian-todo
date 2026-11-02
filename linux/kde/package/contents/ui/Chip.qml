// Knopf im Windows-Stil: abgerundete Flaeche mit feinem Rand, ausgewaehlt in der Akzentfarbe.
// iconButton: dunkler, deckender Symbol-Knopf (Zahnrad, Pfeil, Bueroklammer) wie in der Windows-Liste.
import QtQuick
import org.kde.plasma.plasmoid
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/palette.js" as P

Rectangle {
    id: chip
    property bool selected: false
    property alias text: label.text
    property string iconName: ""
    property string iconFallback: ""
    property color textColor: selected ? P.text : P.note
    property bool iconButton: false
    property bool flat: false        // alt: wie iconButton
    property real fontScale: 1.0
    property bool bold: true
    readonly property bool asIcon: iconButton || flat
    readonly property color accentFill: P.check(Plasmoid.configuration.accent)
    signal clicked()

    implicitWidth: Math.max(implicitHeight, row.implicitWidth + (label.visible ? Kirigami.Units.largeSpacing * 2.2 : Kirigami.Units.smallSpacing * 3))
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.9)
    radius: Kirigami.Units.gridUnit * 0.45
    property color fill: selected ? accentFill
        : asIcon ? (hov.hovered ? P.btnHover : P.btnFill)
        : (hov.hovered ? P.chipHover : P.chip)
    color: fill
    border.width: 1
    border.color: selected ? accentFill : (asIcon ? P.btnStroke : P.chipStroke)
    // gedrueckt: kurz heller
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#30FFFFFF"
        visible: tap.pressed
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            visible: chip.iconName !== ""
            source: chip.iconName
            fallback: chip.iconFallback
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            color: chip.textColor
            isMask: true
        }
        PC3.Label {
            id: label
            color: chip.textColor
            font.weight: chip.bold ? Font.DemiBold : Font.Normal
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * chip.fontScale
            visible: text !== ""
        }
    }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: chip.clicked() }
}
