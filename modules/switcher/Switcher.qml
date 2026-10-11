import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Alt+Tab-Umschalter (.switcher-popup): Pille mit den Apps (oder Fenstern der App) mittig auf dem primären Monitor.
// Hält den Tastaturfokus, solange er offen ist: Loslassen der Modifikatortaste aktiviert die Auswahl, Esc bricht ab,
// Pfeile/Tab wählen, Enter aktiviert, ein Klick auf ein Symbol aktiviert es, ein Klick daneben bricht ab.
// Weiterschalten mit Tab selbst kommt als Hyprland-Kürzel (`niselle switcher next`) über SwitcherService.
PanelWindow {
    id: root

    readonly property bool onThisScreen: OverviewService.isPrimary(screen)
    readonly property bool active: SwitcherService.open && onThisScreen

    readonly property int count: SwitcherService.items.length
    readonly property real iconSize: Math.max(48, Math.min(96, Math.floor((screen.width * 0.9 - 80) / Math.max(1, count)) - 32))

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: active || box.opacity > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-switcher"
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Liegt die Auswahl lange brach (Modifikator-Loslassen verpasst), abbrechen statt hängen zu bleiben
    Connections {
        target: SwitcherService
        function onIndexChanged() {
            guard.restart();
        }
    }
    Timer {
        id: guard
        interval: 10000
        running: root.active
        onTriggered: SwitcherService.close()
    }

    // Klick ins Leere: abbrechen
    MouseArea {
        anchors.fill: parent
        enabled: root.active
        onClicked: SwitcherService.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.active

        readonly property var releaseKeys: [Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control]

        Keys.onPressed: event => {
            event.accepted = true;
            switch (event.key) {
            case Qt.Key_Escape:
                SwitcherService.close();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                SwitcherService.commit();
                break;
            case Qt.Key_Right:
            case Qt.Key_Down:
                SwitcherService.next();
                break;
            case Qt.Key_Left:
            case Qt.Key_Up:
                SwitcherService.prev();
                break;
            case Qt.Key_Tab:
                SwitcherService.next();
                break;
            case Qt.Key_Backtab:
                SwitcherService.prev();
                break;
            case Qt.Key_QuoteLeft:
            case Qt.Key_AsciiTilde:
                SwitcherService.window();
                break;
            default:
                event.accepted = false;
            }
        }
        Keys.onReleased: event => {
            if (releaseKeys.indexOf(event.key) >= 0) {
                event.accepted = true;
                SwitcherService.commit();
            }
        }
    }

    Rectangle {
        id: box

        anchors.centerIn: parent
        width: Math.min(parent.width * 0.92, list.naturalWidth + 2 * 20)
        height: list.height + label.implicitHeight + 3 * 12 + 2 * 8
        radius: 28
        color: Theme.osdBg
        border.width: Theme.osdBorderWidth
        border.color: Theme.osdBorders
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.96

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationPopover
                easing.type: Theme.easeOutQuad
            }
        }
        Behavior on scale {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationPopover
                easing.type: Theme.easeOutQuad
            }
        }

        // Absorbiert Klicks auf die Pille selbst (sonst bräche der Klick darunter ab)
        MouseArea {
            anchors.fill: parent
        }

        Flow {
            id: list

            readonly property real maxWidth: root.width * 0.92 - 40

            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(naturalWidth, maxWidth)
            spacing: 4

            readonly property real naturalWidth: root.count * (root.iconSize + 32 + spacing) - spacing

            Repeater {
                model: SwitcherService.items

                Rectangle {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool current: index === SwitcherService.index

                    width: root.iconSize + 32
                    height: root.iconSize + 32
                    radius: 20
                    color: current ? Theme.alpha(Theme.osdFg, 0.18) : cellMouse.containsMouse ? Theme.alpha(Theme.osdFg, 0.08) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        name: cell.modelData.icon
                        symbolic: false
                        size: root.iconSize
                    }

                    // Zahl der Fenster, wenn die App mehrere hat
                    Rectangle {
                        visible: SwitcherService.mode === "apps" && cell.modelData.windows.length > 1
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: Math.max(height, countText.implicitWidth + 10)
                        height: countText.implicitHeight + 2
                        radius: height / 2
                        color: Theme.alpha(Theme.osdFg, 0.85)

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: cell.modelData.windows.length
                            color: Theme.osdBg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            font.weight: Theme.fontWeightBold
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            SwitcherService.index = cell.index;
                            SwitcherService.commit();
                        }
                    }
                }
            }
        }

        Text {
            id: label

            anchors.top: list.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, box.width - 40)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: SwitcherService.selected ? SwitcherService.selected.name : ""
            color: Theme.osdFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeHeading
            font.weight: Theme.fontWeightBold
        }
    }
}
