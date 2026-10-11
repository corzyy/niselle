import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components
import ".."

// System → Über [cc-about-page]: Distributions-Logo, Gerätename, Software- und Hardware-Informationen.
SettingsPage {
    id: root

    property bool editing: false

    // Logo der aktuellen Distribution (os-release LOGO, Theme-Icon)
    Icon {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        visible: AboutService.osLogo !== ""
        name: AboutService.osLogo
        symbolic: false
        size: 138
    }

    PrefGroup {
        ActionRow {
            id: nameRow
            title: "Device Name"
            subtitle: AboutService.deviceName
            propertyStyle: true
            implicitHeight: 54
            visible: !root.editing

            IconButton {
                icon: "document-edit-symbolic"
                flat: true
                bg: Theme.cardBg
                padding: 8
                onClicked: {
                    nameEntry.text = AboutService.deviceName;
                    root.editing = true;
                    nameEntry.forceFocus();
                }
            }
        }

        // Bearbeiten: Eingabefeld statt Zeile
        Item {
            width: parent.width
            implicitHeight: 54
            visible: root.editing

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Entry {
                    id: nameEntry
                    Layout.fillWidth: true
                    onAccepted: {
                        AboutService.setDeviceName(text);
                        root.editing = false;
                    }
                }
                Button {
                    text: "Cancel"
                    onClicked: root.editing = false
                }
                SuggestedButton {
                    text: "Apply"
                    onClicked: nameEntry.accepted()
                }
            }
        }
    }

    PrefGroup {
        title: "Software Information"

        ActionRow {
            title: "Shell"
            subtitle: AboutService.shellVersion
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
            suffixIcon: Qt.resolvedUrl("../../../assets/icons/external-link-symbolic.svg")
            activatable: true
            onActivated: Quickshell.execDetached(["xdg-open", "https://quickshell.org"])
        }
        ActionRow {
            title: "Operating System Name"
            subtitle: AboutService.osName
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Operating System Build"
            subtitle: AboutService.osBuild
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Operating System Type"
            subtitle: AboutService.osType
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Windowing System"
            subtitle: AboutService.windowing
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Virtualization"
            subtitle: AboutService.virtualization
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Kernel Version"
            subtitle: AboutService.kernel
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
    }

    PrefGroup {
        title: "Hardware Information"

        ActionRow {
            title: "Model"
            subtitle: AboutService.hardwareModel
            propertyStyle: true
            visible: subtitle.trim() !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Memory"
            subtitle: AboutService.memory
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Processor"
            subtitle: AboutService.processor
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Graphics"
            subtitle: AboutService.graphics
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Disk Capacity"
            subtitle: AboutService.disk
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
        ActionRow {
            title: "Firmware Version"
            subtitle: AboutService.firmware
            propertyStyle: true
            visible: subtitle !== ""
            height: visible ? implicitHeight : 0
        }
    }
}
