import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property string icon: ""
    property real value: 0
    property real maximumValue: 1
    property var marks: []
    property bool iconReactive: false
    property bool menuEnabled: false
    property bool menuOpen: false
    property string menuIcon: "go-next-symbolic"

    readonly property bool pressed: drag.pressed
    readonly property real barHeight: 36

    signal moved(real value)
    signal dragStarted
    signal dragEnded
    signal iconClicked
    signal menuClicked

    property var _unsnapped: null
    property real _shown: value

    implicitWidth: row.implicitWidth
    implicitHeight: barHeight

    function _clamp(v) {
        return Math.max(0, Math.min(v, maximumValue));
    }
    function _set(v) {
        let next = _clamp(v);
        for (const mark of marks) {
            if (Math.abs(next - mark) < 0.04) {
                next = mark;
                break;
            }
        }
        if (next === _shown)
            return;
        _shown = next;
        moved(next);
    }
    function _applyDelta(delta) {
        _unsnapped = _clamp((_unsnapped ?? _shown) + delta);
        _set(_unsnapped);
    }
    function _moveTo(x) {
        const r = barHeight / 2;
        _unsnapped = _clamp((x - r) / Math.max(1, track.width - barHeight) * maximumValue);
        _set(_unsnapped);
    }

    onValueChanged: {
        if (!pressed) {
            _shown = value;
            if (_unsnapped !== null && Math.abs(_unsnapped - value) > 0.04)
                _unsnapped = null;
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.quickSliderSpacing

        Item {
            id: track

            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: 2 * root.barHeight
            activeFocusOnTab: true

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: Theme.sliderTrough
                border.width: 1
                border.color: Theme.dark ? Theme.alpha(Theme.light1, 0.04) : Theme.alpha(Theme.dark5, 0.05)
            }
            Rectangle {
                id: fill
                width: root.barHeight + (track.width - root.barHeight) * Math.max(0, Math.min(root._shown / root.maximumValue, 1))
                height: parent.height
                radius: Theme.radiusPill
                color: Theme.accentColor
                Behavior on width {
                    enabled: !Theme.gameMode && !root.pressed
                    NumberAnimation {
                        duration: Theme.motionFast
                        easing.type: Theme.easeOut
                    }
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                onPressed: m => {
                    track.forceActiveFocus(Qt.MouseFocusReason);
                    root.dragStarted();
                    root._moveTo(m.x);
                }
                onPositionChanged: m => {
                    if (pressed)
                        root._moveTo(m.x);
                }
                onReleased: root.dragEnded()
                onWheel: w => {
                    root._applyDelta(w.angleDelta.y / 120 * 0.02);
                    w.accepted = true;
                }
            }

            Item {
                width: root.barHeight
                height: root.barHeight

                Icon {
                    anchors.centerIn: parent
                    name: root.icon
                    color: Theme.accentFg
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.iconReactive
                    onClicked: root.iconClicked()
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -Theme.focusRingWidth
                radius: Theme.radiusPill
                color: "transparent"
                border.width: Theme.focusRingWidth
                border.color: Theme.focusRing
                opacity: track.activeFocus ? 1 : 0
            }

            Keys.onLeftPressed: root._applyDelta(-0.1)
            Keys.onRightPressed: root._applyDelta(0.1)
        }

        IconButton {
            visible: root.menuEnabled
            Layout.alignment: Qt.AlignVCenter
            icon: root.menuIcon
            padding: (root.barHeight - iconSize) / 2
            onClicked: root.menuClicked()

            Behavior on rotation {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.durationQuickMenu
                    easing.type: Theme.easeOutQuad
                }
            }
            rotation: root.menuOpen ? 90 : 0
        }
    }
}
