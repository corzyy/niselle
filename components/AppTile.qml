import QtQuick
import qs

Item {
    id: root

    property string icon: ""
    property string label: ""
    property real iconSize: Theme.appGridIconSizes[0]
    property bool showLabel: true
    property bool running: false
    property bool hovered: false
    property bool pressed: false
    property bool checked: false
    property bool dropTarget: false
    property bool raised: false
    property color bg: Theme.systemBase
    property bool expandOnHover: true
    property real iconScale: 1
    property real labelOpacity: 1
    property bool focused: activeFocus

    property Component customIcon: null

    readonly property real lineHeight: probe.implicitHeight
    readonly property real naturalSize: Math.max(iconSize + 2 * Theme.overviewTilePadding, iconSize + 2 * Theme.overviewTilePadding + (showLabel ? Theme.overviewTileSpacing + lineHeight : 0))

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

    Text {
        id: oneLine
        visible: false
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBase
    }

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
