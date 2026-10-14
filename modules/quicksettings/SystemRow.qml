import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

RowLayout {
    id: root

    property bool forceBattery: false
    property bool forceScreenshot: false

    readonly property bool showBattery: forceBattery || PowerService.hasBattery
    readonly property bool powerMenuAvailable: SessionService.canLock || SessionService.canSuspend || SessionService.canReboot || SessionService.canPowerOff || SessionService.canLogout
    readonly property bool screenshotAvailable: forceScreenshot || SessionService.canScreenshot || ScreenRecordingService.canRecord || ScreenRecordingService.recording

    signal editRequested
    signal settingsRequested
    signal powerMenuRequested
    signal batteryRequested
    signal screenshotRequested

    spacing: Theme.quickSystemSpacing

    Item {
        id: battery

        visible: root.showBattery
        implicitWidth: batteryRow.implicitWidth + Theme.quickToggleIconLeading + Theme.quickToggleHPadding
        Layout.fillHeight: true

        readonly property string buttonState: Theme.buttonState(batteryMouse.containsMouse, batteryMouse.pressed, false, enabled, activeFocus)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusPill
            color: Theme.buttonBg(battery.buttonState, {})
        }

        RowLayout {
            id: batteryRow
            anchors.fill: parent
            anchors.leftMargin: Theme.quickToggleIconLeading
            anchors.rightMargin: Theme.quickToggleHPadding
            spacing: Theme.quickToggleSpacing

            Icon {
                name: PowerService.hasBattery ? PowerService.iconName : "battery-level-100-symbolic"
            }
            Text {
                text: Math.round(PowerService.percentage) + " %"
                color: Theme.fgColor
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeHeading
                font.weight: Theme.fontWeightBold
            }
        }

        MouseArea {
            id: batteryMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: SessionService.canOpenSettings
            onClicked: root.batteryRequested()
        }
    }

    Item {
        visible: root.showBattery
        Layout.fillWidth: true
    }

    IconButton {
        icon: "document-edit-symbolic"
        padding: Theme.iconButtonQuickPadding
        onClicked: root.editRequested()
    }

    IconButton {
        visible: root.screenshotAvailable
        icon: ScreenRecordingService.recording ? "media-record-symbolic" : "applets-screenshooter-symbolic"
        padding: Theme.iconButtonQuickPadding
        onClicked: root.screenshotRequested()
    }

    IconButton {
        icon: "emblem-system-symbolic"
        padding: Theme.iconButtonQuickPadding
        onClicked: root.settingsRequested()
    }

    Item {
        visible: !root.showBattery
        Layout.fillWidth: true
    }

    IconButton {
        visible: root.powerMenuAvailable
        icon: "system-shutdown-symbolic"
        padding: Theme.iconButtonQuickPadding
        onClicked: root.powerMenuRequested()
    }
}
