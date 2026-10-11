import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

// Symbolisches Icon (wie StIcon mit -st-icon-style: symbolic): wird in `color` eingefärbt.
// Fehlt das Icon im Theme, bleibt das Element leer.
Item {
    id: root

    property string name: ""
    property color color: Theme.fgColor
    property real size: Theme.iconSize
    // false: Icon unverändert darstellen (App-Icons)
    property bool symbolic: true
    // false: Bild synchron laden (erscheint sofort, z. B. Dash beim Start)
    property bool asynchronous: false

    // BigYahoo: legt die israelische Flagge über jedes Icon, ohne die Icon-Kette darunter anzufassen
    // (sonst bliebe nach dem Abschalten die einfarbige Maske des Effects leer).
    readonly property bool flagActive: SettingsService.bigYahoo && name !== ""
    readonly property string flagSource: "file://" + Quickshell.shellPath("assets/icons/israel-flag.svg")

    implicitWidth: size
    implicitHeight: size

    readonly property string resolved: {
        if (name === "")
            return "";
        if (name.startsWith("/"))
            return "file://" + name;
        if (name.includes("://"))
            return name;
        // check=true: fehlt das Icon im Theme, kommt "" zurück statt eines Pfads,
        // der sonst als leere Maske eine schwarze Fläche zeichnen würde.
        return Quickshell.iconPath(name, true);
    }

    IconImage {
        id: image
        anchors.fill: parent
        source: root.resolved
        asynchronous: root.asynchronous
        visible: !root.symbolic && !root.flagActive
        layer.enabled: root.symbolic
    }

    // Einfärben: Helligkeit anheben und über colorization die Zielfarbe setzen.
    // Die vorherige Maske (einfarbige Fläche, maskiert mit dem Alphabet des Icons) hat die
    // Kantenglättung auf hartes 0/1 reduziert – die Symbole wirkten dadurch ausgefranst und fett.
    // colorization behält den Alphakanal des Icons (weiche Kanten) und sogar teiltransparente
    // Farben (disabled-Zustände). brightness 0.8 hebt die Symbolfüllung (#2e3436) auf Weiß,
    // sodass colorization exakt die Zielfarbe trifft.
    MultiEffect {
        anchors.fill: parent
        source: image
        visible: root.symbolic && !root.flagActive && image.status === Image.Ready
        brightness: 0.8
        colorization: 1.0
        colorizationColor: root.color
    }

    // Flaggen-Überlagerung: farbig, ungefiltert, ersetzt das Icon solange BigYahoo aktiv ist
    IconImage {
        anchors.fill: parent
        source: root.flagActive ? root.flagSource : ""
        visible: root.flagActive
    }
}
