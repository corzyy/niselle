pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root


    property bool dark: true

    property string primaryScreenName: "DP-1"

    property string accent: "blue"

    property bool matugen: true

    property bool gameMode: false

    property bool blur: false
    readonly property real blurSurfaceOpacity: 0.4
    function glass(c) {
        return blur && !gameMode ? alpha(c, Qt.color(c).a * blurSurfaceOpacity) : c;
    }

    property bool compact: false


    readonly property string paletteFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/niselle/colors.json"
    property var _palette: null
    readonly property bool matugenActive: matugen && _palette !== null
    readonly property var _modePalette: matugenActive ? (dark ? _palette.dark : _palette.light) : null

    function pc(role, fallback) {
        const v = _modePalette ? _modePalette[role] : undefined;
        return v ? Qt.color(v) : fallback;
    }
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


    function alpha(c, a) {
        const k = Qt.color(c);
        return Qt.rgba(k.r, k.g, k.b, a);
    }

    function transparentize(c, amount) {
        const k = Qt.color(c);
        return Qt.rgba(k.r, k.g, k.b, k.a * (1 - amount));
    }

    function lighten(c, amount) {
        return Qt.hsla(c.hslHue, c.hslSaturation, Math.max(0, Math.min(1, c.hslLightness + amount)), c.a);
    }

    function darken(c, amount) {
        return lighten(c, -amount);
    }

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

    readonly property color accentColor: pc("primary", accents[accent] ?? accents["blue"])
    readonly property color accentFg: pc("on_primary", "#ffffff")
    readonly property color accentText: dark && !matugenActive ? mix(accentColor, light1, 0.6) : accentColor
    readonly property color accentBorder: dark ? lighten(accentColor, matugenActive ? 0.1 : 0.3) : darken(accentColor, 0.2)
    readonly property color linkColor: dark ? lighten(accentColor, 0.2) : darken(accentColor, 0.1)

    readonly property color focusRing: transparentize(accentText, 0.2)
    readonly property real focusRingWidth: 2
    readonly property color focusRingDefault: transparentize(accentBorder, 0.2)


    readonly property color destructive: pc("error", dark ? red4 : red3)
    readonly property color destructiveFg: pc("on_error", light1)
    readonly property color success: dark ? green5 : green4
    readonly property color successFg: light1
    readonly property color warning: dark ? "#cd9309" : yellow5
    readonly property color warningFg: transparentize("#000000", 0.2)
    readonly property color error: destructive
    readonly property color errorFg: light1


    readonly property color baseDark: pcMode("dark", "surface", "#222226")
    readonly property color baseLight: pcMode("light", "surface", "#fafafb")

    readonly property color baseColor: pc("surface_container_lowest", dark ? baseDark : light1)
    readonly property color bgColor: pc("surface_container", dark ? "#36363a" : baseLight)
    readonly property color fgColor: pc("on_surface", dark ? light1 : baseDark)

    readonly property color panelBg: glass(pc("surface_container_lowest", dark ? dark5 : baseLight))
    readonly property color panelFg: fgColor
    readonly property color panelBorder: dark ? "transparent" : alpha(baseDark, 0.1)
    readonly property color panelFgTransparent: light1
    readonly property color panelFgSystem: systemFg
    readonly property color privacyIndicator: dark ? orange3 : orange4
    readonly property color recordingIndicator: red4

    readonly property color shellCardBg: pc("surface_container_high", dark ? lighten(bgColor, 0.07) : light1)
    readonly property color cardShadowColor: dark ? alpha(dark5, 0.28) : alpha(dark5, 0.07)
    readonly property color cardShadowBorder: dark ? alpha(light1, 0.05) : alpha(dark5, 0.09)

    readonly property real borderOpacity: dark ? 0.10 : 0.15
    readonly property color borders: alpha(fgColor, borderOpacity)
    readonly property color outerBorders: dark ? lighten(bgColor, 0.05) : darken(bgColor, 0.07)

    readonly property color osdFg: light1
    readonly property color osdBg: glass(lighten(baseDark, 0.05))
    readonly property color osdBorders: alpha(osdFg, 0.1)
    readonly property color osdOuterBorders: alpha(osdFg, 0.02)

    readonly property color systemBase: baseDark
    readonly property color systemFg: pcMode("dark", "on_surface", baseLight)
    readonly property color systemBg: lighten(systemBase, 0.05)
    readonly property color systemBorders: alpha(systemFg, 0.1)
    readonly property color systemInsensitiveFg: mix(systemBg, systemFg, 0.37)
    readonly property color systemOverlayBg: mix(systemBase, systemFg, 0.9)

    readonly property color overviewBg: systemBase
    readonly property color overviewFg: systemFg

    readonly property color insensitiveFg: dark ? mix(fgColor, bgColor, 0.5) : mix(fgColor, bgColor, 0.6)
    readonly property color insensitiveBg: mix(bgColor, baseColor, 0.6)

    readonly property color shadowColor: dark ? alpha(dark5, 0.5) : alpha(dark5, 0.2)

    readonly property color menuBg: glass(bgColor)
    readonly property color menuItemBg: dark ? lighten(menuBg, 0.05) : darken(menuBg, 0.05)
    readonly property color subMenuBg: dark ? lighten(menuBg, 0.13) : darken(menuBg, 0.17)

    readonly property real backgroundMixFactor: dark ? 0.09 : 0.12

    readonly property color sliderTrough: alpha(fgColor, 0.1)
    readonly property color sliderHandle: dark ? darken(fgColor, 0.09) : fgColor
    readonly property color sliderHandleHover: dark ? fgColor : lighten(fgColor, 0.07)
    readonly property color switchBg: alpha(dark ? light1 : dark5, 0.15)
    readonly property color switchBgHover: alpha(dark ? light1 : dark5, 0.2)
    readonly property color switchHandle: dark ? mix(light1, bgColor, 0.8) : light1
    readonly property color switchHandleChecked: light1
    readonly property color switchHandleShadow: alpha(dark5, 0.2)

    readonly property color quickToggleMenuButtonBg: dark ? lighten(bgColor, 0.08) : darken(bgColor, 0.05)
    readonly property color quickToggleMenuButtonCheckedBg: dark ? mix(accentColor, fgColor, 0.85) : mix(accentColor, fgColor, 0.92)
    readonly property color quickToggleSeparator: alpha(fgColor, 0.25)
    readonly property color quickToggleCheckedSeparator: dark ? mix(accentFg, accentColor, 0.3) : mix(accentFg, accentColor, 0.2)

    readonly property color quickMenuHeaderIconBg: transparentize(fgColor, 0.8)
    readonly property color entryBg: mix(fgColor, bgColor, backgroundMixFactor)
    readonly property color entryBgHover: dark ? lighten(entryBg, 0.04) : darken(entryBg, 0.04)
    readonly property color entryFg: fgColor
    readonly property color entryFgIdle: transparentize(fgColor, 0.3)
    readonly property color entryHint: transparentize(fgColor, 0.3)
    readonly property color entrySelection: transparentize(accentColor, 0.7)
    readonly property color dialogShade: alpha("#000000", 0.4)
    readonly property color dialogWarningBg: transparentize(warning, 0.9)


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
    readonly property color adwOverviewBg: pc("surface_container_low", dark ? "#28282c" : "#f3f3f5")
    readonly property color adwOverviewFg: dark ? "#ffffff" : Qt.rgba(0, 0, 6 / 255, 0.8)
    readonly property real adwBorderOpacity: 0.15
    readonly property real adwDimOpacity: 0.55
    readonly property real disabledOpacity: 0.5

    function buttonBg(state, o) {
        const opt = o ?? {};
        const c = opt.bg ?? bgColor;
        const tc = opt.fg ?? fgColor;
        const style = opt.style ?? "";
        const darkEl = opt.alwaysDark === true;
        const light = !dark;

        const toward = (col, f) => (light && !darkEl) ? darken(col, f) : lighten(col, f);

        let base = mix(tc, c, backgroundMixFactor);
        if (style === "card")
            base = shellCardBg;
        if (style === "flat" || style === "default")
            base = c;

        const hoverF = style === "flat" ? 0.07 : 0.04;
        const activeF = 0.09;
        const checkedF = 0.08;
        const insF = 0.03;

        let normal = base;
        let hover = toward(base, hoverF);
        let active = toward(base, activeF);
        let checked = toward(base, checkedF);
        let insensitive = (light && !darkEl) ? lighten(base, insF) : darken(base, insF);
        let activeHover = toward(active, hoverF);
        let checkedHover = toward(checked, hoverF);
        let checkedActive = toward(checked, activeF);

        if (style === "dialog") {
            normal = transparentize(tc, 0.9);
            hover = transparentize(tc, 0.87);
            active = transparentize(tc, 0.84);
            activeHover = transparentize(tc, 0.81);
            insensitive = transparentize(tc, 0.9);
        } else if (style === "notification") {
            normal = transparentize(tc, 0.85);
            hover = transparentize(tc, 0.7);
            insensitive = transparentize(tc, 0.9);
            active = transparentize(tc, 0.8);
            activeHover = transparentize(tc, 0.8);
        }
        if (style === "flat")
            insensitive = normal;

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
                const b = state === "focus" ? (style === "flat" ? transparentize(normal, 0.75) : normal) : hover;
                return mix(accentText, b, 0.05);
            }
        case "undecorated":
            return "transparent";
        default:
            return normal;
        }
    }

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

    function buttonFgInsensitive(fg) {
        return transparentize(fg ?? fgColor, dark ? 0.5 : 0.6);
    }

    function panelButtonFill(state, fg, filled) {
        const f = fg ?? panelFg;
        if (filled !== undefined) {
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


    readonly property real basePadding: compact ? 5 : 6
    readonly property real baseMargin: 4
    readonly property real baseRadius: 8
    readonly property real spacingXs: 2
    readonly property real spacingSm: baseMargin
    readonly property real spacingMd: basePadding
    readonly property real spacingLg: basePadding * 2
    readonly property real spacingXl: basePadding * 3


    readonly property real radiusPill: 999
    readonly property real radiusModal: baseRadius * 2
    readonly property real radiusAlert: 18
    readonly property real radiusPopover: radiusModal * 1.25
    readonly property real radiusMenuItem: baseRadius * 1.5
    readonly property real radiusSubMenu: radiusMenuItem + 1
    readonly property real radiusButton: baseRadius
    readonly property real radiusEntry: baseRadius
    readonly property real radiusTile: baseRadius * 2
    readonly property real radiusCard: baseRadius * 1.5
    readonly property real radiusDialogButton: baseRadius * 1.5
    readonly property real radiusQuickSettings: radiusModal * 2.25
    readonly property real radiusQuickToggleMenu: baseRadius * 3
    readonly property real radiusWindow: 15
    readonly property real radiusAdwPopover: 15


    readonly property real panelHeight: compact ? 28 : 32
    readonly property real panelButtonBorder: 3
    readonly property real panelButtonHPadding: basePadding * 2
    readonly property real panelButtonMinHPadding: basePadding
    readonly property real panelIndicatorSpacing: 2
    readonly property real panelClockHPadding: basePadding * 2
    readonly property real workspaceDotSize: 8
    readonly property real workspaceDotSpacing: 5
    readonly property real workspaceDotInactiveScale: 0.75
    readonly property real workspaceDotInactiveOpacity: 0.5
    readonly property int durationWorkspaceDot: 500
    function workspaceDotWidthMultiplier(count) {
        return count <= 2 ? 3.625 : (count <= 5 ? 3.25 : 2.75);
    }
    readonly property real panelStatusIconSpacing: baseMargin
    readonly property real panelStatusIconMargin: baseMargin
    readonly property real panelAppNameMaxWidth: 24 * 14.667
    readonly property real screenCornerRadius: radiusWindow

    property var barAnchors: ({})
    property var _pendingAnchors: ({})
    property bool _anchorFlushScheduled: false

    function setBarAnchor(id, x, y, w, h) {
        const key = (id || "").trim();
        if (key.length === 0)
            return;
        const nx = Math.round(x), ny = Math.round(y);
        const nw = Math.max(1, Math.round(w)), nh = Math.max(1, Math.round(h));
        let cur = _pendingAnchors[key];
        if (cur === undefined)
            cur = barAnchors[key];
        if (cur && cur.x === nx && cur.y === ny && cur.w === nw && cur.h === nh)
            return;
        _pendingAnchors[key] = {
            "x": nx,
            "y": ny,
            "w": nw,
            "h": nh
        };
        if (_anchorFlushScheduled)
            return;
        _anchorFlushScheduled = true;
        Qt.callLater(() => {
            _anchorFlushScheduled = false;
            const pend = _pendingAnchors;
            _pendingAnchors = ({});
            const next = {};
            for (const k in barAnchors)
                next[k] = barAnchors[k];
            let changed = false;
            for (const k in pend) {
                const n = pend[k], c = next[k];
                if (!c || c.x !== n.x || c.y !== n.y || c.w !== n.w || c.h !== n.h) {
                    next[k] = n;
                    changed = true;
                }
            }
            if (changed)
                barAnchors = next;
        });
    }
    function barAnchor(id) {
        const a = barAnchors[(id || "").trim()];
        return a ? a : null;
    }
    property int anchorRefreshTrigger: 0
    Timer {
        id: anchorRefreshDebounce
        interval: 80
        repeat: false
        onTriggered: anchorRefreshTrigger++
    }
    function refreshBarAnchors() {
        anchorRefreshDebounce.restart();
    }

    readonly property real popoverPadding: basePadding
    readonly property real popoverMinWidth: 220
    readonly property real popoverRise: basePadding
    readonly property real popoverBorderWidth: 1
    readonly property real menuItemPaddingV: basePadding * 1.5
    readonly property real menuItemPaddingH: basePadding * 2
    readonly property real menuItemSpacing: basePadding
    readonly property real menuOrnamentPaddingLeft: basePadding
    readonly property real menuOrnamentSize: 16
    readonly property real menuSeparatorHeight: 1
    readonly property real menuSwitchMargin: baseMargin

    readonly property real buttonPaddingV: basePadding * 0.5
    readonly property real buttonPaddingH: basePadding * 4
    readonly property real buttonMinHeight: 22
    readonly property real iconButtonPadding: basePadding * 2
    readonly property real iconButtonQuickPadding: basePadding * 1.75

    readonly property real tilePadding: basePadding
    readonly property real tileSpacing: basePadding

    readonly property real sliderTroughHeight: 4
    readonly property real sliderHandleSize: 16
    readonly property real sliderBinPadding: basePadding

    readonly property real switchWidth: 46
    readonly property real switchHandleSize: 20
    readonly property real switchHandleMargin: 3
    readonly property real switchHeight: switchHandleSize + 2 * switchHandleMargin

    readonly property real quickSettingsPadding: basePadding * 3
    readonly property real quickToggleWidth: compact ? 156 : 176
    readonly property real quickToggleHeight: compact ? 40 : 48
    readonly property real quickToggleSpacing: basePadding * 1.5
    readonly property real quickToggleHPadding: basePadding * 2
    readonly property real quickToggleIconLeading: basePadding * 2.5
    readonly property real quickToggleMenuButtonPaddingV: basePadding
    readonly property real quickToggleMenuButtonPaddingH: basePadding * 1.75
    readonly property real quickToggleSeparatorWidth: 1
    readonly property real backgroundAppsToggleHeight: 40
    readonly property real backgroundAppClosePadding: basePadding
    readonly property real backgroundAppIconSize: iconSizeLarge

    readonly property real quickSettingsWidth: 2 * quickToggleWidth + spacingLg
    readonly property real quickSettingsMinListHeight: 140
    readonly property real quickSettingsMaxListHeight: 560
    readonly property real quickSliderSpacing: basePadding
    readonly property real quickSliderButtonPadding: basePadding
    readonly property real quickMenuMargin: basePadding * 2
    readonly property real quickMenuHeaderIconPadding: basePadding * 1.5
    readonly property real quickMenuHeaderSpacingV: basePadding * 0.5
    readonly property real quickMenuHeaderSpacingH: basePadding * 2
    readonly property real quickMenuHeaderPaddingBottom: basePadding * 2
    readonly property real quickSystemSpacing: basePadding * 2
    readonly property real wirelessSecureIconSize: iconSize * 0.5
    readonly property real menuPlaceholderPaddingV: 2 * 14.667
    readonly property real menuPlaceholderPaddingH: 4 * 14.667

    readonly property real dialogPadding: basePadding * 4
    readonly property real dialogSpacing: basePadding * 3
    readonly property real dialogContentPaddingTop: basePadding * 2
    readonly property real dialogContentMaxWidth: 28 * 14.667
    readonly property real dialogPromptWidth: 28 * 14.667
    readonly property real dialogEntryWidth: 20 * 14.667
    readonly property real dialogButtonBoxPaddingTop: basePadding
    readonly property real dialogButtonPadding: basePadding * 2
    readonly property real dialogEntryPaddingV: basePadding * 2
    readonly property real entryPaddingH: basePadding * 1.5
    readonly property real entryPaddingV: basePadding * 1.5
    readonly property real dialogLabelPadding: basePadding * 1.5
    readonly property int durationDialog: 200

    readonly property real lockDialogWidth: 26 * 14.667
    readonly property real lockClockSpacing: basePadding * 3
    readonly property real lockClockHintMargin: basePadding * 3
    readonly property real lockNameFontSize: 20
    readonly property real lockEntryRadius: baseRadius * 1.5
    readonly property real lockButtonRadius: radiusPill
    readonly property real lockButtonFontSize: fontSizeBase + 2
    readonly property real lockButtonHeight: 40
    readonly property real lockMessageMinHeight: 2.75 * 14.667

    readonly property real cardPadding: basePadding * 2
    readonly property real cardMargin: baseMargin
    readonly property real cardBorderWidth: 1


    readonly property real shadowPopoverY: 0
    readonly property real shadowPopoverBlur: 0
    readonly property real shadowCardY: 0
    readonly property real shadowCardBlur: 0
    readonly property color highlightEdge: "transparent"
    readonly property real shadowHandleY: 0
    readonly property real shadowHandleBlur: 0


    property string fontOverride: ""
    property string fontMonoOverride: ""

    readonly property string fontFamily: fontOverride !== "" ? fontOverride : (Qt.fontFamilies().indexOf("Adwaita Sans") >= 0 ? "Adwaita Sans" : "Cantarell")
    readonly property string fontFamilyMono: fontMonoOverride !== "" ? fontMonoOverride : (Qt.fontFamilies().indexOf("Adwaita Mono") >= 0 ? "Adwaita Mono" : "monospace")

    readonly property real fontSizeBase: 11
    readonly property real fontSizeLargeTitle: 24
    readonly property real fontSizeTitle1: 20
    readonly property real fontSizeTitle2: 15
    readonly property real fontSizeTitle3: 15
    readonly property real fontSizeTitle4: 13
    readonly property real fontSizeHeading: 11
    readonly property real fontSizeCaptionHeading: 9
    readonly property real fontSizeCaption: 9
    readonly property real fontSizeSmaller: 9

    readonly property int fontWeightLight: Font.Light
    readonly property int fontWeightNormal: Font.Normal
    readonly property int fontWeightBold: Font.Bold
    readonly property int fontWeightExtraBold: Font.ExtraBold


    readonly property real iconSize: 16
    readonly property real iconSizeMedium: 24
    readonly property real iconSizeLarge: 32
    readonly property real iconSizeSwitch: 16


    readonly property int durationOverview: 260
    readonly property int durationSideControls: 300
    readonly property int durationPanel: 300
    readonly property int durationPopover: 240
    readonly property int durationDash: 260
    readonly property int durationDashLabelShow: 200
    readonly property int durationDashLabelHide: 140
    readonly property int durationNotification: 280
    readonly property int notificationTimeout: 4000
    readonly property int notificationHideTimeout: 200
    readonly property int notificationLeaveTimeout: 600
    readonly property int notificationMaxQueue: 3
    readonly property int durationWindowMinimize: 400
    readonly property int durationWindowShow: 200
    readonly property int durationWindowShowDialog: 160
    readonly property int durationWindowDestroy: 200
    readonly property int durationWindowDestroyDialog: 140
    readonly property int durationWindow: 320
    readonly property int durationDim: 500
    readonly property int durationUndim: 320
    readonly property int durationWorkspaceSwitch: 340
    readonly property int durationAppViewsSwitch: 380
    readonly property int durationAppIconTitleExpand: 240
    readonly property int durationAppIconTitleCollapse: 160
    readonly property int durationAppFolderDialog: 260
    readonly property int durationAppPagePreview: 200
    readonly property int durationTile: 140
    readonly property int durationMenuItem: 140
    readonly property int durationPanelButton: 190
    readonly property int durationButton: 260
    readonly property int durationSwitch: 160

    function enter(p, i, n) {
        return 1;
    }
    readonly property real enterRise: 0
    readonly property int durationControlCenter: 460

    readonly property real pressScale: 1.0
    readonly property int durationPress: 120

    readonly property int easeOutBack: Easing.OutBack
    readonly property int easeOutQuad: Easing.OutQuint
    readonly property int easeInQuad: Easing.InCubic
    readonly property int easeOutCubic: Easing.OutQuart
    readonly property int easeOutSine: Easing.OutSine
    readonly property int easeOutQuint: Easing.OutQuint
    readonly property int easeOutExpo: Easing.OutExpo

    readonly property int easeTransition: Easing.InOutCubic

    readonly property var cssEaseOutQuad: [0.25, 0.46, 0.45, 0.94, 1, 1]

    readonly property int durationQuickSettings: 400
    readonly property int durationQuickMenu: durationQuickSettings / 2
    readonly property real quickSettingsDim: 0.4
    readonly property int durationSpinner: 1000

    readonly property int motionSnap: 140
    readonly property int motionFast: 210
    readonly property int motionMedium: 300
    readonly property int motionSlow: 340
    readonly property int easeOut: Easing.OutCubic
    readonly property int easeEmphasized: Easing.OutQuint
    readonly property int easeSpring: Easing.OutBack
    readonly property real springOvershoot: 1.03
    readonly property real panelSpring: 6.5
    readonly property real panelDamping: 0.42
    readonly property real panelMass: 1.0
    readonly property real overviewSpring: 9.0
    readonly property real overviewDamping: 0.6
    readonly property real overviewSpringEpsilon: 0.002

    readonly property real overviewSpacingRatio: 0.02
    readonly property real overviewThumbnailsSpacingTop: 0.6
    readonly property real overviewThumbnailsSpacingBottom: 0.4
    readonly property real overviewDashMaxHeightRatio: 0.16
    readonly property real overviewSecondaryScale: 0.8
    readonly property int overviewActivationTimeout: 500
    readonly property real overviewScrimOpacity: 1.0
    readonly property real hotCornerSize: 1
    readonly property int hotCornerRetriggerDelay: 250
    readonly property int overviewShortcutDebounce: 150

    readonly property real windowPreviewMaxScale: 0.95
    readonly property real workspaceCornerRadius: 30
    readonly property real workspaceInactiveScale: 0.94
    readonly property real workspaceSideInset: 24
    readonly property real layoutScaleWeight: 1
    readonly property real layoutSpaceWeight: 0.1
    readonly property real windowPickerSpacing: basePadding
    readonly property real windowPickerPaddingRatio: 0.05
    readonly property real windowIconSize: 64
    readonly property real windowIconOverlap: 0.7
    readonly property real windowIconTitleSpacing: 6
    readonly property real windowActiveSizeInc: 5
    readonly property int durationWindowOverlay: 240
    readonly property int windowOverlayHideTimeout: 750
    readonly property real windowDndSize: 256
    readonly property real windowDraggingOpacity: 100 / 255
    readonly property color windowIconShadow: alpha("#000000", 0.4)
    readonly property real windowIconShadowY: 2
    readonly property real windowIconShadowBlur: 4
    readonly property color tooltipBg: transparentize("#000000", 0.1)
    readonly property color tooltipBorder: transparentize(light1, 0.9)
    readonly property color tooltipFg: light1
    readonly property real tooltipPaddingV: basePadding
    readonly property real tooltipPaddingH: basePadding * 2
    readonly property real tooltipBorderWidth: 1
    readonly property color windowCloseBg: transparentize(lighten(systemBg, 0.07), 0.02)
    readonly property color windowCloseBgHover: lighten(windowCloseBg, 0.07)
    readonly property color windowCloseBgActive: lighten(windowCloseBg, 0.13)
    readonly property real windowCloseSize: iconSizeLarge
    readonly property real windowCloseIconSize: iconSizeMedium
    readonly property real windowCloseBorder: 2
    readonly property int durationWindowClose: 100

    readonly property real thumbnailsMaxScale: 0.075
    readonly property int thumbnailsMinWorkspaces: 2
    readonly property real thumbnailsSpacing: basePadding
    readonly property real thumbnailsPadding: basePadding
    readonly property color thumbnailBackground: lighten(systemBg, 0.10)
    readonly property real thumbnailBorder: 1
    readonly property real radiusThumbnail: baseRadius * 0.5
    readonly property real thumbnailIndicatorBorder: 3
    readonly property real radiusThumbnailIndicator: baseRadius
    readonly property int durationThumbnailsExpand: 200
    readonly property real overviewWheelStep: 120
    readonly property color thumbnailDropOverlay: alpha(light1, 0.15)
    readonly property int durationWindowReposition: 200

    readonly property real popoverScaleFrom: 0.94


    readonly property color dashBackground: glass(systemOverlayBg)
    readonly property real dashPadding: basePadding * 2
    readonly property real dashEdgeOffset: baseMargin * 3
    readonly property real dashItemSpacing: baseMargin * 0.5
    readonly property real radiusDash: radiusModal + dashPadding
    readonly property real dashOuterPadding: basePadding
    readonly property real dashPlaceholderSize: 32
    readonly property real dashSeparatorWidth: 1
    readonly property real dashSeparatorMargin: baseMargin * 2
    readonly property color dashSeparator: alpha(systemFg, 0.35)
    readonly property var dashIconSizes: [16, 22, 24, 32, 48, 64]
    readonly property real dashIconSizeDefault: 64
    readonly property real dashLabelOffsetY: baseMargin * 2
    readonly property int dashItemHoverTimeout: 300
    readonly property real dashDotSize: 5
    readonly property color dashDot: systemFg
    readonly property real dashDotOffset: dashPadding
    readonly property real dashDotSpacing: 3
    readonly property int dashMaxDots: 4
    readonly property real dashBounceHeight: 16
    readonly property int durationDashBounce: 400
    readonly property int dashBounceMinCycles: 2
    readonly property int dashBounceMaxCycles: 10
    readonly property real dashMenuMaxWidth: 27.25 * 14.667


    readonly property var appGridIconSizes: [96, 64, 48, 32, 24, 16]
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
    readonly property real appGridRowSpacing: basePadding * 2
    readonly property real appGridColumnSpacing: basePadding * 2
    readonly property real appGridMaxRowSpacing: basePadding * 6
    readonly property real appGridMaxColumnSpacing: basePadding * 6
    readonly property real appGridPagePaddingV: basePadding * 4
    readonly property real appGridPagePaddingH: basePadding * 3
    readonly property real appGridPagePreviewRatio: 0.20
    readonly property real appGridIndicatorGutterRatio: 0.10
    readonly property real radiusOverviewTile: baseRadius * 3
    readonly property real overviewTilePadding: basePadding * 2
    readonly property real overviewTileSpacing: basePadding
    readonly property real appDotOffset: 6
    readonly property real appFolderSubiconFraction: 0.4
    readonly property int appFolderHoverTimeout: 500
    readonly property real appGridDividerLeeway: 20
    readonly property int appGridDelayedMove: 200
    readonly property int appGridDragPageSwitchInitial: 1000
    readonly property int appGridDragPageSwitchRepeat: 1000
    readonly property real appGridDragPageSwitchEdge: 20
    readonly property int appGridScrollTimeout: 150
    readonly property int durationAppGridPage: 300
    readonly property int durationAppIconMove: 250
    readonly property int appIconMoveDelay: 10
    readonly property real appIconDragScale: 0.5
    readonly property real appIconDragSourceOpacity: 0.4
    readonly property real appGridRevealOpacity: 1
    readonly property real appGridRevealSpread: 0
    readonly property real appGridRevealScale: 0
    readonly property int durationAppGridReveal: 520
    readonly property real appIconLaunchScale: 3
    readonly property int durationAppIconLaunch: 250
    readonly property color pageHintStart: alpha(light1, 0.05)
    readonly property color pageHintEnd: "transparent"
    readonly property real radiusPageHint: radiusModal * 1.5
    readonly property real pageArrowMargin: basePadding
    readonly property real pageArrowPadding: basePadding * 3
    readonly property real pageArrowSize: iconSizeMedium + 2 * pageArrowPadding
    readonly property int durationPageIndicatorFade: 200
    readonly property real pageIndicatorSize: 10
    readonly property real pageIndicatorPaddingTop: basePadding
    readonly property real pageIndicatorPaddingH: basePadding * 2
    readonly property real pageIndicatorInactiveOpacity: 128 / 255
    readonly property real pageIndicatorInactiveOpacityHover: 1
    readonly property real pageIndicatorInactiveScale: 2 / 3
    readonly property real pageIndicatorInactiveScalePressed: 0.5
    readonly property color tileDropBg: transparentize(accentColor, 0.8)
    readonly property color tileDropRing: transparentize(accentColor, 0.2)

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


    readonly property real searchEntryWidth: 24 * 14.667
    readonly property real searchEntryMarginTop: basePadding * 2
    readonly property real searchEntryMarginBottom: basePadding
    readonly property real searchEntryIconPadding: baseMargin
    readonly property real searchEntryIconMarginTop: 2
    readonly property color systemEntryBg: mix(systemFg, systemBg, backgroundMixFactor)
    readonly property color systemEntryBgHover: lighten(systemEntryBg, 0.04)
    readonly property color systemEntryBgFocus: mix(accentText, systemEntryBg, 0.05)
    readonly property color systemEntryFg: systemFg
    readonly property color systemEntryFgIdle: transparentize(systemFg, 0.3)
    readonly property color systemEntryHint: transparentize(systemFg, 0.3)
    readonly property real searchResultsMargin: baseMargin
    readonly property real searchResultsMaxWidth: 1044
    readonly property real searchOverlayWidth: 640
    readonly property real searchOverlayPadding: basePadding * 2
    readonly property real searchOverlayRadius: radiusModal * 1.5
    readonly property real searchOverlayMinHeight: 180
    readonly property real searchOverlayScrim: 0.35
    readonly property real searchOverlayStartScale: 1
    readonly property real searchOverlayStartOffset: 0
    readonly property real searchCalcFontSize: 22
    readonly property real searchSectionSpacing: basePadding * 3
    readonly property real searchSectionSeparator: baseMargin * 2
    readonly property real searchSectionPadding: basePadding * 2
    readonly property real searchSectionMargin: baseMargin * 3
    readonly property real searchSectionBorderWidth: 2
    readonly property real radiusSearchSection: radiusModal * 1.5
    readonly property real radiusSearchItem: baseRadius * 1.65
    readonly property real searchStatusSpacing: basePadding * 4
    readonly property color searchStatusFg: transparentize(systemFg, 0.2)
    readonly property real searchSpinnerSize: 64
    readonly property real searchGridSpacing: basePadding * 5
    readonly property real searchListSpacing: basePadding
    readonly property real searchListContentSpacing: basePadding
    readonly property real searchListTitleSpacing: basePadding * 2
    readonly property real searchListIconSize: iconSizeMedium
    readonly property real searchProviderIconSize: iconSizeLarge
    readonly property real searchProviderSpacing: basePadding * 2
    readonly property real searchProviderDetailsWidth: 120
    readonly property real searchProviderMargin: baseMargin
    readonly property color searchDescriptionFg: systemInsensitiveFg
    readonly property int searchListMaxRows: 5
    readonly property int searchAppsMaxResults: 6
    readonly property int searchDelay: 150
    readonly property int searchFilesQueryLimit: 25


    readonly property color hoverBg: dark ? lighten(bgColor, 0.10) : darken(bgColor, 0.09)
    readonly property color activeBg: dark ? lighten(bgColor, 0.12) : darken(bgColor, 0.11)
    readonly property color cardInsensitiveFg: dark ? lighten(insensitiveFg, 0.09) : darken(insensitiveFg, 0.05)
    readonly property color messageBg: dark ? lighten(shellCardBg, 0.05) : shellCardBg
    readonly property color messageSecondBg: dark ? darken(shellCardBg, 0.01) : darken(shellCardBg, 0.04)
    readonly property color messageLowerBg: dark ? darken(shellCardBg, 0.04) : darken(shellCardBg, 0.07)
    readonly property color messageLowerBorder: dark ? "transparent" : darken(shellCardBg, 0.10)
    readonly property color messageThemedIconBg: transparentize(fgColor, 0.93)
    readonly property color messagePlaceholderFg: transparentize(fgColor, 0.55)
    readonly property color groupCollapseBg: transparentize(fgColor, 0.8)
    readonly property color groupCollapseBgHover: transparentize(fgColor, 0.7)
    readonly property color mediaControlHover: lighten(hoverBg, 0.05)
    readonly property color mediaControlActive: lighten(activeBg, 0.05)
    readonly property color mediaControlInsensitiveFg: lighten(insensitiveFg, 0.05)
    readonly property color calendarOtherMonthFg: transparentize(fgColor, 0.5)
    readonly property color calendarWeekNumberBg: transparentize(insensitiveFg, 0.8)
    readonly property color calendarEventDot: dark ? alpha(light1, 0.858277) : "#242424"
    readonly property color calendarEventDotToday: alpha(light1, 0.858277)
    readonly property real calendarEventDotRadius: 2 / 32
    readonly property real calendarEventDotY: 28 / 32
    readonly property color scrollbarHandle: mix(fgColor, bgColor, 0.3)
    readonly property color scrollbarHandleHover: mix(fgColor, bgColor, 0.5)
    readonly property color scrollbarHandleActive: mix(fgColor, bgColor, 0.4)
    readonly property color dndButtonFocus: transparentize(accentColor, 0.4)

    readonly property real radiusDateMenu: baseRadius * 1.5 + basePadding * 3
    readonly property real calendarAreaPadding: baseMargin
    readonly property real calendarColumnSpacing: basePadding
    readonly property real calendarColumnMargin: basePadding

    readonly property real messageListWidth: 29 * 14.667
    readonly property real messageListMarginRight: baseMargin
    readonly property real messageListPaddingRight: basePadding
    readonly property real messageListBorder: 1
    readonly property real messageViewMarginRight: baseMargin * 3
    readonly property real messageViewFade: 68
    readonly property real messagePlaceholderIconSize: 96
    readonly property real messagePlaceholderSpacing: baseMargin * 3
    readonly property real messageControlsPadding: basePadding * 2
    readonly property real messageControlsPaddingBottom: basePadding
    readonly property real messageControlsSpacing: basePadding
    readonly property real dndButtonBorder: 2
    readonly property real radiusDndButton: 32

    readonly property real messageSpacing: basePadding * 2
    readonly property real radiusMessage: radiusModal + 2
    readonly property real messagePadding: basePadding
    readonly property real messageHeaderSpacing: basePadding
    readonly property real messageHeaderMinHeight: 24
    readonly property real messageHeaderButtonPadding: basePadding
    readonly property real messageCloseButtonMargin: basePadding * 0.5
    readonly property real messageIconSize: iconSize * 3
    readonly property real messageIconMargin: basePadding
    readonly property real messageContentSpacing: baseMargin
    readonly property real messageActionPadding: baseMargin
    readonly property real messageActionSpacing: basePadding
    readonly property int messageExpandLines: 6
    readonly property real radiusMediaArt: baseRadius
    readonly property real mediaThemedIconSize: iconSize * 2
    readonly property real mediaControlPaddingH: basePadding * 3
    readonly property real notificationButtonPaddingV: basePadding
    readonly property real notificationButtonPaddingH: basePadding * 2

    readonly property real groupHeaderPadding: basePadding
    readonly property real groupTitleMargin: baseMargin
    readonly property real groupCollapsePadding: 4
    readonly property real groupCollapseBorder: 4
    readonly property int groupMaxVisibleStacked: 3
    readonly property real groupStackWidthOffset: 6
    readonly property real groupStackHeightOffset: 10
    readonly property real groupStackHeightReduction: 1.4
    readonly property real groupExpandedBottomMargin: 15

    readonly property real scrollbarWidth: 8
    readonly property real scrollbarHandleBorder: 3
    readonly property int durationScrollbar: 500

    readonly property real todayButtonPadding: basePadding * 1.5

    readonly property real calendarPagerSize: 2.6 * 14.667
    readonly property real calendarMonthLabelWidth: 10 * 14.667
    readonly property real calendarMonthLabelPaddingV: 8
    readonly property real calendarDaySize: 3 * 14.667
    readonly property real calendarDayMargin: 2
    readonly property real calendarHeadingMargin: baseMargin
    readonly property real calendarHeadingPaddingV: basePadding * 0.5
    readonly property real calendarHeadingPaddingH: basePadding
    readonly property real calendarWeekNumberMargin: basePadding
    readonly property real calendarWeekNumberPaddingH: basePadding
    readonly property real radiusCalendarWeekNumber: baseRadius * 0.5

    readonly property real eventsTitlePaddingBottom: basePadding
    readonly property real eventsListSpacing: basePadding
    readonly property real calendarSideWidth: 17 * 14.667

    readonly property int durationMessage: 100
    readonly property int durationGroupExpand: 200
    readonly property int durationMessageExpand: durationNotification

    readonly property real notificationBannerWidth: (compact ? 30 : 34) * 14.667
    readonly property real notificationBannerMinHeight: compact ? 52 : 64
    readonly property real notificationBannerMargin: baseMargin
    readonly property real notificationBannerShadowBlur: 0
    readonly property real notificationBannerShadowY: 0
    readonly property real notificationBannerScaleFrom: 0.9
    readonly property real notificationWindowMargin: 5 * baseMargin * 2
    readonly property real notificationWindowHeight: 480

    readonly property color osdLevelBg: alpha(osdFg, dark ? 0.1 : 0.3)
    readonly property real osdBorderWidth: 1
    readonly property real osdPaddingV: basePadding * (compact ? 1.5 : 2)
    readonly property real osdPaddingH: basePadding * 3
    readonly property real osdSpacing: basePadding * 2
    readonly property real osdInnerSpacing: baseMargin * 2
    readonly property real osdMarginBottom: (compact ? 3 : 4) * 14.667
    readonly property real osdIconSize: iconSizeLarge
    readonly property real osdLabelMarginEnd: basePadding
    readonly property real osdLevelWidth: compact ? 130 : 160
    readonly property real osdLevelHeight: 6
    readonly property real osdLevelMarginBottom: baseMargin
    readonly property real osdLevelMarginEnd: basePadding
    readonly property real osdOverdriveSeparatorWidth: basePadding * 0.5
    readonly property int osdHideTimeout: 1500
    readonly property int durationOsdFade: 100
    readonly property int durationOsdLevel: 100
}
