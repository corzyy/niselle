import QtQuick
import QtQuick.Effects
import Quickshell
import qs

// Benutzer-Avatar (UserWidget.Avatar): rundes Bild aus ~/.face bzw. AccountsService, sonst das Standard-Symbol.
Item {
    id: root

    property string userName: ""
    property real size: 64

    readonly property var candidates: {
        const list = [];
        if (userName === Quickshell.env("USER"))
            list.push("file://" + Quickshell.env("HOME") + "/.face");
        if (userName !== "")
            list.push("file:///var/lib/AccountsService/icons/" + userName);
        return list;
    }
    property int candidate: 0

    onCandidatesChanged: candidate = 0

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.mix(Theme.fgColor, Theme.bgColor, 0.1)
        visible: face.status !== Image.Ready

        Icon {
            anchors.centerIn: parent
            name: "avatar-default-symbolic"
            size: root.size / 2
            color: Theme.fgColor
        }
    }

    Image {
        id: face
        anchors.fill: parent
        source: root.candidate < root.candidates.length ? root.candidates[root.candidate] : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        onStatusChanged: {
            if (status === Image.Error)
                root.candidate++;
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: face
        visible: face.status === Image.Ready
        maskEnabled: true
        maskSource: mask
    }
}
