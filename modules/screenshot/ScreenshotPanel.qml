import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Bedienfeld des Bildschirmfoto-Overlays (.screenshot-ui-panel): oben die Modusknöpfe Bereich/Bildschirm/Fenster
// (Symbol 32 px über der Beschriftung), darunter links der Foto/Aufnahme-Schalter, in der Mitte der Auslöser (weißer Kreis
// im Ring, bei Aufnahme rot) und rechts der Mauszeiger-Schalter. Werte aus gnome-shell-dark.css.
Rectangle {
    id: root

    readonly property bool recordKind: ScreenshotService.kind === "record"
    readonly property color panelBg: Theme.osdBg

    implicitWidth: column.implicitWidth + 2 * 18
    implicitHeight: column.implicitHeight + 18 + 12
    width: implicitWidth
    height: implicitHeight
    radius: 32
    color: root.panelBg
    border.width: 1
    border.color: Theme.osdOuterBorders

    // Klicks auf dem Feld dürfen darunter nichts auslösen
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Column {
        id: column
        x: 18
        y: 18
        spacing: 12

        // Modusknöpfe
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: [
                    {
                        "mode": "selection",
                        "icon": "screenshot-ui-area-symbolic",
                        "label": "Selection"
                    },
                    {
                        "mode": "screen",
                        "icon": "screenshot-ui-display-symbolic",
                        "label": "Screen"
                    },
                    {
                        "mode": "window",
                        "icon": "screenshot-ui-window-symbolic",
                        "label": "Window"
                    }
                ]

                Rectangle {
                    id: typeButton
                    required property var modelData
                    readonly property bool checked: ScreenshotService.mode === modelData.mode

                    implicitWidth: Math.max(48, content.implicitWidth + 2 * 18)
                    implicitHeight: content.implicitHeight + 2 * 12
                    width: implicitWidth
                    height: implicitHeight
                    radius: 14
                    color: {
                        let c = root.panelBg;
                        if (checked)
                            c = Theme.lighten(c, 0.08);
                        if (typeMouse.pressed)
                            return Theme.lighten(root.panelBg, checked ? 0.17 : 0.09);
                        return typeMouse.containsMouse ? Theme.lighten(c, 0.07) : c;
                    }

                    Column {
                        id: content
                        anchors.centerIn: parent
                        spacing: Math.round(0.409 * Theme.fontSizeBase * 96 / 72)

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: Quickshell.shellPath("assets/icons/" + typeButton.modelData.icon + ".svg")
                            size: 32
                            color: Theme.osdFg
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: typeButton.modelData.label
                            color: Theme.osdFg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase * 0.818
                        }
                    }

                    MouseArea {
                        id: typeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ScreenshotService.mode = typeButton.modelData.mode
                    }
                }
            }
        }

        // Untere Zeile: Foto/Aufnahme links, Auslöser mittig, Mauszeiger rechts
        Item {
            width: parent.width
            height: 48

            // .screenshot-ui-shot-cast-container
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: shotCast.implicitWidth + 2 * 3
                height: shotCast.implicitHeight + 2 * 3
                radius: 999
                color: Theme.alpha(Theme.osdFg, 0.1)

                Row {
                    id: shotCast
                    x: 3
                    y: 3
                    spacing: 3

                    Repeater {
                        model: [
                            {
                                "kind": "screenshot",
                                "icon": "camera-photo-symbolic"
                            },
                            {
                                "kind": "record",
                                "icon": "camera-video-symbolic"
                            }
                        ]

                        Rectangle {
                            id: kindButton
                            required property var modelData
                            readonly property bool checked: ScreenshotService.kind === modelData.kind
                            readonly property bool usable: modelData.kind === "screenshot" || ScreenshotService.canRecord

                            implicitWidth: 16 + 2 * 12
                            implicitHeight: 16 + 2 * 6
                            width: implicitWidth
                            height: implicitHeight
                            radius: 999
                            color: checked ? Theme.osdFg : (kindMouse.pressed ? Theme.alpha(Theme.osdFg, 0.5) : (kindMouse.containsMouse && usable ? Theme.alpha(Theme.osdFg, 0.2) : "transparent"))

                            Icon {
                                anchors.centerIn: parent
                                name: kindButton.modelData.icon
                                size: 16
                                color: kindButton.checked ? root.panelBg : (kindButton.usable ? Theme.osdFg : Theme.alpha(Theme.osdFg, 0.5))
                            }
                            MouseArea {
                                id: kindMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (kindButton.usable)
                                        ScreenshotService.kind = kindButton.modelData.kind;
                                    else
                                        ScreenshotService.warnNoRecorder();
                                }
                            }
                        }
                    }
                }
            }

            // .screenshot-ui-capture-button: 32 px Kreis, 4 px Abstand, 4 px Ring
            Item {
                id: capture
                anchors.centerIn: parent
                width: 48
                height: 48
                enabled: ScreenshotService.currentTarget().width > 0
                opacity: enabled ? 1 : 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: 999
                    color: "transparent"
                    border.width: 4
                    border.color: "white"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 999
                    color: {
                        const cast = root.recordKind;
                        if (captureMouse.pressed)
                            return cast ? "#a11722" : "gray";
                        if (captureMouse.containsMouse || capture.activeFocus)
                            return cast ? "#d61f2d" : "#cccccc";
                        return cast ? "#c01c28" : "white";
                    }
                    Behavior on color {
                        enabled: !Theme.gameMode
                        ColorAnimation {
                            duration: 200
                            easing.type: Theme.easeOut
                        }
                    }
                }
                MouseArea {
                    id: captureMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: ScreenshotService.captureCurrent()
                }
            }

            // Mauszeiger im Bild
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: Quickshell.shellPath("assets/icons/screenshot-ui-show-pointer-symbolic.svg")
                checked: ScreenshotService.showPointer
                enabled: !root.recordKind
                bg: root.panelBg
                fg: Theme.osdFg
                onClicked: ScreenshotService.showPointer = !ScreenshotService.showPointer
            }
        }
    }
}
