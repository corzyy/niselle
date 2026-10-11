import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Weltuhren [GNOME-Mockup calendar-popover]: Karte mit einer Zeile je Ort (Zifferblatt, Name, Uhrzeit). Die Liste
// passt sich der Anzahl an: bis `compactAbove` Uhren große Zeilen (Name über Uhrzeit), darüber eine kompakte Liste
// (Name links, Uhrzeit rechts) und ab mehr als `pageAbove` Uhren Seiten mit Punkten darunter.
// Die Uhrzeit läuft nur, solange das Menü offen ist. Ohne Orte ausgeblendet.
Card {
    id: root

    property bool active: false
    signal launch

    property var clocksApp: AppsService.byId(SettingsService.defaultApps.clocks ?? "") ?? null

    readonly property var clocks: WorldClocksService.clocks
    readonly property bool analog: SettingsService.calendarAnalogClocks
    readonly property bool compact: clocks.length > SettingsService.calendarCompactClocksAbove
    readonly property int pageSize: Math.max(1, SettingsService.calendarPageClocksAbove)
    readonly property int pageCount: Math.ceil(clocks.length / pageSize)
    readonly property bool paged: clocks.length > pageSize
    property int page: 0
    readonly property real rowHeight: compact ? Theme.worldClocksCompactRow : Theme.worldClocksRow
    readonly property int shownCount: paged ? Math.min(pageSize, clocks.length - page * pageSize) : clocks.length

    visible: WorldClocksService.available && SettingsService.calendarShowWorldClocks
    interactive: clocksApp !== null
    onClicked: if (clocksApp) {
        AppsService.launch(clocksApp);
        root.launch();
    }
    onPageCountChanged: page = Math.min(page, Math.max(0, pageCount - 1))
    onActiveChanged: if (!active)
        page = 0

    SystemClock {
        id: clock
        enabled: root.active && root.visible
        precision: SystemClock.Minutes
    }

    function timeAt(c) {
        return WorldClocksService.timeAt(c, clock.date);
    }
    function timeText(c) {
        return Qt.formatTime(timeAt(c), Qt.locale().timeFormat(Locale.ShortFormat));
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.worldClocksRowSpacing

        // Seitenhöhe fest auf eine volle Seite, damit das Menü beim Blättern nicht springt
        ColumnLayout {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: (root.paged ? root.pageSize : root.clocks.length) * root.rowHeight + Math.max(0, (root.paged ? root.pageSize : root.clocks.length) - 1) * spacing
            spacing: Theme.worldClocksRowSpacing

            Repeater {
                model: root.clocks.slice(root.page * root.pageSize, root.page * root.pageSize + root.pageSize)

                RowLayout {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowHeight
                    spacing: Theme.worldClocksColumnSpacing

                    AnalogClock {
                        visible: root.analog
                        Layout.alignment: Qt.AlignVCenter
                        size: root.compact ? Theme.worldClocksCompactDial : Theme.worldClocksDial
                        time: root.timeAt(row.modelData)
                    }

                    // Große Zeile: Name über Uhrzeit
                    ColumnLayout {
                        visible: !root.compact
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: Theme.fgColor
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            font.weight: Theme.fontWeightBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.timeText(row.modelData) + "  " + WorldClocksService.relativeOffset(row.modelData)
                            elide: Text.ElideRight
                            color: Theme.cardInsensitiveFg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeCaption
                            font.features: ({
                                    "tnum": 1
                                })
                        }
                    }

                    // Kompakte Zeile: Name links, Uhrzeit rechts
                    Text {
                        visible: root.compact
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: Theme.fgColor
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        visible: root.compact
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        text: root.timeText(row.modelData)
                        color: Theme.cardInsensitiveFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                        font.features: ({
                                "tnum": 1
                            })
                    }
                }
            }

            // Platz der fehlenden Zeilen auf der letzten Seite
            Item {
                Layout.fillHeight: true
                visible: root.paged
            }
        }

        PageIndicators {
            Layout.alignment: Qt.AlignHCenter
            nPages: root.pageCount
            currentPosition: root.page
            onPageActivated: p => root.page = p
        }
    }

    WheelHandler {
        enabled: root.paged
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
            if (d !== 0)
                root.page = Math.max(0, Math.min(root.pageCount - 1, root.page + (d > 0 ? -1 : 1)));
        }
    }
}
