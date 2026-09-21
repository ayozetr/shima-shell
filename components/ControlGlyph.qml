import QtQuick
import "../services"

// Small interface icons, drawn by hand like the player ones so they
// don't depend on any theme.
Canvas {
    id: root
    property string kind: "wifi"   // wifi · bt · mute · output · brightness · night · back
                                   // · bell · bellOff · trash
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
        } else if (kind === "output") {
            // Speaker with waves: where the sound is going.
            ctx.fillRect(w * 0.10, h * 0.36, w * 0.14, h * 0.28);
            ctx.beginPath();
            ctx.moveTo(w * 0.24, h * 0.36);
            ctx.lineTo(w * 0.48, h * 0.14);
            ctx.lineTo(w * 0.48, h * 0.86);
            ctx.lineTo(w * 0.24, h * 0.64);
            ctx.closePath();
            ctx.fill();

            ctx.lineWidth = Math.max(1.3, w * 0.09);
            ctx.lineCap = "round";
            for (const r of [0.62, 0.84]) {
                ctx.beginPath();
                ctx.arc(w * 0.48, h * 0.5, w * r * 0.5, -Math.PI / 3.2, Math.PI / 3.2);
                ctx.stroke();
            }
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
        } else if (kind === "brightness") {
            // Sun: a filled core with eight rays, so it still reads as
            // brightness at fourteen pixels.
            ctx.beginPath();
            ctx.arc(w / 2, h / 2, w * 0.22, 0, Math.PI * 2);
            ctx.fill();

            ctx.lineWidth = Math.max(1.3, w * 0.09);
            ctx.lineCap = "round";
            ctx.beginPath();
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4;
                ctx.moveTo(w / 2 + Math.cos(a) * w * 0.34,
                           h / 2 + Math.sin(a) * h * 0.34);
                ctx.lineTo(w / 2 + Math.cos(a) * w * 0.46,
                           h / 2 + Math.sin(a) * h * 0.46);
            }
            ctx.stroke();
        } else if (kind === "night") {
            // Crescent: a disc with a second one bitten out of it,
            // which keeps the horns sharp at any size.
            ctx.save();
            ctx.beginPath();
            ctx.arc(w * 0.50, h * 0.50, w * 0.42, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.arc(w * 0.76, h * 0.30, w * 0.40, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        } else if (kind === "bell" || kind === "bellOff") {
            ctx.beginPath();
            ctx.moveTo(w * 0.18, h * 0.70);
            ctx.lineTo(w * 0.18, h * 0.42);
            ctx.arc(w * 0.50, h * 0.42, w * 0.32, Math.PI, 0);
            ctx.lineTo(w * 0.82, h * 0.70);
            ctx.closePath();
            ctx.fill();
            ctx.fillRect(w * 0.08, h * 0.68, w * 0.84, h * 0.10);
            ctx.beginPath();
            ctx.arc(w * 0.50, h * 0.86, w * 0.11, 0, Math.PI * 2);
            ctx.fill();

            if (kind === "bellOff") {
                // The stroke is cut out of the bell first, so it reads
                // as crossing over it rather than sitting on top.
                ctx.save();
                ctx.globalCompositeOperation = "destination-out";
                ctx.lineWidth = Math.max(2.4, w * 0.22);
                ctx.beginPath();
                ctx.moveTo(w * 0.06, h * 0.02);
                ctx.lineTo(w * 0.94, h * 0.98);
                ctx.stroke();
                ctx.restore();

                ctx.lineWidth = Math.max(1.3, w * 0.11);
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(w * 0.12, h * 0.06);
                ctx.lineTo(w * 0.88, h * 0.94);
                ctx.stroke();
            }
        } else if (kind === "trash") {
            ctx.fillRect(w * 0.38, h * 0.04, w * 0.24, h * 0.12);
            ctx.fillRect(w * 0.08, h * 0.18, w * 0.84, h * 0.11);
            ctx.beginPath();
            ctx.moveTo(w * 0.19, h * 0.32);
            ctx.lineTo(w * 0.81, h * 0.32);
            ctx.lineTo(w * 0.72, h * 0.95);
            ctx.lineTo(w * 0.28, h * 0.95);
            ctx.closePath();
            ctx.fill();

            // Two grooves, cut rather than drawn, so they show on any
            // background.
            ctx.save();
            ctx.globalCompositeOperation = "destination-out";
            ctx.lineWidth = Math.max(1.1, w * 0.09);
            ctx.beginPath();
            ctx.moveTo(w * 0.42, h * 0.42); ctx.lineTo(w * 0.42, h * 0.85);
            ctx.moveTo(w * 0.58, h * 0.42); ctx.lineTo(w * 0.58, h * 0.85);
            ctx.stroke();
            ctx.restore();
        } else if (kind === "back") {
            ctx.lineWidth = Math.max(1.4, w * 0.13);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(w * 0.62, h * 0.18);
            ctx.lineTo(w * 0.34, h * 0.50);
            ctx.lineTo(w * 0.62, h * 0.82);
            ctx.stroke();
        }
    }
}
