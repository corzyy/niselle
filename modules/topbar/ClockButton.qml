import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Uhr/Datum in der Mitte, Format "Do 9. Okt  14:32" [dateMenu.js, Panel-Button mit hervorgehobenem .clock]
Pill {
    id: root

    property color foreground: Theme.panelFg

    signal calendarRequested

    fg: foreground
    inset: Theme.panelButtonBorder
    hPadding: Theme.panelClockHPadding

    readonly property var locale: Qt.locale()
    readonly property bool german: locale.name.startsWith("de")
    readonly property bool twelveHour: SettingsService.clock12h
    // "dateTime" | "time" | "date"
    readonly property string style: SettingsService.barClockFormat

    // Kurzformen ohne den Abkürzungspunkt, den CLDR anhängt ("Do." → "Do")
    function short(name) {
        return name.replace(/\.$/, "");
    }
    function format(date) {
        const day = short(locale.dayName(date.getDay(), Locale.ShortFormat));
        const month = short(locale.monthName(date.getMonth(), Locale.ShortFormat));
        const time = Qt.formatTime(date, twelveHour ? "h:mm AP" : "HH:mm");
        // "Do 9. Okt  14:32" (de), "Thu Oct 9  14:32" (sonst); zwei Leerzeichen vor der Uhrzeit
        const dateText = german ? day + " " + date.getDate() + ". " + month : day + " " + month + " " + date.getDate();
        return style === "time" ? time : style === "date" ? dateText : dateText + "  " + time;
    }

    onClicked: m => {
        if (!m || m.button === Qt.LeftButton)
            root.calendarRequested();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PanelText {
        text: root.format(clock.date)
        color: root.fg
    }
}
