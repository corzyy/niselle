pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Anzeigen über Hyprland: liest die Monitore (hyprctl -j monitors all), hält einen Entwurf (draft) für die
// Einstellungen-App und wendet ihn per Lua-`hl.monitor` (Hyprland ≥ 0.55) bzw. klassischem `keyword monitor` an.
// Aufbau und Werte folgen gnome-control-center (panels/display): Auflösung/Refresh/Skalierung/Drehung, Primäranzeige.
Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0
    // Hyprland mit Lua-Konfiguration (hl.monitor) statt klassischem keyword
    readonly property bool usingLua: Hyprland.usingLua

    // Aufgelöste Monitore (feste Reihenfolge wie hyprctl); `number` ist die 1-basierte Anzeigenummer
    property var outputs: []
    // Entwurf je Monitorname: { enabled, mode, x, y, scale, transform, vrr, cm }
    property var draft: ({})
    // Ausgewählter Monitor (Name) im Layout-Bereich
    property string selected: ""
    // "join" (erweitern) oder "mirror" (spiegeln); nur bei mehreren Monitoren von Bedeutung
    property string configMode: "join"

    // Erst nach dem ersten Einlesen sind outputs gültig
    property bool loaded: false
    // Gespeicherte Zuweisung wurde bereits angewandt
    property bool _restored: false
    // Beim Einlesen gemerkter Modus (join/mirror)
    property string _appliedMode: "join"

    readonly property var enabledOutputs: outputs.filter(o => root._d(o).enabled)
    readonly property int outputCount: outputs.length

    // Primäranzeige: gespeicherte Auswahl, sonst der erste aktive Monitor
    readonly property string primaryName: {
        // Erst nach dem Laden der Einstellungen entscheiden, sonst flackert die Leiste auf den falschen Monitor
        if (!SettingsService.loaded)
            return "";
        const want = SettingsService.primaryDisplay;
        if (want !== "" && outputs.some(o => o.name === want && root._d(o).enabled))
            return want;
        const first = enabledOutputs.length > 0 ? enabledOutputs[0] : outputs[0];
        return first ? first.name : "";
    }

    readonly property var selectedOutput: outputs.find(o => o.name === root.selected) ?? null

    // ───────────────────────── Entwurf ─────────────────────────

    function _d(output) {
        return draft[output.name] ?? root._fromOutput(output);
    }

    function _fromOutput(o) {
        let mode = o.modeString;
        if (mode === "" && o.modes.length > 0)
            mode = root.modeOf(o.modes[0]);
        return {
            "enabled": o.enabled,
            "mode": mode,
            "x": o.x,
            "y": o.y,
            "scale": o.scale,
            "transform": o.transform,
            "vrr": o.vrr,
            "cm": o.cm
        };
    }

    function _clone(obj) {
        return JSON.parse(JSON.stringify(obj));
    }

    // Entwurf weicht von der live gelesenen Zuweisung ab?
    readonly property bool dirty: {
        if (!loaded)
            return false;
        if (configMode !== _appliedMode)
            return true;
        for (const o of outputs) {
            const d = root._d(o);
            const b = root._fromOutput(o);
            if (d.enabled !== b.enabled || d.mode !== b.mode || d.x !== b.x || d.y !== b.y || Math.abs(d.scale - b.scale) > 1e-6 || d.transform !== b.transform || d.vrr !== b.vrr || d.cm !== b.cm)
                return true;
        }
        return false;
    }

    function _update(name, patch) {
        const next = root._clone(root.draft);
        next[name] = Object.assign({}, next[name] ?? {}, patch);
        root.draft = next;
    }

    function setEnabled(name, on) {
        root._update(name, { "enabled": on });
    }
    function setMode(name, mode) {
        root._update(name, { "mode": mode });
    }
    function setScale(name, scale) {
        root._update(name, { "scale": scale });
    }
    function setTransform(name, t) {
        root._update(name, { "transform": t });
    }
    function setPosition(name, x, y) {
        root._update(name, { "x": Math.round(x), "y": Math.round(y) });
    }
    function setVrr(name, on) {
        root._update(name, { "vrr": on });
    }
    function setColorMode(name, cm) {
        root._update(name, { "cm": cm });
    }
    function setPrimary(name) {
        SettingsService.set("primaryDisplay", name);
    }
    function setConfigMode(mode) {
        root.configMode = mode;
    }

    // Alle Entwürfe verwerfen
    function cancel() {
        const next = {};
        for (const o of outputs)
            next[o.name] = root._fromOutput(o);
        root.draft = next;
        root.configMode = _appliedMode;
    }

    // ───────────────────────── Geometrie ─────────────────────────

    function _modeParts(mode) {
        const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)/);
        return m ? { "w": +m[1], "h": +m[2], "refresh": +m[3] } : { "w": 0, "h": 0, "refresh": 0 };
    }
    function _trim(n) {
        return String(Math.round(n * 100) / 100);
    }
    function modeOf(mode) {
        return mode.w + "x" + mode.h + "@" + root._trim(mode.refresh);
    }

    // Logische Breite/Höhe (physisch/Skalierung, bei 90°/270° getauscht) – wie GNOME get_scaled_geometry
    function logicalWidth(output) {
        const d = root._d(output);
        const p = root._modeParts(d.mode);
        return Math.round(((d.transform % 2 === 1) ? p.h : p.w) / d.scale);
    }
    function logicalHeight(output) {
        const d = root._d(output);
        const p = root._modeParts(d.mode);
        return Math.round(((d.transform % 2 === 1) ? p.w : p.h) / d.scale);
    }

    // ───────────────────────── Auswahllisten (wie CcDisplaySettings) ─────────────────────────

    function resolutionOptions(output) {
        const seen = {};
        const list = [];
        for (const m of output.modes) {
            const k = m.w + "x" + m.h;
            if (!seen[k]) {
                seen[k] = true;
                list.push({ "w": m.w, "h": m.h, "label": m.w + " × " + m.h });
            }
        }
        list.sort((a, b) => (b.w * b.h - a.w * a.h) || (b.w - a.w));
        return list;
    }

    function refreshOptions(output, w, h) {
        const seen = {};
        const list = [];
        for (const m of output.modes) {
            if (m.w !== w || m.h !== h)
                continue;
            const k = root._trim(m.refresh);
            if (!seen[k]) {
                seen[k] = true;
                list.push({ "refresh": m.refresh, "mode": root.modeOf(m), "label": m.refresh.toFixed(2) + " Hz" });
            }
        }
        list.sort((a, b) => b.refresh - a.refresh);
        return list;
    }

    // Unterstützte Skalierungen (Mutter-Algorithmus, meta-monitor.c)
    function scaleOptions(w, h) {
        const MAX_INTEGER_SCALE = 4;
        const MAX_DENOMINATOR = 4;
        const MINIMUM_LOGICAL_AREA = 600 * 600;
        const out = [];
        function gcd(a, b) {
            while (b > 0) {
                const t = a % b;
                a = b;
                b = t;
            }
            return a;
        }
        for (let den = 1; den <= MAX_DENOMINATOR; den++) {
            for (let num = den; num <= MAX_INTEGER_SCALE * den; num++) {
                if ((w * den) % num !== 0 || (h * den) % num !== 0)
                    continue;
                if (gcd(num, den) > 1)
                    continue;
                const scale = num / den;
                if (scale < 1 || scale > MAX_INTEGER_SCALE)
                    continue;
                if (Math.floor(w / scale) * Math.floor(h / scale) < MINIMUM_LOGICAL_AREA)
                    continue;
                if (!out.some(s => Math.abs(s - scale) < 1e-6))
                    out.push(scale);
            }
        }
        out.sort((a, b) => a - b);
        if (out.length === 0)
            out.push(1);
        return out;
    }
    function scaleLabel(scale) {
        return Math.round(scale * 100) + " %";
    }

    readonly property var orientationOptions: [
        { "transform": 0, "label": "Landscape" },
        { "transform": 1, "label": "Portrait Right" },
        { "transform": 3, "label": "Portrait Left" },
        { "transform": 2, "label": "Landscape (flipped)" }
    ]

    // ───────────────────────── Anwenden ─────────────────────────

    function _shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Lua-Feldliste eines Monitors
    function _luaFields(name, d, mirrorSrc) {
        const fields = ["output = " + JSON.stringify(name)];
        if (!d.enabled) {
            fields.push("disabled = true");
            return fields;
        }
        fields.push("mode = " + JSON.stringify(d.mode));
        fields.push("position = " + JSON.stringify(d.x + "x" + d.y));
        fields.push("scale = " + d.scale);
        fields.push("transform = " + d.transform);
        fields.push("vrr = " + (d.vrr ? 1 : 0));
        if (d.cm && d.cm !== "srgb")
            fields.push("cm = " + JSON.stringify(d.cm));
        if (mirrorSrc !== "" && mirrorSrc !== name)
            fields.push("mirror = " + JSON.stringify(mirrorSrc));
        return fields;
    }

    function _commands(entries, mode) {
        const active = entries.filter(e => e.d.enabled);
        const names = active.map(e => e.name);
        const src = names.indexOf(root.primaryName) >= 0 ? root.primaryName : (names[0] ?? "");
        const lines = [];
        for (const e of entries) {
            const name = e.name, d = e.d;
            if (root.usingLua) {
                const mirror = (mode === "mirror") ? src : "";
                lines.push("hyprctl eval " + root._shq("hl.monitor({ " + root._luaFields(name, d, mirror).join(", ") + " })"));
                continue;
            }
            if (!d.enabled) {
                lines.push("hyprctl keyword monitor " + root._shq(name + ",disable"));
                continue;
            }
            // Alles in EINER Regel: Hyprland liest nach der Skalierung Schlüssel/Wert-Paare
            let rule = name + "," + d.mode + "," + d.x + "x" + d.y + "," + d.scale;
            if (d.transform)
                rule += ",transform," + d.transform;
            if (d.vrr)
                rule += ",vrr,1";
            if (mode === "mirror" && src !== "" && name !== src)
                rule += ",mirror," + src;
            lines.push("hyprctl keyword monitor " + root._shq(rule));
        }
        return lines.join("\n");
    }

    function apply() {
        if (!available)
            return;
        // Zustand vor dem Anwenden merken (für „Zurücksetzen“ im Bestätigungsdialog)
        root._preApply = outputs.map(o => ({ "name": o.name, "d": root._fromOutput(o) }));
        root._preApplyMode = _appliedMode;
        const entries = outputs.map(o => ({ "name": o.name, "d": root._d(o) }));
        applyProcess.command = ["sh", "-c", root._commands(entries, root.configMode)];
        applyProcess.running = true;
        root._appliedMode = root.configMode;
        root.cancel();
        refreshTimer.restart();
    }

    property var _preApply: []
    property string _preApplyMode: "join"

    // Vorherigen Zustand wiederherstellen (Revert)
    function revertApply() {
        if (root._preApply.length === 0)
            return;
        applyProcess.command = ["sh", "-c", root._commands(root._preApply, root._preApplyMode)];
        applyProcess.running = true;
        root._appliedMode = root._preApplyMode;
        root.configMode = root._preApplyMode;
        refreshTimer.restart();
    }

    // Aktuelle Zuweisung in die Einstellungen schreiben (Persistenz)
    function save() {
        const map = {};
        for (const o of outputs) {
            const d = root._d(o);
            map[o.name] = { "enabled": d.enabled, "mode": d.mode, "x": d.x, "y": d.y, "scale": d.scale, "transform": d.transform, "vrr": d.vrr, "cm": d.cm };
        }
        SettingsService.set("displays", { "mode": root.configMode, "outputs": map });
    }

    // Gespeicherte Zuweisung anwenden (beim Start bzw. nach Neuladen der Hyprland-Konfiguration)
    function applySaved() {
        const saved = SettingsService.displays;
        const outs = saved && saved.outputs ? saved.outputs : null;
        if (!outs)
            return;
        const entries = outputs.filter(o => outs[o.name]).map(o => ({ "name": o.name, "d": outs[o.name] }));
        if (entries.length === 0)
            return;
        applyProcess.command = ["sh", "-c", root._commands(entries, saved.mode === "mirror" ? "mirror" : "join")];
        applyProcess.running = true;
        refreshTimer.restart();
    }

    Process {
        id: applyProcess
    }

    // ───────────────────────── Einlesen ─────────────────────────

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 350
        onTriggered: root.refresh()
    }

    Process {
        id: query
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root._ingest(JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    function _ingest(list) {
        const parsed = [];
        for (const m of list) {
            const modes = [];
            for (const s of (m.availableModes ?? [])) {
                const mm = String(s).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
                if (mm)
                    modes.push({ "w": +mm[1], "h": +mm[2], "refresh": +mm[3] });
            }
            parsed.push({
                "name": m.name,
                "description": m.description ?? "",
                "make": m.make ?? "",
                "model": m.model ?? "",
                "serial": m.serial ?? "",
                "enabled": !m.disabled,
                "focused": !!m.focused,
                "mirrorOf": (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : "",
                "x": m.x,
                "y": m.y,
                "width": m.width,
                "height": m.height,
                "refresh": m.refreshRate,
                "scale": m.scale || 1,
                "transform": m.transform || 0,
                "vrr": !!m.vrr,
                "cm": m.colorManagementPreset ?? "srgb",
                "physicalWidth": m.physicalWidth ?? 0,
                "physicalHeight": m.physicalHeight ?? 0,
                "modes": modes,
                "modeString": root._nearestMode(modes, m.width, m.height, m.refreshRate)
            });
        }
        // Anzeigenummern wie GNOME: von links nach rechts, dann von oben nach unten
        parsed.sort((a, b) => (a.x - b.x) || (a.y - b.y));
        parsed.forEach((o, i) => o.number = i + 1);

        // Nutzer-Entwurf bleibt erhalten, sonst aus dem gelesenen Zustand neu aufbauen
        if (root.dirty) {
            const next = root._clone(root.draft);
            for (const o of parsed)
                if (!next[o.name])
                    next[o.name] = root._fromOutput(o);
            root.outputs = parsed;
            root.draft = next;
        } else {
            root.outputs = parsed;
            root.cancel();
        }

        if (root.selected === "" || !parsed.some(o => o.name === root.selected))
            root.selected = (parsed.find(o => o.enabled) ?? parsed[0])?.name ?? "";

        root.loaded = true;
        if (!root._restored && !root.dirty) {
            root._restored = true;
            if (SettingsService.displays && SettingsService.displays.outputs && Object.keys(SettingsService.displays.outputs).length > 0)
                root.applySaved();
        }
    }

    function _nearestMode(modes, w, h, refresh) {
        let best = null;
        let bestErr = Infinity;
        for (const m of modes) {
            if (m.w !== w || m.h !== h)
                continue;
            const err = Math.abs(m.refresh - refresh);
            if (err < bestErr) {
                bestErr = err;
                best = m;
            }
        }
        if (!best && modes.length > 0)
            best = modes[0];
        return best ? root.modeOf(best) : "";
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (["monitoradded", "monitorremoved", "monitoraddedv2", "configreloaded"].indexOf(e.name) >= 0) {
                // Hyprland setzt Monitore dabei auf die Regeln der Konfiguration zurück
                if (e.name === "configreloaded" || e.name.startsWith("monitoradded"))
                    root._restored = false;
                refreshTimer.restart();
            }
        }
    }
}
