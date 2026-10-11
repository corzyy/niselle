pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Zentrale Designwerte der Shell. Alles, was Farbe, Maß, Schrift oder Animation ist, kommt von hier.
//
// Quellen (Kopien unter docs/sources/, Zeilenangaben beziehen sich darauf):
//   gnome-shell main, data/theme/gnome-shell-sass  (letzter Theme-Commit 90f34071cd7a, 2026-09-21)
//     _colors.scss, _default-colors.scss, _palette.scss, _common.scss, _drawing.scss, _panel.scss,
//     _popovers.scss, _slider.scss, _switches.scss, _buttons.scss, _quick-settings.scss, _overview.scss
//   gnome-shell main, js/ui: overview.js, boxpointer.js, dash.js, windowManager.js, workspacesView.js,
//     overviewControls.js, messageTray.js, appDisplay.js; src/st: st-theme-context.c, st-theme-node.c
//   libadwaita 1.9.4: Stylesheet aus libadwaita-1.9.4-gtk.css (gresource /org/gnome/Adwaita/styles/gtk.css)
// Kürzel: [_common:31] = docs/sources/_common.scss Zeile 31, [adw:62] = libadwaita-1.9.4-gtk.css Zeile 62.
//
// Rechenbasis: 1em = 11pt = 14.667px bei 96 dpi ([_common:30], stage-Schriftgröße). Qt muss mit 96 dpi
// laufen (QT_FONT_DPI=96), damit pointSize-Werte den GNOME-Pixelwerten entsprechen.
Singleton {
    id: root

    // ───────────────────────── Schalter ─────────────────────────

    // Hell/Dunkel. Wird in shell.qml an SettingsService.darkMode gebunden.
    property bool dark: true

    // Primärer Monitor (Dash, Suche, Arbeitsflächen-Leiste, Banner); fehlt er, gilt der erste Bildschirm.
    // shell.qml bindet das an DisplayService.primaryName (Displays-Einstellungen).
    property string primaryScreenName: "DP-1"

    // Akzent: blue teal green yellow orange red pink purple slate (Schlüssel von `accents`); gilt ohne Matugen-Palette
    property string accent: "blue"

    // Matugen-Palette verwenden, wenn sie vorhanden ist (shell.qml bindet das an SettingsService.useMatugen)
    property bool matugen: true

    // Gamemode: Shell-Animationen und -Schatten aus (shell.qml bindet das an SettingsService.gameMode)
    property bool gameMode: false

    // Hyprland-Blur hinter den Shell-Flächen (shell.qml bindet das an SettingsService.shellBlur): Flächen werden
    // leicht durchscheinend, damit der Blur sichtbar wird. Gamemode schaltet den Blur im Compositor ab.
    property bool blur: false
    readonly property real blurSurfaceOpacity: 0.4
    function glass(c) {
        return blur && !gameMode ? alpha(c, Qt.color(c).a * blurSurfaceOpacity) : c;
    }

    // Schriftgröße: Faktor auf alle fontSize*-Werte (shell.qml bindet das an SettingsService.a11yLargeText)
    property real textScale: 1

    // Kompakte Darstellung: engere Abstände und niedrigere Leiste/Kacheln/Zeilen (shell.qml bindet das an SettingsService.compact)
    property bool compact: false

    // ───────────────────────── Matugen ─────────────────────────
    // Matugen schreibt die Palette (assets/matugen/niselle-colors.json als Vorlage) nach paletteFile; sie wird bei jeder
    // Änderung neu gelesen. Format: { "dark": { <Material-Rolle>: "#rrggbb", … }, "light": { … } }.
    // Die Basisfarben unten (Akzent, Flächen, Vordergrund) kommen aus der Palette; alles Abgeleitete (Hover, Rahmen,
    // Schalter …) rechnet weiter wie bisher daraus. Ohne Datei bleibt das GNOME-Aussehen.

    readonly property string paletteFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/niselle/colors.json"
    property var _palette: null
    readonly property bool matugenActive: matugen && _palette !== null
    readonly property var _modePalette: matugenActive ? (dark ? _palette.dark : _palette.light) : null

    // Rolle des aktuellen Modus, sonst der GNOME-Wert
    function pc(role, fallback) {
        const v = _modePalette ? _modePalette[role] : undefined;
        return v ? Qt.color(v) : fallback;
    }
    // Rolle eines festen Modus (für Teile, die immer dunkel bzw. hell sind)
    function pcMode(mode, role, fallback) {
        const v = matugenActive && _palette[mode] ? _palette[mode][role] : undefined;
        return v ? Qt.color(v) : fallback;
    }

    FileView {
        path: root.paletteFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root._palette = parsed && parsed.dark && parsed.light ? parsed : null;
            } catch (e) {
                root._palette = null;
            }
        }
        onLoadFailed: root._palette = null
    }

    // ───────────────────────── Farbhelfer ─────────────────────────
    // Entsprechen den Sass-/St-Funktionen der Shell (lighten/darken über HSL, mix mit Prämultiplikation).

    function alpha(c, a) {
        const k = Qt.color(c);
        return Qt.rgba(k.r, k.g, k.b, a);
    }

    // Sass transparentize($c, $amount)
    function transparentize(c, amount) {
        const k = Qt.color(c);
        return Qt.rgba(k.r, k.g, k.b, k.a * (1 - amount));
    }

    // Sass lighten / st-lighten: HSL-Helligkeit + amount [st-theme-node.c:696]
    function lighten(c, amount) {
        return Qt.hsla(c.hslHue, c.hslSaturation, Math.max(0, Math.min(1, c.hslLightness + amount)), c.a);
    }

    function darken(c, amount) {
        return lighten(c, -amount);
    }

    // Sass mix / st-mix: `weight` ist der Anteil von c1 [st-theme-node.c:639]
    function mix(c1, c2, weight) {
        const a = c1.a * weight + c2.a * (1 - weight);
        if (a === 0)
            return Qt.rgba(0, 0, 0, 0);
        return Qt.rgba(
            (c1.r * c1.a * weight + c2.r * c2.a * (1 - weight)) / a,
            (c1.g * c1.a * weight + c2.g * c2.a * (1 - weight)) / a,
            (c1.b * c1.a * weight + c2.b * c2.a * (1 - weight)) / a,
            a);
    }

    // ───────────────────────── Farbpalette (GNOME) ─────────────────────────
    // [_palette.scss:2-45], identisch zu libadwaita [adw:1-48]

    readonly property color blue1: "#99c1f1"
    readonly property color blue2: "#62a0ea"
    readonly property color blue3: "#3584e4"
    readonly property color blue4: "#1c71d8"
    readonly property color blue5: "#1a5fb4"
    readonly property color green1: "#8ff0a4"
    readonly property color green2: "#57e389"
    readonly property color green3: "#33d17a"
    readonly property color green4: "#2ec27e"
    readonly property color green5: "#26a269"
    readonly property color yellow1: "#f9f06b"
    readonly property color yellow2: "#f8e45c"
    readonly property color yellow3: "#f6d32d"
    readonly property color yellow4: "#f5c211"
    readonly property color yellow5: "#e5a50a"
    readonly property color orange1: "#ffbe6f"
    readonly property color orange2: "#ffa348"
    readonly property color orange3: "#ff7800"
    readonly property color orange4: "#e66100"
    readonly property color orange5: "#c64600"
    readonly property color red1: "#f66151"
    readonly property color red2: "#ed333b"
    readonly property color red3: "#e01b24"
    readonly property color red4: "#c01c28"
    readonly property color red5: "#a51d2d"
    readonly property color purple1: "#dc8add"
    readonly property color purple2: "#c061cb"
    readonly property color purple3: "#9141ac"
    readonly property color purple4: "#813d9c"
    readonly property color purple5: "#613583"
    readonly property color light1: "#ffffff"
    readonly property color light2: "#f6f5f4"
    readonly property color light3: "#deddda"
    readonly property color light4: "#c0bfbc"
    readonly property color light5: "#9a9996"
    readonly property color dark1: "#77767b"
    readonly property color dark2: "#5e5c64"
    readonly property color dark3: "#3d3846"
    readonly property color dark4: "#241f31"
    readonly property color dark5: "#000000"

    // ───────────────────────── Akzentfarben ─────────────────────────
    // Shell-Tabelle [st-theme-context.c:31-39]; libadwaita nutzt dieselben Werte [adw:100]

    readonly property var accents: ({
            "blue": "#3584e4",
            "teal": "#2190a4",
            "green": "#3a944a",
            "yellow": "#c88800",
            "orange": "#ed5b00",
            "red": "#e62d42",
            "pink": "#d56199",
            "purple": "#9141ac",
            "slate": "#6f8396"
        })

    // -st-accent-color / -st-accent-fg-color [st-theme-context.c:41]
    readonly property color accentColor: pc("primary", accents[accent] ?? accents["blue"])
    readonly property color accentFg: pc("on_primary", "#ffffff")
    // $accent_color: Akzent als Textfarbe [_default-colors.scss:8]
    readonly property color accentText: dark && !matugenActive ? mix(accentColor, light1, 0.6) : accentColor
    // $accent_borders_color [_colors.scss:70]
    readonly property color accentBorder: dark ? lighten(accentColor, matugenActive ? 0.1 : 0.3) : darken(accentColor, 0.2)
    // $link_color [_default-colors.scss:29]
    readonly property color linkColor: dark ? lighten(accentColor, 0.2) : darken(accentColor, 0.1)

    // Fokusring: inset 0 0 0 2px, $accent_color (Textvariante) mit Deckkraft 1 - 0.2 [_drawing.scss:57-66,
    // _default-colors.scss:41]
    readonly property color focusRing: transparentize(accentText, 0.2)
    readonly property real focusRingWidth: 2
    readonly property color focusRingDefault: transparentize(accentBorder, 0.2) // Stil "default" [_drawing.scss:316]

    // ───────────────────────── Statusfarben ─────────────────────────

    // [_default-colors.scss:11-13]
    readonly property color destructive: pc("error", dark ? red4 : red3)
    readonly property color destructiveFg: pc("on_error", light1)
    // [_default-colors.scss:16-18]
    readonly property color success: dark ? green5 : green4
    readonly property color successFg: light1
    // [_default-colors.scss:20-22], dunkles Gelb liegt außerhalb der Palette
    readonly property color warning: dark ? "#cd9309" : yellow5
    readonly property color warningFg: transparentize("#000000", 0.2)
    // [_default-colors.scss:24-26]
    readonly property color error: destructive
    readonly property color errorFg: light1

    // ───────────────────────── Shell-Farben (gnome-shell-sass) ─────────────────────────

    // Basis [_default-colors.scss:4-5]
    readonly property color baseDark: pcMode("dark", "surface", "#222226")
    readonly property color baseLight: pcMode("light", "surface", "#fafafb")

    // [_colors.scss:11-13]
    readonly property color baseColor: pc("surface_container_lowest", dark ? baseDark : light1)
    readonly property color bgColor: pc("surface_container", dark ? "#36363a" : baseLight)
    readonly property color fgColor: pc("on_surface", dark ? light1 : baseDark)

    // Panel (Top Bar): dunkel schwarz, hell #fafafb [_colors.scss:24-26]
    readonly property color panelBg: glass(pc("surface_container_lowest", dark ? dark5 : baseLight))
    readonly property color panelFg: fgColor
    // Nur hell: inset 0 -0.5px 0 0 panel_border_color [_panel.scss:20-23]
    readonly property color panelBorder: dark ? "transparent" : alpha(baseDark, 0.1)
    // Immer weiß auf Sperr-/Anmeldebildschirm [_panel.scss:7]
    readonly property color panelFgTransparent: light1
    // Immer hell in Overview/Sperrbildschirm [_panel.scss:8]
    readonly property color panelFgSystem: systemFg
    readonly property color privacyIndicator: dark ? orange3 : orange4 // [_panel.scss:4]
    readonly property color recordingIndicator: red4                   // [_panel.scss:5]

    // Karten [_colors.scss:29-31]
    readonly property color shellCardBg: pc("surface_container_high", dark ? lighten(bgColor, 0.07) : light1)
    readonly property color cardShadowColor: dark ? alpha(dark5, 0.28) : alpha(dark5, 0.07)
    readonly property color cardShadowBorder: dark ? alpha(light1, 0.05) : alpha(dark5, 0.09)

    // Rahmen [_colors.scss:39-40], Opazität [_default-colors.scss:40]
    readonly property real borderOpacity: dark ? 0.10 : 0.15
    readonly property color borders: alpha(fgColor, borderOpacity)
    readonly property color outerBorders: dark ? lighten(bgColor, 0.05) : darken(bgColor, 0.07)

    // OSD [_colors.scss:16-17, 43-44]
    readonly property color osdFg: light1
    readonly property color osdBg: glass(lighten(baseDark, 0.05))
    readonly property color osdBorders: alpha(osdFg, 0.1)
    readonly property color osdOuterBorders: alpha(osdFg, 0.02)

    // System (immer dunkel: Overview, Dash, Sperrbildschirm) [_colors.scss:20-21, 47-50]
    readonly property color systemBase: baseDark
    readonly property color systemFg: pcMode("dark", "on_surface", baseLight)
    readonly property color systemBg: lighten(systemBase, 0.05)
    readonly property color systemBorders: alpha(systemFg, 0.1)
    readonly property color systemInsensitiveFg: mix(systemBg, systemFg, 0.37)
    readonly property color systemOverlayBg: mix(systemBase, systemFg, 0.9) // z. B. Dash

    // Overview-Hintergrund: #overviewGroup { background-color: $system_base_color } [_overview.scss:8]
    readonly property color overviewBg: systemBase
    readonly property color overviewFg: systemFg

    // Gesperrt/deaktiviert [_colors.scss:53-55]
    readonly property color insensitiveFg: dark ? mix(fgColor, bgColor, 0.5) : mix(fgColor, bgColor, 0.6)
    readonly property color insensitiveBg: mix(bgColor, baseColor, 0.6)

    // Schatten [_default-colors.scss:36]
    readonly property color shadowColor: dark ? alpha(dark5, 0.5) : alpha(dark5, 0.2)

    // Popover-/Menüfarben [_popovers.scss:3-8]
    readonly property color menuBg: glass(bgColor)
    readonly property color menuItemBg: dark ? lighten(menuBg, 0.05) : darken(menuBg, 0.05)
    readonly property color subMenuBg: dark ? lighten(menuBg, 0.13) : darken(menuBg, 0.17)

    // Faktor, mit dem Button-Hintergründe aus fg und bg gemischt werden [_default-colors.scss:33]
    readonly property real backgroundMixFactor: dark ? 0.09 : 0.12

    // Slider-Trog [_slider.scss:10] und Switch-Hintergrund [_switches.scss:12-23]
    readonly property color sliderTrough: alpha(fgColor, 0.1)
    readonly property color sliderHandle: dark ? darken(fgColor, 0.09) : fgColor // .slider color [_slider.scss:6]
    readonly property color sliderHandleHover: dark ? fgColor : lighten(fgColor, 0.07) // [_slider.scss:25]
    readonly property color switchBg: alpha(dark ? light1 : dark5, 0.15)
    readonly property color switchBgHover: alpha(dark ? light1 : dark5, 0.2)
    readonly property color switchHandle: dark ? mix(light1, bgColor, 0.8) : light1 // [_switches.scss:35]
    readonly property color switchHandleChecked: light1 // [_switches.scss:49-51]
    readonly property color switchHandleShadow: alpha(dark5, 0.2) // [_switches.scss:36]

    // Quick-Settings: Menü-Button, Trenner [_quick-settings.scss:92-110]
    readonly property color quickToggleMenuButtonBg: dark ? lighten(bgColor, 0.08) : darken(bgColor, 0.05)
    readonly property color quickToggleMenuButtonCheckedBg: dark ? mix(accentColor, fgColor, 0.85) : mix(accentColor, fgColor, 0.92)
    readonly property color quickToggleSeparator: alpha(fgColor, 0.25)
    readonly property color quickToggleCheckedSeparator: dark ? mix(accentFg, accentColor, 0.3) : mix(accentFg, accentColor, 0.2)

    // Quick-Settings: Untermenü-Kopf (.quick-toggle-menu .header .icon) [_quick-settings:150-180]
    readonly property color quickMenuHeaderIconBg: transparentize(fgColor, 0.8)
    // Eingabefeld (entry(normal/hover/focus/insensitive)) [_drawing:85-150]
    readonly property color entryBg: mix(fgColor, bgColor, backgroundMixFactor)
    readonly property color entryBgHover: dark ? lighten(entryBg, 0.04) : darken(entryBg, 0.04)
    readonly property color entryFg: fgColor
    readonly property color entryFgIdle: transparentize(fgColor, 0.3)
    readonly property color entryHint: transparentize(fgColor, 0.3) // StLabel.hint-text [_common:190]
    readonly property color entrySelection: transparentize(accentColor, 0.7) // [_common:178]
    // Modaler Dialog: Schatten [_dialogs.scss:9], Fehlerzeile [_dialogs.scss:135-136]; Abdunklung (Lightbox): Wert nicht in den Quellen, Annahme
    readonly property color dialogShade: alpha("#000000", 0.4)   // Lightbox fadeFactor 0.4 (Annahme)
    readonly property color dialogWarningBg: transparentize(warning, 0.9)

    // ───────────────────────── libadwaita-Farben (Apps) ─────────────────────────
    // Hell [adw:62-93], Dunkel [adw:94]. Für Elemente, die wie GTK4-/libadwaita-Fenster aussehen.

    readonly property color windowBg: pc("surface", dark ? "#222226" : "#fafafb")
    readonly property color windowFg: pc("on_surface", dark ? "#ffffff" : Qt.rgba(0, 0, 6 / 255, 0.8))
    readonly property color viewBg: pc("surface_container_lowest", dark ? "#1d1d20" : "#ffffff")
    readonly property color viewFg: windowFg
    readonly property color headerbarBg: pc("surface_container", dark ? "#2e2e32" : "#ffffff")
    readonly property color headerbarFg: windowFg
    readonly property color headerbarShade: dark ? Qt.rgba(0, 0, 6 / 255, 0.36) : Qt.rgba(0, 0, 6 / 255, 0.12)
    readonly property color sidebarBg: pc("surface_container_low", dark ? "#2e2e32" : "#ebebed")
    readonly property color cardBg: glass(pc("surface_container_high", dark ? Qt.rgba(1, 1, 1, 0.08) : "#ffffff"))
    readonly property color cardFg: windowFg
    readonly property color cardShade: dark ? Qt.rgba(0, 0, 6 / 255, 0.36) : Qt.rgba(0, 0, 6 / 255, 0.07)
    readonly property color dialogBg: glass(pc("surface_container_high", dark ? "#36363a" : "#fafafb"))
    readonly property color popoverBg: glass(pc("surface_container_high", dark ? "#36363a" : "#ffffff"))
    readonly property color popoverFg: windowFg
    readonly property color popoverShade: dark ? Qt.rgba(0, 0, 6 / 255, 0.25) : Qt.rgba(0, 0, 6 / 255, 0.07)
    readonly property color thumbnailBg: pc("surface_container_highest", dark ? "#39393d" : "#ffffff")
    readonly property color shade: dark ? Qt.rgba(0, 0, 6 / 255, 0.25) : Qt.rgba(0, 0, 6 / 255, 0.07)
    // --overview-bg-color / --overview-fg-color (libadwaita-Overview, nicht Shell-Overview) [adw:110, adw:112]
    readonly property color adwOverviewBg: pc("surface_container_low", dark ? "#28282c" : "#f3f3f5")
    readonly property color adwOverviewFg: dark ? "#ffffff" : Qt.rgba(0, 0, 6 / 255, 0.8)
    // Deckkraft von Rahmen, Abdunkelung, Deaktiviert [adw:114]
    readonly property real adwBorderOpacity: 0.15
    readonly property real adwDimOpacity: 0.55
    readonly property real disabledOpacity: 0.5

    // ───────────────────────── Button-Zustände ─────────────────────────
    // Portierung des Mixins button() [_drawing.scss:160-344].
    //   state: normal hover active activeHover checked checkedHover checkedActive insensitive focus focusHover undecorated
    //   o.bg/o.fg: Hintergrund/Vordergrund-Basis (Standard bgColor/fgColor)
    //   o.style: "" flat card default notification dialog
    //   o.alwaysDark: Element ist immer dunkel (System, OSD)
    function buttonBg(state, o) {
        const opt = o ?? {};
        const c = opt.bg ?? bgColor;
        const tc = opt.fg ?? fgColor;
        const style = opt.style ?? "";
        const darkEl = opt.alwaysDark === true;
        const light = !dark;

        // Richtung der Zustandsänderung: hell dunkelt ab, dunkel (oder immer-dunkel) hellt auf
        const toward = (col, f) => (light && !darkEl) ? darken(col, f) : lighten(col, f);

        let base = mix(tc, c, backgroundMixFactor);                  // [_drawing.scss:171]
        if (style === "card")
            base = shellCardBg;                                      // [:174]
        if (style === "flat" || style === "default")
            base = c;                                                // [:176-178]

        const hoverF = style === "flat" ? 0.07 : 0.04;               // [:182,189]
        const activeF = 0.09;                                        // [:183]
        const checkedF = 0.08;                                       // [:184]
        const insF = 0.03;                                           // [:185]

        let normal = base;
        let hover = toward(base, hoverF);
        let active = toward(base, activeF);
        let checked = toward(base, checkedF);
        let insensitive = (light && !darkEl) ? lighten(base, insF) : darken(base, insF);
        let activeHover = toward(active, hoverF);
        let checkedHover = toward(checked, hoverF);
        let checkedActive = toward(checked, activeF);

        if (style === "dialog") {                                    // [:217-223]
            normal = transparentize(tc, 0.9);
            hover = transparentize(tc, 0.87);
            active = transparentize(tc, 0.84);
            activeHover = transparentize(tc, 0.81);
            insensitive = transparentize(tc, 0.9);
        } else if (style === "notification") {                       // [:226-232]
            normal = transparentize(tc, 0.85);
            hover = transparentize(tc, 0.7);
            insensitive = transparentize(tc, 0.9);
            active = transparentize(tc, 0.8);
            activeHover = transparentize(tc, 0.8);
        }
        if (style === "flat")
            insensitive = normal;                                    // [:235-237]

        switch (state) {
        case "hover":
            return hover;
        case "active":
            return active;
        case "activeHover":
            return activeHover;
        case "checked":
            return checked;
        case "checkedHover":
            return checkedHover;
        case "checkedActive":
            return checkedActive;
        case "insensitive":
            return insensitive;
        case "focus":
        case "focusHover":
            {
                // Flat: Basis auf 25 % Deckkraft [:323-325]; Hintergrund = mix(accent, bg, 5 %) [_drawing.scss:22-25]
                const b = state === "focus" ? (style === "flat" ? transparentize(normal, 0.75) : normal) : hover;
                return mix(accentText, b, 0.05);
            }
        case "undecorated":
            return "transparent";                                    // [:335-338]
        default:
            return normal;
        }
    }

    // Zustandsname für buttonBg(). Reihenfolge entspricht der CSS-Kaskade in %button [_common:101-110]:
    // insensitive > checked(+active/hover) > active(+hover) > focus(+hover) > hover > normal
    function buttonState(hovered, pressed, checked, enabled, focused) {
        if (enabled === false)
            return "insensitive";
        if (checked)
            return pressed ? "checkedActive" : (hovered ? "checkedHover" : "checked");
        if (pressed)
            return hovered ? "activeHover" : "active";
        if (focused)
            return hovered ? "focusHover" : "focus";
        return hovered ? "hover" : "normal";
    }

    // Vordergrund deaktivierter Buttons [_drawing.scss:299]
    function buttonFgInsensitive(fg) {
        return transparentize(fg ?? fgColor, dark ? 0.5 : 0.6);
    }

    // Panel-Button-Füllung [_drawing.scss:419-421, panel_button()]
    //   state: normal hover active activeHover; fg: Vordergrund; filled: Farbe für filled-Stil (Aufnahme-/Teilen-Anzeige)
    function panelButtonFill(state, fg, filled) {
        const f = fg ?? panelFg;
        if (filled !== undefined) {                                  // [:423-428]
            const step = (col, v) => dark ? lighten(col, v) : darken(col, v);
            switch (state) {
            case "hover":
                return step(filled, 0.05);
            case "active":
                return step(filled, 0.09);
            case "activeHover":
                return step(filled, 0.11);
            default:
                return filled;
            }
        }
        switch (state) {
        case "hover":
            return transparentize(f, 0.83);
        case "active":
            return transparentize(f, 0.72);
        case "activeHover":
            return transparentize(f, 0.68);
        default:
            return "transparent";
        }
    }

    // ───────────────────────── Maße / Abstände ─────────────────────────

    readonly property real basePadding: compact ? 5 : 6 // [_common:31]
    readonly property real baseMargin: 4             // [_common:32]
    readonly property real baseRadius: 8             // [_common:33]
    readonly property real spacingXs: 2              // Panel-Indikatoren [_panel:146]
    readonly property real spacingSm: baseMargin     // 4
    readonly property real spacingMd: basePadding    // 6
    readonly property real spacingLg: basePadding * 2 // 12, Quick-Settings-Gitter [_quick-settings:11-12]
    readonly property real spacingXl: basePadding * 3 // 18, Quick-Settings-Innenabstand [_quick-settings:2]

    // ───────────────────────── Radien ─────────────────────────

    readonly property real radiusPill: 999                     // $forced_circular_radius [_common:37]
    readonly property real radiusModal: baseRadius * 2         // 16, $modal_radius [_common:40]
    readonly property real radiusAlert: 18                     // [_common:43]
    readonly property real radiusPopover: radiusModal * 1.25   // 20, .popup-menu-content [_popovers:30]
    readonly property real radiusMenuItem: baseRadius * 1.5    // 12 [_popovers:6]
    readonly property real radiusSubMenu: radiusMenuItem + 1   // 13 [_popovers:76]
    readonly property real radiusButton: baseRadius            // 8 [_common:94]
    readonly property real radiusEntry: baseRadius             // 8 [_common:176]
    readonly property real radiusTile: baseRadius * 2          // 16, %tile [_common:85]
    readonly property real radiusCard: baseRadius * 1.5        // 12 [_common:140]
    readonly property real radiusDialogButton: baseRadius * 1.5 // 12 [_common:214]
    readonly property real radiusQuickSettings: radiusModal * 2.25 // 36 [_quick-settings:3]
    readonly property real radiusQuickToggleMenu: baseRadius * 3   // 24 [_quick-settings:158]
    readonly property real radiusWindow: 15                    // --window-radius [adw:118]
    readonly property real radiusAdwPopover: 15                // popover > contents [adw:2111]

    // ───────────────────────── Komponentenmaße ─────────────────────────

    // Panel [_panel:10]: 2.2em × 14.667px = 32.27px, Shell rendert 32px
    readonly property real panelHeight: compact ? 28 : 32
    readonly property real panelButtonBorder: 3              // transparenter Rand, Füllung liegt innen [_drawing:410]
    readonly property real panelButtonHPadding: basePadding * 2 // natural-hpadding 12 [_panel:28]
    readonly property real panelButtonMinHPadding: basePadding  // minimum-hpadding 6 [_panel:29]
    readonly property real panelIndicatorSpacing: 2          // [_panel:146]
    readonly property real panelClockHPadding: basePadding * 2 // .clock padding [_panel:162-163]
    readonly property real workspaceDotSize: 8               // scalable_icon_size × 0.5 [_panel:55-56]
    readonly property real workspaceDotSpacing: 5            // [_panel:50]
    // Arbeitsflächen-Punkte [panel.js:44-136, 175-199]: inaktive Punkte 0.75 groß und halbtransparent,
    // der aktive wird auf das Vielfache der Punktbreite gedehnt (≤2 Flächen 3.625, ≤5 3.25, sonst 2.75)
    readonly property real workspaceDotInactiveScale: 0.75
    readonly property real workspaceDotInactiveOpacity: 0.5
    readonly property int durationWorkspaceDot: 500          // Ein-/Ausblenden eines Punkts [panel.js:113,124]
    function workspaceDotWidthMultiplier(count) {
        return count <= 2 ? 3.625 : (count <= 5 ? 3.25 : 2.75);
    }
    // Symbolleiste im Panel: Symbolabstand in der Quick-Settings-Pille [_panel:33-37, base_margin]
    readonly property real panelStatusIconSpacing: baseMargin
    readonly property real panelStatusIconMargin: baseMargin  // .system-status-icon margin [_panel:31]
    // Maximale Breite der App-Anzeige (24em wie #appMenu in GNOME 3.x; in aktuellem GNOME entfernt, daher abgeleitet)
    readonly property real panelAppNameMaxWidth: 24 * 14.667
    // Abgerundete Bildschirmecken (oben); GNOME-Shell zeichnet keine, Radius = Fensterradius
    readonly property real screenCornerRadius: radiusWindow

    // Popover / Menü
    readonly property real popoverPadding: basePadding           // 6 [_popovers:28]
    readonly property real popoverMinWidth: 220                  // 15em ≈ 220px [_popovers:17]
    readonly property real popoverRise: basePadding              // -arrow-rise 6 [_popovers:12]
    readonly property real popoverBorderWidth: 1                 // [_popovers:31]
    readonly property real menuItemPaddingV: basePadding * 1.5   // 9 [_common:135]
    readonly property real menuItemPaddingH: basePadding * 2     // 12 [_common:135]
    readonly property real menuItemSpacing: basePadding          // [_common:133]
    readonly property real menuOrnamentPaddingLeft: basePadding  // [_popovers:58]
    readonly property real menuOrnamentSize: 16                  // [_popovers:110]
    readonly property real menuSeparatorHeight: 1                // [_popovers:118]
    readonly property real menuSwitchMargin: baseMargin          // [_popovers:52]

    // Buttons
    readonly property real buttonPaddingV: basePadding * 0.5     // 3 [_common:95]
    readonly property real buttonPaddingH: basePadding * 4       // 24 [_common:95]
    readonly property real buttonMinHeight: 22                   // to_em(22px) = 1.5em = 22px [_buttons:6]
    readonly property real iconButtonPadding: basePadding * 2    // 12 [_buttons:22]
    readonly property real iconButtonQuickPadding: basePadding * 1.75 // 10.5 [_quick-settings:6]

    // Tiles (Dash-/App-Icons) [_common:84-90]
    readonly property real tilePadding: basePadding
    readonly property real tileSpacing: basePadding

    // Slider [_slider:3-17]
    readonly property real sliderTroughHeight: 4
    readonly property real sliderHandleSize: 16                  // $slider_size = scalable_icon_size
    readonly property real sliderBinPadding: basePadding         // [_quick-settings:145]

    // Switch [_switches:3-4, 7, 31-33]
    readonly property real switchWidth: 46
    readonly property real switchHandleSize: 20
    readonly property real switchHandleMargin: 3
    readonly property real switchHeight: switchHandleSize + 2 * switchHandleMargin // 26

    // Quick-Settings [_quick-settings:1-20]
    readonly property real quickSettingsPadding: basePadding * 3
    readonly property real quickToggleWidth: compact ? 156 : 176                 // 12em
    readonly property real quickToggleHeight: compact ? 40 : 48                 // scalable_icon_size × 3
    readonly property real quickToggleSpacing: basePadding * 1.5 // 9 [_quick-settings:26]
    readonly property real quickToggleHPadding: basePadding * 2  // 12 [_quick-settings:32]
    readonly property real quickToggleIconLeading: basePadding * 2.5 // 15 [_quick-settings:35]
    readonly property real quickToggleMenuButtonPaddingV: basePadding // [_quick-settings:71]
    readonly property real quickToggleMenuButtonPaddingH: basePadding * 1.75 // [_quick-settings:71]
    readonly property real quickToggleSeparatorWidth: 1          // [_quick-settings:82]
    // Hintergrundprogramme-Zeile ist flach und etwas niedriger als ein Toggle: to_em(40px) = 40px
    readonly property real backgroundAppsToggleHeight: 40        // .background-apps-quick-toggle [_quick-settings:245]
    // Schließen-Knopf im Eintrag: Padding $base_padding, App-Symbol $large_icon_size [.background-app-item, _quick-settings:252-259]
    readonly property real backgroundAppClosePadding: basePadding
    readonly property real backgroundAppIconSize: iconSizeLarge

    readonly property real quickSettingsWidth: 2 * quickToggleWidth + spacingLg // 2 Spalten + spacing-columns [_quick-settings:11-12]
    // Höhe der Medien-/Benachrichtigungsliste unter den Kacheln: nie kleiner als min, nie größer als max (sonst bis zum Bildschirmrand)
    readonly property real quickSettingsMinListHeight: 140
    readonly property real quickSettingsMaxListHeight: 560
    readonly property real quickSliderSpacing: basePadding       // .quick-slider > StBoxLayout [_quick-settings:139-140]
    readonly property real quickSliderButtonPadding: basePadding // .quick-slider .icon-button [_quick-settings:141]
    readonly property real quickMenuMargin: basePadding * 2      // .quick-toggle-menu margin-top [_quick-settings:150-158]
    readonly property real quickMenuHeaderIconPadding: basePadding * 1.5 // [_quick-settings:175]
    readonly property real quickMenuHeaderSpacingV: basePadding * 0.5    // [_quick-settings:164-165]
    readonly property real quickMenuHeaderSpacingH: basePadding * 2      // [_quick-settings:166-167]
    readonly property real quickMenuHeaderPaddingBottom: basePadding * 2 // [_quick-settings:170]
    readonly property real quickSystemSpacing: basePadding * 2   // .quick-settings-system-item > StBoxLayout [_quick-settings:205-206]
    readonly property real wirelessSecureIconSize: iconSize * 0.5 // .wireless-secure-icon [_quick-settings:220]
    readonly property real menuPlaceholderPaddingV: 2 * 14.667    // .bt-menu-placeholder 2em 4em [_quick-settings:227-231]
    readonly property real menuPlaceholderPaddingH: 4 * 14.667

    // Modaler Dialog [_dialogs.scss:3-21, 96-130]
    readonly property real dialogPadding: basePadding * 4
    readonly property real dialogSpacing: basePadding * 3
    readonly property real dialogContentPaddingTop: basePadding * 2
    readonly property real dialogContentMaxWidth: 28 * 14.667    // 28em
    readonly property real dialogPromptWidth: 28 * 14.667
    readonly property real dialogEntryWidth: 20 * 14.667
    readonly property real dialogButtonBoxPaddingTop: basePadding
    readonly property real dialogButtonPadding: basePadding * 2  // %dialog_button [_common:211-214]
    readonly property real dialogEntryPaddingV: basePadding * 2  // .prompt-dialog-password-entry [_dialogs.scss:119-122]
    readonly property real entryPaddingH: basePadding * 1.5      // %entry_common [_common:175-177]
    readonly property real entryPaddingV: basePadding * 1.5
    readonly property real dialogLabelPadding: basePadding * 1.5 // .prompt-dialog-error-label [_dialogs.scss:125-131]
    readonly property int durationDialog: 200                    // Einblenden des Dialogs (Annahme, modalDialog.js nicht in den Quellen)

    // Sperrbildschirm / Entsperr-Dialog (Screen Shield) [_login-lock.scss:9-43, 292-313; unlockDialog.js]
    readonly property real lockDialogWidth: 26 * 14.667          // .login-dialog-prompt-layout 25em × 1.2 (hier etwas schmaler)
    readonly property real lockClockSpacing: basePadding * 3     // .unlock-dialog-clock spacing 2em
    readonly property real lockClockHintMargin: basePadding * 3  // .unlock-dialog-clock-hint margin-top 2em
    readonly property real lockNameFontSize: 20 * textScale      // .user-widget.vertical .user-widget-label fontsize(20pt)
    readonly property real lockEntryRadius: baseRadius * 1.5     // .login-dialog-prompt-entry border-radius
    readonly property real lockButtonRadius: radiusPill          // %lockscreen_button border-radius base×4
    readonly property real lockButtonFontSize: fontSizeBase + 2  // @include fontsize($base_font_size + 2) [_login-lock.scss:263]
    readonly property real lockButtonHeight: 40                  // %lockscreen_button + Rand
    readonly property real lockMessageMinHeight: 2.75 * 14.667   // .login-dialog-message min-height 2.75em

    // Karten [_common:139-152]
    readonly property real cardPadding: basePadding * 2
    readonly property real cardMargin: baseMargin
    readonly property real cardBorderWidth: 1

    // ───────────────────────── Schatten ─────────────────────────
    // CSS box-shadow: x y blur spread color. Spread ist in der Shell überall 0.

    // .popup-menu-content: 0 2px 4px 0 shadow_color [_popovers:32]
    // Premium: weit gestreuter, tiefer Schatten statt GNOMEs enger Kante (Popover schweben sichtbar über dem Inhalt)
    readonly property real shadowPopoverY: 10
    readonly property real shadowPopoverBlur: 28
    // Karten: 0 1px 2px 0 card_shadow_color [_common:144]
    readonly property real shadowCardY: 2
    readonly property real shadowCardBlur: 8
    // Haarlinie am oberen Rand erhabener Flächen (Glanzkante): Farbe der Mitte, an den Enden läuft sie aus
    readonly property color highlightEdge: dark ? alpha(light1, 0.14) : alpha(light1, 0.9)
    // Switch-Handle: 0 2px 4px rgba(0,0,0,.2) [_switches:61]
    readonly property real shadowHandleY: 2
    readonly property real shadowHandleBlur: 4

    // ───────────────────────── Schrift ─────────────────────────
    // Adwaita Sans (GNOME 48+), Fallback Cantarell. Größe 11.

    // Eigene Schriften aus den Einstellungen (shell.qml bindet sie an SettingsService.fontFamily/fontFamilyMono); leer = Standard
    property string fontOverride: ""
    property string fontMonoOverride: ""

    readonly property string fontFamily: fontOverride !== "" ? fontOverride : (Qt.fontFamilies().indexOf("Adwaita Sans") >= 0 ? "Adwaita Sans" : "Cantarell")
    readonly property string fontFamilyMono: fontMonoOverride !== "" ? fontMonoOverride : (Qt.fontFamilies().indexOf("Adwaita Mono") >= 0 ? "Adwaita Mono" : "monospace")

    // Größen in pt (Qt font.pointSize, bei 96 dpi = GNOME-Pixel). [_common:241-284]
    readonly property real fontSizeBase: 11 * textScale        // stage [_common:30,69]
    readonly property real fontSizeLargeTitle: 24 * textScale  // [_common:243]
    readonly property real fontSizeTitle1: 20 * textScale      // [_common:248]
    readonly property real fontSizeTitle2: 15 * textScale      // [_common:253]
    readonly property real fontSizeTitle3: 15 * textScale      // [_common:258]
    readonly property real fontSizeTitle4: 13 * textScale      // [_common:263]
    readonly property real fontSizeHeading: 11 * textScale     // [_common:268]
    readonly property real fontSizeCaptionHeading: 9 * textScale // [_common:273]
    readonly property real fontSizeCaption: 9 * textScale      // [_common:278]
    readonly property real fontSizeSmaller: 9 * textScale      // [_common:283]

    // Gewichte (CSS font-weight → Qt Font.Weight)
    readonly property int fontWeightLight: Font.Light       // 300, large-title [_common:242]
    readonly property int fontWeightNormal: Font.Normal     // 400 [_common:276]
    readonly property int fontWeightBold: Font.Bold         // 700, heading/title-3/4, Panel, Buttons [_common:96,257,262,267]
    readonly property int fontWeightExtraBold: Font.ExtraBold // 800, title-1/2 [_common:247,252]

    // ───────────────────────── Icongrößen ─────────────────────────

    readonly property real iconSize: 16            // $base_icon_size [_common:51]
    readonly property real iconSizeMedium: 24      // [_common:52]
    readonly property real iconSizeLarge: 32       // [_common:53]
    readonly property real iconSizeSwitch: 16      // StIcon im Switch [_switches:26-28]

    // ───────────────────────── Animationen ─────────────────────────
    // Dauern in ms, Kurven als QtQuick Easing.Type. Clutter-Modi sind exakt Qt-Easing-Typen
    // (EASE_OUT_QUAD = Easing.OutQuad usw.), nur CSS-Transitions nutzen cubic-bezier.

    // Overview [overview.js:12], Seitenleisten [overviewControls.js:30], Panel-Übergang [_panel:11]
    readonly property int durationOverview: 260
    readonly property int durationSideControls: 300
    readonly property int durationPanel: 300
    // Popover/Boxpointer [boxpointer.js:14]
    readonly property int durationPopover: 240
    // Dash [dash.js:16-18]
    readonly property int durationDash: 260
    readonly property int durationDashLabelShow: 200
    readonly property int durationDashLabelHide: 140
    // Benachrichtigungen [messageTray.js:17]
    readonly property int durationNotification: 280
    readonly property int notificationTimeout: 4000      // Banner-Anzeigedauer [messageTray.js:19]
    readonly property int notificationHideTimeout: 200   // Pause bis zum nächsten Banner [messageTray.js:21]
    readonly property int notificationLeaveTimeout: 600  // Ausblenden nach Verlassen mit dem Zeiger [messageTray.js:22]
    readonly property int notificationMaxQueue: 3        // MAX_NOTIFICATIONS_IN_QUEUE [messageTray.js:24]
    // Fenster [windowManager.js:28-38]
    readonly property int durationWindowMinimize: 400
    readonly property int durationWindowShow: 200
    readonly property int durationWindowShowDialog: 160
    readonly property int durationWindowDestroy: 200
    readonly property int durationWindowDestroyDialog: 140
    readonly property int durationWindow: 320
    readonly property int durationDim: 500
    readonly property int durationUndim: 320
    // Arbeitsflächen [workspacesView.js:18]
    readonly property int durationWorkspaceSwitch: 340
    // App-Grid [appDisplay.js:33-46]
    readonly property int durationAppViewsSwitch: 380
    readonly property int durationAppIconTitleExpand: 240
    readonly property int durationAppIconTitleCollapse: 160
    readonly property int durationAppFolderDialog: 260
    readonly property int durationAppPagePreview: 200
    // CSS-Transitions: Tile/Menüeintrag 100 ms [_common:89,134], Panel-Button 150 ms [_drawing:409],
    // Button-Rand/Schatten 300 ms [_common:97], Switch 100 ms [_switches:9]
    readonly property int durationTile: 140
    readonly property int durationMenuItem: 140
    readonly property int durationPanelButton: 190
    readonly property int durationButton: 260
    readonly property int durationSwitch: 160

    // Gestaffeltes Einblenden: Fortschritt p (0..1) eines Containers, Element i von n beginnt versetzt und läuft
    // über die halbe Gesamtzeit; Ergebnis 0..1 mit weichem Auslauf (für opacity und Translate)
    function enter(p, i, n) {
        if (gameMode)
            return 1;
        const w = 0.55;
        const t = Math.max(0, Math.min(1, (p - (1 - w) * i / Math.max(1, n - 1)) / w));
        return 1 - Math.pow(1 - t, 3);
    }
    readonly property real enterRise: 14
    readonly property int durationControlCenter: 460

    // Druckrückmeldung: Schaltflächen und Kacheln federn beim Drücken leicht ein
    readonly property real pressScale: 0.97
    readonly property int durationPress: 120

    // Easing-Typen der Shell-JS-Animationen
    readonly property int easeOutBack: Easing.OutBack     // Banner ein-/ausblenden [messageTray.js:1203,1264]
    readonly property int easeOutQuad: Easing.OutQuint     // Popover [boxpointer.js:121], Overview [overviewControls.js:559], Dash [dash.js:125]
    readonly property int easeInQuad: Easing.InCubic       // [dash.js:468]
    readonly property int easeOutCubic: Easing.OutQuart   // Panel [panel.js:115], Workspaces [workspacesView.js:417], App-Grid [appDisplay.js:447]
    readonly property int easeOutSine: Easing.OutSine     // [overviewControls.js:653]
    readonly property int easeOutQuint: Easing.OutQuint   // [appDisplay.js:1956]
    readonly property int easeOutExpo: Easing.OutExpo     // Minimieren [windowManager.js:29], Ordner [appDisplay.js:2686]

    // St-CSS-Transitions (durationTile, durationPanelButton, …) laufen mit EASE_IN_OUT_QUAD [st-theme-node-transition.c:110]
    readonly property int easeTransition: Easing.InOutCubic

    // CSS $ease_out_quad = cubic-bezier(0.25, 0.46, 0.45, 0.94) [_common:65]; QML: Easing.BezierSpline-Kontrollpunkte
    readonly property var cssEaseOutQuad: [0.25, 0.46, 0.45, 0.94, 1, 1]

    // Quick-Settings: Untermenüs und Abdunkeln [quickSettings.js:16-17, 371-428, 586-606]
    readonly property int durationQuickSettings: 400   // POPUP_ANIMATION_TIME
    readonly property int durationQuickMenu: durationQuickSettings / 2 // Höhe, dann Einblenden: je 200 ms
    readonly property real quickSettingsDim: 0.4       // DIM_BRIGHTNESS -0.4 beim offenen Untermenü
    readonly property int durationSpinner: 1000        // Umlaufdauer des Ladekreises (Annahme, animation.js nicht in den Quellen)

    // ───────────────────────── Bewegung (Karu-Motor) ─────────────────────────
    // Übernommen aus karu/core/theme/Theme.qml: eine gemeinsame Bewegungssprache für die ganze Shell.
    // Dauern staffeln sich nach der Größe der Änderung; statt roher Easing-Werte benannte Kurven.
    // Die Übersicht öffnet und schließt auf einer echten Physik-Feder (panelSpring/panelDamping) statt
    // auf einer festen Dauer – das ist der weiche, „teure“ Lauf von Karu.
    readonly property int motionSnap: 140        // kleine Zustandswechsel (Hover, Auswahl)
    readonly property int motionFast: 210        // Ein-/Ausblenden, Seitenwechsel
    readonly property int motionMedium: 300      // Standardgleiten (Arbeitsflächen, App-Grid-Seiten)
    readonly property int motionSlow: 340        // große Flächen (Übersicht, Panel)
    readonly property int easeOut: Easing.OutCubic           // ausgleiten ohne Überschwingen
    readonly property int easeEmphasized: Easing.OutQuint    // lange Gleitkurven, sehr weicher Auslauf
    readonly property int easeSpring: Easing.OutBack         // wachsen/schrumpfen mit Überschwingen
    readonly property real springOvershoot: 1.03          // Überschwingen der OutBack-Kurven
    // Feder der Übersicht: Steifigkeit (panelSpring), Abklingen (panelDamping), Masse und Ruheschwelle
    readonly property real panelSpring: 6.5
    readonly property real panelDamping: 0.42
    readonly property real panelMass: 1.0
    // Für die große Übersichtsfläche die straffere Karu-Voreinstellung („Snappy“): schnellere, kaum
    // nachschwingende Feder. Auf Vollbild wirkt das ruhiger als das weiche Standard-Bouncen.
    readonly property real overviewSpring: 9.0
    readonly property real overviewDamping: 0.6
    // Ruheschwelle der normierten Fortschritts-Feder (0 → 1 statt Pixelmaß, daher feiner als panelEpsilon)
    readonly property real overviewSpringEpsilon: 0.002

    // ───────────────────────── Übersicht ─────────────────────────
    // [overview.js], [overviewControls.js], [workspacesView.js], [_overview.scss]
    // Abstand zwischen den Bereichen: Anteil der Höhe ohne Panel [overviewControls.js:21]
    readonly property real overviewSpacingRatio: 0.02
    // Abstand der Arbeitsflächen-Leiste unter der Suche (oben) bzw. zum Fensterbereich (unten) [overviewControls.js:22-23]
    readonly property real overviewThumbnailsSpacingTop: 0.6
    readonly property real overviewThumbnailsSpacingBottom: 0.4
    // Höchste Dash-Höhe als Anteil der Höhe [overviewControls.js:20]
    readonly property real overviewDashMaxHeightRatio: 0.16
    // Fensterbereich auf Nebenmonitoren [workspacesView.js:27, 695-697]
    readonly property real overviewSecondaryScale: 0.8
    // Ein Klick auf Aktivitäten oder die heiße Ecke binnen dieser Zeit nach dem Öffnen wird ignoriert [overview.js:24, 436-447]
    readonly property int overviewActivationTimeout: 500
    // Abdunklung des Hintergrunds hinter der Übersicht. GNOME zeichnet den Übersichts-Hintergrund deckend
    // (#overviewGroup background-color: $system_base_color über dem unscharfen Hintergrundbild), hier deckend
    // in der Systemfarbe, damit Fenster nicht durchscheinen [overview.js:12, _overview.scss:8]
    readonly property real overviewScrimOpacity: 1.0
    // Heiße Ecke: Kantenlänge der Auslösefläche in der oberen linken Ecke (Annahme, layout.js nicht in den Quellen)
    readonly property real hotCornerSize: 1
    // Nach dem Ausblenden der Übersicht betritt der ruhende Zeiger die Ecke neu; dieses Ereignis löst nicht aus (ms)
    readonly property int hotCornerRetriggerDelay: 250
    // Mehrfachauslösung desselben Kürzels (Taste loslassen löst Hyprland-Bind und Fensterereignis aus)
    readonly property int overviewShortcutDebounce: 150

    // Fensterbereich [workspace.js, windowPreview.js, _window-picker.scss]
    // Layout: Größtanteil, Gewichtung von Skalierung und Flächennutzung beim Wählen der Zeilenzahl [workspace.js:15-24]
    readonly property real windowPreviewMaxScale: 0.95          // WINDOW_PREVIEW_MAXIMUM_SCALE [workspace.js:15]
    // Arbeitsflächen-Hintergrund hinter den Fenstern: Eckenradius der Vorschaufläche, mit dem Fortschritt
    // von 0 auf 30 px [workspace.js:30, 1002-1009]
    readonly property real workspaceCornerRadius: 30            // BACKGROUND_CORNER_RADIUS_PIXELS [workspace.js:30]
    // Seitlicher Einzug des Hintergrunds von den Bildschirmrändern, damit er sie nicht berührt
    // [workspacesView.js:22 WORKSPACE_MIN_SPACING]
    readonly property real workspaceSideInset: 24
    readonly property real layoutScaleWeight: 1                 // [workspace.js:23]
    readonly property real layoutSpaceWeight: 0.1               // [workspace.js:24]
    readonly property real windowPickerSpacing: basePadding     // .window-picker spacing [_window-picker.scss:6]
    // Rand zwischen dem Arbeitsflächen-Hintergrund und den Fenstern (Anteil der Hintergrundhöhe)
    readonly property real windowPickerPaddingRatio: 0.05
    // Vorschau: App-Icon, Titel, Hervorhebung [windowPreview.js:15-27]
    readonly property real windowIconSize: 64                   // ICON_SIZE
    readonly property real windowIconOverlap: 0.7               // ICON_OVERLAP: Anteil des Icons über der Fensterkante
    readonly property real windowIconTitleSpacing: 6            // ICON_TITLE_SPACING
    readonly property real windowActiveSizeInc: 5               // WINDOW_ACTIVE_SIZE_INC je Richtung
    readonly property int durationWindowOverlay: 240            // WINDOW_OVERLAY_FADE_TIME, WINDOW_SCALE_TIME
    readonly property int windowOverlayHideTimeout: 750         // WINDOW_OVERLAY_IDLE_HIDE_TIMEOUT
    readonly property real windowDndSize: 256                   // WINDOW_DND_SIZE
    readonly property real windowDraggingOpacity: 100 / 255     // DRAGGING_WINDOW_OPACITY
    // .icon-dropshadow: 0 2px 4px rgba(black, 0.4) [_base.scss:16-17]
    readonly property color windowIconShadow: alpha("#000000", 0.4)
    readonly property real windowIconShadowY: 2
    readonly property real windowIconShadowBlur: 4
    // .window-caption (%tooltip) [_common:225-232]
    readonly property color tooltipBg: transparentize("#000000", 0.1)
    readonly property color tooltipBorder: transparentize(light1, 0.9)
    readonly property color tooltipFg: light1
    readonly property real tooltipPaddingV: basePadding
    readonly property real tooltipPaddingH: basePadding * 2
    readonly property real tooltipBorderWidth: 1
    // .window-close [_window-picker.scss:2, 24-47]
    readonly property color windowCloseBg: transparentize(lighten(systemBg, 0.07), 0.02)
    readonly property color windowCloseBgHover: lighten(windowCloseBg, 0.07)
    readonly property color windowCloseBgActive: lighten(windowCloseBg, 0.13)
    readonly property real windowCloseSize: iconSizeLarge       // 32
    readonly property real windowCloseIconSize: iconSizeMedium  // 24
    readonly property real windowCloseBorder: 2
    readonly property int durationWindowClose: 100

    // Arbeitsflächen-Leiste [workspaceThumbnail.js, _workspace-thumbnails.scss]
    readonly property real thumbnailsMaxScale: 0.075            // MAX_THUMBNAIL_SCALE: Anteil der Arbeitsfläche [workspaceThumbnail.js:19]
    readonly property int thumbnailsMinWorkspaces: 2            // NUM_WORKSPACES_THRESHOLD: Leiste erst bei mehr Flächen [:16]
    readonly property real thumbnailsSpacing: basePadding       // .workspace-thumbnails spacing/padding [_workspace-thumbnails:5-6]
    readonly property real thumbnailsPadding: basePadding
    readonly property color thumbnailBackground: lighten(systemBg, 0.10) // .workspace-thumbnail [:10]
    readonly property real thumbnailBorder: 1
    readonly property real radiusThumbnail: baseRadius * 0.5    // 4
    readonly property real thumbnailIndicatorBorder: 3          // .workspace-thumbnail-indicator [:29]
    readonly property real radiusThumbnailIndicator: baseRadius
    readonly property int durationThumbnailsExpand: 200         // RESCALE_ANIMATION_TIME / SLIDE_ANIMATION_TIME [:21-22]
    // Mausrad: Rasterschritt für einen Wechsel (Qt-Standard 120 je Rastung)
    readonly property real overviewWheelStep: 120
    // Ziel beim Ziehen: Fläche hellt auf (Annahme, die Hervorhebung steht nicht in den Quellen)
    readonly property color thumbnailDropOverlay: alpha(light1, 0.15)
    // Platz der Vorschauen bei Änderungen: animateAllocation 200 ms EASE_OUT_QUAD [workspace.js:380-391]
    readonly property int durationWindowReposition: 200

    // Popover-Öffnung: Skalierung 0.96 → 1, Verschiebung um `popoverRise` [boxpointer.js:91-97, 117-121]
    readonly property real popoverScaleFrom: 0.94

    // ───────────────────────── Dash ─────────────────────────
    // [_dash.scss], [dash.js], [_app-grid.scss:44-51] (Quellen unter docs/sources/)

    readonly property color dashBackground: glass(systemOverlayBg)    // $dash_background_color [_dash:4]
    readonly property real dashPadding: basePadding * 2          // 12 [_dash:7]
    readonly property real dashEdgeOffset: baseMargin * 3        // 12, Abstand zum Bildschirmrand [_dash:8]
    readonly property real dashItemSpacing: baseMargin * 0.5     // 2, margin 0 2 je Eintrag [_dash:10, 54]
    readonly property real radiusDash: radiusModal + dashPadding // 28 [_dash:9, 21]
    readonly property real dashOuterPadding: basePadding         // #dash padding-left/right [_dash:15-16]
    readonly property real dashPlaceholderSize: 32               // Ziel bei leerem Dash [_dash:6, 43-44]
    readonly property real dashSeparatorWidth: 1                 // [_dash:84]
    readonly property real dashSeparatorMargin: baseMargin * 2   // [_dash:85-86]
    readonly property color dashSeparator: alpha(systemFg, 0.35) // [_dash:87]
    // Icongrößen, aus denen das Dash die größte passende wählt, und Startgröße [dash.js:303, 321]
    readonly property var dashIconSizes: [16, 22, 24, 32, 48, 64]
    readonly property real dashIconSizeDefault: 64
    readonly property real dashLabelOffsetY: baseMargin * 2      // -y-offset des Tooltips [_dash:105]
    readonly property int dashItemHoverTimeout: 300              // DASH_ITEM_HOVER_TIMEOUT [dash.js:19]
    // Laufpunkt .app-grid-running-dot: 5 px, rund, offset-y im Dash -$dash_padding [_app-grid:45-51, _dash:77]
    readonly property real dashDotSize: 5
    readonly property color dashDot: systemFg
    readonly property real dashDotOffset: dashPadding
    // Abweichung von GNOME (dort genau ein Punkt je App): ein Punkt je Fenster, Abstand und Obergrenze sind Annahmen
    readonly property real dashDotSpacing: 3
    readonly property int dashMaxDots: 4
    // Start-Animation (Annahme, GNOME zoomt das Icon stattdessen heraus [iconGrid.js:25-26]): Hüpfen mit Höhe,
    // Dauer je Sprung, mindestens und höchstens so viele Sprünge
    readonly property real dashBounceHeight: 16
    readonly property int durationDashBounce: 400
    readonly property int dashBounceMinCycles: 2
    readonly property int dashBounceMaxCycles: 10
    // .app-menu max-width: 27.25em [_popovers:144]
    readonly property real dashMenuMaxWidth: 27.25 * 14.667

    // ───────────────────────── App-Grid ─────────────────────────
    // [_app-grid.scss], [appDisplay.js], [iconGrid.js], [pageIndicators.js] (Quellen unter docs/sources/)

    // Symbolgrößen, aus denen das Raster die größte passende wählt [iconGrid.js:17-24]
    readonly property var appGridIconSizes: [96, 64, 48, 32, 24, 16]
    // Rasterformate Zeilen × Spalten; gewählt wird das mit dem Seitenverhältnis am nächsten an der Fläche [iconGrid.js:36-53, 1167-1187]
    readonly property var appGridModes: [
        {
            "rows": 8,
            "columns": 3
        },
        {
            "rows": 6,
            "columns": 4
        },
        {
            "rows": 4,
            "columns": 6
        },
        {
            "rows": 3,
            "columns": 8
        }
    ]
    // .icon-grid [_app-grid:7-16]
    readonly property real appGridRowSpacing: basePadding * 2
    readonly property real appGridColumnSpacing: basePadding * 2
    readonly property real appGridMaxRowSpacing: basePadding * 6
    readonly property real appGridMaxColumnSpacing: basePadding * 6
    readonly property real appGridPagePaddingV: basePadding * 4
    readonly property real appGridPagePaddingH: basePadding * 3
    // Breite der Seitenhinweise: Anteil der Breite, je Seite halb [appDisplay.js:48, 221-237]
    readonly property real appGridPagePreviewRatio: 0.20
    // Randspalte je Seite für Pfeile: max(Anteil der Breite, Pfeilbreite) [appDisplay.js: BaseAppViewGridLayout._getIndicatorsWidth]
    readonly property real appGridIndicatorGutterRatio: 0.10
    // .overview-tile [_app-grid:21-37]: Radius 24, Padding 12, Abstand Icon–Titel 6
    readonly property real radiusOverviewTile: baseRadius * 3
    readonly property real overviewTilePadding: basePadding * 2
    readonly property real overviewTileSpacing: basePadding
    // Laufpunkt unter dem Icon: Verschiebung nach unten [_app-grid:50]
    readonly property real appDotOffset: 6
    // Verkleinerung des Icons mit Ziel-Ordner und seine Verzögerung [appDisplay.js:31, 3119-3141]
    readonly property real appFolderSubiconFraction: 0.4
    readonly property int appFolderHoverTimeout: 500
    // Zeiger über Rand eines Icons (Umsortieren) statt auf dem Icon (Ordner) [iconGrid.js:57-58]
    readonly property real appGridDividerLeeway: 20
    // Verzögerung vor dem Verschieben beim Ziehen, Seitenwechsel beim Ziehen [appDisplay.js:50-55]
    readonly property int appGridDelayedMove: 200
    readonly property int appGridDragPageSwitchInitial: 1000
    readonly property int appGridDragPageSwitchRepeat: 1000
    readonly property real appGridDragPageSwitchEdge: 20
    // Blättern mit dem Mausrad höchstens alle 150 ms [appDisplay.js:36]
    readonly property int appGridScrollTimeout: 150
    // Seitenwechsel 300 ms EASE_OUT_CUBIC [iconGrid.js:27, 1316-1337]; Icons verschieben 250 ms (Standard der Clutter-Zustände) mit 10 ms Staffelung
    readonly property int durationAppGridPage: 300
    readonly property int durationAppIconMove: 250
    readonly property int appIconMoveDelay: 10
    // Einblenden neuer Icons: Skalierung 0 → 1 [appDisplay.js:38-39, 1947-1958], Ziehen: 0.5 + Ausblenden [appDisplay.js:1960-1976]
    readonly property real appIconDragScale: 0.5
    // Quelle eines gezogenen Icons bleibt blass stehen, während der Geist am Zeiger hängt [appDisplay.js:scaleAndFade]
    readonly property real appIconDragSourceOpacity: 0.4
    // Öffnen des App-Grids [GNOME-Mockup appgrid-animation]: alle Zeilen liegen zunächst übereinander knapp über dem
    // Dash und fahren auseinander an ihren Platz, die obere Zeile zuerst. `appGridRevealSpread` ist der Anteil des
    // Fortschritts, über den die Zeilenverzögerung verteilt wird, `appGridRevealOpacity` die Deckkraft der noch
    // nicht aufgedeckten Kachel.
    readonly property real appGridRevealOpacity: 0
    readonly property real appGridRevealSpread: 0.5
    readonly property real appGridRevealScale: 0.8      // Anfangsgröße der Kacheln: 1 - Wert
    readonly property int durationAppGridReveal: 520
    // Zoom beim Start einer App [iconGrid.js:25-26, 391-425]
    readonly property real appIconLaunchScale: 3
    readonly property int durationAppIconLaunch: 250
    // Seitenhinweise und Pfeile [_app-grid:182-216, appDisplay.js:46-47]
    readonly property color pageHintStart: alpha(light1, 0.05)
    readonly property color pageHintEnd: "transparent"
    readonly property real radiusPageHint: radiusModal * 1.5
    readonly property real pageArrowMargin: basePadding
    readonly property real pageArrowPadding: basePadding * 3
    readonly property real pageArrowSize: iconSizeMedium + 2 * pageArrowPadding
    readonly property int durationPageIndicatorFade: 200
    // Seitenpunkte [_app-grid:120-132, pageIndicators.js:6-9]
    readonly property real pageIndicatorSize: 10
    readonly property real pageIndicatorPaddingTop: basePadding
    readonly property real pageIndicatorPaddingH: basePadding * 2
    readonly property real pageIndicatorInactiveOpacity: 128 / 255
    readonly property real pageIndicatorInactiveOpacityHover: 1
    readonly property real pageIndicatorInactiveScale: 2 / 3
    readonly property real pageIndicatorInactiveScalePressed: 0.5
    // Ziel-Hervorhebung für Ablegen: :drop [_drawing:376-379]
    readonly property color tileDropBg: transparentize(accentColor, 0.8)
    readonly property color tileDropRing: transparentize(accentColor, 0.2)

    // Ordner-Dialog [_app-grid:53-109, appDisplay.js:2463-2910]
    readonly property real appFolderSize: 720
    readonly property real radiusAppFolder: radiusModal * 4
    readonly property real appFolderBorderWidth: 1
    readonly property real appFolderNamePaddingV: basePadding * 4
    readonly property real appFolderNamePaddingH: basePadding * 6
    readonly property real appFolderNameEntryWidth: 12 * 14.667
    readonly property real appFolderIndicatorsMargin: basePadding * 4
    readonly property int appFolderGridColumns: 3
    readonly property int appFolderGridRows: 3
    readonly property int durationAppFolderNameSwitch: 300
    readonly property int appFolderPopdownTimeout: 500
    readonly property color appFolderShade: alpha("#000000", 204 / 255)
    readonly property color appFolderShadeLight: alpha("#000000", 85 / 255)

    // ───────────────────────── Suche ─────────────────────────
    // [_search-entry.scss], [_search-results.scss], [search.js], [searchController.js]

    // Suchfeld: 24em breit, Pille, Abstand oben 12 / unten 6, Symbole 16 px mit 4 px Rand [_search-entry:3-14]
    readonly property real searchEntryWidth: 24 * 14.667
    readonly property real searchEntryMarginTop: basePadding * 2
    readonly property real searchEntryMarginBottom: basePadding
    readonly property real searchEntryIconPadding: baseMargin
    readonly property real searchEntryIconMarginTop: 2
    // Eingabefeld im System-Stil (immer dunkel) [_common:337-345, _drawing:85-150]
    readonly property color systemEntryBg: mix(systemFg, systemBg, backgroundMixFactor)
    readonly property color systemEntryBgHover: lighten(systemEntryBg, 0.04)
    readonly property color systemEntryBgFocus: mix(accentText, systemEntryBg, 0.05)
    readonly property color systemEntryFg: systemFg
    readonly property color systemEntryFgIdle: transparentize(systemFg, 0.3)
    readonly property color systemEntryHint: transparentize(systemFg, 0.3)
    // Ergebnisfläche [_search-results:4-10]
    readonly property real searchResultsMargin: baseMargin
    readonly property real searchResultsMaxWidth: 1044
    // Such-Overlay (GNOME „Search as Overlay“): Panel unter dem Suchfeld, Übersicht bleibt dahinter sichtbar
    readonly property real searchOverlayWidth: 640
    readonly property real searchOverlayPadding: basePadding * 2
    readonly property real searchOverlayRadius: radiusModal * 1.5
    readonly property real searchOverlayMinHeight: 180
    readonly property real searchOverlayScrim: 0.35
    readonly property real searchOverlayStartScale: 0.9
    // Startversatz nach unten beim Aufschwingen (gleitet mit der Feder herein) [Overview.qml: searchPanel]
    readonly property real searchOverlayStartOffset: baseMargin * 2
    readonly property real searchCalcFontSize: 22
    // Abschnitte [_search-results:13-36]
    readonly property real searchSectionSpacing: basePadding * 3
    readonly property real searchSectionSeparator: baseMargin * 2
    readonly property real searchSectionPadding: basePadding * 2
    readonly property real searchSectionMargin: baseMargin * 3
    readonly property real searchSectionBorderWidth: 2
    readonly property real radiusSearchSection: radiusModal * 1.5
    readonly property real radiusSearchItem: baseRadius * 1.65
    // Kein-Treffer-Anzeige [_search-results:43-51], Wartekreis [search.js:19]
    readonly property real searchStatusSpacing: basePadding * 4
    readonly property color searchStatusFg: transparentize(systemFg, 0.2)
    readonly property real searchSpinnerSize: 64
    // Rastertreffer (Apps) [_search-results:53-60]
    readonly property real searchGridSpacing: basePadding * 5
    // Listentreffer [_search-results:80-111, search.js:81-150, 936-1013]
    readonly property real searchListSpacing: basePadding
    readonly property real searchListContentSpacing: basePadding
    readonly property real searchListTitleSpacing: basePadding * 2
    readonly property real searchListIconSize: iconSizeMedium
    readonly property real searchProviderIconSize: iconSizeLarge
    readonly property real searchProviderSpacing: basePadding * 2
    readonly property real searchProviderDetailsWidth: 120
    readonly property real searchProviderMargin: baseMargin
    readonly property color searchDescriptionFg: systemInsensitiveFg
    // Höchstzahl Zeilen je Anbieter und Apps im Raster [search.js:18, appDisplay.js:1760]
    readonly property int searchListMaxRows: 5
    readonly property int searchAppsMaxResults: 6
    // Wartezeit zwischen Eingabe und Suche in Dateien [search.js:674-676]
    readonly property int searchDelay: 150
    // Obergrenze der Dateitreffer, die abgefragt werden (angezeigt werden searchListMaxRows)
    readonly property int searchFilesQueryLimit: 25

    // ───────────────────────── Datumsmenü ─────────────────────────
    // [_calendar.scss], [_message-list.scss], [_message-list-48.scss] (Nicht-stören-Schalter), [_notifications.scss],
    // [_scrollbars.scss], [dateMenu.js], [calendar.js], [messageList.js], [mpris.js]

    // Farben
    // $hover_bg_color / $active_bg_color [_colors:62,66]
    readonly property color hoverBg: dark ? lighten(bgColor, 0.10) : darken(bgColor, 0.09)
    readonly property color activeBg: dark ? lighten(bgColor, 0.12) : darken(bgColor, 0.11)
    // $card_insensitive_fg_color [_colors:77]
    readonly property color cardInsensitiveFg: dark ? lighten(insensitiveFg, 0.09) : darken(insensitiveFg, 0.05)
    // .message und Stapel darunter [_message-list:95-108]
    readonly property color messageBg: dark ? lighten(shellCardBg, 0.05) : shellCardBg
    readonly property color messageSecondBg: dark ? darken(shellCardBg, 0.01) : darken(shellCardBg, 0.04)
    readonly property color messageLowerBg: dark ? darken(shellCardBg, 0.04) : darken(shellCardBg, 0.07)
    readonly property color messageLowerBorder: dark ? "transparent" : darken(shellCardBg, 0.10)
    readonly property color messageThemedIconBg: transparentize(fgColor, 0.93)       // [_message-list:166]
    readonly property color messagePlaceholderFg: transparentize(fgColor, 0.55)      // [_message-list:16]
    readonly property color groupCollapseBg: transparentize(fgColor, 0.8)            // [_message-list:79-82]
    readonly property color groupCollapseBgHover: transparentize(fgColor, 0.7)
    // .message-media-control [_message-list:228-250]
    readonly property color mediaControlHover: lighten(hoverBg, 0.05)
    readonly property color mediaControlActive: lighten(activeBg, 0.05)
    readonly property color mediaControlInsensitiveFg: lighten(insensitiveFg, 0.05)
    // Kalender [_calendar:82-148]
    readonly property color calendarOtherMonthFg: transparentize(fgColor, 0.5)
    readonly property color calendarWeekNumberBg: transparentize(insensitiveFg, 0.8)
    // Punkt für Tage mit Terminen: calendar-today(-light).svg, Kreis r=2 bei (16, 28) in 32×32, auf die Zelle skaliert
    readonly property color calendarEventDot: dark ? alpha(light1, 0.858277) : "#242424"
    readonly property color calendarEventDotToday: alpha(light1, 0.858277)
    readonly property real calendarEventDotRadius: 2 / 32
    readonly property real calendarEventDotY: 28 / 32
    // Scrollleiste [_scrollbars:19-27]
    readonly property color scrollbarHandle: mix(fgColor, bgColor, 0.3)
    readonly property color scrollbarHandleHover: mix(fgColor, bgColor, 0.5)
    readonly property color scrollbarHandleActive: mix(fgColor, bgColor, 0.4)
    // Fokusrand des Nicht-stören-Schalters [_message-list-48:57-59]
    readonly property color dndButtonFocus: transparentize(accentColor, 0.4)

    // Popover und Spalten
    readonly property real radiusDateMenu: baseRadius * 1.5 + basePadding * 3 // 30, .datemenu-popover [_calendar:9]
    readonly property real calendarAreaPadding: baseMargin       // #calendarArea [_calendar:5]
    readonly property real calendarColumnSpacing: basePadding    // .datemenu-calendar-column [_calendar:14-19]
    readonly property real calendarColumnMargin: basePadding

    // Nachrichtenliste [_message-list:3-62]
    readonly property real messageListWidth: 29 * 14.667         // 29em
    readonly property real messageListMarginRight: baseMargin
    readonly property real messageListPaddingRight: basePadding
    readonly property real messageListBorder: 1
    readonly property real messageViewMarginRight: baseMargin * 3 // Platz für die Scrollleiste
    readonly property real messageViewFade: 68                    // -st-vfade-offset
    readonly property real messagePlaceholderIconSize: 96
    readonly property real messagePlaceholderSpacing: baseMargin * 3
    readonly property real messageControlsPadding: basePadding * 2
    readonly property real messageControlsPaddingBottom: basePadding   // [_message-list-48:30]
    readonly property real messageControlsSpacing: basePadding
    readonly property real dndButtonBorder: 2                     // [_message-list-48:48-55]
    readonly property real radiusDndButton: 32

    // Nachricht (.message) [_message-list:86-215]
    readonly property real messageSpacing: basePadding * 2        // margin-bottom in .message-view
    readonly property real radiusMessage: radiusModal + 2         // 18 in .message-view
    readonly property real messagePadding: basePadding
    readonly property real messageHeaderSpacing: basePadding
    readonly property real messageHeaderMinHeight: 24
    readonly property real messageHeaderButtonPadding: basePadding
    readonly property real messageCloseButtonMargin: basePadding * 0.5
    readonly property real messageIconSize: iconSize * 3          // 48
    readonly property real messageIconMargin: basePadding
    readonly property real messageContentSpacing: baseMargin
    readonly property real messageActionPadding: baseMargin
    readonly property real messageActionSpacing: basePadding
    readonly property int messageExpandLines: 6                   // DEFAULT_EXPAND_LINES [messageList.js:23]
    readonly property real radiusMediaArt: baseRadius             // .media-message .message-icon [_message-list:256]
    readonly property real mediaThemedIconSize: iconSize * 2      // 32
    readonly property real mediaControlPaddingH: basePadding * 3  // [_message-list:229]
    readonly property real notificationButtonPaddingV: basePadding // %notification_button [_common:197-201]
    readonly property real notificationButtonPaddingH: basePadding * 2

    // Gruppen [_message-list:65-84, messageList.js:19-30]
    readonly property real groupHeaderPadding: basePadding
    readonly property real groupTitleMargin: baseMargin
    readonly property real groupCollapsePadding: 4
    readonly property real groupCollapseBorder: 4
    readonly property int groupMaxVisibleStacked: 3
    readonly property real groupStackWidthOffset: 6
    readonly property real groupStackHeightOffset: 10
    readonly property real groupStackHeightReduction: 1.4
    readonly property real groupExpandedBottomMargin: 15

    // Scrollleiste [_scrollbars:13-27]
    readonly property real scrollbarWidth: 8
    readonly property real scrollbarHandleBorder: 3
    readonly property int durationScrollbar: 500

    // Heute-Knopf [_calendar:23-36]
    readonly property real todayButtonPadding: basePadding * 1.5

    // Monatskalender [_calendar:39-149]
    readonly property real calendarPagerSize: 2.6 * 14.667        // 2.6em
    readonly property real calendarMonthLabelWidth: 10 * 14.667   // 10em
    readonly property real calendarMonthLabelPaddingV: 8
    readonly property real calendarDaySize: 3 * 14.667            // 3em = 44px
    readonly property real calendarDayMargin: 2
    readonly property real calendarHeadingMargin: baseMargin
    readonly property real calendarHeadingPaddingV: basePadding * 0.5
    readonly property real calendarHeadingPaddingH: basePadding
    readonly property real calendarWeekNumberMargin: basePadding
    readonly property real calendarWeekNumberPaddingH: basePadding
    readonly property real radiusCalendarWeekNumber: baseRadius * 0.5

    // Termine, Weltuhren, Wetter [_calendar:152-285]
    readonly property real eventsTitlePaddingBottom: basePadding
    readonly property real eventsListSpacing: basePadding
    readonly property real worldClocksRowSpacing: basePadding
    readonly property real worldClocksColumnSpacing: basePadding * 2
    readonly property real worldClocksRow: 40            // große Zeile mit Zifferblatt
    readonly property real worldClocksDial: 40
    readonly property real worldClocksCompactRow: 24     // kompakte Liste ab mehr als 4 Uhren
    readonly property real worldClocksCompactDial: 22
    readonly property real calendarSideWidth: 17 * 14.667 // linke Spalte (Datum, Wetter, Termine) im zweispaltigen Menü
    readonly property real weatherSpacing: basePadding
    readonly property real weatherForecastTimePadding: basePadding
    readonly property real weatherForecastIconSize: iconSize * 2  // $large_scalable_icon_size
    readonly property real weatherForecastIconMargin: baseMargin
    // Sonne in Gelb wie im Mockup, sonst Vordergrundfarbe
    function weatherIconColor(icon) {
        return icon.indexOf("weather-clear-symbolic") === 0 || icon.indexOf("weather-few-clouds-symbolic") === 0 ? yellow3 : fgColor;
    }
    readonly property int weatherMaxForecasts: 5                  // MAX_FORECASTS [dateMenu.js:22]

    // Animationen [messageList.js:20-25, messageTray.js:17]
    readonly property int durationMessage: 100                    // MESSAGE_ANIMATION_TIME
    readonly property int durationGroupExpand: 200                // GROUP_EXPENSION_TIME
    readonly property int durationMessageExpand: durationNotification // Text/Aktionen aufklappen (ANIMATION_TIME)

    // Banner (.notification-banner) [_notifications.scss:3-13, messageTray.js:1196-1204]
    readonly property real notificationBannerWidth: (compact ? 30 : 34) * 14.667   // 34em
    readonly property real notificationBannerMinHeight: compact ? 52 : 64
    readonly property real notificationBannerMargin: baseMargin
    readonly property real notificationBannerShadowBlur: 24
    readonly property real notificationBannerShadowY: 8
    readonly property real notificationBannerScaleFrom: 0.9
    readonly property real notificationWindowMargin: 5 * baseMargin * 2 // Platz für den Schatten im Layer-Fenster
    readonly property real notificationWindowHeight: 480          // höchster aufgeklappter Banner samt Stapel

    // On-Screen-Anzeige (.osd-window, .level) [_osd.scss:5-33, _common.scss:291-301, osdWindow.js:6-8]
    readonly property color osdLevelBg: alpha(osdFg, dark ? 0.1 : 0.3)  // -barlevel-background-color, $variant=='light' → 0.7 transparent
    readonly property real osdBorderWidth: 1
    readonly property real osdPaddingV: basePadding * (compact ? 1.5 : 2)
    readonly property real osdPaddingH: basePadding * 3
    readonly property real osdSpacing: basePadding * 2            // Icon ↔ Inhalt
    readonly property real osdInnerSpacing: baseMargin * 2        // Label ↔ Balken (& > * { spacing })
    readonly property real osdMarginBottom: (compact ? 3 : 4) * 14.667            // margin-bottom: 4em
    readonly property real osdIconSize: iconSizeLarge             // StIcon icon-size: $large_icon_size
    readonly property real osdLabelMarginEnd: basePadding         // StLabel:ltr margin-right
    readonly property real osdLevelWidth: compact ? 130 : 160                     // .level min-width
    readonly property real osdLevelHeight: 6                      // $osd_levelbar_height
    readonly property real osdLevelMarginBottom: baseMargin       // .level margin-bottom (Label darüber)
    readonly property real osdLevelMarginEnd: basePadding         // .level:ltr margin-right
    readonly property real osdOverdriveSeparatorWidth: basePadding * 0.5
    readonly property int osdHideTimeout: 1500                    // HIDE_TIMEOUT
    readonly property int durationOsdFade: 100                    // FADE_TIME
    readonly property int durationOsdLevel: 100                   // LEVEL_ANIMATION_TIME
}
