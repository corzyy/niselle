import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Medien-Element der Leiste: Cover und „Titel – Künstler“ des aktuellen MPRIS-Spielers; Klick öffnet ein größeres
// Wiedergabefenster (Cover, Titel, Fortschritt mit Spulen, Zurück / Wiedergabe-Pause / Weiter, Spieler nach vorn holen).
// Ohne Spieler bleibt das Element unsichtbar.
Pill {
    id: root

    property color foreground: Theme.panelFg

    // Zeitpunkt, an dem das Fenster zuletzt geschlossen wurde: der Klick, der per Fokus-Grab schloss, soll es nicht wieder öffnen
    property double closedAt: 0

    readonly property string label: MediaService.artist !== "" && MediaService.title !== "" ? MediaService.title + " – " + MediaService.artist : (MediaService.title !== "" ? MediaService.title : MediaService.identity)

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    fg: foreground
    inset: Theme.panelButtonBorder
    checked: popup.open
    visible: MediaService.available

    onClicked: m => {
        if (m && m.button === Qt.MiddleButton) {
            MediaService.playPause();
            return;
        }
        if (m && m.button !== Qt.LeftButton)
            return;
        if (!popup.open && Date.now() - root.closedAt < 200)
            return;
        popup.toggle();
    }

    Icon {
        name: MediaService.playing ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
        color: root.fg
        size: Theme.iconSize
    }
    PanelText {
        text: root.label
        color: root.fg
        elide: Text.ElideRight
        Layout.maximumWidth: Theme.panelAppNameMaxWidth
    }

    PopupMenu {
        id: popup

        anchor.item: root
        anchor.rect.x: root.width / 2
        anchor.rect.y: root.height + Theme.popoverRise - margin - 1
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.None

        minWidth: 340
        grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"
        onOpenChanged: {
            if (open)
                MediaService.updatePosition();
            else
                root.closedAt = Date.now();
        }

        // Position wird vom Spieler nicht gemeldet: solange das Fenster offen ist, jede Sekunde nachfragen
        Timer {
            interval: 1000
            repeat: true
            running: popup.open && MediaService.playing
            onTriggered: MediaService.updatePosition()
        }

        ColumnLayout {
            Layout.preferredWidth: 316
            Layout.margins: 4
            spacing: 12

            // Cover
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width
                radius: Theme.radiusCard
                color: Theme.alpha(Theme.fgColor, 0.08)
                clip: true

                Image {
                    id: cover
                    anchors.fill: parent
                    source: MediaService.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    name: "audio-x-generic-symbolic"
                    size: 96
                    color: Theme.alpha(Theme.fgColor, 0.4)
                }
            }

            // Titel, Künstler, Album
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: MediaService.title !== "" ? MediaService.title : "Nothing playing"
                    elide: Text.ElideRight
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase * 1.2
                    font.weight: Theme.fontWeightBold
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: MediaService.artist
                    elide: Text.ElideRight
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: MediaService.album
                    elide: Text.ElideRight
                    color: Theme.alpha(Theme.fgColor, 0.6)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                }
            }

            // Fortschritt
            ColumnLayout {
                Layout.fillWidth: true
                visible: MediaService.length > 0
                spacing: 2

                Slider {
                    id: seek
                    Layout.fillWidth: true
                    enabled: MediaService.canSeek
                    maximumValue: Math.max(1, MediaService.length)
                    onMoved: v => MediaService.seek(v)

                    Binding {
                        target: seek
                        property: "value"
                        value: MediaService.position
                        when: !seek.pressed
                    }
                }
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatTime(seek.value)
                        color: Theme.alpha(Theme.fgColor, 0.6)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                        font.features: ({
                                "tnum": 1
                            })
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.formatTime(MediaService.length)
                        color: Theme.alpha(Theme.fgColor, 0.6)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                        font.features: ({
                                "tnum": 1
                            })
                    }
                }
            }

            // Bedienung
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                IconButton {
                    icon: "media-skip-backward-symbolic"
                    flat: true
                    enabled: MediaService.canPrevious
                    onClicked: MediaService.previous()
                }
                IconButton {
                    icon: MediaService.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    accent: true
                    padding: Theme.iconButtonPadding + 4
                    enabled: MediaService.canPlayPause
                    onClicked: MediaService.playPause()
                }
                IconButton {
                    icon: "media-skip-forward-symbolic"
                    flat: true
                    enabled: MediaService.canNext
                    onClicked: MediaService.next()
                }
            }

            // Spieler
            Text {
                Layout.fillWidth: true
                visible: MediaService.identity !== ""
                horizontalAlignment: Text.AlignHCenter
                text: MediaService.identity
                elide: Text.ElideRight
                color: Theme.alpha(Theme.fgColor, 0.5)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaption
            }
        }
    }
}
