import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services

// Uhr und Datum des Sperrbildschirms (Vorhang). Sie füllt ihren Elternteil und richtet den Block
// selbst aus, damit Sperrbildschirm und Einstellungs-Vorschau dieselbe Darstellung teilen.
//
// Das Aussehen kommt aus den Lockscreen-Einstellungen (SettingsService.lock*):
//   lockClockStyle    inline (eine Zeile) | stacked (Stunden über Minuten) | minimal | mono
//   lockClockSize     s | m | l | xl
//   lockClockWeight   light | regular | bold | extra
//   lockClockPosition top | upper | center | lower
//   lockClockColor    auto (weiß) | accent
//   lockDateFormat    long | full | short | numeric | weekday | none
//   lockDateUppercase
//   lockShowHint
// Vorbilder: Material 3 Expressive (flexible Uhr) und GNOME Screen Shield.
Item {
    id: root

    // Vorschaufenster: den Hinweis sofort zeigen, ohne Wartezeit
    property bool hintAlways: false
    // Nur auf dem Vorhang aktiv: setzt den Hinweis zurück und startet den Timer neu
    property bool active: true

    readonly property color white: "#ffffff"
    readonly property color fg: SettingsService.lockClockColor === "accent" ? Theme.accentColor : white
    readonly property bool stacked: SettingsService.lockClockStyle === "stacked"
    readonly property bool minimal: SettingsService.lockClockStyle === "minimal"
    readonly property string family: SettingsService.lockClockStyle === "mono" ? Theme.fontFamilyMono : Theme.fontFamily

    readonly property real sizeMul: {
        switch (SettingsService.lockClockSize) {
        case "s":
            return 4.5;
        case "m":
            return 5.5;
        case "xl":
            return 7.5;
        default:
            return 6;
        }
    }
    readonly property int weight: {
        switch (SettingsService.lockClockWeight) {
        case "light":
            return Font.Light;
        case "regular":
            return Font.Normal;
        case "bold":
            return Font.Bold;
        default:
            return Font.ExtraBold;
        }
    }
    readonly property real positionOffset: {
        switch (SettingsService.lockClockPosition) {
        case "top":
            return -0.36;
        case "center":
            return 0;
        case "lower":
            return 0.24;
        default:
            return -0.13;
        }
    }
    readonly property int timeSize: Math.round(Theme.fontSizeBase * root.sizeMul)
    readonly property bool hintVisible: SettingsService.lockShowHint && (root.hintAlways || root.hintShown)

    property bool hintShown: false

    function _armHint() {
        root.hintShown = false;
        if (SettingsService.lockShowHint && !root.hintAlways && root.active)
            hintTimer.restart();
    }

    onActiveChanged: root._armHint()
    Component.onCompleted: root._armHint()

    Timer {
        id: hintTimer
        interval: 4000
        repeat: false
        onTriggered: root.hintShown = true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string dateText: {
        const d = clock.date;
        const de = Qt.locale().name.startsWith("de");
        switch (SettingsService.lockDateFormat) {
        case "none":
            return "";
        case "full":
            return Qt.formatDate(d, de ? "dddd, d. MMMM yyyy" : "dddd, MMMM d, yyyy");
        case "short":
            return Qt.formatDate(d, de ? "ddd, d. MMM" : "ddd, MMM d");
        case "numeric":
            return Qt.formatDate(d, de ? "d.M.yyyy" : "M/d/yyyy");
        case "weekday":
            return Qt.formatDate(d, "dddd");
        default:
            return Qt.formatDate(d, de ? "dddd, d. MMMM" : "dddd, MMMM d");
        }
    }

    Column {
        id: col

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.height * root.positionOffset
        spacing: Theme.lockClockSpacing

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: !Theme.gameMode
            shadowColor: "#99000000"
            shadowBlur: root.minimal ? 0.5 : 0.8
            shadowVerticalOffset: 2
            autoPaddingEnabled: true
        }

        // Uhr, eine Zeile
        Text {
            visible: !root.stacked
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, SettingsService.clock12h ? "h:mm" : "HH:mm")
            color: root.fg
            font.family: root.family
            font.pointSize: root.timeSize
            font.weight: root.weight
            font.letterSpacing: root.minimal ? -Theme.fontSizeBase * 0.15 : 0
            font.features: {
                "tnum": 1
            }
        }

        // Uhr, gestapelt: Stunden über Minuten (Material 3 Expressive)
        Column {
            visible: root.stacked
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -root.timeSize * 0.18

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "hh")
                color: root.fg
                font.family: root.family
                font.pointSize: root.timeSize
                font.weight: root.weight
                font.features: {
                    "tnum": 1
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm

                Text {
                    id: minutes
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "mm")
                    color: root.fg
                    font.family: root.family
                    font.pointSize: root.timeSize
                    font.weight: root.weight
                    font.features: {
                        "tnum": 1
                    }
                }
                Text {
                    visible: SettingsService.clock12h
                    anchors.bottom: minutes.bottom
                    anchors.bottomMargin: root.timeSize * 0.18
                    text: Qt.formatTime(clock.date, "AP")
                    color: root.fg
                    opacity: 0.85
                    font.family: root.family
                    font.pointSize: Theme.fontSizeTitle2
                    font.weight: root.weight
                }
            }
        }

        // Datum
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.dateText !== ""
            text: root.dateText
            color: root.fg
            opacity: 0.92
            font.family: root.family
            font.pointSize: Theme.fontSizeTitle1
            font.weight: Theme.fontWeightNormal
            font.capitalization: SettingsService.lockDateUppercase ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: SettingsService.lockDateUppercase ? 1 : 0
        }

        // Hinweis, erscheint nach kurzer Untätigkeit
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.hintVisible
            text: "Click or press a key"
            color: root.fg
            opacity: root.hintVisible ? 0.85 : 0
            topPadding: Theme.lockClockHintMargin
            font.family: root.family
            font.pointSize: Theme.fontSizeBase
            font.weight: Theme.fontWeightBold

            Behavior on opacity {
                enabled: !Theme.gameMode
                NumberAnimation {
                    duration: Theme.durationButton
                    easing.type: Theme.easeOut
                }
            }
        }
    }
}
