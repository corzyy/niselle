import QtQuick
import qs
import qs.services
import qs.components

// Suchfeld der Übersicht (.search-entry) [_search-entry.scss, searchController.js: SearchEntry].
// Pille in voller Breite (24em), System-Farben (immer dunkel): führendes Lupensymbol, danach das Eingabefeld,
// rechts ein Löschen-Knopf, sobald etwas eingegeben ist. Jede Änderung setzt `SearchService.text` und startet
// damit sofort die Suche. Tastatur (Pfeile, Enter, Esc) wird über Signale an die Übersicht gereicht.
Item {
    id: root

    readonly property alias text: input.text
    readonly property bool focused: input.activeFocus

    // Abstand oben/unten des Suchfelds [_search-entry.scss:4-5]
    implicitWidth: Theme.searchEntryWidth
    implicitHeight: Math.max(field.height, input.implicitHeight + 2 * Theme.entryPaddingV) + Theme.searchEntryMarginTop + Theme.searchEntryMarginBottom

    signal accepted
    signal moveSelection(int dx, int dy)
    signal escapePressed

    function forceFocus() {
        input.forceActiveFocus();
    }

    // Eingabe und Diensteingabe angleichen (reset() leert den Dienst)
    onTextChanged: {
        if (SearchService.text !== root.text)
            SearchService.text = root.text;
    }
    Connections {
        target: SearchService
        function onTextChanged() {
            if (input.text !== SearchService.text) {
                input.text = SearchService.text;
                input.cursorPosition = input.text.length;
            }
        }
    }

    Rectangle {
        id: field
        x: (root.width - width) / 2
        y: Theme.searchEntryMarginTop
        width: Math.min(Theme.searchEntryWidth, root.width)
        height: input.implicitHeight + 2 * Theme.entryPaddingV
        radius: Theme.radiusPill
        color: Theme.glass(input.activeFocus ? Theme.systemEntryBgFocus : Theme.systemEntryBg)

        Behavior on color {
            enabled: !Theme.gameMode
            ColorAnimation {
                duration: Theme.durationButton
                easing.type: Theme.easeTransition
            }
        }

        // Klick in das Feld setzt den Fokus (liegt unter Feld und Knopf)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.forceFocus()
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.entryPaddingH
            anchors.rightMargin: Theme.entryPaddingH + (clearButton.visible ? clearButton.width : 0)
            spacing: Theme.searchEntryIconPadding

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "edit-find-symbolic"
                color: Theme.systemFg
                size: Theme.iconSize
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSize - parent.spacing
                height: input.implicitHeight

                TextInput {
                    id: input
                    anchors.fill: parent
                    color: Theme.systemEntryFg
                    selectionColor: Theme.entrySelection
                    selectedTextColor: Theme.systemFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightNormal
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    onTextEdited: SearchService.text = text
                    onAccepted: root.accepted()

                    Keys.onDownPressed: root.moveSelection(0, 1)
                    Keys.onUpPressed: root.moveSelection(0, -1)
                    Keys.onLeftPressed: root.moveSelection(-1, 0)
                    Keys.onRightPressed: root.moveSelection(1, 0)
                    Keys.onEscapePressed: root.escapePressed()
                }

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "Zum Suchen tippen"
                    color: Theme.systemEntryHint
                    elide: Text.ElideRight
                    font: input.font
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.forceFocus()
                    }
                }
            }
        }

        // Löschen-Knopf [searchController.js: _clearIcon]
        IconButton {
            id: clearButton
            visible: input.text !== ""
            icon: "edit-clear-symbolic"
            flat: true
            bg: "transparent"
            fg: Theme.systemFg
            padding: Theme.basePadding * 0.5
            anchors.right: parent.right
            anchors.rightMargin: Theme.entryPaddingH * 0.5
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                SearchService.reset();
                root.forceFocus();
            }
        }
    }
}
