import Quickshell
import QtQuick
import qs
import qs.services
import qs.modules.topbar
import qs.modules.overview
import qs.modules.dash
import qs.modules.notifications
import qs.modules.osd
import qs.modules.desktop
import qs.modules.settings
import qs.modules.lock
import qs.modules.polkit
import qs.modules.screenshot
import qs.modules.clipboard
import qs.modules.matugeninstall

ShellRoot {
    id: root

    Binding {
        target: Theme
        property: "dark"
        value: Quickshell.env("NISELLE_LIGHT") === "1" ? false : SettingsService.darkMode
    }

    Binding {
        target: Theme
        property: "compact"
        value: SettingsService.compact
    }

    Binding {
        target: Theme
        property: "blur"
        value: SettingsService.shellBlur
    }

    Component.onCompleted: {
        MatugenService.init();
        BlurService.available;
        GameModeService.available;
        IdleService.caffeine;
        ClipboardService.available;
    }

    Binding {
        target: Theme
        property: "matugen"
        value: SettingsService.useMatugen
    }

    Binding {
        target: Theme
        property: "gameMode"
        value: SettingsService.gameMode
    }

    Binding {
        target: Theme
        property: "fontOverride"
        value: SettingsService.fontFamily
    }
    Binding {
        target: Theme
        property: "fontMonoOverride"
        value: SettingsService.fontFamilyMono
    }

    Binding {
        target: Theme
        property: "primaryScreenName"
        value: DisplayService.primaryName
    }

    Variants {
        model: OverviewService.primaryScreen ? [OverviewService.primaryScreen] : []

        TopBar {
            required property var modelData
            screen: modelData
            overview: OverviewService.shown
            overviewVisible: OverviewService.visible
            onOverviewRequested: OverviewService.toggleByCornerOrButton()
        }
    }

    Variants {
        model: OverviewService.primaryScreen ? [OverviewService.primaryScreen] : []

        Dock {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Desktop {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Overview {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        HotCorner {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        NotificationBanner {
            required property var modelData
            screen: modelData
        }
    }

    LazyLoader {
        active: ScreenshotService.open
        Variants {
            model: Quickshell.screens

            ScreenshotOverlay {
                required property var modelData
                screen: modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        ClipboardPopup {
            required property var modelData
            screen: modelData
        }
    }

    LazyLoader {
        active: SettingsWindowService.open
        component: SettingsWindow {}
    }

    LazyLoader {
        active: MatugenInstallService.open
        component: MatugenInstallWindow {}
    }

    Variants {
        model: Quickshell.screens

        Osd {
            required property var modelData
            screen: modelData
        }
    }

    LockScreen {}

    PolkitDialog {}
}
