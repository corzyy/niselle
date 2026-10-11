import Quickshell
import QtQuick
import qs
import qs.dev
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
import qs.modules.switcher
import qs.modules.clipboard
import qs.modules.matugeninstall

ShellRoot {
    id: root

    // Hell/Dunkel folgt SettingsService.darkMode (Dunkler Stil in den Quick-Settings)
    Binding {
        target: Theme
        property: "dark"
        // NISELLE_LIGHT=1 erzwingt hell (Entwicklungshilfe, speichert nichts)
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
        // GameModeService laden, damit Hyprland-Blur und -Animationen folgen (sonst bliebe das Singleton ungenutzt)
        GameModeService.available;
        AccessibilityService.available;
        // Leerlauf-Sperre/-Standby und Koffein
        IdleService.caffeine;
        ClipboardService.available;
        UpdateService.supported;
    }

    // Farben aus Matugen (Palette wird von `matugen` erzeugt, siehe MatugenService)
    Binding {
        target: Theme
        property: "matugen"
        value: SettingsService.useMatugen
    }

    // Gamemode: Shell-Animationen und -Schatten aus (Hyprland wendet GameModeService an)
    Binding {
        target: Theme
        property: "gameMode"
        // Weniger Bewegung (Barrierefreiheit) schaltet dieselben Animationen ab
        value: SettingsService.gameMode || SettingsService.a11yReduceMotion
    }

    // Schrift aus den Einstellungen (Appearance › Font)
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

    // Größere Schrift (Barrierefreiheit)
    Binding {
        target: Theme
        property: "textScale"
        value: SettingsService.a11yLargeText ? 1.25 : 1
    }

    // Leiste nur auf dem primären Monitor (Theme.primaryScreenName), nicht auf Zweitmonitoren
    // Primäranzeige aus den Displays-Einstellungen (DisplayService)
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

    // Dauerhaftes Dock (Einstellung „Persistent“) nur auf dem primären Monitor
    Variants {
        model: OverviewService.primaryScreen ? [OverviewService.primaryScreen] : []

        Dock {
            required property var modelData
            screen: modelData
        }
    }

    // Hintergrundflächen je Monitor: Rechtsklick auf den Desktop öffnet das Hintergrundmenü
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

    // Bildschirmfoto-/Aufnahme-Oberfläche je Monitor (niselle screenshot); lädt erst beim ersten Öffnen
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

    // Alt+Tab-Umschalter, nur auf dem primären Monitor sichtbar (niselle switcher next|prev|window)
    Variants {
        model: Quickshell.screens

        Switcher {
            required property var modelData
            screen: modelData
        }
    }

    // Zwischenablage-Verlauf am Mauszeiger (niselle clipboard, Super+V)
    Variants {
        model: Quickshell.screens

        ClipboardPopup {
            required property var modelData
            screen: modelData
        }
    }

    // Einstellungen-App (niselle settings [panel]); lädt erst beim ersten Öffnen
    LazyLoader {
        active: SettingsWindowService.open
        component: SettingsWindow {}
    }

    // Protokollfenster der Matugen-Installation (Einstellungen › System); lädt erst beim ersten Öffnen
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

    // Sperrbildschirm (niselle lock, loginctl lock-session)
    LockScreen {}

    // Polkit-Agent mit Authentifizierungsdialog (pkexec, Systemeinstellungen usw.)
    PolkitDialog {}

    // Entwicklungshilfe: NISELLE_GALLERY=1 zeigt alle Basis-Komponenten
    LazyLoader {
        active: Quickshell.env("NISELLE_GALLERY") === "1"
        component: Gallery {}
    }

    // Entwicklungshilfe: NISELLE_DEBUG=<service> zeigt das Debug-Fenster der Services
    LazyLoader {
        active: !!Quickshell.env("NISELLE_DEBUG")
        component: ServiceDebug {}
    }
}
