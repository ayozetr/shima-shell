pragma Singleton
import QtQuick
import Quickshell

// Every visual value lives here, and most of them derive from Config,
// so the settings window repaints the shell without a restart.
Singleton {
    id: root

    // ── Island ─────────────────────────────────────────────────
    readonly property color islandBg: Qt.rgba(
        Qt.color(Config.data.islandTint ?? "#000000").r,
        Qt.color(Config.data.islandTint ?? "#000000").g,
        Qt.color(Config.data.islandTint ?? "#000000").b,
        (Config.data.islandOpacity ?? 1.0))
    readonly property color islandBorder:  "#1a1a1a"
    readonly property int   islandRadius:  Config.data.islandRadius ?? 22

    readonly property int islandCollapsedWidth:  Config.data.islandCollapsedWidth ?? 410
    readonly property int islandCollapsedHeight: Config.data.islandCollapsedHeight ?? 38
    readonly property int islandExpandedWidth:   Config.data.islandExpandedWidth ?? 425
    readonly property int islandExpandedHeight:  140
    readonly property int islandExpandedMargin:  8

    // ── Dock ───────────────────────────────────────────────────
    readonly property color dockBg: Qt.rgba(
        Qt.color(Config.data.dockTint ?? "#000000").r,
        Qt.color(Config.data.dockTint ?? "#000000").g,
        Qt.color(Config.data.dockTint ?? "#000000").b,
        (Config.data.dockOpacity ?? 0.8))
    readonly property color dockBorder: "#1affffff"

    // Gradient of the icon container.
    readonly property color iconTop:    "#33ffffff"
    readonly property color iconBottom: "#0dffffff"
    readonly property color iconBorder: "#1affffff"

    // Ratios calibrated against a 36 px icon and preserved when
    // scaling: gap 0.33, padding 0.22, artwork 0.55.
    readonly property int dockIconSize:    Config.data.dockIconSize ?? 56
    readonly property int dockIconSpacing: Math.round(dockIconSize * 0.333)
    readonly property int dockPadding:     Math.round(dockIconSize * 0.222)
    readonly property real dockIconArt:    0.55
    readonly property int dockRadius:      Config.data.dockCornerRadius ?? 28
    readonly property int dockDotLane:     10

    readonly property int dockIconRadius: {
        const s = root.dockIconSize;
        switch (Config.data.iconShape) {
            case "circle": return Math.round(s / 2);
            case "square": return 0;
            default:       return Math.round(s * (Config.data.iconRadiusPct ?? 33) / 100);
        }
    }

    // ── Colour and motion ──────────────────────────────────────
    readonly property color accent:        Qt.color(Config.data.accent ?? "#a78bfa")

    // What gets painted ON TOP of the accent. With a light accent
    // (white, yellow) white text vanishes, so this is decided by
    // luminance instead of assumed.
    readonly property color accentText: {
        const c = root.accent;
        const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return lum > 0.6 ? "#101010" : "#ffffff";
    }

    // The accent toned down, for large fills where the solid colour
    // would be overwhelming.
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#9a9a9a"
    readonly property color textTertiary:  "#5c5c5c"
    readonly property color trackFill:     "#ffffff"
    readonly property color trackBg:       "#3a3a3a"

    readonly property int springDuration: 420
    readonly property int fadeDuration:   160
    readonly property int hoverDuration:  180
}
