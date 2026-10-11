import QtQuick
import qs

// Kachel eines Icons mit Titel (.overview-tile mit BaseIcon) [_app-grid.scss:21-37, iconGrid.js: BaseIcon, appDisplay.js: AppIcon]:
// Radius 24, Padding 12, Icon und Titel mit 6 px Abstand, Titel einzeilig mit Auslassung; bei Zeiger oder Fokus klappt ein
// zu langer Titel auf (200 ms, zurück 100 ms) und die Kachel wächst nach unten über die darunter liegenden Kacheln.
// Icon: Themenname oder Dateipfad; eigener Inhalt (Ordnervorschau) über `customIcon`.
//
// Die Größe legt das Raster fest. Zustände (hovered, pressed, …) kommen vom Besitzer, der die Mausfläche hat.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property real iconSize: Theme.appGridIconSizes[0]
    property bool showLabel: true
    // Läuft die App (Punkt unter dem Icon)
    property bool running: false
    property bool hovered: false
    property bool pressed: false
    // Hervorgehoben (:selected / :highlighted)
    property bool checked: false
    property bool dropTarget: false
    // Ordner: dauerhaft gefüllter Hintergrund
    property bool raised: false
    property color bg: Theme.systemBase
    property bool expandOnHover: true
    // Skalierung des Icons (Ordnervorschau beim Ziehen darüber)
    property real iconScale: 1
    property real labelOpacity: 1
    // Kachel soll Tastaturfokus zeigen
    property bool focused: activeFocus

    // Eigener Icon-Inhalt statt `icon` (Ordnervorschau); füllt die Icon-Fläche
    property Component customIcon: null

    // Höhe einer Titelzeile und Kantenlänge, die eine Kachel dieser Icongröße mindestens braucht
    readonly property real lineHeight: probe.implicitHeight
    readonly property real naturalSize: Math.max(iconSize + 2 * Theme.overviewTilePadding, iconSize + 2 * Theme.overviewTilePadding + (showLabel ? Theme.overviewTileSpacing + lineHeight : 0))

    // Titel aufgeklappt: Hover/Fokus bei abgeschnittenem Titel [appDisplay.js:1891-1928]
    readonly property bool truncated: oneLine.implicitWidth > root.width - 2 * Theme.overviewTilePadding
    readonly property bool expanded: showLabel && expandOnHover && (hovered || focused) && truncated
    readonly property real extraHeight: Math.max(0, wrapProbe.implicitHeight - probe.implicitHeight)

    Text {
        id: probe
        visible: false
        text: "Ag"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

    // Titel in einer Zeile, zum Messen der Abschneidung
    Text {
        id: oneLine
        visible: false
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

    // Titel über mehrere Zeilen, für die Höhe der aufgeklappten Kachel
    Text {
        id: wrapProbe
        visible: false
        width: root.width - 2 * Theme.overviewTilePadding
        text: root.label
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

    property real expandProgress: expanded ? 1 : 0

    Behavior on expandProgress {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: root.expanded ? Theme.durationAppIconTitleExpand : Theme.durationAppIconTitleCollapse
            easing.type: Theme.easeOut
        }
    }

    // Die Kachel wächst über die Zelle hinaus; z hebt sie über die Nachbarn
    z: expandProgress > 0 ? 1 : 0

    Tile {
        id: base
        x: 0
        y: 0
        width: root.width
        height: root.height + root.extraHeight * root.expandProgress
        interactive: false
        system: true
        raised: root.raised
        bg: root.bg
        radius: Theme.radiusOverviewTile
        hovered: root.hovered
        pressed: root.pressed
        checked: root.checked
        focused: root.focused
        dropTarget: root.dropTarget
    }

    Item {
        id: iconBox
        x: (root.width - width) / 2
        y: Theme.overviewTilePadding
        width: root.iconSize
        height: root.iconSize
        scale: root.iconScale

        Icon {
            anchors.fill: parent
            visible: root.icon !== "" && root.customIcon === null
            name: root.icon
            size: root.iconSize
            symbolic: false
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.customIcon
        }
    }

    Text {
        id: label
        visible: root.showLabel
        x: Theme.overviewTilePadding
        y: Theme.overviewTilePadding + root.iconSize + Theme.overviewTileSpacing
        width: root.width - 2 * Theme.overviewTilePadding
        height: root.lineHeight + root.extraHeight * root.expandProgress
        opacity: root.labelOpacity
        text: root.label
        color: Theme.systemFg
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: root.expanded ? Text.Wrap : Text.NoWrap
        elide: root.expanded ? Text.ElideNone : Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
        font.weight: Theme.fontWeightNormal
    }

    // Laufpunkt [_app-grid.scss:45-51, appDisplay.js:2951-2967, 2995-3005]
    Rectangle {
        visible: root.running
        width: Theme.dashDotSize
        height: Theme.dashDotSize
        radius: Theme.dashDotSize
        color: Theme.dashDot
        x: (root.width - width) / 2
        y: root.height - Theme.overviewTilePadding - height + Theme.appDotOffset
    }
}
