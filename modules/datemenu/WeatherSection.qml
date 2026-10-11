import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Wetter [dateMenu.js WeatherSection, _calendar.scss:231-285, GNOME-Mockup calendar-popover]. Zwei Stile
// (SettingsService.calendarWeatherStyle):
//   summary:  Symbol, Zustand („Mostly sunny“) und Höchst-/Tiefstwert in einer Zeile
//   forecast: Titel „Wetter“ mit Ort, darunter bis zu fünf Vorhersagen (Uhrzeit, Symbol 32px, Temperatur fett)
// Statt der Vorhersage erscheint bei Fehlern oder beim Laden eine Statuszeile. Ohne Ort ausgeblendet.
// `plain`: ohne Kartenfläche (in der linken Spalte des zweispaltigen Menüs).
Card {
    id: root

    signal launch

    property var weatherApp: AppsService.byId(SettingsService.defaultApps.weather ?? "") ?? null
    readonly property bool german: Qt.locale().name.startsWith("de")

    property bool plain: false
    readonly property bool summary: SettingsService.calendarWeatherStyle !== "forecast"
    readonly property var current: WeatherService.current

    flat: plain
    visible: WeatherService.available && SettingsService.calendarShowWeather
    interactive: weatherApp !== null
    onClicked: if (weatherApp) {
        AppsService.launch(weatherApp);
        root.launch();
    }

    readonly property string status: {
        if (WeatherService.loading)
            return german ? "Wird geladen …" : "Loading…";
        if (WeatherService.error === "network")
            return german ? "Gehen Sie online, um Wetterinformationen zu erhalten" : "Go Online for Weather Information";
        if (WeatherService.error !== "" || WeatherService.forecasts.length === 0)
            return german ? "Wetterinformationen nicht verfügbar" : "Weather Information Unavailable";
        return "";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.weatherSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: root.summary && root.status === "" && root.current !== null
            spacing: Theme.worldClocksColumnSpacing

            Icon {
                name: root.current ? root.current.icon : ""
                size: Theme.weatherForecastIconSize
                color: Theme.weatherIconColor(root.current ? root.current.icon : "")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.current ? root.current.condition : ""
                    elide: Text.ElideRight
                    color: Theme.fgColor
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.current ? Math.round(root.current.high) + "°  " + Math.round(root.current.low) + "°" : ""
                    color: Theme.cardInsensitiveFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeCaption
                    font.features: ({
                            "tnum": 1
                        })
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.summary
            spacing: Theme.weatherSpacing

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                text: root.german ? "Wetter" : "Weather"
                color: Theme.cardInsensitiveFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeHeading
                font.weight: Theme.fontWeightBold
            }
            Text {
                Layout.alignment: Qt.AlignBottom
                text: WeatherService.locationName
                color: Theme.cardInsensitiveFg
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeHeading
                font.weight: Theme.fontWeightNormal
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.status !== "" || (root.summary && root.current === null)
            text: root.status !== "" ? root.status : (german ? "Wird geladen …" : "Loading…")
            wrapMode: Text.Wrap
            color: Theme.fgColor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.summary && root.status === ""
            spacing: Theme.worldClocksColumnSpacing

            Repeater {
                model: WeatherService.forecasts

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.weatherSpacing

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.weatherForecastTimePadding
                        Layout.bottomMargin: Theme.weatherForecastTimePadding
                        text: Qt.formatTime(modelData.time, Qt.locale().timeFormat(Locale.ShortFormat))
                        color: Theme.fgColor
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeSmaller
                    }
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Theme.weatherForecastIconMargin
                        name: modelData.icon
                        size: Theme.weatherForecastIconSize
                        color: Theme.fgColor
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (Math.round(modelData.temp) >= 0 ? " " : "") + Math.round(modelData.temp) + "°"
                        color: Theme.fgColor
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeBase
                        font.weight: Theme.fontWeightBold
                        font.features: ({
                                "tnum": 1
                            })
                    }
                }
            }
        }
    }
}
