import QtQuick
import QtQuick.Layouts
import qs

// .popup-menu-item [_popovers.scss:36-55, _common.scss:130-136, _drawing.scss:386-395, menuitem()]:
// radius 12, padding 9/12, spacing 6, Übergang 100 ms; hover/selected/checked = flat-hover, active beim Drücken.
// Ornament-Variante (.popup-ornamented-menu-item): linkes Padding 6 + 16px-Ornamentfläche [_popovers.scss:57-60, 108-111].
Item {
    id: root

    property string text: ""
    property string icon: ""
    // Kleines Zusatz-Icon neben dem Icon (z. B. Schloss bei verschlüsselten WLANs)
    property string badgeIcon: ""
    // Ornament-Spalte reservieren; ornamentChecked zeigt das Häkchen
    property bool ornamented: false
    property bool ornamentChecked: false
    // Hintergrund der Zeile (Untermenüs nutzen subMenuBg)
    property color bg: Theme.menuItemBg
    // Menü nach Aktivierung schließen
    property bool closeOnActivate: true
    // Tastaturauswahl (:selected)
    property bool selected: false

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property color fg: enabled ? Theme.fgColor : Theme.insensitiveFg

    default property alias trailing: trailingRow.data

    signal activated

    implicitWidth: layout.implicitWidth + leftPadding + Theme.menuItemPaddingH
    implicitHeight: Math.max(layout.implicitHeight, Theme.iconSize) + 2 * Theme.menuItemPaddingV
    readonly property real leftPadding: ornamented ? Theme.menuOrnamentPaddingLeft : Theme.menuItemPaddingH
    activeFocusOnTab: true

    Layout.fillWidth: true

    function activate() {
        if (!enabled)
            return;
        activated();
        if (closeOnActivate) {
            for (let p = parent; p; p = p.parent) {
                if (p.menuOwner) {
                    p.menuOwner.close();
                    break;
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMenuItem
        color: {
            if (!root.enabled)
                return "transparent";
            const active = root.pressed;
            const lit = root.hovered || root.selected || root.activeFocus;
            if (!active && !lit)
                return "transparent";
            return Theme.buttonBg(active ? "active" : "hover", {
                "bg": root.bg,
                "style": "flat"
            });
        }

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationMenuItem
                easing.type: Theme.easeTransition
            }
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: Theme.menuItemPaddingH
        spacing: Theme.menuItemSpacing

        Item {
            visible: root.ornamented
            implicitWidth: Theme.menuOrnamentSize
            implicitHeight: Theme.menuOrnamentSize

            Icon {
                anchors.fill: parent
                visible: root.ornamentChecked
                name: "object-select-symbolic"
                color: root.fg
                size: Theme.menuOrnamentSize
            }
        }

        // Icon mit optionalem kleinem Zusatz-Icon unten rechts (.wireless-secure-icon, halbe Größe, ohne Abstand)
        RowLayout {
            visible: root.icon !== ""
            spacing: 0

            Icon {
                name: root.icon
                color: root.fg
            }
            Icon {
                visible: root.badgeIcon !== ""
                Layout.alignment: Qt.AlignBottom
                name: root.badgeIcon
                size: Theme.wirelessSecureIconSize
                color: root.fg
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.text
            color: root.fg
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
            font.weight: Theme.fontWeightNormal
            verticalAlignment: Text.AlignVCenter
        }

        RowLayout {
            id: trailingRow
            spacing: Theme.menuItemSpacing
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activate()
    }

    Keys.onReturnPressed: root.activate()
    Keys.onSpacePressed: root.activate()
}
