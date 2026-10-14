import QtQuick
import QtQuick.Effects
import qs

Item {
    id: root

    property real fadeOffset: Theme.messageViewFade
    property alias contentHeight: flick.contentHeight
    property alias contentY: flick.contentY
    readonly property alias flick: flick
    default property alias content: holder.data

    readonly property real fadeTop: flick.contentY > 0 ? Math.min(flick.contentY, fadeOffset) : 0
    readonly property real fadeBottom: flick.contentY < flick.contentHeight - flick.height ? Math.min(flick.contentHeight - flick.height - flick.contentY, fadeOffset) : 0

    signal userScrolled

    function scrollTo(value) {
        scrollAnimation.to = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), value));
        scrollAnimation.restart();
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick
        layer.enabled: (root.fadeTop > 0 || root.fadeBottom > 0) && contentHeight > height
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
        }

        Item {
            id: holder
            width: flick.width
            height: flick.contentHeight
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse
            onWheel: event => {
                scrollAnimation.stop();
                root.userScrolled();
                const max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - Math.sign(event.angleDelta.y) * flick.height / 6));
                scrollbar.poke();
            }
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: flick
        property: "contentY"
        duration: Theme.gameMode ? 0 : Theme.durationGroupExpand
        easing.type: Theme.easeOutQuad
    }

    Rectangle {
        id: fadeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.fadeTop > 0 ? "transparent" : "black"
            }
            GradientStop {
                position: root.height > 0 ? root.fadeTop / root.height : 0
                color: "black"
            }
            GradientStop {
                position: root.height > 0 ? 1 - root.fadeBottom / root.height : 1
                color: "black"
            }
            GradientStop {
                position: 1
                color: root.fadeBottom > 0 ? "transparent" : "black"
            }
        }
    }

    Item {
        id: scrollbar

        readonly property bool shown: handleMouse.containsMouse || handleMouse.pressed || flick.moving || flick.dragging

        function poke() {
            hideTimer.restart();
            poked = true;
        }
        property bool poked: false

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.scrollbarWidth
        visible: flick.contentHeight > flick.height + 1
        opacity: shown || poked ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationScrollbar
                easing.type: Theme.easeTransition
            }
        }

        Timer {
            id: hideTimer
            interval: 1000
            onTriggered: scrollbar.poked = false
        }

        Rectangle {
            readonly property real inner: parent.height - 2 * Theme.scrollbarHandleBorder
            readonly property real range: Math.max(flick.contentHeight - flick.height, 1)

            x: Theme.scrollbarHandleBorder
            width: parent.width - 2 * Theme.scrollbarHandleBorder
            height: Math.max(width, inner * flick.height / Math.max(flick.contentHeight, 1))
            y: Theme.scrollbarHandleBorder + (inner - height) * (flick.contentY / range)
            radius: width / 2
            color: handleMouse.pressed ? Theme.scrollbarHandleActive : (handleMouse.containsMouse ? Theme.scrollbarHandleHover : Theme.scrollbarHandle)
        }

        MouseArea {
            id: handleMouse
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: mouse => {
                if (pressed)
                    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, mouse.y / height * (flick.contentHeight - flick.height)));
            }
        }
    }
}
