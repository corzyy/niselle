import QtQuick
import qs

// Zifferblatt für die Weltuhren [GNOME-Mockup calendar-popover]: Ring, zwölf Striche, Stunden- und Minutenzeiger.
// `time` ist ein Date, dessen lokale Felder die anzuzeigende Zeit enthalten (WorldClocksService.timeAt).
Item {
    id: root

    property date time: new Date()
    property real size: 40
    property color color: Theme.fgColor

    readonly property real minuteAngle: time.getMinutes() * 6
    readonly property real hourAngle: (time.getHours() % 12) * 30 + time.getMinutes() * 0.5

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, root.size / 24)
        border.color: root.color
    }

    Repeater {
        model: 12

        Item {
            required property int index

            anchors.fill: parent
            rotation: index * 30

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.size * 0.09
                width: Math.max(1, root.size / 28)
                height: index % 3 === 0 ? root.size * 0.09 : root.size * 0.05
                color: root.color
                opacity: 0.6
            }
        }
    }

    // Stundenzeiger
    Item {
        anchors.fill: parent
        rotation: root.hourAngle

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height
            width: Math.max(1.5, root.size / 16)
            height: root.size * 0.24
            radius: width / 2
            color: root.color
        }
    }
    // Minutenzeiger
    Item {
        anchors.fill: parent
        rotation: root.minuteAngle

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height
            width: Math.max(1.5, root.size / 20)
            height: root.size * 0.36
            radius: width / 2
            color: root.color
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.max(3, root.size / 10)
        height: width
        radius: width / 2
        color: root.color
    }
}
