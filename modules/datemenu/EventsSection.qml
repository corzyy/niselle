import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Terminliste (.events-button) [dateMenu.js EventsSection, _calendar.scss:156-190]: Titel („Heute“, „Gestern“, „Morgen“ oder
// Datum), je Termin Zusammenfassung und Zeit, ohne Termine „Keine Termine“. Ohne Kalender ausgeblendet.
// `plain` (linke Spalte des zweispaltigen Menüs, GNOME-Mockup): ohne Karte und Titel, je Termin eine Zeile
// „14:00  Zusammenfassung“. Mit calendarUpcomingOnly zeigt der heutige Tag nur noch nicht beendete Termine.
Card {
    id: root

    property date date: new Date()
    property var now: new Date()
    signal launch

    readonly property var locale: Qt.locale()
    readonly property bool german: locale.name.startsWith("de")
    readonly property date startDate: new Date(date.getFullYear(), date.getMonth(), date.getDate())
    readonly property date endDate: new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1)
    property bool plain: false
    readonly property bool isToday: startDate <= now && now < endDate
    readonly property var events: {
        EventsService.events;
        const list = EventsService.getEvents(startDate, endDate);
        if (!SettingsService.calendarUpcomingOnly || !isToday)
            return list;
        return list.filter(e => e.end > now || e.start.getTime() === e.end.getTime() && e.start >= now || e.start <= startDate && e.end >= endDate);
    }
    property var calendarApp: AppsService.byId(SettingsService.defaultApps.calendar ?? "") ?? null

    flat: plain
    visible: EventsService.available && SettingsService.calendarShowEvents
    interactive: calendarApp !== null
    onClicked: if (calendarApp) {
        AppsService.launch(calendarApp);
        root.launch();
    }

    readonly property string title: {
        const day = 86400000;
        const n = now;
        if (startDate <= n && n < endDate)
            return german ? "Heute" : "Today";
        if (endDate <= n && n - endDate < day)
            return german ? "Gestern" : "Yesterday";
        if (startDate > n && startDate - n <= day)
            return german ? "Morgen" : "Tomorrow";
        const month = locale.monthName(startDate.getMonth(), Locale.LongFormat);
        const year = startDate.getFullYear() === n.getFullYear() ? "" : " " + startDate.getFullYear();
        return german ? startDate.getDate() + ". " + month + year : month + " " + startDate.getDate() + year;
    }

    // Zeitspalte der schlichten Zeile: Beginn, bei Ganztags- und mehrtägigen Terminen ein Strich
    function rowTime(event) {
        if (event.start < startDate || event.end > endDate)
            return "–";
        return timeOnly(event.start);
    }

    function timeOnly(d) {
        return Qt.formatTime(d, locale.timeFormat(Locale.ShortFormat));
    }

    function dateOnly(d, withYear) {
        if (withYear)
            return Qt.formatDate(d, locale.dateFormat(Locale.ShortFormat));
        return german ? Qt.formatDate(d, "dd.MM.") : Qt.formatDate(d, "MM/dd");
    }

    // Zeitangabe eines Termins [dateMenu.js _formatEventTime]
    function formatEventTime(event) {
        const start = event.start;
        let end = event.end;
        const allDay = start.getTime() === startDate.getTime() && end.getTime() === endDate.getTime();
        if (allDay)
            return german ? "Ganztägig" : "All Day";
        const startsBefore = start < startDate;
        const endsAfter = end > endDate;
        const midnight = d => d.getHours() === 0 && d.getMinutes() === 0 && d.getSeconds() === 0;
        const dash = "–";
        if (startsBefore || endsAfter) {
            const thisYear = now.getFullYear();
            const startsAtMidnight = midnight(start);
            const endsAtMidnight = midnight(end);
            if (endsAtMidnight)
                end = new Date(end.getFullYear(), end.getMonth(), end.getDate() - 1);
            const sameYear = start.getFullYear() === thisYear && end.getFullYear() === thisYear;
            const startDateOnly = dateOnly(start, !sameYear);
            const endDateOnly = dateOnly(end, !sameYear);
            if (startsAtMidnight && endsAtMidnight)
                return startDateOnly + " " + dash + " " + endDateOnly;
            return startDateOnly + " " + timeOnly(start) + " " + dash + " " + endDateOnly + " " + timeOnly(event.end);
        }
        if (start.getTime() === end.getTime())
            return timeOnly(start);
        return timeOnly(start) + " " + dash + " " + timeOnly(end);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.eventsTitlePaddingBottom
            visible: !root.plain
            text: root.title
            color: Theme.cardInsensitiveFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeHeading
            font.weight: Theme.fontWeightBold
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.eventsListSpacing

            Repeater {
                model: root.events

                ColumnLayout {
                    id: entry

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Theme.eventsListSpacing

                    // Schlichte Zeile: Beginn und Zusammenfassung
                    RowLayout {
                        visible: root.plain
                        Layout.fillWidth: true
                        spacing: Theme.basePadding * 2

                        Text {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: Math.max(implicitWidth, 40)
                            text: root.rowTime(entry.modelData)
                            color: Theme.fgColor
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                            font.weight: Theme.fontWeightBold
                            font.features: ({
                                    "tnum": 1
                                })
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.summary
                            elide: Text.ElideRight
                            color: Theme.fgColor
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                        }
                    }

                    // Kartenzeile: Zusammenfassung über Zeitangabe
                    Text {
                        visible: !root.plain
                        Layout.fillWidth: true
                        text: entry.modelData.summary
                        elide: Text.ElideRight
                        color: Theme.fgColor
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeHeading
                        font.weight: Theme.fontWeightBold
                    }
                    Text {
                        visible: !root.plain
                        Layout.fillWidth: true
                        text: root.formatEventTime(entry.modelData)
                        elide: Text.ElideRight
                        color: Theme.cardInsensitiveFg
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeCaption
                        font.weight: Theme.fontWeightNormal
                        font.features: ({
                                "tnum": 1
                            })
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.events.length === 0
                text: root.german ? "Keine Termine" : "No Events"
                color: Theme.cardInsensitiveFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeBase
                font.italic: true
            }
        }
    }
}
