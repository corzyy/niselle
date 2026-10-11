import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import ".."

// Nachtlicht (gnome-control-center cc-night-light-page): Schalter, Zeitplan (Sonnenuntergang/Aufgang oder
// manuell), Zeiten von/bis und Farbtemperatur (1.700–4.700 K). Angewandt über hyprsunset/wlsunset (SettingsService).
SettingsPage {
    id: root

    readonly property bool twelve: SettingsService.clock12h
    readonly property var fromHM: root._toHM(SettingsService.nightLightFrom)
    readonly property var toHM: root._toHM(SettingsService.nightLightTo)

    function _pad(n) {
        return (n < 10 ? "0" : "") + n;
    }
    function _toHM(frac) {
        const h = Math.floor(frac) % 24;
        let m = Math.round((frac - Math.floor(frac)) * 60);
        if (m === 60)
            m = 59;
        return { "h": h, "m": m };
    }
    function _frac(h, m) {
        return h + m / 60;
    }
    function _h12(h) {
        const x = h % 12;
        return x === 0 ? 12 : x;
    }
    function _ampm(h) {
        return h < 12 ? "AM" : "PM";
    }

    // Stundenwert im Anzeigeformat (24h oder 12h)
    function _hourText(h) {
        return root.twelve ? String(root._h12(h)) : root._pad(h);
    }

    // Ein −/Wert/+-Feld (wie die SpinButtons im Original)
    component SpinValue: RowLayout {
        id: spin

        property int value: 0
        property int max: 59
        property int step: 1
        property bool hour: false

        signal edited(int value)

        spacing: 1

        Button {
            text: "−"
            paddingH: 8
            paddingV: 1
            onClicked: spin.edited((spin.value - spin.step + spin.max + 1) % (spin.max + 1))
        }
        Text {
            Layout.minimumWidth: 22
            horizontalAlignment: Text.AlignHCenter
            text: spin.hour ? root._hourText(spin.value) : root._pad(spin.value)
            color: Theme.windowFg
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeBase
            font.features: ({ "tnum": 1 })
        }
        Button {
            text: "+"
            paddingH: 8
            paddingV: 1
            onClicked: spin.edited((spin.value + spin.step) % (spin.max + 1))
        }
    }

    PrefGroup {
        title: "Night Light"
        description: "Night light makes the screen color warmer. This can help to prevent eye strain and sleeplessness."

        ActionRow {
            title: "Night Light"
            subtitle: SettingsService.nightLightAvailable ? (SettingsService.nightLightActive ? "On" : "Off") : "Night light is not available on this system"
            ToggleSwitch {
                checked: SettingsService.nightLight
                enabled: SettingsService.nightLightAvailable
                onToggled: SettingsService.setNightLight(checked)
            }
        }

        ChoiceRow {
            title: "Schedule"
            enabled: SettingsService.nightLight
            choices: [
                {
                    "value": "automatic",
                    "label": "Sunset to Sunrise"
                },
                {
                    "value": "manual",
                    "label": "Manual Schedule"
                }
            ]
            value: SettingsService.nightLightSchedule
            onPicked: v => SettingsService.set("nightLightSchedule", v)
        }

        // Zeiten von/bis
        ActionRow {
            title: "Times"
            enabled: SettingsService.nightLight && SettingsService.nightLightSchedule === "manual"
            implicitHeight: 58

            RowLayout {
                spacing: 6

                Text {
                    text: "From"
                    color: Theme.alpha(Theme.windowFg, 0.55)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                SpinValue {
                    value: root.fromHM.h
                    max: 23
                    hour: true
                    onEdited: v => SettingsService.set("nightLightFrom", root._frac(v, root.fromHM.m))
                }
                Text {
                    text: ":"
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                SpinValue {
                    value: root.fromHM.m
                    max: 59
                    onEdited: v => SettingsService.set("nightLightFrom", root._frac(root.fromHM.h, v))
                }
                Text {
                    visible: root.twelve
                    text: root._ampm(root.fromHM.h)
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }

                Text {
                    Layout.leftMargin: 6
                    text: "To"
                    color: Theme.alpha(Theme.windowFg, 0.55)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                SpinValue {
                    value: root.toHM.h
                    max: 23
                    hour: true
                    onEdited: v => SettingsService.set("nightLightTo", root._frac(v, root.toHM.m))
                }
                Text {
                    text: ":"
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
                SpinValue {
                    value: root.toHM.m
                    max: 59
                    onEdited: v => SettingsService.set("nightLightTo", root._frac(root.toHM.h, v))
                }
                Text {
                    visible: root.twelve
                    text: root._ampm(root.toHM.h)
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                }
            }
        }

        // Farbtemperatur
        Item {
            Layout.fillWidth: true
            width: parent ? parent.width : 0
            implicitHeight: temperatureColumn.implicitHeight + 2 * 12

            Column {
                id: temperatureColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                opacity: SettingsService.nightLight ? 1 : Theme.disabledOpacity

                Text {
                    text: "Color Temperature"
                    color: Theme.windowFg
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeBase
                    font.weight: Theme.fontWeightBold
                }

                // Schieberegler mit Temperaturverlauf (1.700 K warm rechts, 4.700 K kühl links)
                Item {
                    id: tempSlider
                    width: parent.width
                    height: 20
                    enabled: SettingsService.nightLight

                    readonly property real low: 1700
                    readonly property real high: 4700
                    readonly property real handleR: Theme.sliderHandleSize / 2
                    readonly property real frac: (tempSlider.high - SettingsService.nightLightTemperature) / (tempSlider.high - tempSlider.low)

                    function setFromX(x) {
                        const f = Math.max(0, Math.min(1, (x - tempSlider.handleR) / (tempSlider.width - 2 * tempSlider.handleR)));
                        const v = Math.round((tempSlider.high - f * (tempSlider.high - tempSlider.low)) / 100) * 100;
                        SettingsService.set("nightLightTemperature", Math.max(1700, Math.min(4700, v)));
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Theme.sliderTroughHeight + 4
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: "#ffe1c4"
                            }
                            GradientStop {
                                position: 1
                                color: "#ff7a00"
                            }
                        }
                    }

                    // Marken
                    Repeater {
                        model: [1700, 2700, 3700, 4700]

                        Rectangle {
                            required property int modelData
                            readonly property real f: (tempSlider.high - modelData) / (tempSlider.high - tempSlider.low)
                            x: tempSlider.handleR + f * (tempSlider.width - 2 * tempSlider.handleR) - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Theme.alpha("#000000", 0.35)
                        }
                    }

                    Rectangle {
                        x: tempSlider.handleR + tempSlider.frac * (tempSlider.width - 2 * tempSlider.handleR) - tempSlider.handleR
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.sliderHandleSize
                        height: Theme.sliderHandleSize
                        radius: width / 2
                        color: sliderMouse.containsMouse || sliderMouse.pressed ? Theme.sliderHandleHover : Theme.sliderHandle
                    }

                    MouseArea {
                        id: sliderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: m => tempSlider.setFromX(m.x)
                        onPositionChanged: m => {
                            if (pressed)
                                tempSlider.setFromX(m.x);
                        }
                    }
                }
            }
        }
    }
}
