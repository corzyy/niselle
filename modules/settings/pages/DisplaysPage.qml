import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    signal navigate(string panel)

    readonly property bool showingApplyBar: DisplayService.dirty
    property bool confirmOpen: false
    property int countdown: 20

    function applyConfiguration() {
        DisplayService.apply();
        root.countdown = 20;
        root.confirmOpen = true;
        countdownTimer.restart();
    }
    function cancelConfiguration() {
        DisplayService.cancel();
    }
    function keepChanges() {
        countdownTimer.stop();
        root.confirmOpen = false;
        DisplayService.save();
    }
    function revertChanges() {
        countdownTimer.stop();
        root.confirmOpen = false;
        DisplayService.revertApply();
    }

    Component.onDestruction: {
        if (root.confirmOpen)
            DisplayService.revertApply();
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0)
                root.revertChanges();
        }
    }

    ModalDialog {
        open: root.confirmOpen
        title: "Keep Changes?"
        description: "The new display configuration will be reverted in " + root.countdown + " seconds."
        buttons: [
            {
                "id": "revert",
                "text": "Revert Settings"
            },
            {
                "id": "keep",
                "text": "Keep Changes",
                "primary": true
            }
        ]
        onCanceled: root.revertChanges()
        onButtonClicked: id => id === "keep" ? root.keepChanges() : root.revertChanges()
    }

    readonly property bool multi: DisplayService.outputCount > 1
    readonly property bool mirror: DisplayService.configMode === "mirror"
    readonly property var sourceMonitor: DisplayService.selectedOutput ?? (DisplayService.enabledOutputs.length > 0 ? DisplayService.enabledOutputs[0] : null)

    readonly property var arrangementMonitors: DisplayService.outputs.filter(o => DisplayService._d(o).enabled).map(o => ({
                "name": o.name,
                "number": o.number,
                "x": DisplayService._d(o).x,
                "y": DisplayService._d(o).y,
                "w": DisplayService.logicalWidth(o),
                "h": DisplayService.logicalHeight(o),
                "primary": o.name === DisplayService.primaryName,
                "selected": o.name === DisplayService.selected
            }))

    PrefGroup {
        visible: DisplayService.loaded && DisplayService.outputCount === 0

        ActionRow {
            title: "No displays found"
            subtitle: "Connect a display to change its settings"
            icon: "video-display-symbolic"
        }
    }

    PrefGroup {
        visible: root.multi

        SegmentedRow {
            title: "Multiple Displays"
            choices: [
                {
                    "value": "join",
                    "label": "Join"
                },
                {
                    "value": "mirror",
                    "label": "Mirror"
                }
            ]
            value: DisplayService.configMode
            onPicked: v => DisplayService.setConfigMode(v)
        }
    }

    PrefGroup {
        visible: root.multi && !root.mirror

        Item {
            Layout.fillWidth: true
            width: parent ? parent.width : 0
            implicitHeight: arrangement.implicitHeight + 2 * 12

            DisplayArrangement {
                id: arrangement
                anchors.fill: parent
                anchors.margins: 12
                monitors: root.arrangementMonitors
                selected: DisplayService.selected
                onMonitorSelected: name => DisplayService.selected = name
                onMonitorMoved: (name, x, y) => DisplayService.setPosition(name, x, y)
            }
        }

        ChoiceRow {
            title: "Primary Display"
            choices: DisplayService.enabledOutputs.map(o => ({
                        "label": o.name,
                        "value": o.name
                    }))
            value: DisplayService.primaryName
            onPicked: name => DisplayService.setPrimary(name)
        }

        ActionRow {
            title: "Make Primary"
            subtitle: "Use the selected display for the top bar and Activities"
            Button {
                text: "Make Primary"
                enabled: DisplayService.selected !== "" && DisplayService.selected !== DisplayService.primaryName
                onClicked: DisplayService.setPrimary(DisplayService.selected)
            }
        }

        Repeater {
            model: DisplayService.outputs

            ActionRow {
                required property var modelData
                badge: String(modelData.number)
                title: modelData.name
                suffixIcon: "go-next-symbolic"
                activatable: true
                onActivated: {
                    DisplayService.selected = modelData.name;
                    root.navigate("displays/monitor/" + modelData.name);
                }
            }
        }
    }

    PrefGroup {
        visible: DisplayService.loaded && root.sourceMonitor !== null && (!root.multi || root.mirror)

        DisplaySettingsList {
            monitor: root.sourceMonitor
            allowRefresh: !root.mirror
        }
    }
}
