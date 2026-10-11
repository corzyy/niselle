pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Standardanwendungen je Kategorie (Web, Mail, …). Abfrage über `gio mime` (Standard und passende Anwendungen),
// Setzen über `xdg-mime default` für alle MIME-Typen der Kategorie (schreibt ~/.config/mimeapps.list).
Singleton {
    id: root

    // mimes[0] wird abgefragt, `xdg-mime default` setzt alle
    readonly property var categories: [
        {
            "id": "web",
            "title": "Web",
            "icon": "web-browser-symbolic",
            "mimes": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"]
        },
        {
            "id": "mail",
            "title": "Mail",
            "icon": "mail-unread-symbolic",
            "mimes": ["x-scheme-handler/mailto"]
        },
        {
            "id": "calendar",
            "title": "Calendar",
            "icon": "x-office-calendar-symbolic",
            "mimes": ["text/calendar"]
        },
        {
            "id": "files",
            "title": "File Manager",
            "icon": "folder-symbolic",
            "mimes": ["inode/directory"]
        },
        {
            "id": "text",
            "title": "Text Editor",
            "icon": "text-editor-symbolic",
            "mimes": ["text/plain"]
        },
        {
            "id": "documents",
            "title": "Documents",
            "icon": "x-office-document-symbolic",
            "mimes": ["application/pdf"]
        },
        {
            "id": "music",
            "title": "Music",
            "icon": "audio-x-generic-symbolic",
            "mimes": ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"]
        },
        {
            "id": "video",
            "title": "Video",
            "icon": "video-x-generic-symbolic",
            "mimes": ["video/mp4", "video/x-matroska", "video/webm"]
        },
        {
            "id": "photos",
            "title": "Photos",
            "icon": "image-x-generic-symbolic",
            "mimes": ["image/jpeg", "image/png", "image/webp", "image/gif"]
        }
    ]

    // { [categoryId]: { current: Desktop-ID oder "", candidates: [Desktop-ID] } }
    property var state: ({})

    function currentId(category) {
        return root.state[category.id]?.current ?? "";
    }
    function candidates(category) {
        return root.state[category.id]?.candidates ?? [];
    }

    function setDefault(category, desktopId) {
        setter.command = ["xdg-mime", "default", desktopId].concat(category.mimes);
        setter.running = true;
    }

    function refresh() {
        if (query.running)
            return;
        // Pro Kategorie ein Block „## id“, danach die Ausgabe von gio (LC_ALL=C: feste Überschriften)
        const script = root.categories.map(c => `echo "## ${c.id}"; LC_ALL=C gio mime ${c.mimes[0]} 2>/dev/null`).join("; ");
        query.command = ["sh", "-c", script];
        query.running = true;
    }

    function _parse(text) {
        const out = {};
        let cur = null;
        let section = "";
        for (const line of text.split("\n")) {
            if (line.startsWith("## ")) {
                cur = out[line.slice(3)] = {
                    "current": "",
                    "candidates": []
                };
                section = "";
            } else if (!cur) {
                continue;
            } else if (line.startsWith("Default application for")) {
                cur.current = line.slice(line.lastIndexOf(": ") + 2).trim();
            } else if (line.startsWith("Registered applications:")) {
                section = "registered";
            } else if (line.startsWith("Recommended applications:")) {
                section = "recommended";
            } else if (line.startsWith("\t") && section !== "") {
                const id = line.trim();
                if (id.endsWith(".desktop") && cur.candidates.indexOf(id) < 0)
                    cur.candidates.push(id);
            }
        }
        // Der Standard gehört immer zur Auswahl
        for (const k in out)
            if (out[k].current && out[k].candidates.indexOf(out[k].current) < 0)
                out[k].candidates.unshift(out[k].current);
        return out;
    }

    Component.onCompleted: refresh()

    Process {
        id: query
        stdout: StdioCollector {
            onStreamFinished: root.state = root._parse(text)
        }
    }

    Process {
        id: setter
        onExited: root.refresh()
    }
}
