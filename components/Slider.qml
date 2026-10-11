import QtQuick
import qs

// GNOME-Slider (St.Slider über St.BarLevel) [slider.js, barLevel.js:117-190, _slider.scss]:
// 4px-Trog mit runden Enden, Füllung in Akzentfarbe, Griff als Kreis (Radius 8) in der Textfarbe,
// Overdrive-Bereich in Destructive-Farbe mit 1px-Trenner. Bedienung: Ziehen, Mausrad (0.02/Raste),
// Pfeiltasten (0.1), Einrasten an `marks` (4 %).
Item {
    id: root

    property real value: 0
    property real maximumValue: 1
    property real overdriveStart: maximumValue
    // Werte, an denen der Griff einrastet [slider.js:8, 87-94]
    property var marks: []

    readonly property bool pressed: mouse.pressed
    readonly property bool hovered: mouse.containsMouse
    readonly property real handleRadius: Theme.sliderHandleSize / 2
    // Griff-Zentrum und Balkenende [slider.js:116-117, barLevel.js:123-133]
    readonly property real barRadius: Math.min(width, Theme.sliderTroughHeight) / 2
    readonly property real handleX: handleRadius + (width - 2 * handleRadius) * value / maximumValue
    readonly property real endX: maximumValue > 0 ? barRadius + (width - 2 * barRadius) * value / maximumValue : 0
    readonly property real overdriveX: barRadius + (width - 2 * barRadius) * overdriveStart / maximumValue
    readonly property bool overdriveActive: overdriveStart !== maximumValue
    readonly property real separatorWidth: overdriveActive ? 1 : 0 // -barlevel-overdrive-separator-width [_slider.scss:15]

    // Nur bei Benutzerinteraktion
    signal moved(real value)
    signal dragStarted
    signal dragEnded

    property var _unsnapped: null

    implicitWidth: 2 * handleRadius
    implicitHeight: 2 * handleRadius
    activeFocusOnTab: true

    function _clamp(v) {
        return Math.max(0, Math.min(v, maximumValue));
    }

    function _snap(v) {
        for (const mark of marks) {
            if (Math.abs(v - mark) < 0.04)
                return mark;
        }
        return v;
    }

    function _set(v) {
        const next = _snap(_clamp(v));
        if (next === value)
            return;
        value = next;
        moved(next);
    }

    // Verschiebt ausgehend vom ungesnappten Wert, damit man Einrastpunkte per Rad/Taste verlassen kann [slider.js:171-182]
    function _applyDelta(delta) {
        const base = _unsnapped ?? value;
        _unsnapped = _clamp(base + delta);
        _set(_unsnapped);
    }

    function step(nSteps) {
        _applyDelta(nSteps * 0.02);
    }

    function _moveHandle(x) {
        let v;
        if (x < handleRadius)
            v = 0;
        else if (x > width - handleRadius)
            v = 1;
        else
            v = (x - handleRadius) / (width - 2 * handleRadius);
        _unsnapped = v * maximumValue;
        _set(_unsnapped);
    }

    onValueChanged: {
        if (!pressed && _unsnapped !== null && Math.abs(_unsnapped - value) > 0.04)
            _unsnapped = null;
    }

    // Trog
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.sliderTroughHeight
        radius: root.barRadius
        color: Theme.sliderTrough
    }

    // Aktive Füllung: links rund, rechts gerade (abgeschnitten am Ende bzw. am Overdrive-Trenner)
    Item {
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.sliderTroughHeight
        width: Math.max(0, Math.min(root.endX, root.overdriveX - root.separatorWidth / 2))
        clip: true
        visible: root.value > 0

        Rectangle {
            width: parent.width + 2 * root.barRadius
            height: parent.height
            radius: root.barRadius
            color: Theme.accentColor
        }
    }

    // Overdrive-Bereich [barLevel.js:177-190]
    Rectangle {
        readonly property real startX: Math.min(root.endX, root.overdriveX) + root.separatorWidth / 2
        visible: root.overdriveActive && root.value > root.overdriveStart
        anchors.verticalCenter: parent.verticalCenter
        x: startX
        width: Math.max(0, root.endX - startX)
        height: Theme.sliderTroughHeight
        color: Theme.destructive
    }

    // Griff
    Rectangle {
        x: root.handleX - root.handleRadius
        y: (root.height - height) / 2
        width: Theme.sliderHandleSize
        height: Theme.sliderHandleSize
        radius: width / 2
        color: (root.hovered || root.pressed) ? Theme.sliderHandleHover : Theme.sliderHandle
    }

    // Fokusring um den ganzen Slider (.slider-bin:focus) [_quick-settings.scss:143-147]
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Theme.sliderBinPadding
        radius: Theme.radiusPill
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRing
        opacity: root.activeFocus ? 1 : 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onPressed: m => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.dragStarted();
            root._moveHandle(m.x);
        }
        onPositionChanged: m => {
            if (pressed)
                root._moveHandle(m.x);
        }
        onReleased: root.dragEnded()
        onWheel: w => {
            // diskrete Rastung: eine Raste = ein Schritt [slider.js:66-73]
            root.step(w.angleDelta.y / 120);
            w.accepted = true;
        }
    }

    Keys.onLeftPressed: root._applyDelta(-0.1)
    Keys.onRightPressed: root._applyDelta(0.1)
}
