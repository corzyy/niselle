import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Heute-Knopf (.datemenu-today-button) [dateMenu.js TodayButton, _calendar.scss:23-36]: Wochentag fett, darunter das
// Datum als title_2. Reagiert nur, solange nicht der heutige Tag gewählt ist (springt dann zu heute).
Card {
    id: root

    property date date: new Date()
    property bool isToday: true

    readonly property var locale: Qt.locale()
    // „%B %-d %Y“, deutsch „%-d. %B %Y“ [dateMenu.js:92]
    readonly property string dateText: locale.name.startsWith("de") ? date.getDate() + ". " + locale.monthName(date.getMonth(), Locale.LongFormat) + " " + date.getFullYear() : locale.monthName(date.getMonth(), Locale.LongFormat) + " " + date.getDate() + " " + date.getFullYear()

    flat: true
    interactive: !isToday
    padding: Theme.todayButtonPadding

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignLeft
            text: root.locale.dayName(root.date.getDay(), Locale.LongFormat)
            color: Theme.fgColor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
            font.weight: Theme.fontWeightBold
        }
        Text {
            text: root.dateText
            color: Theme.fgColor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeTitle2
            font.weight: Theme.fontWeightExtraBold
        }
    }
}
