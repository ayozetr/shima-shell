import QtQuick
import "../services"

// Control centre icons, drawn by hand like the player ones so they
// don't depend on any theme.
Canvas {
    id: root
    property string kind: "wifi"   // wifi · bt · mute
    property color fill: Theme.textPrimary

    onKindChanged: requestPaint()
    onFillChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.strokeStyle = root.fill;
        ctx.fillStyle = root.fill;
        const w = width, h = height;

        if (kind === "wifi") {
            ctx.lineWidth = Math.max(1.4, w * 0.11);
            ctx.lineCap = "round";
            // Three concentric arcs and the dot underneath.
            for (const r of [0.44, 0.30, 0.16]) {
                ctx.beginPath();
                ctx.arc(w / 2, h * 0.80, w * r, -Math.PI * 0.78, -Math.PI * 0.22);
                ctx.stroke();
            }
            ctx.beginPath();
            ctx.arc(w / 2, h * 0.78, w * 0.06, 0, Math.PI * 2);
            ctx.fill();
        } else if (kind === "bt") {
            ctx.lineWidth = Math.max(1.4, w * 0.11);
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            // The rune: two triangles over a vertical axis.
            ctx.beginPath();
            ctx.moveTo(w * 0.28, h * 0.30);
            ctx.lineTo(w * 0.70, h * 0.70);
            ctx.lineTo(w * 0.50, h * 0.88);
            ctx.lineTo(w * 0.50, h * 0.12);
            ctx.lineTo(w * 0.70, h * 0.30);
            ctx.lineTo(w * 0.28, h * 0.70);
            ctx.stroke();
        } else if (kind === "mute") {
            ctx.fillRect(w * 0.06, h * 0.36, w * 0.14, h * 0.28);
            ctx.beginPath();
            ctx.moveTo(w * 0.20, h * 0.36);
            ctx.lineTo(w * 0.44, h * 0.14);
            ctx.lineTo(w * 0.44, h * 0.86);
            ctx.lineTo(w * 0.20, h * 0.64);
            ctx.closePath();
            ctx.fill();

            ctx.lineWidth = Math.max(1.4, w * 0.10);
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(w * 0.58, h * 0.34); ctx.lineTo(w * 0.88, h * 0.66);
            ctx.moveTo(w * 0.88, h * 0.34); ctx.lineTo(w * 0.58, h * 0.66);
            ctx.stroke();
        }
    }
}
