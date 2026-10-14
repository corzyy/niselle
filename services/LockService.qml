pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs

Singleton {
    id: root

    readonly property bool debug: Quickshell.env("NISELLE_LOCK_DEBUG") === "1"

    property bool locked: false
    property bool dialogShown: false
    property string password: ""
    readonly property bool busy: pam.active
    property string errorMessage: ""
    property int failures: 0

    readonly property string userName: Quickshell.env("USER") || ""
    property string realName: ""

    function lock() {
        if (root.locked)
            return;
        root.password = "";
        root.errorMessage = "";
        root.dialogShown = false;
        root.locked = true;
        Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetLockedHint", "b", "true"]);
    }

    function _unlocked() {
        root.locked = false;
        root.dialogShown = false;
        root.password = "";
        root.errorMessage = "";
        Quickshell.execDetached(["busctl", "--system", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetLockedHint", "b", "false"]);
    }

    function showDialog() {
        root.dialogShown = true;
    }
    function showCurtain() {
        if (pam.active)
            pam.abort();
        root.dialogShown = false;
        root.password = "";
        root.errorMessage = "";
    }

    function submit() {
        if (pam.active || root.password === "")
            return;
        root.errorMessage = "";
        pam.pending = root.password;
        pam.start();
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function dialog(): void {
            if (root.locked)
                root.showDialog();
        }
        function unlock(): void {
            if (root.debug)
                root._unlocked();
        }
    }

    PamContext {
        id: pam

        property string pending: ""

        config: "login"
        user: root.userName

        onResponseRequiredChanged: {
            if (responseRequired && pending !== "") {
                const pw = pending;
                pending = "";
                respond(pw);
            }
        }
        onCompleted: result => {
            pending = "";
            if (result === PamResult.Success) {
                root._unlocked();
            } else {
                root.password = "";
                root.errorMessage = "Sorry, that didn’t work. Please try again.";
                root.failures++;
            }
        }
        onError: {
            pending = "";
            root.password = "";
            root.errorMessage = "Authentication is unavailable.";
            root.failures++;
        }
    }

    Process {
        running: true
        command: ["stdbuf", "-oL", "dbus-monitor", "--system", "type='signal',interface='org.freedesktop.login1.Session',member='Lock'"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("member=Lock") >= 0)
                    root.lock();
            }
        }
    }

    Process {
        running: root.userName !== ""
        command: ["getent", "passwd", root.userName]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0].trim();
                root.realName = gecos;
            }
        }
    }
}
