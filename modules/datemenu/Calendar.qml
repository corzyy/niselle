import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Monatskalender (.calendar) [calendar.js Calendar, _calendar.scss:39-149]: Kopf "‹ Oktober ›" mit Pager-Knöpfen,
// Wochentagskürzel, immer 6 Wochen. Heute im Akzentstil, ausgewählter Tag im flachen Aktiv-Stil, Wochenenden
// gedimmt, Tage anderer Monate halbtransparent, Punkt bei Tagen mit Terminen. Wochennummern und Wochenstart
// folgen SettingsService (showWeekNumbers, weekStart), Wochenstart sonst nach Locale.
// Mausrad wechselt den Monat.
Item {
    id: root

    // Ausgewählter Tag (bestimmt auch den angezeigten Monat)
    property date selectedDate: new Date()
    // Heutiges Datum (von außen, damit der Kalender um Mitternacht neu zeichnet)
    property date today: new Date()
    // Wochennummern unabhängig von der Einstellung zeigen (Demo)
    property bool forceWeekNumbers: false

    signal dateSelected(date date)

    readonly property var locale: Qt.locale()
    readonly property bool showWeekNumbers: forceWeekNumbers || SettingsService.showWeekNumbers
    readonly property int weekStart: {
        const i = SettingsService.weekStart;
        return i >= 0 && i <= 6 ? i : locale.firstDayOfWeek % 7;
    }

    // Kürzel des Wochenrasters [calendar.js:55-74, de.po "grid …"]: S M D M D F S
    readonly property var dayAbbreviations: locale.name.startsWith("de") ? ["S", "M", "D", "M", "D", "F", "S"] : [0, 1, 2, 3, 4, 5, 6].map(d => locale.dayName(d, Locale.NarrowFormat))

    // Arbeitsfreie Tage: "06" (Sonntag, Samstag) [calendar.js:32-36]
    function isWorkDay(d) {
        return d.getDay() !== 0 && d.getDay() !== 6;
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Erster sichtbarer Tag; 6 Wochen mit Polsterung nach calendar.js:633-666
    readonly property date beginDate: {
        const first = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1);
        const daysToWeekStart = (7 + first.getDay() - weekStart) % 7;
        const weekPadding = daysToWeekStart === 0 ? 7 : 0;
        return new Date(first.getFullYear(), first.getMonth(), 1 - weekPadding - daysToWeekStart);
    }
    readonly property var days: {
        const list = [];
        for (let i = 0; i < 42; i++)
            list.push(new Date(beginDate.getFullYear(), beginDate.getMonth(), beginDate.getDate() + i));
        return list;
    }

    // ISO-Wochennummer (%V)
    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7);
        const firstThursday = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(((t - firstThursday) / 86400000 - 3 + (firstThursday.getDay() + 6) % 7) / 7);
    }

    // Monat zurück/vor; Tag auf Monatsende begrenzen [calendar.js:575-619]
    function shiftMonth(delta) {
        const y = selectedDate.getFullYear();
        const m = selectedDate.getMonth() + delta;
        const last = new Date(y, m + 1, 0).getDate();
        dateSelected(new Date(y, m, Math.min(selectedDate.getDate(), last)));
    }

    // Termine des sichtbaren Bereichs anfordern
    onBeginDateChanged: EventsService.requestRange(beginDate, new Date(beginDate.getFullYear(), beginDate.getMonth(), beginDate.getDate() + 42))
    Component.onCompleted: EventsService.requestRange(beginDate, new Date(beginDate.getFullYear(), beginDate.getMonth(), beginDate.getDate() + 42))

    // %card_flat mit padding 0 und margin-top 0 [_calendar:40-43]
    implicitWidth: grid.implicitWidth + 2 * (Theme.cardMargin + Theme.cardBorderWidth)
    implicitHeight: grid.implicitHeight + Theme.cardMargin + 2 * Theme.cardBorderWidth

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
            if (d !== 0)
                root.shiftMonth(d > 0 ? -1 : 1);
        }
    }

    GridLayout {
        id: grid

        x: Theme.cardMargin + Theme.cardBorderWidth
        y: Theme.cardBorderWidth
        columns: root.showWeekNumbers ? 8 : 7
        rowSpacing: 0
        columnSpacing: 0

        // Kopf: ‹ Monat › [_calendar:45-71]
        RowLayout {
            Layout.columnSpan: grid.columns
            Layout.fillWidth: true
            spacing: 0

            IconButton {
                icon: "pan-start-symbolic"
                flat: true
                padding: (Theme.calendarPagerSize - Theme.iconSize) / 2
                onClicked: root.shiftMonth(-1)
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: monthLabel.implicitHeight

                Rectangle {
                    id: monthLabel

                    readonly property bool sameYear: root.selectedDate.getFullYear() === root.today.getFullYear()

                    anchors.centerIn: parent
                    implicitWidth: Theme.calendarMonthLabelWidth
                    implicitHeight: monthText.implicitHeight + 2 * Theme.calendarMonthLabelPaddingV
                    width: implicitWidth
                    height: implicitHeight
                    radius: Theme.radiusPill
                    color: monthMouse.containsMouse ? Theme.buttonBg(monthMouse.pressed ? "active" : "hover", {
                        "style": "flat"
                    }) : "transparent"

                    Text {
                        id: monthText
                        anchors.centerIn: parent
                        // "%OB" bzw. "%OB %Y" außerhalb des aktuellen Jahres [calendar.js:419-435]
                        text: root.locale.standaloneMonthName(root.selectedDate.getMonth(), Locale.LongFormat) + (monthLabel.sameYear ? "" : " " + root.selectedDate.getFullYear())
                        color: Theme.fgColor
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeHeading
                        font.weight: Theme.fontWeightBold
                    }

                    MouseArea {
                        id: monthMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
            IconButton {
                icon: "pan-end-symbolic"
                flat: true
                padding: (Theme.calendarPagerSize - Theme.iconSize) / 2
                onClicked: root.shiftMonth(1)
            }
        }

        // Wochentagskürzel [_calendar:120-130]
        Item {
            visible: root.showWeekNumbers
            implicitWidth: 1
            implicitHeight: 1
        }
        Repeater {
            model: 7

            Item {
                required property int index
                readonly property int weekday: (root.weekStart + index) % 7

                Layout.fillWidth: true
                implicitWidth: heading.implicitWidth + 2 * Theme.calendarHeadingMargin
                implicitHeight: heading.implicitHeight + 2 * (Theme.calendarHeadingPaddingV + Theme.calendarHeadingMargin)

                Text {
                    id: heading
                    anchors.centerIn: parent
                    leftPadding: Theme.calendarHeadingPaddingH
                    rightPadding: Theme.calendarHeadingPaddingH
                    text: root.dayAbbreviations[parent.weekday]
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeSmaller
                    font.weight: Theme.fontWeightBold
                    font.features: ({
                            "tnum": 1
                        })
                }
            }
        }

        // 6 Wochen
        Repeater {
            model: 6

            delegate: Repeater {
                id: week

                required property int index
                readonly property int row: index

                model: root.showWeekNumbers ? 8 : 7

                Loader {
                    required property int index
                    readonly property int dayIndex: week.row * 7 + index - (root.showWeekNumbers ? 1 : 0)

                    Layout.row: week.row + 2
                    Layout.column: index
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    sourceComponent: dayIndex < week.row * 7 ? weekNumber : dayButton

                    Component {
                        id: weekNumber

                        // Wochennummer des Donnerstags der Zeile [calendar.js:730-739, _calendar:133-147]
                        Item {
                            implicitWidth: weekText.implicitWidth + 2 * (Theme.calendarWeekNumberPaddingH + Theme.calendarWeekNumberMargin)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Theme.calendarWeekNumberMargin
                                radius: Theme.radiusCalendarWeekNumber
                                color: Theme.calendarWeekNumberBg

                                Text {
                                    id: weekText
                                    anchors.centerIn: parent
                                    text: {
                                        const rowStart = root.days[week.row * 7];
                                        const offset = (4 - rowStart.getDay() + 7) % 7;
                                        return String(root.isoWeek(new Date(rowStart.getFullYear(), rowStart.getMonth(), rowStart.getDate() + offset))).padStart(2, "0");
                                    }
                                    color: Theme.insensitiveFg
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSizeSmaller
                                    font.weight: Theme.fontWeightBold
                                    font.features: ({
                                            "tnum": 1
                                        })
                                }
                            }
                        }
                    }

                    Component {
                        id: dayButton

                        CalendarDay {
                            date: root.days[dayIndex]
                            today: root.sameDay(date, root.today)
                            selected: root.sameDay(date, root.selectedDate)
                            otherMonth: date.getMonth() !== root.selectedDate.getMonth()
                            weekend: !root.isWorkDay(date)
                            hasEvents: EventsService.events.length > 0 && EventsService.hasEvents(date)
                            onClicked: root.dateSelected(date)
                        }
                    }
                }
            }
        }
    }
}
