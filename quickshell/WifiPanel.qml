import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import QtQuick

// Wifi: list networks, connect (with password prompt), toggle radio,
// disconnect the current one, and open NetworkManager's connection editor.
PanelWindow {
    id: panel

    property var shell
    property var wifiDev: null
    property var netList: []
    property var pendingNet: null
    property string pendingSsid: ""
    property string statusText: ""
    property string currentSsid: ""

    readonly property Miasma pal: Miasma {}
    readonly property bool connected: wifiDev !== null && wifiDev.connected

    // WifiSecurityType: Owe=9, Open=10, Unknown=11 (no password needed)
    function needsPassword(net) {
        return net.security !== 9 && net.security !== 10;
    }

    function refresh() {
        var list = Networking.devices.values.filter(d => d.type == DeviceType.Wifi);
        panel.wifiDev = list.length > 0 ? list[0] : null;
        if (!panel.wifiDev) {
            panel.netList = [];
            panel.currentSsid = "";
            return;
        }
        var map = {};
        panel.wifiDev.networks.values.forEach(function (n) {
            if (!n.name)
                return;
            var prev = map[n.name];
            if (!prev || prev.signalStrength < n.signalStrength)
                map[n.name] = n;
        });
        var out = [];
        for (var k in map) out.push(map[k]);
        out.sort(function (a, b) {
            return b.signalStrength - a.signalStrength;
        });
        panel.netList = out;
        var conn = panel.wifiDev.networks.values.filter(n => n.connected)[0];
        panel.currentSsid = (conn && conn.name) ? conn.name : "";
    }

    function connectTo(net) {
        if (!net)
            return;
        panel.statusText = "";
        if (net.known) {
            runConnect(net.name, "");
            return;
        }
        if (!needsPassword(net)) {
            runConnect(net.name, "");
            return;
        }
        panel.pendingNet = net;
        panel.pendingSsid = net.name;
        panel.statusText = "password required for " + net.name;
        pskField.text = "";
        pskField.forceActiveFocus();
    }

    function runConnect(ssid, psk) {
        var cmd;
        if (psk && psk.length > 0)
            cmd = ["nmcli", "device", "wifi", "connect", ssid, "password", psk];
        else
            cmd = ["nmcli", "device", "wifi", "connect", ssid];
        panel.statusText = "connecting to " + ssid;
        connectProc.command = cmd;
        connectProc.running = true;
    }

    function submitPassword() {
        var net = panel.pendingNet;
        if (!net)
            return;
        runConnect(net.name, pskField.text);
        panel.pendingNet = null;
        pskField.text = "";
    }

    function disconnectCurrent() {
        if (!panel.wifiDev)
            return;
        disconnectProc.command = ["nmcli", "device", "disconnect", panel.wifiDev.name];
        disconnectProc.running = true;
        panel.statusText = "disconnecting…";
    }

    visible: shell.wifiOpen
    anchors {
        top: true
        right: true
    }
    margins {
        top: pal.barHeight + 4
        right: 8
    }
    implicitWidth: 330
    implicitHeight: Math.min(470, col.implicitHeight + 24)
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wifi"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (visible) {
            refresh();
            rescanProc.running = true;
            wifiRefresh.start();
        } else {
            pendingNet = null;
            statusText = "";
        }
    }

    Timer {
        id: wifiRefresh
        interval: 4000
        repeat: true
        onTriggered: panel.refresh()
    }

    Timer {
        id: afterRescan
        interval: 3000
        repeat: false
        onTriggered: panel.refresh()
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onRunningChanged: if (!running) afterRescan.restart()
    }

    Process {
        id: connectProc
        command: ["nmcli", "device", "wifi", "connect", "x"]
        stdout: StdioCollector {
            id: connectOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: connectErr
            waitForEnd: true
        }
        onRunningChanged: if (!running) {
            var e = (connectErr.text || "").trim();
            var o = (connectOut.text || "").trim();
            if (e.length > 0)
                panel.statusText = "error: " + e.split("\n")[0];
            else
                panel.statusText = o.length > 0 ? o : "done";
        }
    }

    Process {
        id: disconnectProc
        command: ["nmcli", "device", "disconnect", "x"]
        stdout: StdioCollector {
            id: discOut
            waitForEnd: true
        }
        onRunningChanged: if (!running) {
            var o = (discOut.text || "").trim();
            panel.statusText = o.length > 0 ? o : "disconnected";
            panel.refresh();
        }
    }

    Process {
        id: nmEditor
        command: ["nm-connection-editor"]
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: panel.pal.bg1
        radius: 10
        border.width: 1
        border.color: panel.pal.bg2

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: panel.shell.closeAllBut("")

            Column {
                id: col
                width: parent.width - 24
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 8

                // ---- header: state + radio toggle
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "wifi"
                        color: panel.pal.gold
                        font.family: panel.pal.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.connected ? panel.currentSsid : (panel.wifiOn ? "not connected" : "radio off")
                        color: panel.connected ? panel.pal.fg : panel.pal.gray
                        font.family: panel.pal.font
                        font.pixelSize: 11
                    }

                    Item {
                        width: 1
                        height: 1
                    }

                    Rectangle {
                        id: headRescan
                        width: 54
                        height: 18
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: headRescanMouse.containsMouse ? panel.pal.bg2 : panel.pal.bg0

                        Text {
                            anchors.centerIn: parent
                            text: "rescan"
                            color: panel.pal.fg2
                            font.family: panel.pal.font
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: headRescanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.statusText = "scanning…";
                                rescanProc.running = true;
                            }
                        }
                    }
                }

                // ---- status + rescan
                Text {
                    width: parent.width
                    text: panel.statusText
                    color: panel.pal.orange
                    font.family: panel.pal.font
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: panel.statusText.length > 0
                }

                // ---- network list
                ListView {
                    id: netView
                    width: parent.width
                    height: Math.min(230, Math.max(28, panel.netList.length * 26))
                    clip: true
                    spacing: 2
                    model: panel.netList

                    delegate: Rectangle {
                        required property var modelData
                        width: netView.width
                        height: 24
                        radius: 4
                        color: rowMouse.containsMouse ? panel.pal.bg2 : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // padlock for secured, not-yet-saved networks
                            Item {
                                width: 9
                                height: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: panel.needsPassword(modelData)

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    x: 1.5
                                    y: 0
                                    color: "transparent"
                                    border.width: 1
                                    border.color: panel.pal.fg2
                                }
                                Rectangle {
                                    width: 9
                                    height: 6
                                    y: 5
                                    radius: 1
                                    color: panel.pal.fg2
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: netView.width - 90
                                text: modelData.name
                                color: modelData.connected ? panel.pal.green : panel.pal.fg
                                font.family: panel.pal.font
                                font.pixelSize: 11
                                font.bold: modelData.connected
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.known ? "saved" : ""
                                color: panel.pal.gray
                                font.family: panel.pal.font
                                font.pixelSize: 9
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(modelData.signalStrength * 100) + "%"
                                color: panel.pal.fg2
                                font.family: panel.pal.font
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.connectTo(modelData)
                        }
                    }
                }

                // ---- password prompt
                Row {
                    width: parent.width
                    spacing: 6
                    visible: panel.pendingNet !== null
                    height: visible ? 26 : 0

                    Rectangle {
                        width: parent.width - connectBtn.width - 6
                        height: 24
                        radius: 4
                        color: panel.pal.bg0
                        border.width: 1
                        border.color: panel.pal.gold

                        TextInput {
                            id: pskField
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: panel.pal.fg
                            font.family: panel.pal.font
                            font.pixelSize: 11
                            clip: true
                            onAccepted: panel.submitPassword()
                            Keys.onEscapePressed: {
                                panel.pendingNet = null;
                                panel.statusText = "";
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            text: "password for " + panel.pendingSsid
                            color: panel.pal.gray
                            font.family: panel.pal.font
                            font.pixelSize: 10
                            visible: pskField.text.length === 0
                        }
                    }

                    Rectangle {
                        id: connectBtn
                        width: 62
                        height: 24
                        radius: 4
                        color: connectMouse.containsMouse ? panel.pal.gold : panel.pal.bg2

                        Text {
                            anchors.centerIn: parent
                            text: "connect"
                            color: connectMouse.containsMouse ? panel.pal.bg0 : panel.pal.fg
                            font.family: panel.pal.font
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: connectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.submitPassword()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: panel.pal.bg2
                }

                // ---- footer actions
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: 92
                        height: 22
                        radius: 4
                        visible: panel.connected
                        color: discMouse.containsMouse ? panel.pal.red : panel.pal.bg0

                        Text {
                            anchors.centerIn: parent
                            text: "disconnect"
                            color: discMouse.containsMouse ? panel.pal.bg0 : panel.pal.fg2
                            font.family: panel.pal.font
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: discMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.disconnectCurrent()
                        }
                    }

                    Rectangle {
                        width: 120
                        height: 22
                        radius: 4
                        color: setMouse.containsMouse ? panel.pal.bg2 : panel.pal.bg0

                        Text {
                            anchors.centerIn: parent
                            text: "network settings"
                            color: panel.pal.fg2
                            font.family: panel.pal.font
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: setMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                nmEditor.running = true;
                                panel.shell.closeAllBut("");
                            }
                        }
                    }
                }
            }
        }
    }
}
