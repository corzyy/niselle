import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components

RowLayout {
    id: root

    property color foreground: Theme.panelFg

    spacing: 0

    readonly property bool recording: ScreenRecordingService.recording
    readonly property bool sharing: SettingsService.showPrivacyIndicators && PrivacyService.screenSharing && PrivacyService.canStopSharing

    Pill {
        id: recordingPill
        visible: root.recording
        Layout.fillHeight: true
        fg: Theme.light1
        filledColor: Theme.recordingIndicator
        inset: Theme.panelButtonBorder
        hPadding: Theme.basePadding * 2.5
        spacing: Theme.basePadding
        onClicked: m => {
            if (!m || m.button === Qt.LeftButton)
                ScreenRecordingService.stop();
        }

        PanelText {
            text: ScreenRecordingService.elapsedText
            color: recordingPill.fg
        }
        Icon {
            name: "media-playback-stop-symbolic"
            color: recordingPill.fg
            size: Theme.iconSize
        }
    }

    Pill {
        id: sharingPill
        visible: root.sharing
        Layout.fillHeight: true
        fg: Theme.light1
        filledColor: Theme.privacyIndicator
        inset: Theme.panelButtonBorder
        onClicked: m => {
            if (!m || m.button === Qt.LeftButton)
                PrivacyService.stopSharing();
        }

        Icon {
            name: "screen-shared-symbolic"
            color: sharingPill.fg
            size: Theme.iconSize
        }
        Icon {
            name: "window-close-symbolic"
            color: sharingPill.fg
            size: Theme.iconSize
        }
    }
}
