import QtQuick
import "../services"

// Icons for the launcher's bottom bar, drawn by hand like the rest so
// they do not depend on the icon theme being complete.
Canvas {
    id: root
    property string kind: "power"   // power · user · settings
    property color fill: Theme.textSecondary

    onKindChanged: requestPaint()
    onFillChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.strokeStyle = root.fill;
        ctx.fillStyle = root.fill;
        ctx.lineCap = "round";
        const w = width, h = height;

        if (kind === "power") {
            // Broken ring with a stem: the usual power symbol.
            ctx.lineWidth = Math.max(1.5, w * 0.11);
            ctx.beginPath();
            ctx.arc(w / 2, h * 0.55, w * 0.34, -Math.PI * 0.35, Math.PI * 1.35);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(w / 2, h * 0.10);
            ctx.lineTo(w / 2, h * 0.48);
            ctx.stroke();
        } else if (kind === "user") {
            // Head and shoulders.
            ctx.beginPath();
            ctx.arc(w / 2, h * 0.34, w * 0.19, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(w / 2, h * 0.92, w * 0.32, Math.PI, Math.PI * 2);
            ctx.fill();
        } else if (kind === "settings") {
            // Sliders rather than a cog: at 16 px a cog's teeth blur
            // into an asterisk, while three tracks with a knob each
            // still read as settings.
            ctx.lineWidth = Math.max(1.4, w * 0.09);
            const rows = [0.26, 0.5, 0.74];
            const knobs = [0.66, 0.36, 0.58];
            for (let i = 0; i < 3; i++) {
                const y = h * rows[i];
                ctx.beginPath();
                ctx.moveTo(w * 0.12, y);
                ctx.lineTo(w * 0.88, y);
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(w * knobs[i], y, w * 0.12, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
}
