import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.services
import qs.modules.datemenu

PanelWindow {
    id: root

    property var current: null
    property bool shown: false

    readonly property var banner: NotificationService.banner
    readonly property bool onThisScreen: NotificationService.bannerScreen === "" ? OverviewService.isPrimary(screen) : NotificationService.bannerScreen === (screen ? screen.name : "")
    readonly property bool critical: current !== null && current.urgency === NotificationUrgency.Critical

    function sync() {
        if (root.banner && root.onThisScreen) {
            root.current = root.banner;
            root.shown = true;
        } else {
            root.shown = false;
        }
    }
    onBannerChanged: sync()
    onOnThisScreenChanged: sync()

    onShownChanged: {
        if (shown) {
            hideAnim.stop();
            if (bin.opacity === 0) {
                bin.y = -bin.height;
                bin.scale = Theme.notificationBannerScaleFrom;
            }
            showAnim.restart();
        } else {
            showAnim.stop();
            hideAnim.restart();
        }
    }

    anchors.top: true
    margins.top: Theme.panelHeight
    implicitWidth: Theme.notificationBannerWidth + 2 * (Theme.notificationBannerMargin + Theme.notificationWindowMargin)
    implicitHeight: Theme.notificationWindowHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || showAnim.running || hideAnim.running

    mask: Region {
        item: bin
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: bin
            property: "opacity"
            to: 1
            duration: Theme.gameMode ? 0 : Theme.durationNotification
            easing.type: Theme.easeOutQuad
        }
        NumberAnimation {
            target: bin
            property: "y"
            to: 0
            duration: Theme.gameMode ? 0 : Theme.durationNotification
            easing.type: Theme.easeOutBack
        }
        NumberAnimation {
            target: bin
            property: "scale"
            to: 1
            duration: Theme.gameMode ? 0 : Theme.durationNotification
            easing.type: Theme.easeOutBack
        }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation {
            target: bin
            property: "opacity"
            to: 0
            duration: Theme.gameMode ? 0 : Theme.durationNotification
            easing.type: Theme.easeOutBack
        }
        NumberAnimation {
            target: bin
            property: "y"
            to: -bin.height
            duration: Theme.gameMode ? 0 : Theme.durationNotification
            easing.type: Theme.easeOutBack
        }
    }

    Item {
        id: bin

        readonly property bool hovered: hover.hovered && root.shown

        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.notificationBannerWidth + 2 * Theme.notificationBannerMargin
        height: message.height + stack.extra
        opacity: 0
        y: -height
        transformOrigin: Item.Center

        onHoveredChanged: NotificationService.setBannerHovered(hovered)

        HoverHandler {
            id: hover
        }

        Item {
            id: stack

            readonly property int levels: Math.min(NotificationService.queueCount, Theme.groupMaxVisibleStacked - 1)
            property real extra: {
                let e = 0, o = Theme.groupStackHeightOffset;
                for (let i = 0; i < levels; i++) {
                    e += o;
                    o /= Theme.groupStackHeightReduction;
                }
                return e;
            }

            Repeater {
                model: stack.levels

                Rectangle {
                    required property int index
                    readonly property real offset: {
                        let e = 0, o = Theme.groupStackHeightOffset;
                        for (let i = 0; i <= index; i++) {
                            e += o;
                            o /= Theme.groupStackHeightReduction;
                        }
                        return e;
                    }
                    x: Theme.notificationBannerMargin + (index + 1) * Theme.groupStackWidthOffset
                    y: Theme.notificationBannerMargin
                    width: Theme.notificationBannerWidth - 2 * (index + 1) * Theme.groupStackWidthOffset
                    height: message.height - 2 * Theme.notificationBannerMargin + offset
                    radius: Theme.radiusModal
                    color: index === 0 ? Theme.messageSecondBg : Theme.messageLowerBg
                    border.width: index === 0 ? 0 : 1
                    border.color: Theme.messageLowerBorder
                }
            }
        }

        NotificationMessage {
            id: message

            width: parent.width
            height: Math.max(implicitHeight, Theme.notificationBannerMinHeight + 2 * Theme.notificationBannerMargin)
            notification: root.current
            visible: root.current !== null
            margin: Theme.notificationBannerMargin
            radius: Theme.radiusModal
            shadowColor: Theme.shadowColor
            shadowBlur: Theme.notificationBannerShadowBlur
            shadowOffsetY: Theme.notificationBannerShadowY
            expandable: false
            closeOpacity: bin.hovered ? 1 : 0
            expanded: bin.hovered || root.critical

            onClicked: NotificationService.activate(root.current)
            onCloseRequested: NotificationService.dismiss(root.current)
        }
    }
}
