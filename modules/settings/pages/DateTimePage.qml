import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.components
import ".."

SettingsPage {
    id: root

    property string timezone: ""
    property bool ntp: false
    property bool canNtp: false
    property var allZones: []
    property bool showZones: false

    readonly property var days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var matches: {
        const q = zoneFilter.text.trim().toLowerCase().replace(/ /g, "_");
        const list = q === "" ? allZones : allZones.filter(z => z.toLowerCase().indexOf(q) >= 0);
        return list.slice(0, 8);
    }

    function refresh() {
        status.running = true;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Process {
        id: status
        running: true
        command: ["timedatectl", "show", "--property=Timezone,NTP,CanNTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    const k = line.slice(0, i), v = line.slice(i + 1);
                    if (k === "Timezone")
                        root.timezone = v;
                    else if (k === "NTP")
                        root.ntp = v === "yes";
                    else if (k === "CanNTP")
                        root.canNtp = v === "yes";
                }
            }
        }
    }

    Process {
        running: true
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: root.allZones = text.split("\n").filter(l => l.length > 0)
        }
    }

    Process {
        id: setter
        onExited: root.refresh()
    }

    PrefGroup {
        title: "Current Time"

        ActionRow {
            title: Qt.formatTime(clock.date, SettingsService.clock12h ? "h:mm:ss AP" : "HH:mm:ss")
            subtitle: Qt.formatDate(clock.date, Qt.locale().dateFormat(Locale.LongFormat))
            propertyStyle: false
            implicitHeight: 64
        }
    }

    PrefGroup {
        title: "Automatic"

        ActionRow {
            title: "Automatic Date & Time"
            subtitle: root.canNtp ? "Synchronize the clock with network time servers" : "Network time synchronization is unavailable"
            ToggleSwitch {
                checked: root.ntp
                enabled: root.canNtp
                onToggled: {
                    setter.command = ["timedatectl", "set-ntp", checked ? "false" : "true"];
                    setter.running = true;
                }
            }
        }
    }

    PrefGroup {
        title: "Time Zone"

        ActionRow {
            title: "Time Zone"
            subtitle: root.timezone.replace(/_/g, " ")
            activatable: true
            suffixIcon: root.showZones ? "go-up-symbolic" : "go-down-symbolic"
            onActivated: {
                root.showZones = !root.showZones;
                if (root.showZones)
                    zoneFilter.forceFocus();
            }
        }
        Item {
            Layout.fillWidth: true
            width: parent ? parent.width : 0
            visible: root.showZones
            implicitHeight: visible ? zoneFilter.implicitHeight + 16 : 0

            Entry {
                id: zoneFilter
                anchors.fill: parent
                anchors.margins: 8
                placeholderText: "Search time zones"
            }
        }
        Repeater {
            model: root.showZones ? root.matches : []

            ActionRow {
                required property string modelData
                title: modelData.replace(/_/g, " ")
                activatable: true
                suffixIcon: modelData === root.timezone ? "object-select-symbolic" : ""
                onActivated: {
                    setter.command = ["timedatectl", "set-timezone", modelData];
                    setter.running = true;
                    root.showZones = false;
                    zoneFilter.text = "";
                }
            }
        }
    }

    PrefGroup {
        title: "Format"

        ActionRow {
            title: "24-Hour Time"
            subtitle: "Show the clock in the top bar as " + (SettingsService.clock12h ? "3:45 PM" : "15:45")
            ToggleSwitch {
                checked: !SettingsService.clock12h
                onToggled: SettingsService.set("clock12h", checked)
            }
        }
        ActionRow {
            title: "Week Numbers"
            subtitle: "Show week numbers in the calendar"
            ToggleSwitch {
                checked: SettingsService.showWeekNumbers
                onToggled: SettingsService.set("showWeekNumbers", !checked)
            }
        }
    }

    PrefGroup {
        title: "First Day of the Week"

        ActionRow {
            title: "Default"
            subtitle: "Follow the system locale"
            activatable: true
            suffixIcon: SettingsService.weekStart < 0 || SettingsService.weekStart > 6 ? "object-select-symbolic" : ""
            onActivated: SettingsService.set("weekStart", -1)
        }
        Repeater {
            model: [1, 0, 6]

            ActionRow {
                required property int modelData
                title: root.days[modelData]
                activatable: true
                suffixIcon: SettingsService.weekStart === modelData ? "object-select-symbolic" : ""
                onActivated: SettingsService.set("weekStart", modelData)
            }
        }
    }
}
