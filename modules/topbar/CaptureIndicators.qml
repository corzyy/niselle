import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components

// Aufnahme und Bildschirmfreigabe mit Knopf zum Beenden [GNOME-Mockup system-status-indicators]: roter Pille mit Dauer und
// Stopp-Symbol, orange Pille mit Freigabe-Symbol und ✕. Beides sind die Anzeigen, bei denen ein sofortiger Weg zum Beenden
// zählt; Kamera, Mikrofon und Standort sind nur Anzeigen (QuickSettingsButton). Die Freigabe-Pille erscheint nur, wenn
// sich die Freigabe beenden lässt (pw-cli); sonst zeigt die Statuspille ein Symbol.
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
