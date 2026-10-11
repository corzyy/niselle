import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components

// CcDisplaySettings: Einstellungen eines Monitors als Zeilen (Drehung, Auflösung, Bildwiederholrate,
// variable Bildwiederholrate, HDR, Skalierung). Wird direkt auf der Seite (ein Monitor/Spiegeln) oder
// auf der Monitor-Unterseite verwendet.
Column {
    id: root

    property var monitor: null
    // Bildwiederholrate ausblenden, wenn gespiegelt wird (wie GNOME)
    property bool allowRefresh: true

    width: parent ? parent.width : 0
    spacing: 0
    visible: monitor !== null

    readonly property var d: root.monitor ? DisplayService._d(root.monitor) : null
    readonly property var parts: root.d ? DisplayService._modeParts(root.d.mode) : ({ "w": 0, "h": 0 })
    readonly property var scales: root.parts.w > 0 ? DisplayService.scaleOptions(root.parts.w, root.parts.h) : [1]

    // ───────── Drehung ─────────
    ChoiceRow {
        title: "Orientation"
        choices: DisplayService.orientationOptions.map(o => ({ "label": o.label, "value": o.transform }))
        value: root.d ? root.d.transform : 0
        onPicked: v => DisplayService.setTransform(root.monitor.name, v)
    }

    // ───────── Auflösung ─────────
    ChoiceRow {
        title: "Resolution"
        choices: root.monitor ? DisplayService.resolutionOptions(root.monitor).map(r => ({ "label": r.label, "value": r.w + "x" + r.h })) : []
        value: root.parts.w + "x" + root.parts.h
        onPicked: v => {
            const wh = String(v).split("x");
            const rates = DisplayService.refreshOptions(root.monitor, parseInt(wh[0]), parseInt(wh[1]));
            DisplayService.setMode(root.monitor.name, rates.length > 0 ? rates[0].mode : v);
        }
    }

    // ───────── Bildwiederholrate ─────────
    ChoiceRow {
        visible: root.allowRefresh
        title: "Refresh Rate"
        choices: root.monitor ? DisplayService.refreshOptions(root.monitor, root.parts.w, root.parts.h).map(r => ({ "label": r.label, "value": r.mode })) : []
        value: root.d ? root.d.mode : ""
        onPicked: m => DisplayService.setMode(root.monitor.name, m)
    }

    // ───────── Variable Bildwiederholrate ─────────
    ActionRow {
        visible: root.allowRefresh
        title: "Variable Refresh Rate"
        subtitle: "Synchronize the monitor's refresh rate with the content"
        ToggleSwitch {
            checked: root.d ? root.d.vrr : false
            onToggled: DisplayService.setVrr(root.monitor.name, checked)
        }
    }

    // ───────── HDR ─────────
    ActionRow {
        title: "HDR (High Dynamic Range)"
        subtitle: "Display content in a wider range of colors and brightness"
        ToggleSwitch {
            checked: root.d ? root.d.cm === "hdr" : false
            onToggled: DisplayService.setColorMode(root.monitor.name, checked ? "hdr" : "srgb")
        }
    }

    // ───────── Skalierung ─────────
    SegmentedRow {
        visible: root.scales.length <= 5 && root.scales.length > 1
        title: "Scale"
        choices: root.scales.map(s => ({ "value": s, "label": DisplayService.scaleLabel(s) }))
        value: root.d ? root.d.scale : 1
        onPicked: s => DisplayService.setScale(root.monitor.name, s)
    }
    ChoiceRow {
        visible: root.scales.length > 5
        title: "Scale"
        choices: root.scales.map(s => ({ "value": s, "label": DisplayService.scaleLabel(s) }))
        value: root.d ? root.d.scale : 1
        onPicked: s => DisplayService.setScale(root.monitor.name, s)
    }
}
