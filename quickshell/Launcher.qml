import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// App launcher (mod+space, or click the NixOS logo in the bar).
// Lists every non-NoDisplay app (A-Z), centred, arrow-key navigable.
// NOTE: children of a PanelWindow do not see its properties unqualified —
// every access below goes through the file-scoped `launcher.` id.
PanelWindow {
    id: launcher

    property var shell
    property var appList: []
    property string query: ""
    property int selected: 0

    readonly property Miasma pal: Miasma {}
    readonly property var results: filterApps()

    // ---- geometry
    readonly property int rowHeight: 40
    readonly property int rowSpacing: 2
    readonly property int headerHeight: 46
    readonly property int pad: 14
    readonly property int gap: 10
    readonly property real maxCardH: Math.max(260, launcher.height - 120)
    readonly property real listH: Math.min(launcher.maxCardH - 2 * launcher.pad - launcher.headerHeight - launcher.gap,
                                           Math.max(1, launcher.results.length) * (launcher.rowHeight + launcher.rowSpacing))

    function filterApps() {
        var q = launcher.query.trim().toLowerCase();
        var all = launcher.appList;
        if (q === "")
            return all;
        return all.filter(function (e) {
            if ((e.name || "").toLowerCase().indexOf(q) >= 0)
                return true;
            if ((e.genericName || "").toLowerCase().indexOf(q) >= 0)
                return true;
            var ks = e.keywords || [];
            for (var i = 0; i < ks.length; i++) {
                if (String(ks[i]).toLowerCase().indexOf(q) >= 0)
                    return true;
            }
            return false;
        });
    }

    function reloadApps() {
        var v = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < v.length; i++) {
            var e = v[i];
            if (e && !e.noDisplay && e.name)
                out.push(e);
        }
        out.sort(function (a, b) {
            return a.name.localeCompare(b.name);
        });
        launcher.appList = out;
    }

    function launch(entry) {
        if (!entry)
            return;
        try {
            entry.execute();
        } catch (e) {
            var cmd = entry.command;
            if (typeof cmd === "string")
                Quickshell.execDetached([cmd]);
            else if (cmd && cmd.length > 0)
                Quickshell.execDetached(cmd);
        }
        launcher.shell.closeAllBut("");
    }

    function move(delta) {
        var n = launcher.results.length;
        if (n === 0)
            return;
        launcher.selected = (launcher.selected + delta + n) % n;
    }

    visible: shell.launcherOpen
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
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (visible) {
            launcher.reloadApps();
            queryField.text = "";
            launcher.query = "";
            launcher.selected = 0;
            queryField.forceActiveFocus();
        }
    }

    // the app model can still be empty on the very first open after login
    Timer {
        interval: 1000
        repeat: true
        running: launcher.appList.length === 0
        onTriggered: launcher.reloadApps()
    }

    // dimmer + click-outside-to-close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.157, 0.157, 0.157, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.shell.closeAllBut("")
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(780, launcher.width - 140)
        height: Math.min(launcher.maxCardH, 2 * launcher.pad + launcher.headerHeight + launcher.gap + launcher.listH)
        radius: 14
        color: launcher.pal.bg1
        border.width: 1
        border.color: launcher.pal.bg2

        Column {
            anchors.fill: parent
            anchors.margins: launcher.pad
            spacing: launcher.gap

            // ---- query
            Rectangle {
                width: parent.width
                height: launcher.headerHeight
                radius: 8
                color: launcher.pal.bg0
                border.width: 1
                border.color: queryField.activeFocus ? launcher.pal.gold : launcher.pal.bg2

                TextInput {
                    id: queryField
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: launcher.pal.fg
                    selectionColor: launcher.pal.gold
                    selectedTextColor: launcher.pal.bg0
                    font.family: launcher.pal.font
                    font.pixelSize: 15
                    clip: true

                    onTextChanged: {
                        launcher.query = text;
                        launcher.selected = 0;
                    }
                    onAccepted: launcher.launch(launcher.results[launcher.selected])

                    Keys.onEscapePressed: launcher.shell.closeAllBut("")
                    Keys.onDownPressed: launcher.move(1)
                    Keys.onUpPressed: launcher.move(-1)
                    Keys.onTabPressed: launcher.move(1)
                    Keys.onBacktabPressed: launcher.move(-1)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    text: "search apps…"
                    color: launcher.pal.gray
                    font.family: launcher.pal.font
                    font.pixelSize: 14
                    visible: queryField.text.length === 0
                }
            }

            // ---- results: every app, scrolled by the arrow keys
            ListView {
                id: resultView
                width: parent.width
                height: launcher.listH
                clip: true
                spacing: launcher.rowSpacing
                model: launcher.results
                currentIndex: launcher.selected
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < count)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }
                onCountChanged: positionViewAtBeginning()

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === launcher.selected

                    width: resultView.width
                    height: launcher.rowHeight
                    radius: 6
                    color: isCurrent ? launcher.pal.bg2 : (rowMouse.containsMouse ? launcher.pal.bg1 : "transparent")

                    // fixed height: the children below are vertically centred
                    // inside it, which a height-less Row cannot resolve
                    Row {
                        height: 26
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon, "") : ""
                            sourceSize.width: 48
                            sourceSize.height: 48
                            fillMode: Image.PreserveAspectFit
                            visible: source != ""
                        }

                        Text {
                            id: nameText
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, resultView.width - 140)
                            text: modelData.name
                            color: isCurrent ? launcher.pal.fg : launcher.pal.fg1
                            font.family: launcher.pal.font
                            font.pixelSize: 13
                            font.bold: isCurrent
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, Math.max(0, resultView.width - nameText.width - 160))
                            text: modelData.genericName || ""
                            color: launcher.pal.gray
                            font.family: launcher.pal.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // only a real mouse move re-targets the selection, so
                        // keyboard scrolling never gets yanked back by the cursor
                        onPositionChanged: launcher.selected = index
                        onClicked: launcher.launch(modelData)
                    }
                }
            }
        }
    }
}
