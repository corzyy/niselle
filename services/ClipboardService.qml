pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool installed: false
    readonly property bool available: installed
    readonly property bool enabled: installed && SettingsService.clipboardHistory

    property var entries: []
    property var thumbs: ({})

    readonly property string cacheDir: Quickshell.cachePath("clipboard")
    property bool ffmpeg: false

    function refresh() {
        if (root.enabled && !list.running)
            list.running = true;
    }

    function copy(entry) {
        if (!entry)
            return;
        const type = entry.kind === "files" ? "text/uri-list" : entry.mime;
        if (type)
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy --type "$2"', "sh", entry.id, type]);
        else
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id]);
    }

    function remove(entry) {
        if (!entry)
            return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", entry.id]);
        root.entries = root.entries.filter(e => e.id !== entry.id);
    }


    property bool popupOpen: false
    property string popupScreen: ""
    property point popupPoint: Qt.point(0, 0)

    function showPopup() {
        if (!root.enabled)
            return;
        root.refresh();
        cursor.running = true;
    }
    function closePopup() {
        root.popupOpen = false;
    }
    function togglePopup() {
        if (root.popupOpen)
            root.closePopup();
        else
            root.showPopup();
    }

    Process {
        id: cursor
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                let pos = {
                    "x": 0,
                    "y": 0
                };
                try {
                    pos = JSON.parse(text);
                } catch (e) {}
                const screens = Quickshell.screens;
                const s = screens.find(m => pos.x >= m.x && pos.x < m.x + m.width && pos.y >= m.y && pos.y < m.y + m.height) ?? screens[0];
                if (!s)
                    return;
                root.popupScreen = s.name;
                root.popupPoint = Qt.point(pos.x - s.x, pos.y - s.y);
                root.popupOpen = true;
            }
        }
    }

    IpcHandler {
        target: "clipboard"

        function show(): void {
            root.showPopup();
        }
        function toggle(): void {
            root.togglePopup();
        }
        function close(): void {
            root.closePopup();
        }
    }

    function clear() {
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf -- "$1"', "sh", root.cacheDir]);
        root.entries = [];
        root.thumbs = ({});
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null && echo yes; true"]
        stdout: StdioCollector {
            onStreamFinished: root.installed = text.trim() === "yes"
        }
    }

    Process {
        running: root.enabled
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
    }
    Process {
        running: root.enabled
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }

    readonly property var imageExt: ({
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "webp": "image/webp",
            "bmp": "image/bmp",
            "svg": "image/svg+xml"
        })
    readonly property var videoExt: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "ogv"]
    readonly property var audioExt: ["mp3", "flac", "ogg", "opus", "wav", "m4a"]

    function _basename(path) {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    function _parse(id, preview) {
        const meta = /^\[\[ binary data (.*) \]\]$/.exec(preview);
        if (meta) {
            const parts = meta[1].split(" ");
            const fmt = (parts[2] ?? "").toLowerCase();
            return {
                "id": id,
                "text": preview,
                "kind": "image",
                "image": true,
                "label": "Image",
                "meta": meta[1],
                "icon": "image-x-generic-symbolic",
                "mime": fmt === "" ? "" : "image/" + (fmt === "jpg" ? "jpeg" : fmt),
                "preview": "image"
            };
        }
        return {
            "id": id,
            "text": preview,
            "kind": "text",
            "image": false,
            "label": preview.replace(/\s+/g, " ").trim(),
            "meta": "",
            "icon": "edit-paste-symbolic",
            "mime": "",
            "preview": ""
        };
    }

    function _files(entry) {
        const urls = entry.text.split(/\s+/).filter(u => u.indexOf("file://") === 0);
        if (urls.length === 0 || urls.join(" ") !== entry.text.trim().split(/\s+/).join(" "))
            return null;
        const paths = urls.map(u => {
            try {
                return decodeURIComponent(u.slice(7));
            } catch (e) {
                return u.slice(7);
            }
        });
        const first = paths[0];
        const ext = first.indexOf(".") >= 0 ? first.slice(first.lastIndexOf(".") + 1).toLowerCase() : "";
        let preview = "";
        let icon = first.endsWith("/") ? "folder-symbolic" : "text-x-generic-symbolic";
        if (root.imageExt[ext]) {
            preview = "image";
            icon = "image-x-generic-symbolic";
        } else if (root.videoExt.indexOf(ext) >= 0) {
            preview = root.ffmpeg ? "video" : "";
            icon = "video-x-generic-symbolic";
        } else if (root.audioExt.indexOf(ext) >= 0) {
            icon = "audio-x-generic-symbolic";
        }
        return {
            "kind": "files",
            "label": root._basename(first.replace(/\/$/, "")) + (paths.length > 1 ? "  +" + (paths.length - 1) + " more" : ""),
            "meta": paths.length > 1 ? paths.length + " files" : (first.slice(0, first.lastIndexOf("/")) || "/"),
            "icon": icon,
            "preview": paths.length === 1 ? preview : "",
            "path": first
        };
    }

    Process {
        id: thumbJob
        stdout: StdioCollector {
            onStreamFinished: {
                const map = Object.assign({}, root.thumbs);
                for (const line of text.split("\n")) {
                    const bar = line.indexOf("|");
                    if (bar > 0)
                        map[line.slice(0, bar)] = line.slice(bar + 1);
                }
                root.thumbs = map;
            }
        }
    }

    function _makeThumbs(list) {
        const jobs = [];
        const ready = Object.assign({}, root.thumbs);
        for (const e of list) {
            if (e.preview === "" || jobs.length >= 60)
                continue;
            if (e.kind === "files" && e.preview === "image") {
                ready[e.id] = "file://" + encodeURI(e.path).replace(/#/g, "%23");
                continue;
            }
            jobs.push(e.id + "|" + e.preview + "|" + (e.path ?? ""));
        }
        root.thumbs = ready;
        if (jobs.length === 0 && !thumbJob.running)
            return;
        thumbJob.running = false;
        thumbJob.command = ["sh", "-c", `dir="$1"; shift
mkdir -p "$dir"
keep=" "
for job in "$@"; do
    id=\${job%%|*}; rest=\${job#*|}; kind=\${rest%%|*}; src=\${rest#*|}
    keep="$keep$id "
    case $kind in
        image) out="$dir/$id.img"; [ -s "$out" ] || cliphist decode "$id" > "$out" 2>/dev/null ;;
        video) out="$dir/$id.jpg"; [ -s "$out" ] || ffmpeg -nostdin -loglevel error -ss 1 -i "$src" -frames:v 1 -vf scale=320:-2 -y "$out" 2>/dev/null ;;
    esac
    [ -s "$out" ] && printf '%s|file://%s\n' "$id" "$out"
done
for f in "$dir"/*; do
    [ -e "$f" ] || continue
    b=\${f##*/}; b=\${b%.*}
    case "$keep" in *" $b "*) ;; *) rm -f "$f" ;; esac
done`, "sh", root.cacheDir].concat(jobs);
        thumbJob.running = true;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v ffmpeg >/dev/null && echo yes; true"]
        stdout: StdioCollector {
            onStreamFinished: root.ffmpeg = text.trim() === "yes"
        }
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const entry = root._parse(line.slice(0, tab), line.slice(tab + 1));
                    if (entry.kind === "text") {
                        const f = root._files(entry);
                        if (f)
                            Object.assign(entry, f);
                    }
                    out.push(entry);
                    if (out.length >= 200)
                        break;
                }
                root.entries = out;
                root._makeThumbs(out);
            }
        }
    }
}
