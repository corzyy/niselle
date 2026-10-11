import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services

// Linke Spalte des Datumsmenüs (.message-list) [calendar.js CalendarMessageList, messageList.js MessageView]: Medienkarten
// und Benachrichtigungsgruppen in einer Liste mit senkrechtem Ausblenden (68px) und schmaler Überlagerungs-Scrollleiste,
// darunter Nicht-stören-Schalter und „Leeren“. Ohne Inhalt steht der Platzhalter „Keine Benachrichtigungen“ in der Mitte.
// Eine aufgeklappte Gruppe bleibt allein bedienbar; Klick daneben oder Esc klappt sie zu.
Item {
    id: root

    property var now: new Date()
    // Eingebettet (Quick-Settings): volle Breite des Elternelements, kein Rand rechts, ohne Nicht-stören-Schalter
    property bool embedded: false
    // Medienkarten in der Liste (Quick-Settings zeigen sie über der Liste)
    property bool showMedia: true
    // Menü offen (Position und Zeit nur dann aktualisieren)
    property bool active: false

    // Schlüssel der aufgeklappten Gruppe oder ""
    property string expandedKey: ""
    readonly property bool empty: mediaRepeater.count === 0 && groupRows.count === 0
    readonly property bool canClear: NotificationService.groups.length > 0

    signal closeRequested

    // 29em Inhalt + Innenabstand rechts + 1px Rand rechts, dazu Außenabstand rechts [_message-list:9-13]
    readonly property real sideExtra: embedded ? 0 : Theme.messageListPaddingRight + Theme.messageListBorder
    readonly property real marginRight: embedded ? 0 : Theme.messageListMarginRight
    implicitWidth: embedded ? Theme.quickSettingsWidth : Theme.messageListWidth + sideExtra + marginRight
    // Höhe des Inhalts samt Steuerzeile, begrenzt auf `maxHeight`
    property real maxHeight: 10000
    // Eingebettet gibt es nur „Leeren“: ohne Benachrichtigungen entfällt die Zeile samt Rändern (sonst bleibt unter der Medienkarte Leerraum)
    readonly property bool showControls: !embedded || (!empty && canClear)
    implicitHeight: Math.min(maxHeight, stack.height + (showControls ? controls.implicitHeight + Theme.messageControlsPadding + Theme.messageControlsPaddingBottom : 0))

    function collapse() {
        expandedKey = "";
        _trackGroup = null;
    }

    onActiveChanged: if (!active)
        collapse()

    // ───────── Gruppen abgleichen ─────────

    ListModel {
        id: groupRows
    }

    function _urgent(g) {
        return g.notifications.some(n => n.urgency === NotificationUrgency.Critical);
    }

    function _rowIndexForPos(pos) {
        let count = 0;
        for (let i = 0; i < groupRows.count; i++) {
            if (groupRows.get(i).removing)
                continue;
            if (count === pos)
                return i;
            count++;
        }
        return groupRows.count;
    }

    function _rowOf(key) {
        for (let i = 0; i < groupRows.count; i++)
            if (groupRows.get(i).gkey === key)
                return i;
        return -1;
    }

    function syncGroups() {
        const all = NotificationService.groups;
        // Kritische Gruppen zuerst [messageList.js:1750-1772]; ohne sort(), das nicht stabil ist und die Reihenfolge mischt
        const list = all.filter(g => _urgent(g)).concat(all.filter(g => !_urgent(g)));
        const keys = list.map(g => g.key);
        for (let i = 0; i < groupRows.count; i++) {
            if (!groupRows.get(i).removing && keys.indexOf(groupRows.get(i).gkey) < 0)
                groupRows.setProperty(i, "removing", true);
        }
        list.forEach((g, pos) => {
            const idx = _rowOf(g.key);
            const target = _rowIndexForPos(pos);
            if (idx < 0) {
                groupRows.insert(target, {
                    "gkey": g.key,
                    "removing": false
                });
            } else if (idx !== target && !groupRows.get(idx).removing) {
                groupRows.move(idx, idx < target ? target - 1 : target, 1);
            }
        });
    }

    Connections {
        target: NotificationService
        function onGroupsChanged() {
            root.syncGroups();
        }
    }

    Component.onCompleted: syncGroups()

    // „Leeren“: bei wenigen Gruppen verkleinern sie sich, sonst gleiten sie nacheinander heraus [messageList.js:1637-1666]
    function clearAll() {
        const items = [];
        for (let i = 0; i < groupRepeater.count; i++) {
            const it = groupRepeater.itemAt(i);
            if (it && !it.removing)
                items.push(it);
        }
        if (items.length < 2) {
            NotificationService.clearAll();
            return;
        }
        const delay = Theme.gameMode ? 0 : Theme.durationMessage / Math.max(items.length, 5);
        items.forEach((it, i) => it.slideOut(i * delay));
    }

    // ───────── Platzhalter ─────────

    ColumnLayout {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -(root.sideExtra + root.marginRight) / 2
        visible: root.empty
        spacing: 0

        Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Theme.messagePlaceholderSpacing
            name: Quickshell.shellPath("assets/icons/no-notifications-symbolic.svg")
            size: Theme.messagePlaceholderIconSize
            color: Theme.messagePlaceholderFg
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Keine Benachrichtigungen"
            color: Theme.messagePlaceholderFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeTitle3
            font.weight: Theme.fontWeightBold
        }
    }

    // ───────── Liste und Steuerung ─────────

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: root.marginRight
        spacing: 0

        FadeScroll {
            id: viewport

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.rightMargin: root.sideExtra
            contentHeight: stack.height
            onUserScrolled: root._trackGroup = null

            // Klick neben die aufgeklappte Gruppe klappt sie zu
            MouseArea {
                width: parent.width
                height: parent.height
                z: 5
                enabled: root.expandedKey !== ""
                onClicked: root.collapse()
            }

            Column {
                id: stack

                width: viewport.width - Theme.messageViewMarginRight

                Repeater {
                    id: mediaRepeater
                    model: root.showMedia ? MediaService.listedPlayers : []

                    ScaleBin {
                        required property var modelData

                        animateIn: false

                        Item {
                            width: parent.width
                            height: media.implicitHeight + Theme.messageSpacing

                            MediaMessage {
                                id: media
                                width: parent.width
                                height: implicitHeight
                                player: modelData
                                onActivated: root.closeRequested()
                            }
                        }
                    }
                }

                Repeater {
                    id: groupRepeater
                    model: groupRows

                    ScaleBin {
                        id: bin

                        required property string gkey
                        required property bool removing

                        readonly property bool isExpanded: root.expandedKey === gkey

                        animateIn: true
                        shown: !removing
                        z: isExpanded ? 10 : 0
                        onHidden: {
                            const i = root._rowOf(gkey);
                            if (i >= 0)
                                groupRows.remove(i);
                            if (root.expandedKey === gkey)
                                root.collapse();
                        }

                        function slideOut(delay) {
                            slide.delay = delay;
                            slide.start();
                        }

                        SequentialAnimation {
                            id: slide
                            property int delay: 0
                            PauseAnimation {
                                duration: Theme.gameMode ? 0 : slide.delay
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: bin
                                    property: "x"
                                    to: viewport.width
                                    duration: Theme.gameMode ? 0 : Theme.durationMessage
                                    easing.type: Theme.easeOutQuad
                                }
                                NumberAnimation {
                                    target: bin
                                    property: "opacity"
                                    to: 0
                                    duration: Theme.gameMode ? 0 : Theme.durationMessage
                                    easing.type: Theme.easeOutQuad
                                }
                            }
                            ScriptAction {
                                script: NotificationService.dismissGroup(bin.gkey)
                            }
                        }

                        NotificationGroup {
                            id: group

                            width: parent.width
                            groupKey: bin.gkey
                            now: root.now
                            expanded: bin.isExpanded
                            onExpandToggleRequested: {
                                if (bin.isExpanded) {
                                    root.collapse();
                                } else {
                                    root.expandedKey = bin.gkey;
                                    root.scrollToGroup(bin, group);
                                }
                            }
                            onActivated: root.closeRequested()
                        }
                    }
                }
            }
        }

        // Nicht stören und Leeren [_message-list-48:26-60]
        RowLayout {
            id: controls

            visible: root.showControls
            Layout.fillWidth: true
            Layout.margins: Theme.messageControlsPadding
            Layout.bottomMargin: Theme.messageControlsPaddingBottom
            Layout.rightMargin: Theme.messageControlsPadding + root.sideExtra
            spacing: Theme.messageControlsSpacing

            Text {
                visible: !root.embedded
                Layout.alignment: Qt.AlignVCenter
                text: "Nicht stören"
                color: Theme.fgColor
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeHeading
                font.weight: Theme.fontWeightBold
            }

            // .dnd-button: 2px Rand, bei Fokus Akzentfarbe, damit der Schalter nicht wächst
            Item {
                id: dndButton

                visible: !root.embedded
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: dndSwitch.implicitWidth + 2 * Theme.dndButtonBorder
                implicitHeight: dndSwitch.implicitHeight + 2 * Theme.dndButtonBorder
                activeFocusOnTab: true

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusDndButton
                    color: "transparent"
                    border.width: Theme.dndButtonBorder
                    border.color: dndButton.activeFocus ? Theme.dndButtonFocus : "transparent"
                }
                ToggleSwitch {
                    id: dndSwitch
                    anchors.centerIn: parent
                    activeFocusOnTab: false
                    checked: NotificationService.doNotDisturb
                    onToggled: {
                        NotificationService.doNotDisturb = checked;
                        checked = Qt.binding(() => NotificationService.doNotDisturb);
                    }
                }
                Keys.onReturnPressed: NotificationService.toggleDoNotDisturb()
                Keys.onSpacePressed: NotificationService.toggleDoNotDisturb()
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                Layout.alignment: Qt.AlignVCenter
                visible: !root.empty && root.canClear
                pill: true
                text: "Leeren"
                onClicked: root.clearAll()
            }
        }
    }

    // Rechter Rand der Liste [_message-list:9-13]
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: root.marginRight
        visible: !root.embedded
        width: Theme.messageListBorder
        color: Theme.borders
    }

    // Aufgeklappte Gruppe in die Mitte rollen: die Bildlaufposition folgt Bild für Bild dem Aufklappen der Gruppe,
    // denn die Inhaltshöhe wächst erst während der Animation (ein einzelnes scrollTo würde an der alten Höhe gekappt)
    property var _trackGroup: null
    property real _trackFrom: 0
    property real _trackTarget: 0

    function scrollToGroup(bin, group) {
        const pageH = viewport.height;
        const y = bin.y;
        root._trackFrom = viewport.flick.contentY;
        root._trackTarget = Math.max(0, Math.min(y, y + group.expandedHeight / 2 - pageH / 2));
        root._trackGroup = group;
    }

    Connections {
        target: root._trackGroup
        ignoreUnknownSignals: true
        function onExpansionChanged() {
            const g = root._trackGroup;
            if (!g)
                return;
            const flick = viewport.flick;
            const max = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.min(max, root._trackFrom + (root._trackTarget - root._trackFrom) * g.expansion);
            if (g.expansion >= 1)
                root._trackGroup = null;
        }
    }

    Keys.onEscapePressed: event => {
        if (root.expandedKey !== "")
            root.collapse();
        else
            event.accepted = false;
    }
}
