import QtQuick
import qs

// Tag im Monatskalender (.calendar-day) [_calendar:73-117]: 3em rund, 2px Rand, %smaller fett, %flat_button.
// Heute: %default_button (Akzent). Ausgewählt (:selected): flacher Aktiv-Zustand. Termine: Punkt unten
// (calendar-today(-light).svg, auf die Zellgröße skaliert). Ziffern zweistellig ("%d").
Item {
    id: root

    property date date
    property bool today: false
    property bool selected: false
    property bool otherMonth: false
    property bool weekend: false
    property bool hasEvents: false

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked

    implicitWidth: Theme.calendarDaySize + 2 * Theme.calendarDayMargin
    implicitHeight: Theme.calendarDaySize + 2 * Theme.calendarDayMargin
    activeFocusOnTab: true

    Rectangle {
        id: circle

        anchors.centerIn: parent
        width: Theme.calendarDaySize
        height: Theme.calendarDaySize
        radius: Theme.radiusPill
        color: {
            if (root.today)
                return Theme.buttonBg(Theme.buttonState(root.hovered, root.pressed, false, true, false), {
                    "bg": Theme.accentColor,
                    "fg": Theme.accentFg,
                    "style": "default"
                });
            const state = (root.pressed || root.selected) ? (root.hovered ? "activeHover" : "active") : (root.hovered ? "hover" : "normal");
            return state === "normal" ? "transparent" : Theme.buttonBg(state, {
                "style": "flat"
            });
        }

        // Fokusring
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: Theme.focusRingWidth
            border.color: root.today ? Theme.focusRingDefault : Theme.focusRing
            visible: root.activeFocus
        }

        Text {
            anchors.centerIn: parent
            text: String(root.date.getDate()).padStart(2, "0")
            color: root.today ? Theme.accentFg : (root.otherMonth ? Theme.calendarOtherMonthFg : (root.weekend ? Theme.insensitiveFg : Theme.fgColor))
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeSmaller
            font.weight: root.otherMonth && !root.today ? Theme.fontWeightNormal : Theme.fontWeightBold
            font.features: ({
                    "tnum": 1
                })
        }

        Rectangle {
            visible: root.hasEvents
            readonly property real r: Theme.calendarEventDotRadius * circle.width
            x: circle.width / 2 - r
            y: Theme.calendarEventDotY * circle.height - r
            width: 2 * r
            height: 2 * r
            radius: r
            color: root.today ? Theme.calendarEventDotToday : Theme.calendarEventDot
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: circle
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
