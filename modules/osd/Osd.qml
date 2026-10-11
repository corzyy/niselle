import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// On-Screen-Anzeige (.osd-window) [osdWindow.js, _osd.scss]: Pille unten mittig, 4em über dem unteren Rand, mit Icon (32px)
// und rechts davon Beschriftung und/oder Pegelbalken. Einblenden/Ausblenden 100 ms EASE_OUT_QUAD, der Pegel läuft in 100 ms
// zum neuen Wert, solange die Anzeige sichtbar ist. Nur auf dem primären Monitor.
PanelWindow {
    id: root

    readonly property bool onThisScreen: OverviewService.isPrimary(screen)
    readonly property bool active: OsdService.shown && onThisScreen

    // Zuletzt gezeigter Inhalt bleibt während des Ausblendens stehen, auch wenn der Dienst ihn schon zurücksetzt
    property string iconName: ""
    property var label: null
    property real level: -1
    property real maxLevel: 1
    readonly property bool hasLabel: root.label !== null
    readonly property bool hasLevel: root.level >= 0

    function sync() {
        if (!root.active || OsdService.iconName === "")
            return;
        root.iconName = OsdService.iconName;
        root.label = OsdService.label;
        root.maxLevel = OsdService.maxLevel;
        root.level = OsdService.level;
    }
    Connections {
        target: OsdService
        function onIconNameChanged() {
            root.sync();
        }
        function onLabelChanged() {
            root.sync();
        }
        function onLevelChanged() {
            root.sync();
        }
        function onMaxLevelChanged() {
            root.sync();
        }
    }
    onActiveChanged: sync()

    anchors.bottom: true
    margins.bottom: Theme.osdMarginBottom
    implicitWidth: pill.width
    implicitHeight: pill.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: active || pill.opacity > 0

    // Leere Maske: Eingaben gehen durch die Anzeige hindurch
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "niselle-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: pill

        width: row.implicitWidth + 2 * Theme.osdPaddingH + 2 * Theme.osdBorderWidth
        height: row.implicitHeight + 2 * Theme.osdPaddingV + 2 * Theme.osdBorderWidth
        radius: Theme.radiusPill
        color: Theme.osdBg
        border.width: Theme.osdBorderWidth
        border.color: Theme.osdOuterBorders
        opacity: root.active ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.gameMode
            NumberAnimation {
                duration: Theme.durationOsdFade
                easing.type: Theme.easeOutQuad
            }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Theme.osdSpacing

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: root.iconName
                size: Theme.osdIconSize
                color: Theme.osdFg
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                visible: root.hasLabel || root.hasLevel
                spacing: Theme.osdInnerSpacing

                Text {
                    id: labelText
                    Layout.rightMargin: Theme.osdLabelMarginEnd
                    visible: root.hasLabel
                    text: root.label ?? ""
                    color: Theme.osdFg
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeHeading
                    font.weight: Theme.fontWeightBold
                }

                BarLevel {
                    id: levelBar
                    Layout.rightMargin: Theme.osdLevelMarginEnd
                    Layout.bottomMargin: Theme.osdLevelMarginBottom
                    Layout.preferredWidth: Theme.osdLevelWidth
                    visible: root.hasLevel
                    value: root.level
                    maximumValue: root.maxLevel

                    // Nur animieren, wenn schon sichtbar; sonst springt der Balken sofort auf den Wert
                    Behavior on value {
                        enabled: (pill.opacity > 0) && !Theme.gameMode
                        NumberAnimation {
                            duration: Theme.durationOsdLevel
                            easing.type: Theme.easeOutQuad
                        }
                    }
                }
            }
        }
    }
}
