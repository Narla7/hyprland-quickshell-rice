import Quickshell
import Quickshell.Wayland
import QtQuick

// Draws rockman.png on the background layer of the focused screen.
PanelWindow {
    id: wallpaper

    readonly property Miasma pal: Miasma {}
    // Ships with the rice (quickshell/wallpapers/), so no external clone is needed.
    readonly property url localImage: Qt.resolvedUrl("wallpapers/rockman.png")
    // Fallback for a full clone of github.com/AngelJumbo/gruvbox-wallpapers at ~/gruvbox-wallpapers.
    readonly property url fallbackImage: "file://" + Quickshell.env("HOME") + "/gruvbox-wallpapers/wallpapers/mix/rockman.png"

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
        source: wallpaper.localImage
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true

        // Local copy missing? Use the external wallpaper collection instead.
        onStatusChanged: if (status === Image.Error && source != wallpaper.fallbackImage)
            source = wallpaper.fallbackImage
    }
}
