import Quickshell
import Quickshell.Io
import QtQuick

// Root of Narla's gruvbox shell: wallpaper + bar + launcher.
// Toggle the launcher from Hyprland with:  quickshell ipc call launcher toggle
ShellRoot {
    id: root

    property bool launcherOpen: false
    property bool wifiOpen: false
    property bool audioOpen: false
    property bool menuOpen: false

    function closeAllBut(which) {
        launcherOpen = which === "launcher";
        wifiOpen = which === "wifi";
        audioOpen = which === "audio";
        menuOpen = which === "menu";
    }

    Wallpaper {}

    Bar {
        shell: root
    }

    Launcher {
        shell: root
    }

    WifiPanel {
        shell: root
    }

    AudioPanel {
        shell: root
    }

    SystemMenu {
        shell: root
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.closeAllBut(root.launcherOpen ? "" : "launcher");
        }

        function open() {
            root.closeAllBut("launcher");
        }

        function close() {
            root.launcherOpen = false;
        }
    }

    IpcHandler {
        target: "bar"

        function wifi() {
            root.closeAllBut(root.wifiOpen ? "" : "wifi");
        }

        function audio() {
            root.closeAllBut(root.audioOpen ? "" : "audio");
        }

        function close() {
            root.closeAllBut("");
        }
    }

    IpcHandler {
        target: "menu"

        function toggle() {
            root.closeAllBut(root.menuOpen ? "" : "menu");
        }

        function close() {
            root.menuOpen = false;
        }
    }
}
