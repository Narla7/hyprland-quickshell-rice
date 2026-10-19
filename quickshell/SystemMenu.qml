import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// System menu (mod+esc): logout / reboot / power off / suspend.
PanelWindow {
    id: menu

    property var shell

    readonly property Miasma pal: Miasma {}
    readonly property var entries: [
        { label: "logout", cmd: ["hyprctl", "dispatch", "exit"] },
        { label: "reboot", cmd: ["systemctl", "reboot"] },
        { label: "power off", cmd: ["systemctl", "poweroff"] },
        { label: "suspend", cmd: ["systemctl", "suspend"] }
    ]

    visible: shell.menuOpen
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Process {
        id: action
        command: ["true"]
        onRunningChanged: if (!running)
            menu.shell.closeAllBut("")
    }

    // dimmer + click-outside closes
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.1, 0.1, 0.1, 0.5)

        MouseArea {
            anchors.fill: parent
            onClicked: menu.shell.closeAllBut("")
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 240
        implicitHeight: col.implicitHeight + 24
        radius: 12
        color: menu.pal.bg1
        border.width: 1
        border.color: menu.pal.bg2

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Text {
                text: "system"
                color: menu.pal.fg
                font.family: menu.pal.font
                font.pixelSize: 12
                font.bold: true
                leftPadding: 4
                bottomPadding: 2
            }

            Repeater {
                model: menu.entries

                delegate: Rectangle {
                    required property var modelData
                    width: col.width
                    height: 30
                    radius: 6
                    color: rowMouse.containsMouse ? menu.pal.bg2 : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: rowMouse.containsMouse ? menu.pal.bright : menu.pal.fg
                        font.family: menu.pal.font
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            action.command = modelData.cmd;
                            action.running = true;
                        }
                    }
                }
            }

            Item {
                height: 1
                width: 1
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.shell.closeAllBut("")
    }
}