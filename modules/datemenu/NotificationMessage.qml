import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services

// Nachricht zu einer Benachrichtigung [messageList.js NotificationMessage]. Die Benachrichtigung wird gemerkt, solange sie
// lebt; verschwindet sie (Schließen), zeigt die Karte beim Verkleinern weiter die letzten Werte.
Message {
    id: root

    required property var notification
    property var now: new Date()

    // Letzte bekannte Werte
    property string _title: ""
    property string _body: ""
    property string _appName: ""
    property string _appIcon: ""
    property string _image: ""
    property var _actions: []
    property var _time: null

    function snapshot() {
        const n = root.notification;
        if (!n)
            return;
        root._title = n.summary;
        root._body = n.body;
        root._appName = n.appName;
        root._appIcon = n.desktopEntry ? (DesktopEntries.heuristicLookup(n.desktopEntry)?.icon ?? n.appIcon) : n.appIcon;
        root._image = n.image !== "" ? n.image : n.appIcon;
        root._time = NotificationService.timeOf(n);
        root._actions = n.actions.filter(a => a.identifier !== "default").map(a => ({
                    "label": a.text,
                    "trigger": () => NotificationService.invoke(a)
                }));
    }

    Component.onCompleted: snapshot()
    onNotificationChanged: snapshot()

    Connections {
        target: root.notification
        ignoreUnknownSignals: true
        function onSummaryChanged() {
            root.snapshot();
        }
        function onBodyChanged() {
            root.snapshot();
        }
        function onAppIconChanged() {
            root.snapshot();
        }
        function onImageChanged() {
            root.snapshot();
        }
        function onActionsChanged() {
            root.snapshot();
        }
    }

    sourceTitle: _appName
    sourceIcon: _appIcon
    title: _title
    body: _body
    iconSource: _image
    actions: _actions
    timeText: NotificationService.timeSpan(_time, now)
    closable: true
}
