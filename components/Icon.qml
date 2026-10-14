import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

Item {
    id: root

    property string name: ""
    property color color: Theme.fgColor
    property real size: Theme.iconSize
    property bool symbolic: true
    property bool asynchronous: false

    readonly property bool flagActive: SettingsService.bigYahoo && name !== ""
    readonly property string flagSource: "file://" + Quickshell.shellPath("assets/icons/israel-flag.svg")

    implicitWidth: size
    implicitHeight: size

    readonly property string resolved: {
        if (name === "")
            return "";
        if (name.startsWith("/"))
            return "file://" + name;
        if (name.includes("://"))
            return name;
        return Quickshell.iconPath(name, true);
    }

    IconImage {
        id: image
        anchors.fill: parent
        source: root.resolved
        asynchronous: root.asynchronous
        visible: !root.symbolic && !root.flagActive
        layer.enabled: root.symbolic
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        visible: root.symbolic && !root.flagActive && image.status === Image.Ready
        brightness: 0.8
        colorization: 1.0
        colorizationColor: root.color
    }

    IconImage {
        anchors.fill: parent
        source: root.flagActive ? root.flagSource : ""
        visible: root.flagActive
    }
}
