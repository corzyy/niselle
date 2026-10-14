import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

Pill {
    id: root

    property color foreground: Theme.panelFg

    readonly property var toplevel: WorkspaceService.activeWindow
    readonly property string appClass: toplevel ? (toplevel.lastIpcObject.class ?? "") : ""
    readonly property var entry: {
        const t = toplevel;
        return t ? (AppsService.runningApps.find(r => r.windows.indexOf(t) >= 0)?.entry ?? null) : null;
    }
    readonly property string liveName: entry ? entry.name : appClass
    readonly property string liveIcon: entry && Quickshell.iconPath(entry.icon, true) !== "" ? entry.icon : "application-x-executable"

    property string appName: ""
    property string iconName: "application-x-executable"
    onLiveNameChanged: {
        if (liveName !== "") {
            clearTimer.stop();
            appName = liveName;
            iconName = liveIcon;
        } else {
            clearTimer.restart();
        }
    }
    onLiveIconChanged: if (liveName !== "")
        iconName = liveIcon
    Component.onCompleted: {
        appName = liveName;
        iconName = liveIcon;
    }
    Timer {
        id: clearTimer
        interval: 400
        onTriggered: root.appName = ""
    }

    fg: foreground
    inset: Theme.panelButtonBorder
    interactive: false
    visible: appName !== ""

    Icon {
        visible: SettingsService.barAppShowIcon || !SettingsService.barAppShowName
        name: root.iconName
        symbolic: false
        size: Theme.iconSize
    }

    PanelText {
        visible: SettingsService.barAppShowName
        text: root.appName
        color: root.fg
        elide: Text.ElideRight
        Layout.maximumWidth: Theme.panelAppNameMaxWidth
    }
}
