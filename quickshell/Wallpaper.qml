import Quickshell
import Quickshell.Wayland
import QtQuick

// Draws rockman.png on the background layer of the focused screen.
PanelWindow {
    id: wallpaper

    readonly property Miasma pal: Miasma {}
    // Distro- and user-agnostic: resolve against $HOME so the repo is portable.
    // Clone github.com/AngelJumbo/gruvbox-wallpapers to ~/gruvbox-wallpapers.
    readonly property string imagePath: "file://" + Quickshell.env("HOME") + "/gruvbox-wallpapers/wallpapers/mix/rockman.png"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: pal.bg0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"

    Image {
        anchors.fill: parent
        source: wallpaper.imagePath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
    }
}
