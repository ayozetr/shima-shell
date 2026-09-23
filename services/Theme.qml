pragma Singleton
import QtQuick
import Quickshell

// Every visual value lives here, and most of them derive from Config,
// so the settings window repaints the shell without a restart.
Singleton {
    id: root

    // The configuration is a file people edit by hand, so what comes
    // out of it is not to be trusted. `?? default` only catches null
    // and undefined: `"accent": ""` sails straight through it and ends
    // up as an invalid colour — the accent turns black, and the text
    // meant to sit on top of it is then worked out against black.
    function colour(value, fallback) {
        if (typeof value !== "string") return Qt.color(fallback);
        const v = value.trim();
        if (v === "") return Qt.color(fallback);
        try {
            // Qt.color throws on a name it does not know rather than
            // returning anything, and an exception here does not leave
            // the default in place: it breaks the binding, and the
            // colour ends up black. Which is how `"accent": "purpel"`
            // turned the accent black and the text meant to sit on it
            // was then worked out against black.
            return Qt.color(v);
        } catch (e) {
            return Qt.color(fallback);
        }
    }

    // ── Island ─────────────────────────────────────────────────
    readonly property color dockTintColour: root.colour(Config.data.dockTint, "#000000")
    readonly property color islandTintColour: root.colour(Config.data.islandTint, "#000000")
    readonly property color islandBg: Qt.rgba(
        root.islandTintColour.r,
        root.islandTintColour.g,
        root.islandTintColour.b,
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
        root.dockTintColour.r,
        root.dockTintColour.g,
        root.dockTintColour.b,
        (Config.data.dockOpacity ?? 0.8))
    readonly property color dockBorder: "#1affffff"

    // Gradient of the icon container.
    readonly property color iconTop:    "#33ffffff"
    readonly property color iconBottom: "#0dffffff"
    readonly property color iconBorder: "#1affffff"

    // Ratios calibrated against a 36 px icon and preserved when
    // scaling: gap 0.33, padding 0.22, artwork 0.55.
    // Clamped, not just defaulted: a zero here propagates into every
    // spacing and radius below it and gives geometries that cannot be
    // laid out, and the settings file is edited by hand.
    readonly property int dockIconSize:
        Math.max(16, Math.min(128, Config.data.dockIconSize ?? 56))
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
    readonly property color accent:        root.colour(Config.data.accent, "#a78bfa")

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
    // The filled part while muted: clearly dimmer than trackBg so the
    // bar still reads, but obviously switched off.
    readonly property color trackMuted:    "#6a6a6a"

    // Urgency is not a matter of taste, so it does not follow the
    // accent: a red dot means the same whatever colour the island is.
    readonly property color urgent:        "#f4564a"

    readonly property int springDuration: 420
    readonly property int fadeDuration:   160
    readonly property int hoverDuration:  180
}
