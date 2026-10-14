import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

Pill {
    id: root

    required property var screen
    property color foreground: Theme.panelFg

    signal overviewRequested

    fg: foreground
    inset: Theme.panelButtonBorder

    readonly property var list: WorkspaceService.workspacesFor(screen)
    readonly property int count: list.length
    readonly property int activeIndex: Math.max(0, list.findIndex(w => w.active))
    readonly property real multiplier: Theme.workspaceDotWidthMultiplier(count)

    property real position: activeIndex
    Behavior on position {
        enabled: !Theme.gameMode
        NumberAnimation {
            duration: Theme.durationWorkspaceSwitch
            easing.type: Theme.easeOutCubic
        }
    }

    property bool settled: false
    Timer {
        interval: 1
        running: true
        onTriggered: root.settled = true
    }

    onClicked: m => {
        if (!m || m.button === Qt.LeftButton)
            root.overviewRequested();
    }

    readonly property bool numbered: SettingsService.barWorkspaceStyle === "numbers"

    Row {
        visible: root.numbered
        spacing: Theme.workspaceDotSpacing

        Repeater {
            model: root.numbered ? root.list : []

            PanelText {
                required property var modelData

                text: modelData.index
                color: root.fg
                opacity: modelData.active ? 1 : Theme.workspaceDotInactiveOpacity
                font.weight: modelData.active ? Theme.fontWeightBold : Theme.fontWeightNormal
            }
        }
    }

    Item {
        visible: !root.numbered
        implicitWidth: dots.implicitWidth + Theme.basePadding
        implicitHeight: Theme.workspaceDotSize

        Row {
            id: dots
            anchors.centerIn: parent
            spacing: Theme.workspaceDotSpacing

            Repeater {
                model: root.count

                Item {
                    id: dot

                    required property int index

                    readonly property real expansion: Math.max(0, Math.min(1, 1 - Math.abs(index - root.position)))
                    property real appear: root.settled ? 0 : 1

                    width: Math.round(Theme.workspaceDotSize * (1 + (root.multiplier - 1) * expansion))
                    height: Theme.workspaceDotSize
                    scale: appear

                    Component.onCompleted: appear = 1

                    Behavior on appear {
                        enabled: !Theme.gameMode
                        NumberAnimation {
                            duration: Theme.durationWorkspaceDot
                            easing.type: Theme.easeOutCubic
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusPill
                        color: root.fg
                        opacity: Theme.workspaceDotInactiveOpacity + (1 - Theme.workspaceDotInactiveOpacity) * dot.expansion
                        scale: Theme.workspaceDotInactiveScale + (1 - Theme.workspaceDotInactiveScale) * dot.expansion

                        Behavior on color {
                            enabled: !Theme.gameMode
                            ColorAnimation {
                                duration: Theme.durationPanel
                                easing.type: Theme.easeOutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    property bool wheelBlocked: false

    onWheeled: (dx, dy, x, y) => {
        if (wheelBlocked || dy === 0)
            return;
        WorkspaceService.switchRelative(dy > 0 ? -1 : 1, root.screen);
        wheelBlocked = true;
        cooldown.restart();
    }
    Timer {
        id: cooldown
        interval: Theme.durationWorkspaceSwitch
        onTriggered: root.wheelBlocked = false
    }
}
