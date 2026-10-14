pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    property string state: "idle"
    readonly property bool running: state === "running"
    property var entries: []
    property string summary: ""

    function start() {
        if (running)
            return;
        entries = [];
        summary = "";
        state = "running";
        open = true;
        proc.running = true;
    }

    function close() {
        if (!running)
            open = false;
    }

    function _add(kind, text) {
        entries = entries.concat([
            {
                "kind": kind,
                "text": text
            }
        ]);
        if (kind === "done")
            summary = text;
    }

    Process {
        id: proc
        command: [Quickshell.shellPath("bin/niselle-matugen-install")]

        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("|");
                if (i > 0)
                    root._add(line.slice(0, i), line.slice(i + 1));
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "")
                    root._add("error", line.trim());
            }
        }
        onExited: code => {
            if (code === 0) {
                root.state = "done";
                MatugenService.regenerate();
            } else {
                root.state = "failed";
                if (root.summary === "")
                    root.summary = "Installation failed";
            }
        }
    }
}
