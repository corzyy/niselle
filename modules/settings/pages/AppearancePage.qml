import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.components
import ".."

// Erscheinungsbild: Stil (Hell/Dunkel), Hintergrundbild und Unterseiten für Farben, Schrift, Fenster, Leiste und Dock.
SettingsPage {
    id: root

    signal navigate(string panel)

    PrefGroup {
        title: "Style"

        Item {
            width: parent.width
            implicitHeight: 150

            RowLayout {
                anchors.centerIn: parent
                spacing: 24

                Repeater {
                    model: [
                        {
                            "name": "Default",
                            "dark": false
                        },
                        {
                            "name": "Dark",
                            "dark": true
                        }
                    ]

                    ColumnLayout {
                        id: option

                        required property var modelData
                        readonly property bool selected: SettingsService.darkMode === modelData.dark
                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 144
                            implicitHeight: 90
                            radius: 10
                            color: option.modelData.dark ? "#1d1d20" : "#fafafb"
                            border.width: option.selected ? 3 : 1
                            border.color: option.selected ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.15)

                            Rectangle {
                                x: 12
                                y: 12
                                width: 64
                                height: 66
                                radius: 6
                                color: option.modelData.dark ? "#2e2e32" : "#ffffff"
                                Rectangle {
                                    x: 8
                                    y: 8
                                    width: 36
                                    height: 6
                                    radius: 3
                                    color: Theme.accentColor
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: SettingsService.setDarkMode(option.modelData.dark)
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: option.modelData.name
                            color: Theme.windowFg
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeBase
                        }
                    }
                }
            }
        }
    }

    // Hintergrundbilder aus <XDG-Bilderordner>/wallpapers (sonst der Bilderordner selbst); Anwenden über awww, Pfad wird in den Einstellungen gemerkt.
    property var scannedFiles: []
    // Nach Nutzung sortiert: zuletzt gesetzte zuerst, danach die übrigen (neueste Datei zuerst)
    readonly property var wallpaperFiles: {
        const history = SettingsService.wallpaperHistory.filter(p => root.scannedFiles.indexOf(p) >= 0);
        return history.concat(root.scannedFiles.filter(p => history.indexOf(p) < 0));
    }
    property bool showAllWallpapers: false
    readonly property int recentWallpapers: 3
    // Was awww tatsächlich anzeigt (primärer Monitor), sonst die gespeicherte Einstellung
    readonly property string currentWallpaper: WallpaperService.awwwPaths[Theme.primaryScreenName] || SettingsService.wallpaper

    function applyWallpaper(path) {
        SettingsService.set("wallpaper", path);
        SettingsService.set("wallpaperHistory", [path].concat(SettingsService.wallpaperHistory.filter(p => p !== path)).slice(0, 50));
        apply.command = ["sh", "-c", 'command -v awww >/dev/null 2>&1 && awww img --transition-type grow --transition-pos center --transition-duration 1.2 --transition-fps 60 "$1"', "sh", path];
        apply.running = true;
    }

    Process {
        id: scan
        running: true
        command: ["sh", "-c", 'pics=$(xdg-user-dir PICTURES 2>/dev/null); [ -n "$pics" ] || pics="$HOME/Pictures"; for d in "$pics/wallpapers" "$pics/Wallpapers" "$pics"; do [ -d "$d" ] || continue; l=$(find "$d" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) -printf "%T@ %p\\n" | sort -rn | cut -d" " -f2-); [ -n "$l" ] && { printf "%s\n" "$l"; break; }; done']
        stdout: StdioCollector {
            onStreamFinished: root.scannedFiles = text.split("\n").filter(l => l !== "")
        }
    }

    Process {
        id: apply
        onExited: {
            WallpaperService.refresh();
            if (SettingsService.useMatugen && MatugenService.available)
                MatugenService.regenerate();
        }
    }

    PrefGroup {
        title: "Wallpaper"
        description: root.wallpaperFiles.length === 0 ? "No images found in the wallpapers folder inside your Pictures directory." : ""

        Item {
            width: parent.width
            // Zeile mit „Get New“/„More“ unter dem Raster (bzw. ganz oben, wenn kein Bild da ist)
            readonly property real actionsY: grid.visible ? grid.y + grid.childrenRect.height + 12 : 12
            implicitHeight: actionsY + actions.implicitHeight + 12

            Grid {
                id: grid
                readonly property int cellWidth: Math.floor((width - (columns - 1) * spacing) / columns)
                x: 12
                y: 12
                width: parent.width - 24
                columns: 3
                spacing: 12

                Repeater {
                    model: root.showAllWallpapers ? root.wallpaperFiles : root.wallpaperFiles.slice(0, root.recentWallpapers)

                    Rectangle {
                        id: thumb

                        required property string modelData
                        readonly property bool selected: root.currentWallpaper === modelData
                        width: grid.cellWidth
                        height: Math.round(width * 0.625)
                        radius: 10
                        color: Theme.alpha(Theme.windowFg, 0.08)
                        border.width: selected ? 3 : 1
                        border.color: selected ? Theme.accentColor : Theme.alpha(Theme.windowFg, 0.15)

                        Item {
                            id: imageClip

                            anchors.fill: parent
                            anchors.margins: thumb.border.width
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: thumbMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }

                            Image {
                                anchors.fill: parent
                                source: "file://" + thumb.modelData
                                sourceSize: Qt.size(288, 180)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        Item {
                            id: thumbMask

                            anchors.fill: imageClip
                            visible: false
                            layer.enabled: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.max(0, thumb.radius - thumb.border.width)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.applyWallpaper(thumb.modelData)
                        }
                    }
                }
            }

            Row {
                id: actions
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.actionsY
                spacing: 12

                Button {
                    text: "Get New"
                    onClicked: root.navigate("appearance/wallpapers")
                }
                Button {
                    visible: root.wallpaperFiles.length > root.recentWallpapers
                    text: root.showAllWallpapers ? "Less" : "More"
                    onClicked: root.showAllWallpapers = !root.showAllWallpapers
                }
            }
        }
    }

    PrefGroup {
        ActionRow {
            title: "Colours"
            icon: "preferences-color-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("appearance/colours")
        }
        ActionRow {
            title: "Font"
            icon: "preferences-desktop-font-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("appearance/font")
        }
        ActionRow {
            title: "Windows"
            icon: "preferences-desktop-appearance-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("appearance/windows")
        }
        ActionRow {
            title: "Menu Bar"
            icon: "view-list-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("appearance/menubar")
        }
        ActionRow {
            title: "Dock"
            icon: "view-app-grid-symbolic"
            suffixIcon: "go-next-symbolic"
            activatable: true
            onActivated: root.navigate("appearance/dock")
        }
    }

    PrefGroup {
        ActionRow {
            title: "Compact"
            subtitle: "Tighter spacing in the top bar, notifications, OSD, quick settings and settings"
            ToggleSwitch {
                checked: SettingsService.compact
                onToggled: SettingsService.set("compact", checked)
            }
        }
        ActionRow {
            title: "Blur"
            ToggleSwitch {
                checked: SettingsService.shellBlur
                onToggled: SettingsService.set("shellBlur", checked)
            }
        }
    }
}
