pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Wetter für das Datumsmenü [dateMenu.js WeatherSection, misc/weather.js]. GNOME nutzt GWeather mit dem Ort aus
// GNOME Wetter; hier kommt der Ort aus SettingsService.weatherLocation ({ name, latitude, longitude }) und die
// Vorhersage stündlich von Open-Meteo (ohne Schlüssel). Kein Ort → `available` false, Abschnitt ausgeblendet.
// Abgefragt wird nur beim Öffnen des Menüs (wie vfunc_map → update), höchstens alle 10 Minuten.
Singleton {
    id: root

    readonly property bool demo: Quickshell.env("NISELLE_DATEMENU_DEMO") === "1"
    readonly property var location: demo ? {
        "name": "Berlin",
        "latitude": 52.52,
        "longitude": 13.41
    } : (SettingsService.weatherLocation ?? {})

    readonly property bool available: location.latitude !== undefined && location.longitude !== undefined
    readonly property string locationName: location.name ?? ""
    readonly property bool loading: _loading
    // "", "network", "unavailable"
    readonly property string error: _error
    // [{ time: Date, temp: Zahl °C, icon: Name }] ab jetzt, mindestens 1 h Abstand, höchstens 5 [dateMenu.js _getInfos]
    readonly property var forecasts: _forecasts
    // Aktuelles Wetter für die Kurzansicht: { icon, condition, high, low } oder null
    readonly property var current: _current
    readonly property string unit: SettingsService.weatherUnit === "fahrenheit" ? "fahrenheit" : "celsius"

    property bool _loading: false
    property string _error: ""
    property var _forecasts: []
    property var _current: null
    property double _fetchedAt: 0

    readonly property int minInterval: 10 * 60 * 1000

    function update() {
        if (!root.available || fetch.running || Date.now() - root._fetchedAt < root.minInterval)
            return;
        root._loading = root._forecasts.length === 0;
        fetch.running = true;
    }

    onLocationChanged: reset()
    onUnitChanged: reset()

    function reset() {
        root._fetchedAt = 0;
        root._forecasts = [];
        root._current = null;
        update();
    }

    // WMO-Wettercode → Beschreibung
    function conditionFor(code) {
        const german = Qt.locale().name.startsWith("de");
        const t = (en, de) => german ? de : en;
        if (code === 0)
            return t("Clear", "Klar");
        if (code === 1)
            return t("Mostly sunny", "Überwiegend sonnig");
        if (code === 2)
            return t("Partly cloudy", "Teilweise bewölkt");
        if (code === 3)
            return t("Overcast", "Bedeckt");
        if (code === 45 || code === 48)
            return t("Fog", "Nebel");
        if (code >= 51 && code <= 57)
            return t("Drizzle", "Nieselregen");
        if (code >= 61 && code <= 67 || code >= 80 && code <= 82)
            return t("Rain", "Regen");
        if (code >= 71 && code <= 77 || code === 85 || code === 86)
            return t("Snow", "Schnee");
        if (code >= 95)
            return t("Thunderstorm", "Gewitter");
        return t("Unknown", "Unbekannt");
    }

    // WMO-Wettercode → GWeather-Symbol [Open-Meteo-Dokumentation, gweather-info.c]
    function iconFor(code, isDay) {
        const night = isDay ? "" : "-night";
        if (code === 0 || code === 1)
            return "weather-clear" + night + "-symbolic";
        if (code === 2)
            return "weather-few-clouds" + night + "-symbolic";
        if (code === 3)
            return "weather-overcast-symbolic";
        if (code === 45 || code === 48)
            return "weather-fog-symbolic";
        if (code >= 51 && code <= 57 || code === 80)
            return "weather-showers-scattered-symbolic";
        if (code >= 61 && code <= 67 || code === 81 || code === 82)
            return "weather-showers-symbolic";
        if (code >= 71 && code <= 77 || code === 85 || code === 86)
            return "weather-snow-symbolic";
        if (code >= 95)
            return "weather-storm-symbolic";
        return "weather-severe-alert-symbolic";
    }

    function _parse(text) {
        const data = JSON.parse(text);
        const h = data.hourly;
        const now = new Date();
        const list = [];
        let last = 0;
        for (let i = 0; i < h.time.length && list.length < Theme.weatherMaxForecasts; i++) {
            // Ortszeit "2026-10-09T14:00" (timezone=auto) → lokale Zeit über den Versatz
            const t = new Date(Date.parse(h.time[i] + ":00Z") - data.utc_offset_seconds * 1000);
            if (t < now)
                continue;
            if (t - last < 3600000)
                continue;
            list.push({
                "time": t,
                "temp": h.temperature_2m[i],
                "icon": root.iconFor(h.weather_code[i], h.is_day[i] === 1)
            });
            last = t.getTime();
        }
        return list;
    }

    function _parseCurrent(data) {
        const c = data.current;
        const d = data.daily;
        if (!c || !d || !d.temperature_2m_max || d.temperature_2m_max.length === 0)
            return null;
        return {
            "icon": root.iconFor(c.weather_code, c.is_day === 1),
            "condition": root.conditionFor(c.weather_code),
            "temp": c.temperature_2m,
            "high": d.temperature_2m_max[0],
            "low": d.temperature_2m_min[0]
        };
    }

    Process {
        id: fetch
        command: ["curl", "-sfL", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + root.location.latitude + "&longitude=" + root.location.longitude + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min&hourly=temperature_2m,weather_code,is_day&forecast_days=2&timezone=auto&temperature_unit=" + root.unit]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === "")
                    return;
                try {
                    root._forecasts = root._parse(text);
                    root._current = root._parseCurrent(JSON.parse(text));
                    root._error = root._forecasts.length > 0 ? "" : "unavailable";
                    root._fetchedAt = Date.now();
                } catch (e) {
                    root._error = "unavailable";
                }
                root._loading = false;
            }
        }
        onExited: code => {
            if (code === 0)
                return;
            root._loading = false;
            // curl: 6/7/28 = keine Verbindung → "Gehen Sie online …"
            root._error = (code === 6 || code === 7 || code === 28) ? "network" : "unavailable";
        }
    }
}
