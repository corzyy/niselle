import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Kopfzeile der Quick-Settings (.quick-settings-system-item) [system.js:215-258, _quick-settings.scss:205-218]:
// Akku, Bearbeiten, Einstellungen, (Abstand), Ein/Aus. Mit Akku steht der Abstand hinter dem Akku,
// ohne Akku zwischen Einstellungen und Ein/Aus. Einträge ohne verfügbare Funktion fehlen. Sperren liegt im Ein/Aus-Menü.
RowLayout {
    id: root

    // Akku-Zeile auch ohne Akku zeigen (nur zum Prüfen des Layouts, NISELLE_QS_DEMO)
    property bool forceBattery: false
    // Aufnahme-Knopf auch ohne Dienst zeigen (nur zur Layout-Prüfung, NISELLE_QS_DEMO)
    property bool forceScreenshot: false

    readonly property bool showBattery: forceBattery || PowerService.hasBattery
    readonly property bool powerMenuAvailable: SessionService.canLock || SessionService.canSuspend || SessionService.canReboot || SessionService.canPowerOff || SessionService.canLogout
    // Bildschirmfoto/Aufnahme: Foto oder Video möglich bzw. läuft bereits
    readonly property bool screenshotAvailable: forceScreenshot || SessionService.canScreenshot || ScreenRecordingService.canRecord || ScreenRecordingService.recording

    signal editRequested
    signal settingsRequested
    signal powerMenuRequested
    signal batteryRequested
    signal screenshotRequested

    spacing: Theme.quickSystemSpacing

    // Akku-Anzeige: Button-Pille mit Icon und Prozent (.power-item) [system.js:35-117]
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

    // Bildschirmfoto/Aufnahme (ScreenshotItem) [system.js:109-130]: runder Knopf im Kopf, öffnet die gemeinsame
    // Oberfläche; läuft eine Aufnahme, zeigt er das Aufnahmesymbol und beendet sie
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
