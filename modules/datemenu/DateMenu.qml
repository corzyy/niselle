import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

Scope {
    id: root

    required property var barWindow

    readonly property alias open: popup.open

    property date selected: new Date()
    property date today: new Date()
    property var now: new Date()

    property double closedAt: 0

    function toggle() {
        if (!popup.open && Date.now() - closedAt < 200)
            return;
        popup.toggle();
    }
    function close() {
        popup.close();
    }

    readonly property bool split: {
        const layout = SettingsService.calendarLayout;
        if (layout === "split")
            return true;
        return layout !== "single" && EventsService.available && SettingsService.calendarShowEvents;
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    IpcHandler {
        target: "datemenu." + (root.barWindow.screen ? root.barWindow.screen.name : "")

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            popup.open = true;
        }
        function close(): void {
            root.close();
        }
    }

    SystemClock {
        id: clock
        enabled: popup.open
        precision: SystemClock.Minutes
        onDateChanged: root.today = date
    }

    BarAnchor {
        id: shellAnchor

        moduleId: "clock"
        panelWidth: popup.implicitWidth - 2 * popup.margin
        screenWidth: root.barWindow.width
        margin: Theme.popoverRise
        fallbackX: (root.barWindow.width - (popup.implicitWidth - 2 * popup.margin)) / 2
    }

    PopupMenu {
        id: popup

        readonly property bool follows: SettingsService.barPanelsFollowItems && shellAnchor.valid

        anchor.window: root.barWindow
        anchor.rect.x: popup.follows ? shellAnchor.panelCenterX : root.barWindow.width / 2
        anchor.rect.y: root.barWindow.height + Theme.popoverRise - popup.margin - 1
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.None

        grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"
        cornerRadius: Theme.radiusDateMenu
        minWidth: 0

        readonly property real maxContentHeight: (root.barWindow.screen ? root.barWindow.screen.height : 1080) - Theme.panelHeight - 2 * Theme.popoverRise - 2 * (contentPadding + Theme.popoverBorderWidth) - 2 * Theme.calendarAreaPadding

        onOpenChanged: {
            if (open) {
                const now = new Date();
                root.now = now;
                root.today = now;
                root.selected = now;
                EventsService.refresh();
            } else {
                root.closedAt = Date.now();
            }
        }

        RowLayout {
            Layout.margins: Theme.calendarAreaPadding
            spacing: Theme.calendarColumnSpacing

            Item {
                id: side

                visible: root.split
                Layout.alignment: Qt.AlignTop
                Layout.fillHeight: true
                Layout.preferredWidth: Theme.calendarSideWidth
                implicitWidth: Theme.calendarSideWidth
                implicitHeight: Math.min(sideColumn.implicitHeight, popup.maxContentHeight)

                ColumnLayout {
                    id: sideColumn

                    anchors.fill: parent
                    spacing: Theme.calendarColumnSpacing

                    TodayButton {
                        Layout.fillWidth: true
                        visible: SettingsService.calendarShowDateHeader
                        date: root.selected
                        isToday: root.sameDay(root.selected, root.today)
                        onClicked: root.selected = new Date()
                    }
                    FadeScroll {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: sideEvents.implicitHeight
                        Layout.minimumHeight: 0
                        contentHeight: sideEvents.implicitHeight

                        EventsSection {
                            id: sideEvents

                            width: parent.width
                            plain: true
                            date: root.selected
                            now: root.now
                            onLaunch: root.close()
                        }
                    }
                }
            }

            ColumnLayout {
                id: column

                Layout.alignment: Qt.AlignTop
                Layout.fillHeight: true
                Layout.preferredWidth: calendarCard.implicitWidth
                spacing: Theme.calendarColumnSpacing

                Card {
                    id: calendarCard

                    Layout.fillWidth: true
                    interactive: false
                    padding: 0

                    Calendar {
                        id: calendar
                        anchors.fill: parent
                        selectedDate: root.selected
                        today: root.today
                        onDateSelected: d => root.selected = d
                    }
                }

                FadeScroll {
                    id: displays

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: Math.min(displaysColumn.implicitHeight, Math.max(0, popup.maxContentHeight - 2 * Theme.calendarColumnSpacing - calendarCard.implicitHeight))
                    Layout.minimumHeight: 0
                    visible: displaysColumn.implicitHeight > 0
                    contentHeight: displaysColumn.implicitHeight

                    ColumnLayout {
                        id: displaysColumn

                        width: displays.width
                        spacing: Theme.calendarColumnSpacing

                        EventsSection {
                            Layout.fillWidth: true
                            visible: !root.split && EventsService.available && SettingsService.calendarShowEvents
                            date: root.selected
                            now: root.now
                            onLaunch: root.close()
                        }
                    }
                }
            }
        }
    }
}
