import QtQuick

Item {
    id: root

    default property alias content: box.data

    readonly property bool occupied: implicitHeight > 0

    implicitHeight: {
        let h = 0;
        for (const c of box.children) {
            if (c.visible)
                h = Math.max(h, c.implicitHeight);
        }
        return h;
    }

    Item {
        id: box
        anchors.fill: parent
    }
}
