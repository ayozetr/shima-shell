import QtQuick
import "../services"

// Marks for the categories that are always there, in place of a count.
// Drawn by hand like the rest so they don't depend on an icon theme.
Canvas {
    id: root
    property string kind: "star"   // star · clock · bookmark · clipboard
    property color fill: Theme.textTertiary

    onKindChanged: requestPaint()
    onFillChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = root.fill;
        ctx.strokeStyle = root.fill;
        const w = width, h = height;

        if (kind === "star") {
            // Five points, outer and inner radius alternating.
            ctx.beginPath();
            for (let i = 0; i < 10; i++) {
                const r = (i % 2 === 0) ? w * 0.48 : w * 0.20;
                const a = -Math.PI / 2 + i * Math.PI / 5;
                const x = w / 2 + Math.cos(a) * r;
                const y = h / 2 + Math.sin(a) * r;
                i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fill();
        } else if (kind === "clock") {
            ctx.lineWidth = Math.max(1.2, w * 0.10);
            ctx.beginPath();
            ctx.arc(w / 2, h / 2, w * 0.40, 0, Math.PI * 2);
            ctx.stroke();
            // Hands at ten past ten, which is how clocks are drawn.
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(w / 2, h / 2);
            ctx.lineTo(w / 2, h * 0.28);
            ctx.moveTo(w / 2, h / 2);
            ctx.lineTo(w * 0.72, h * 0.58);
            ctx.stroke();
        } else if (kind === "clipboard") {
            // Two sheets, one in front of the other. The one in front
            // is cut out of the one behind rather than drawn on top of
            // it: at eleven pixels an outline is a smudge and a gap
            // between two solids keeps its shape all the way down.
            //
            // Cut and not painted over, because what is behind this is
            // the launcher and the launcher has a colour of its own.
            ctx.beginPath();
            ctx.rect(w * 0.04, h * 0.02, w * 0.54, h * 0.66);
            ctx.fill();

            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.rect(w * 0.30, h * 0.26, w * 0.70, h * 0.76);
            ctx.fill();
            ctx.globalCompositeOperation = "source-over";

            ctx.beginPath();
            ctx.rect(w * 0.38, h * 0.32, w * 0.54, h * 0.66);
            ctx.fill();
        } else if (kind === "bookmark") {
            // Eleven pixels only keep a silhouette, so it has to be
            // one nothing else has: a compass became a smudge and a
            // folder became a rectangle with a notch. The bite out of
            // the bottom survives the size.
            ctx.beginPath();
            ctx.moveTo(w * 0.22, h * 0.04);
            ctx.lineTo(w * 0.78, h * 0.04);
            ctx.lineTo(w * 0.78, h * 0.96);
            ctx.lineTo(w * 0.50, h * 0.66);
            ctx.lineTo(w * 0.22, h * 0.96);
            ctx.closePath();
            ctx.fill();
        }
    }
}
