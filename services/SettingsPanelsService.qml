pragma Singleton

import QtQuick
import Quickshell

// Katalog der Einstellungen-App (modules/settings): Seitenleisten-Bereiche, Unterseiten und die daraus
// abgeleitete, durchsuchbare Liste. SettingsWindow nutzt `groups`/`subpageTitles`/`pageFiles`; die Shell-Suche
// (SearchService) nutzt `searchable`, um Bereiche und Unterseiten als Ergebnis anzubieten.
Singleton {
    id: root

    // Seitenleiste: Gruppen durch Trennlinien getrennt [Reihenfolge wie in der Vorlage]
    readonly property var groups: [
        [
            {
                "id": "network",
                "title": "Network",
                "icon": "preferences-system-network-symbolic"
            },
            {
                "id": "bluetooth",
                "title": "Bluetooth",
                "icon": "bluetooth-active-symbolic"
            }
        ],
        [
            {
                "id": "displays",
                "title": "Displays",
                "icon": "video-display-symbolic"
            },
            {
                "id": "sound",
                "title": "Sound",
                "icon": "audio-volume-high-symbolic"
            },
            {
                "id": "power",
                "title": "Power",
                "icon": "gnome-power-manager-symbolic"
            },
            {
                "id": "appearance",
                "title": "Appearance",
                "icon": "org.gnome.Settings-appearance-symbolic"
            }
        ],
        [
            {
                "id": "notifications",
                "title": "Notifications",
                "icon": "preferences-system-notifications-symbolic"
            }
        ],
        [
            {
                "id": "mouse",
                "title": "Mouse",
                "icon": "input-mouse-symbolic"
            },
            {
                "id": "keyboard",
                "title": "Keyboard",
                "icon": "input-keyboard-symbolic"
            }
        ],
        [
            {
                "id": "system",
                "title": "System",
                "icon": "emblem-system-symbolic"
            },
            {
                "id": "about",
                "title": "About",
                "icon": "help-about-symbolic"
            }
        ]
    ]

    readonly property var subpageTitles: ({
            "network/saved": "Saved Wi-Fi Networks",
            "appearance/windows": "Windows",
            "appearance/colours": "Colours",
            "appearance/font": "Font",
            "appearance/menubar": "Menu Bar",
            "appearance/dock": "Dock",
            "system/defaultapps": "Default Apps",
            "system/datetime": "Date & Time"
        })
    readonly property var pageFiles: ({
            "network": "NetworkPage",
            "network/saved": "SavedNetworksPage",
            "bluetooth": "BluetoothPage",
            "displays": "DisplaysPage",
            "sound": "SoundPage",
            "power": "PowerPage",
            "appearance": "AppearancePage",
            "appearance/windows": "WindowsPage",
            "appearance/colours": "ColoursPage",
            "appearance/font": "FontPage",
            "appearance/menubar": "MenuBarPage",
            "appearance/dock": "DockPage",
            "mouse": "MousePage",
            "keyboard": "KeyboardPage",
            "notifications": "NotificationsPage",
            "system/defaultapps": "DefaultAppsPage",
            "system": "SystemPage",
            "about": "AboutPage",
            "system/datetime": "DateTimePage"
        })

    // Unterseiten ohne eigenen Seitenleisten-Eintrag, die aber durchsuchbar sein sollen
    readonly property var subpages: [
        {
            "id": "settings:network/saved",
            "name": "Saved Wi-Fi Networks",
            "genericName": "",
            "keywords": "saved known network wifi wireless",
            "comment": "",
            "icon": "network-wireless-symbolic",
            "panel": "network/saved",
            "description": "Network"
        },
        {
            "id": "settings:appearance/font",
            "name": "Font",
            "genericName": "",
            "keywords": "font fonts typeface text system interface monospace serif sans",
            "comment": "",
            "icon": "preferences-desktop-font-symbolic",
            "panel": "appearance/font",
            "description": "Appearance"
        },
        {
            "id": "settings:appearance/colours",
            "name": "Colours",
            "genericName": "",
            "keywords": "colours colors colour palette matugen scheme accent tint theme",
            "comment": "",
            "icon": "preferences-color-symbolic",
            "panel": "appearance/colours",
            "description": "Appearance"
        },
        {
            "id": "settings:appearance/windows",
            "name": "Windows",
            "genericName": "",
            "keywords": "windows hyprland compositor gaps border rounding corners opacity shadow blur",
            "comment": "",
            "icon": "preferences-desktop-appearance-symbolic",
            "panel": "appearance/windows",
            "description": "Appearance"
        },
        {
            "id": "settings:appearance/menubar",
            "name": "Menu Bar",
            "genericName": "",
            "keywords": "shell menu bar top panel battery percentage",
            "comment": "",
            "icon": "view-list-symbolic",
            "panel": "appearance/menubar",
            "description": "Appearance"
        },
        {
            "id": "settings:appearance/dock",
            "name": "Dock",
            "genericName": "",
            "keywords": "shell dock dash size icon persistent autohide hide pinned apps",
            "comment": "",
            "icon": "view-app-grid-symbolic",
            "panel": "appearance/dock",
            "description": "Appearance"
        },
        {
            "id": "settings:system/defaultapps",
            "name": "Default Apps",
            "genericName": "",
            "keywords": "default applications handler web browser mail",
            "comment": "",
            "icon": "application-x-executable-symbolic",
            "panel": "system/defaultapps",
            "description": "System"
        },
        {
            "id": "settings:system/datetime",
            "name": "Date & Time",
            "genericName": "",
            "keywords": "date time timezone clock ntp automatic",
            "comment": "",
            "icon": "preferences-system-time-symbolic",
            "panel": "system/datetime",
            "description": "System"
        }
    ]

    // Zusatzbegriffe je Seitenleisten-Bereich (über den Titel hinaus)
    readonly property var _keywords: ({
            "network": "network wifi wireless ethernet vpn proxy dns",
            "bluetooth": "bluetooth device pairing",
            "displays": "display monitor resolution scale refresh rate",
            "sound": "sound audio volume speaker microphone output input",
            "power": "power battery energy mode profile suspend sleep lock screen idle blank caffeine keep awake",
            "appearance": "appearance style theme dark light wallpaper colors fonts blur",
            "notifications": "notifications alerts banners do not disturb",
            "mouse": "mouse pointer cursor speed touchpad",
            "keyboard": "keyboard layout shortcuts repeat",
            "about": "about system information version hardware model",
            "system": "system date time default apps"
        })

    // Flache, durchsuchbare Liste { id, name, genericName, keywords, comment, icon, panel, description }.
    // Aufbau wie ein Desktop-Eintrag, damit AppsService.makeIndex/searchIndex sie indizieren können.
    readonly property var searchable: {
        const list = [];
        for (const g of root.groups)
            for (const item of g)
                list.push({
                    "id": "settings:" + item.id,
                    "name": item.title,
                    "genericName": "",
                    "keywords": root._keywords[item.id] ?? "",
                    "comment": "",
                    "icon": item.icon,
                    "panel": item.id,
                    "description": ""
                });
        return list.concat(root.subpages);
    }
}
