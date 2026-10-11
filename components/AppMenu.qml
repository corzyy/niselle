import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components

// Kontextmenü einer App (.app-menu) [appMenu.js, _popovers.scss:143-155]: Offene Fenster, Neues Fenster,
// Desktop-Actions, Anheften/Lösen, Beenden. Ein Menü für ein ganzes Dash bzw. Raster, `target` ist der Eintrag, an dem es hängt
// (braucht die Eigenschaften `entry`, `windows`, `label`).
// Trennlinien erscheinen nur zwischen sichtbaren Abschnitten [popupMenu.js: _updateSeparatorVisibility].
// Lage [appDisplay.js: popupMenuSide]: im Dash über dem Eintrag (Pfeil unten, Qt.BottomEdge), im App-Grid rechts neben der
// Kachel (Pfeil links, Qt.LeftEdge).
PopupMenu {
    id: root

    property Item target: null

    readonly property var entry: target?.entry ?? null
    readonly property var windows: target?.windows ?? []
    readonly property var actions: entry?.actions ?? []

    readonly property bool hasNewWindowAction: {
        for (const a of root.actions) {
            if (a.id === "new-window")
                return true;
        }
        return false;
    }
    readonly property bool showWindows: windows.length > 0
    readonly property bool showLaunch: entry !== null && (!hasNewWindowAction || actions.length > 0)
    readonly property bool showPin: entry !== null
    readonly property bool showQuit: entry !== null && windows.length > 0

    function openFor(item) {
        if (root.open)
            root.close();
        root.target = item;
        root.show();
    }

    arrowSide: Qt.BottomEdge
    readonly property bool sideways: arrowSide === Qt.LeftEdge || arrowSide === Qt.RightEdge

    anchor.item: root.target
    anchor.rect.x: {
        if (!root.target)
            return 0;
        if (!root.sideways)
            return root.target.width / 2;
        return root.arrowSide === Qt.LeftEdge ? root.target.width + Theme.popoverRise - margin - 1 : margin - Theme.popoverRise;
    }
    anchor.rect.y: root.sideways ? (root.target ? root.target.height / 2 : 0) : margin - Theme.popoverRise
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: root.sideways ? (root.arrowSide === Qt.LeftEdge ? Edges.Right : Edges.Left) : Edges.Top
    anchor.gravity: root.sideways ? (root.arrowSide === Qt.LeftEdge ? Edges.Right : Edges.Left) : Edges.Top
    anchor.adjustment: root.sideways ? PopupAdjustment.Slide | PopupAdjustment.Flip : PopupAdjustment.None

    // Klick außerhalb schließt über den Fokus-Grab. NISELLE_QS_NOGRAB=1 schaltet ihn ab (Screenshots per IPC ohne Klick).
    grabFocus: Quickshell.env("NISELLE_QS_NOGRAB") !== "1"

    // Offene Fenster: Überschrift (%caption_heading), dann ein Eintrag je Fenster
    ColumnLayout {
        visible: root.showWindows
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.menuItemPaddingH
            Layout.rightMargin: Theme.menuItemPaddingH
            Layout.topMargin: Theme.menuItemPaddingV
            Layout.bottomMargin: Theme.menuItemPaddingV
            spacing: Theme.baseMargin * 2

            Text {
                text: "Offene Fenster"
                color: Theme.fgColor
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeCaptionHeading
                font.weight: Theme.fontWeightBold
            }
        }

        Repeater {
            model: root.windows

            PopupMenuItem {
                required property var modelData

                Layout.maximumWidth: Theme.dashMenuMaxWidth - 2 * (Theme.popoverPadding + Theme.popoverBorderWidth)
                text: modelData.title || root.target?.label || ""
                onActivated: {
                    WorkspaceService.focusWindow(modelData);
                    OverviewService.hide();
                }
            }
        }
    }

    // Neues Fenster und Desktop-Actions
    ColumnLayout {
        visible: root.showLaunch
        Layout.fillWidth: true
        spacing: 0

        PopupMenuItem {
            visible: !root.hasNewWindowAction
            text: "Neues Fenster"
            onActivated: {
                AppsService.openNewWindow(root.entry);
                OverviewService.hide();
            }
        }

        Repeater {
            model: root.actions

            PopupMenuItem {
                required property var modelData

                text: modelData.name
                onActivated: {
                    AppsService.launchAction(modelData);
                    if (modelData.id === "new-window")
                        AppsService.launched(root.entry);
                    OverviewService.hide();
                }
            }
        }
    }

    PopupMenuItem {
        visible: root.showPin
        text: root.entry && AppsService.isFavorite(root.entry) ? "Lösen" : "An Dash anheften"
        onActivated: AppsService.toggleFavorite(root.entry)
    }

    PopupMenuItem {
        visible: root.showQuit
        text: "Beenden"
        onActivated: AppsService.quit(root.entry)
    }
}
