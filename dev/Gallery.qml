import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// Entwicklungs-Galerie aller Basis-Komponenten (NISELLE_GALLERY=1, NISELLE_LIGHT=1, NISELLE_ACCENT=<name>)
FloatingWindow {
    id: win

    implicitWidth: 760
    implicitHeight: 620
    color: Theme.windowBg

    Component.onCompleted: {
        Theme.dark = Quickshell.env("NISELLE_LIGHT") !== "1";
        if (Quickshell.env("NISELLE_ACCENT"))
            Theme.accent = Quickshell.env("NISELLE_ACCENT");
    }

    // Menü-Karte statisch daneben (zusätzlich zum Popup)
    Rectangle {
        anchors.fill: parent
        color: Theme.windowBg
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            spacing: 12

            Pill {
                inset: Theme.panelButtonBorder
                Text {
                    text: "Aktivitäten"
                    color: Theme.panelFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }
            }
            Pill {
                inset: Theme.panelButtonBorder
                checked: true
                Text {
                    text: "Mi 9. Okt  22:41"
                    color: Theme.panelFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }
            }
            IconButton { icon: "audio-volume-high-symbolic" }
            IconButton { icon: "audio-volume-high-symbolic"; flat: true }
            IconButton { icon: "audio-volume-high-symbolic"; accent: true }
            IconButton { icon: "audio-volume-high-symbolic"; enabled: false }
            ToggleSwitch {}
            ToggleSwitch { checked: true }
        }

        RowLayout {
            spacing: 12
            ToggleButton { title: "Netzwerk"; subtitle: "Verbunden"; icon: "network-wireless-symbolic"; checked: true; hasMenu: true }
            ToggleButton { title: "Bluetooth"; subtitle: "Aus"; icon: "bluetooth-active-symbolic"; hasMenu: true }
            ToggleButton { title: "Nachtlicht"; icon: "night-light-symbolic" }
        }

        RowLayout {
            spacing: 18
            Slider { Layout.preferredWidth: 220; value: 0.4 }
            Slider { Layout.preferredWidth: 220; value: 1.3; maximumValue: 1.5; overdriveStart: 1.0; marks: [1.0] }
            Slider { Layout.preferredWidth: 140; value: 0 }
        }

        RowLayout {
            spacing: 12
            Rectangle {
                implicitWidth: 330
                implicitHeight: 90
                radius: Theme.radiusTile
                color: Theme.overviewBg
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Tile {
                        Icon { symbolic: false; name: "system-file-manager"; size: 48 }
                    }
                    Tile {
                        checked: true
                        Icon { symbolic: false; name: "system-file-manager"; size: 48 }
                    }
                    Tile {
                        raised: true
                        Icon { symbolic: false; name: "system-file-manager"; size: 48 }
                    }
                }
            }
            ShadowRect {
                implicitWidth: 120
                implicitHeight: 70
                color: Theme.cardBg
                radius: Theme.radiusCard
                shadowBlur: Theme.shadowCardBlur
                shadowOffsetY: Theme.shadowCardY
                shadowColor: Theme.cardShadowColor
                border.width: 1
                border.color: Theme.cardShadowBorder
            }
            Rectangle {
                id: openBtn
                implicitWidth: 120
                implicitHeight: 36
                radius: Theme.radiusButton
                color: Theme.buttonBg("normal")
                Text {
                    anchors.centerIn: parent
                    text: "Menü öffnen"
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }
                MouseArea { anchors.fill: parent; onClicked: menu.toggle() }
            }
        }

        // Statisch gerenderte Menükarte zum Vergleich
        ShadowRect {
            Layout.preferredWidth: 260
            Layout.preferredHeight: 190
            color: Theme.menuBg
            radius: Theme.radiusPopover
            border.width: 1
            border.color: Theme.outerBorders
            shadowBlur: Theme.shadowPopoverBlur
            shadowOffsetY: Theme.shadowPopoverY
            padding: Theme.popoverPadding + 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                PopupMenuItem { text: "Einstellungen"; icon: "emblem-system-symbolic" }
                PopupMenuItem { text: "Markiert"; ornamented: true; ornamentChecked: true }
                Separator { Layout.fillWidth: true; Layout.topMargin: 3; Layout.bottomMargin: 3 }
                PopupMenuItem { text: "Gesperrt"; enabled: false }
                PopupMenuItem { text: "Mit Schalter"; ToggleSwitch {} }
            }
        }
        Item { Layout.fillHeight: true }
    }

    Timer {
        interval: 1000
        running: Quickshell.env("NISELLE_OPEN") === "1"
        onTriggered: menu.show()
    }

    PopupMenu {
        id: menu
        anchor.window: win
        grabFocus: Quickshell.env("NISELLE_OPEN") !== "1"
        anchor.rect.x: 460
        anchor.rect.y: 520 - menu.margin
        PopupMenuItem { text: "Einstellungen"; icon: "emblem-system-symbolic" }
        PopupMenuItem { text: "Beenden" }
    }
}
