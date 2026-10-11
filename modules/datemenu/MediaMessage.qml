import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Medienkarte eines MPRIS-Spielers [messageList.js MediaMessage, _message-list.scss:218-262]: Cover (Radius 8) bzw. Notensymbol,
// Titel, Künstler, Zurück / Wiedergabe-Pause / Weiter. Klick auf die Karte bringt den Spieler nach vorn. Die Karte hat keine
// Zeit und keinen Schließen-Knopf; Position wird nicht angezeigt, es gibt also keine Aktualisierung während des Lesens.
Message {
    id: root

    required property var player

    signal activated

    // Knopf der Medienbedienung (.message-media-control): 16px-Symbol, Innenabstand 18 horizontal, Radius 8
    component MediaButton: Item {
        id: button

        property string icon: ""

        readonly property bool hovered: mouse.containsMouse

        signal clicked

        Layout.fillHeight: true
        implicitWidth: Theme.iconSize + 2 * (Theme.mediaControlPaddingH + 1)
        implicitHeight: Theme.iconSize + 2
        activeFocusOnTab: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusButton
            color: !button.enabled ? "transparent" : (mouse.pressed ? Theme.mediaControlActive : (button.hovered ? Theme.mediaControlHover : "transparent"))
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusButton
            color: "transparent"
            border.width: Theme.focusRingWidth
            border.color: Theme.focusRing
            visible: button.activeFocus
        }
        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: Theme.iconSize
            color: button.enabled ? Theme.fgColor : Theme.mediaControlInsensitiveFg
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            onClicked: button.clicked()
        }
        Keys.onReturnPressed: if (enabled)
            clicked()
        Keys.onSpacePressed: if (enabled)
            clicked()
    }

    readonly property var entry: player && player.desktopEntry ? DesktopEntries.heuristicLookup(player.desktopEntry) : null

    media: true
    closable: false
    sourceTitle: player ? player.identity : ""
    sourceIcon: entry && entry.icon ? entry.icon : ""
    title: player ? (player.trackTitle ?? "") : ""
    body: player ? (player.trackArtist ?? "") : ""
    iconSource: player ? (player.trackArtUrl ?? "") : ""

    onClicked: {
        if (root.player && root.player.canRaise) {
            root.player.raise();
            root.activated();
        }
    }

    controls: [
        MediaButton {
            icon: "media-skip-backward-symbolic"
            enabled: root.player ? root.player.canGoPrevious : false
            onClicked: root.player.previous()
        },
        MediaButton {
            icon: root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            enabled: root.player ? root.player.canTogglePlaying : false
            onClicked: root.player.togglePlaying()
        },
        MediaButton {
            icon: "media-skip-forward-symbolic"
            enabled: root.player ? root.player.canGoNext : false
            onClicked: root.player.next()
        }
    ]
}
