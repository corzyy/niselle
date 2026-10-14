pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property bool available: Hyprland.monitors.values.length > 0
    readonly property bool usingLua: Hyprland.usingLua

    readonly property var categories: [
        {
            "title": "Niselle",
            "groups": [
                {
                    "title": "Shell",
                    "entries": [
                        {
                            "id": "overview",
                            "title": "Toggle Overview",
                            "keys": "SUPER"
                        },
                        {
                            "id": "restart",
                            "title": "Restart Niselle",
                            "keys": "SUPER + F",
                            "action": "hl.dsp.exec_cmd(\"~/.local/bin/niselle restart 2>/dev/null || niselle restart\")"
                        },
                        {
                            "id": "clipboard",
                            "title": "Clipboard History",
                            "keys": "SUPER + V",
                            "action": "hl.dsp.exec_cmd(\"niselle clipboard\")"
                        },
                        {
                            "id": "appGrid",
                            "title": "Show App Grid",
                            "keys": "SUPER + A",
                            "action": "hl.dsp.exec_cmd(\"niselle apps\")"
                        },
                        {
                            "id": "lockScreen",
                            "title": "Lock Screen",
                            "keys": "SUPER + L",
                            "action": "hl.dsp.exec_cmd(\"niselle lock\")"
                        },
                        {
                            "id": "locks",
                            "title": "Show Lock Key Status",
                            "keys": "Caps_Lock",
                            "alt": "Num_Lock"
                        }
                    ]
                }
            ]
        },
        {
            "title": "Hyprland",
            "groups": [
                {
                    "title": "Applications",
                    "entries": [
                        {
                            "id": "terminal",
                            "title": "Terminal",
                            "keys": "SUPER + T",
                            "action": "hl.dsp.exec_cmd(programs.terminal)"
                        },
                        {
                            "id": "files",
                            "title": "Files",
                            "keys": "SUPER + E",
                            "action": "hl.dsp.exec_cmd(programs.fileManager)"
                        },
                        {
                            "id": "browser",
                            "title": "Web Browser",
                            "keys": "SUPER + B",
                            "action": "hl.dsp.exec_cmd(programs.browser)"
                        }
                    ]
                },
                {
                    "title": "Windows",
                    "entries": [
                        {
                            "id": "close",
                            "title": "Close Window",
                            "keys": "SUPER + W",
                            "action": "hl.dsp.window.close()"
                        },
                        {
                            "id": "float",
                            "title": "Toggle Floating",
                            "keys": "SUPER + R",
                            "action": "hl.dsp.window.float({ action = \"toggle\" })"
                        },
                        {
                            "id": "focusLeft",
                            "title": "Focus Left",
                            "keys": "SUPER + left",
                            "action": "hl.dsp.focus({ direction = \"left\" })"
                        },
                        {
                            "id": "focusRight",
                            "title": "Focus Right",
                            "keys": "SUPER + right",
                            "action": "hl.dsp.focus({ direction = \"right\" })"
                        },
                        {
                            "id": "focusUp",
                            "title": "Focus Up",
                            "keys": "SUPER + up",
                            "action": "hl.dsp.focus({ direction = \"up\" })"
                        },
                        {
                            "id": "focusDown",
                            "title": "Focus Down",
                            "keys": "SUPER + down",
                            "action": "hl.dsp.focus({ direction = \"down\" })"
                        },
                        {
                            "id": "move",
                            "title": "Move Window",
                            "keys": "SUPER + mouse:272"
                        },
                        {
                            "id": "resize",
                            "title": "Resize Window",
                            "keys": "SUPER + mouse:273"
                        }
                    ]
                },
                {
                    "title": "Workspaces",
                    "entries": [
                        {
                            "id": "wsSwitch",
                            "title": "Switch to Workspace 1–10",
                            "keys": "SUPER + 1…0"
                        },
                        {
                            "id": "wsMove",
                            "title": "Move Window to Workspace 1–10",
                            "keys": "SUPER + SHIFT + 1…0"
                        },
                        {
                            "id": "wsNext",
                            "title": "Next Workspace",
                            "keys": "SUPER + mouse_down"
                        },
                        {
                            "id": "wsPrev",
                            "title": "Previous Workspace",
                            "keys": "SUPER + mouse_up"
                        }
                    ]
                },
                {
                    "title": "Volume & Brightness",
                    "entries": [
                        {
                            "id": "volUp",
                            "title": "Volume Up",
                            "keys": "XF86AudioRaiseVolume",
                            "action": "hl.dsp.exec_cmd(\"wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+\")",
                            "opts": "{ locked = true, repeating = true }"
                        },
                        {
                            "id": "volDown",
                            "title": "Volume Down",
                            "keys": "XF86AudioLowerVolume",
                            "action": "hl.dsp.exec_cmd(\"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-\")",
                            "opts": "{ locked = true, repeating = true }"
                        },
                        {
                            "id": "mute",
                            "title": "Mute",
                            "keys": "XF86AudioMute",
                            "action": "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")",
                            "opts": "{ locked = true, repeating = true }"
                        },
                        {
                            "id": "micMute",
                            "title": "Mute Microphone",
                            "keys": "XF86AudioMicMute",
                            "action": "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")",
                            "opts": "{ locked = true, repeating = true }"
                        },
                        {
                            "id": "brightUp",
                            "title": "Brightness Up",
                            "keys": "XF86MonBrightnessUp",
                            "action": "hl.dsp.exec_cmd(\"brightnessctl -e4 -n2 set 5%+\")",
                            "opts": "{ locked = true, repeating = true }"
                        },
                        {
                            "id": "brightDown",
                            "title": "Brightness Down",
                            "keys": "XF86MonBrightnessDown",
                            "action": "hl.dsp.exec_cmd(\"brightnessctl -e4 -n2 set 5%-\")",
                            "opts": "{ locked = true, repeating = true }"
                        }
                    ]
                },
                {
                    "title": "Media",
                    "entries": [
                        {
                            "id": "playPause",
                            "title": "Play / Pause",
                            "keys": "XF86AudioPlay",
                            "action": "hl.dsp.exec_cmd(\"playerctl play-pause\")",
                            "opts": "{ locked = true }"
                        },
                        {
                            "id": "next",
                            "title": "Next Track",
                            "keys": "XF86AudioNext",
                            "action": "hl.dsp.exec_cmd(\"playerctl next\")",
                            "opts": "{ locked = true }"
                        },
                        {
                            "id": "prev",
                            "title": "Previous Track",
                            "keys": "XF86AudioPrev",
                            "action": "hl.dsp.exec_cmd(\"playerctl previous\")",
                            "opts": "{ locked = true }"
                        }
                    ]
                },
                {
                    "title": "Screenshots",
                    "entries": [
                        {
                            "id": "shotRegion",
                            "title": "Screenshot UI",
                            "keys": "Print",
                            "action": "hl.dsp.exec_cmd(\"niselle screenshot\")"
                        },
                        {
                            "id": "shotWindow",
                            "title": "Screenshot Window",
                            "keys": "SHIFT + Print",
                            "action": "hl.dsp.exec_cmd(\"hyprshot -m window -o \\\"$(xdg-user-dir PICTURES)\\\"\")"
                        },
                        {
                            "id": "shotScreen",
                            "title": "Screenshot Screen",
                            "keys": "SUPER + Print",
                            "action": "hl.dsp.exec_cmd(\"hyprshot -m output -o \\\"$(xdg-user-dir PICTURES)\\\"\")"
                        },
                        {
                            "id": "recordUi",
                            "title": "Screen Recording UI",
                            "keys": "CTRL + SHIFT + ALT + R",
                            "action": "hl.dsp.exec_cmd(\"niselle screenshot record\")"
                        }
                    ]
                }
            ]
        }
    ]

    readonly property var entries: {
        const m = {};
        for (const c of categories)
            for (const g of c.groups)
                for (const e of g.entries)
                    m[e.id] = e;
        return m;
    }

    readonly property var overrides: store.overrides ?? ({})
    readonly property bool anyOverride: Object.keys(overrides).length > 0

    function editable(id) {
        return root.entries[id]?.action !== undefined;
    }

    function customized(id) {
        return root.overrides[id] !== undefined;
    }

    function combo(id) {
        return root.overrides[id] ?? root.entries[id]?.keys ?? "";
    }

    function normalize(combo) {
        const parts = combo.split("+").map(p => p.trim()).filter(p => p);
        if (parts.length === 0)
            return "";
        const key = parts.pop().toLowerCase();
        return parts.map(p => p.toUpperCase()).sort().concat([key]).join("+");
    }

    function conflict(id, combo) {
        const n = root.normalize(combo);
        if (n === "")
            return "";
        for (const other of Object.keys(root.entries)) {
            if (other === id)
                continue;
            const e = root.entries[other];
            if (root.normalize(root.combo(other)) === n || (e.alt && !root.customized(other) && root.normalize(e.alt) === n))
                return e.title;
        }
        return "";
    }

    function conflictId(id, combo) {
        const n = root.normalize(combo);
        for (const other of Object.keys(root.entries))
            if (other !== id && n !== "" && root.normalize(root.combo(other)) === n)
                return other;
        return "";
    }

    function set(id, combo) {
        const e = root.entries[id];
        if (!e || !e.action)
            return;
        const other = root.conflictId(id, combo);
        const next = Object.assign({}, root.overrides);
        if (other !== "" && root.editable(other))
            next[other] = "";
        if (normalize(combo) === normalize(e.keys))
            delete next[id];
        else
            next[id] = combo;
        root._commit(next);
    }

    function reset(id) {
        if (!root.customized(id) || !root.editable(id))
            return;
        const next = Object.assign({}, root.overrides);
        delete next[id];
        root._commit(next);
    }

    function resetAll() {
        root._commit({});
    }


    readonly property var keyLabels: ({
            "SUPER": "Super",
            "CTRL": "Ctrl",
            "ALT": "Alt",
            "SHIFT": "Shift",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "space": "Space",
            "grave": "`",
            "mouse:272": "Left Mouse Button",
            "mouse:273": "Right Mouse Button",
            "mouse_down": "Scroll Down",
            "mouse_up": "Scroll Up",
            "Caps_Lock": "Caps Lock",
            "Num_Lock": "Num Lock",
            "XF86AudioRaiseVolume": "Volume Up",
            "XF86AudioLowerVolume": "Volume Down",
            "XF86AudioMute": "Mute",
            "XF86AudioMicMute": "Mic Mute",
            "XF86MonBrightnessUp": "Brightness Up",
            "XF86MonBrightnessDown": "Brightness Down",
            "XF86AudioPlay": "Play",
            "XF86AudioPause": "Pause",
            "XF86AudioNext": "Next",
            "XF86AudioPrev": "Previous"
        })

    function labels(combo) {
        return combo.split("+").map(p => p.trim()).filter(p => p).map(p => {
            if (root.keyLabels[p])
                return root.keyLabels[p];
            if (p.indexOf("code:") === 0)
                return "Key " + p.slice(5);
            return p.length === 1 ? p.toUpperCase() : p;
        });
    }


    readonly property var specialKeys: ({
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_Return]: "Return",
            [Qt.Key_Enter]: "Return",
            [Qt.Key_Space]: "space",
            [Qt.Key_Tab]: "Tab",
            [Qt.Key_Print]: "Print",
            [Qt.Key_Home]: "Home",
            [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Prior",
            [Qt.Key_PageDown]: "Next",
            [Qt.Key_Insert]: "Insert",
            [Qt.Key_Delete]: "Delete",
            [Qt.Key_Comma]: "comma",
            [Qt.Key_Period]: "period",
            [Qt.Key_Minus]: "minus",
            [Qt.Key_Equal]: "equal",
            [Qt.Key_Slash]: "slash",
            [Qt.Key_Semicolon]: "semicolon",
            [Qt.Key_Apostrophe]: "apostrophe",
            [Qt.Key_BracketLeft]: "bracketleft",
            [Qt.Key_BracketRight]: "bracketright",
            [Qt.Key_Backslash]: "backslash",
            [Qt.Key_QuoteLeft]: "grave",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume",
            [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute",
            [Qt.Key_MicMute]: "XF86AudioMicMute",
            [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
            [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
            [Qt.Key_MediaPlay]: "XF86AudioPlay",
            [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
            [Qt.Key_MediaPause]: "XF86AudioPause",
            [Qt.Key_MediaNext]: "XF86AudioNext",
            [Qt.Key_MediaPrevious]: "XF86AudioPrev"
        })

    function fromEvent(key, modifiers, scanCode) {
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock].indexOf(key) >= 0)
            return "";
        let name = root.specialKeys[key] ?? "";
        if (name === "") {
            if (key >= Qt.Key_A && key <= Qt.Key_Z)
                name = String.fromCharCode(key);
            else if (key >= Qt.Key_0 && key <= Qt.Key_9)
                name = String.fromCharCode(key);
            else if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
                name = "F" + (key - Qt.Key_F1 + 1);
            else if (scanCode > 0)
                name = "code:" + scanCode;
            else
                return "";
        }
        const mods = [];
        if (modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        return mods.concat([name]).join(" + ");
    }

    function usable(combo) {
        const parts = combo.split("+").map(p => p.trim());
        if (parts.length > 1)
            return true;
        return /^(F\d+|Print|Insert|Delete|Home|End|Prior|Next|XF86.*)$/.test(parts[0]);
    }

    function captureBegin() {
        captureGuard.restart();
        root._run("hl.define_submap(\"niselle_capture\", \"reset\", function() hl.bind(\"SUPER + SUPER_L + F24\", hl.dsp.exec_cmd(\"true\")) end)\nhl.dispatch(hl.dsp.submap(\"niselle_capture\"))");
    }

    function captureEnd() {
        captureGuard.stop();
        root._run("hl.dispatch(hl.dsp.submap(\"reset\"))");
    }


    function _bind(e, combo) {
        return "hl.bind(" + JSON.stringify(combo) + ", " + e.action + (e.opts ? ", " + e.opts : "") + ")";
    }

    function _run(script) {
        if (!root.usingLua)
            return;
        runner.queue.push(script);
        if (!runner.running)
            runner._next();
    }

    function _commit(next) {
        store.overrides = next;
        luaFile.setText(root._generate(next));
    }

    function _generate(overrides) {
        const lines = ["-- Generated by Niselle (Settings → Keyboard). Do not edit; use the settings page.", "local programs = require(\"configs/programs\")", ""];
        for (const id of Object.keys(overrides)) {
            const e = root.entries[id];
            if (!e?.action)
                continue;
            lines.push("hl.unbind(" + JSON.stringify(e.keys) + ")");
        }
        for (const id of Object.keys(overrides)) {
            const e = root.entries[id];
            if (e?.action && overrides[id] !== "")
                lines.push(root._bind(e, overrides[id]));
        }
        lines.push("", "return {}", "");
        return lines.join("\n");
    }

    Timer {
        id: captureGuard
        interval: 30000
        onTriggered: root.captureEnd()
    }

    Process {
        id: runner

        property var queue: []

        function _next() {
            if (queue.length === 0)
                return;
            command = ["hyprctl", "eval", queue.shift()];
            running = true;
        }

        onRunningChanged: if (!running)
            _next()
    }


    Process {
        id: reloader
        command: ["hyprctl", "reload"]
    }

    FileView {
        id: luaFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/niselle-keybinds.lua"
        onSaved: reloader.running = true
    }

    FileView {
        path: Quickshell.statePath("keybinds.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => writeAdapter()

        adapter: JsonAdapter {
            id: store
            property var overrides: ({})
        }
    }
}
