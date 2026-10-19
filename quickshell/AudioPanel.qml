import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Sound panel: volume slider + mute + output device list.
// Everything via wpctl (quickshell's pipewire node binding is broken in 0.3.1).
PanelWindow {
    id: panel

    property var shell

    readonly property Miasma pal: Miasma {}
    property int volPercent: 0
    property bool mutedFlag: false
    property var sinkList: []

    function setVolume(pct) {
        volSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.max(0, Math.min(100, pct)).toFixed(0) + "%"];
        volSet.running = false;
        volSet.running = true;
        afterSet.restart();
    }

    function toggleMute() {
        muteProc.running = true;
        afterSet.restart();
    }

    function makeDefault(id) {
        defaultProc.command = ["wpctl", "set-default", String(id)];
        defaultProc.running = true;
        statusProc.running = true;
    }

    function parseStatus(text) {
        var lines = String(text).split("\n");
        var out = [];
        var section = "";
        for (var i = 0; i < lines.length; i++) {
            var t = lines[i];
            if (t.indexOf("Sinks:") >= 0) {
                section = "sinks";
                continue;
            }
            if (t.indexOf("Sources:") >= 0) {
                section = "sources";
                continue;
            }
            if (t.indexOf("Control:") >= 0 || t.indexOf("Streams:") >= 0)
                section = "";
            if (section !== "sinks")
                continue;
            if (t.indexOf("│") < 0 && t.indexOf("└") < 0)
                continue;
            var m = t.match(/(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[[^\]]*\])?\s*$/);
            if (m) {
                out.push({
                    id: parseInt(m[2], 10),
                    name: m[3].trim(),
                    def: !!m[1]
                });
            }
        }
        panel.sinkList = out;
    }

    visible: shell.audioOpen
    anchors {
        top: true
        right: true
    }
    margins {
        top: pal.barHeight + 4
        right: 8
    }
    implicitWidth: 320
    implicitHeight: Math.min(440, col.implicitHeight + 24)
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-audio"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (visible) {
            volProbe.running = true;
            statusProc.running = true;
        }
    }

    // ---- wpctl plumbing
    Process {
        id: volProbe
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: line => {
                var m = line.match(/Volume:\s*([\d.]+)/);
                if (m) {
                    panel.volPercent = Math.round(parseFloat(m[1]) * 100);
                    panel.mutedFlag = line.indexOf("MUTED") >= 0;
                }
            }
        }
    }

    Process {
        id: volSet
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "50%"]
    }

    Process {
        id: muteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    }

    Process {
        id: defaultProc
        command: ["wpctl", "set-default", "0"]
    }

    Process {
        id: statusProc
        command: ["wpctl", "status"]
        stdout: StdioCollector {
            id: statusCol
            waitForEnd: true
        }
        onRunningChanged: if (!running) panel.parseStatus(statusCol.text)
    }

    Timer {
        id: afterSet
        interval: 250
        repeat: false
        onTriggered: {
            volProbe.running = true;
            statusProc.running = true;
        }
    }

    Timer {
        id: audioRefresh
        interval: 5000
        repeat: true
        onTriggered: {
            volProbe.running = true;
            if (visible)
                statusProc.running = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: panel.pal.bg1
        radius: 10
        border.width: 1
        border.color: panel.pal.bg2

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: panel.shell.closeAllBut("")

            Column {
                id: col
                width: parent.width - 24
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "sound"
                        color: panel.pal.gold
                        font.family: panel.pal.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 70
                        text: {
                            var def = panel.sinkList.filter(s => s.def)[0];
                            return def ? def.name : "";
                        }
                        color: panel.pal.fg2
                        font.family: panel.pal.font
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        id: muteBtn
                        width: 30
                        height: 22
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: panel.mutedFlag ? panel.pal.red : (muteMouse.containsMouse ? panel.pal.bg2 : panel.pal.bg0)

                        Text {
                            anchors.centerIn: parent
                            text: panel.mutedFlag ? "off" : "on"
                            color: panel.mutedFlag ? panel.pal.bg0 : panel.pal.fg2
                            font.family: panel.pal.font
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: muteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.toggleMute()
                        }
                    }

                    Item {
                        id: slider
                        width: parent.width - muteBtn.width - volText.width - 16
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: 2
                            color: panel.pal.bg2
                        }

                        Rectangle {
                            id: fill
                            anchors.verticalCenter: parent.verticalCenter
                            width: panel.volPercent / 100 * track.width
                            height: 5
                            radius: 2
                            color: panel.mutedFlag ? panel.pal.gray : panel.pal.gold
                        }

                        Rectangle {
                            id: knob
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            x: panel.volPercent / 100 * track.width - width / 2
                            color: panel.pal.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => panel.setVolume(mouse.x / slider.width * 100)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    panel.setVolume(mouse.x / slider.width * 100);
                            }
                        }
                    }

                    Text {
                        id: volText
                        width: 36
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: panel.volPercent + "%"
                        color: panel.pal.fg
                        font.family: panel.pal.font
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: panel.pal.bg2
                }

                Text {
                    text: "output devices"
                    color: panel.pal.fg2
                    font.family: panel.pal.font
                    font.pixelSize: 10
                }

                ListView {
                    id: devView
                    width: parent.width
                    height: Math.min(200, Math.max(24, panel.sinkList.length * 26))
                    clip: true
                    spacing: 2
                    model: panel.sinkList

                    delegate: Rectangle {
                        required property var modelData
                        width: devView.width
                        height: 24
                        radius: 4
                        color: modelData.def ? panel.pal.bg2 : (devMouse.containsMouse ? panel.pal.bg2 : "transparent")

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name + (modelData.def ? "  •" : "")
                            color: modelData.def ? panel.pal.green : panel.pal.fg
                            font.family: panel.pal.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: devMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.makeDefault(modelData.id)
                        }
                    }
                }
            }
        }
    }
}