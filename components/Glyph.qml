import QtQuick
import "../services"

// Hand-drawn icons: the system equivalents are Apple's SF Symbols,
// which we cannot redistribute.
Canvas {
    id: root
    property string kind: "play"   // play · pause · next · prev · speakerOff · speakerOn
    property color fill: Theme.textPrimary

    onKindChanged: requestPaint()
    onFillChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = root.fill;
        const w = width, h = height;

        function triangle(x, y, tw, th) {
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x, y + th);
            ctx.lineTo(x + tw, y + th / 2);
            ctx.closePath();
            ctx.fill();
        }
        function triangleLeft(x, y, tw, th) {
            ctx.beginPath();
            ctx.moveTo(x + tw, y);
            ctx.lineTo(x + tw, y + th);
            ctx.lineTo(x, y + th / 2);
            ctx.closePath();
            ctx.fill();
        }

        if (kind === "play") {
            triangle(w * 0.22, h * 0.12, w * 0.62, h * 0.76);
        } else if (kind === "pause") {
            const bw = w * 0.22;
            ctx.fillRect(w * 0.22, h * 0.14, bw, h * 0.72);
            ctx.fillRect(w * 0.56, h * 0.14, bw, h * 0.72);
        } else if (kind === "next") {
            triangle(w * 0.08, h * 0.18, w * 0.40, h * 0.64);
            triangle(w * 0.46, h * 0.18, w * 0.40, h * 0.64);
            ctx.fillRect(w * 0.86, h * 0.18, w * 0.10, h * 0.64);
        } else if (kind === "prev") {
            triangleLeft(w * 0.14, h * 0.18, w * 0.40, h * 0.64);
            triangleLeft(w * 0.52, h * 0.18, w * 0.40, h * 0.64);
            ctx.fillRect(w * 0.04, h * 0.18, w * 0.10, h * 0.64);
        } else if (kind === "speakerOff" || kind === "speakerOn") {
            // Speaker body
            ctx.fillRect(w * 0.06, h * 0.36, w * 0.16, h * 0.28);
            ctx.beginPath();
            ctx.moveTo(w * 0.22, h * 0.36);
            ctx.lineTo(w * 0.46, h * 0.12);
            ctx.lineTo(w * 0.46, h * 0.88);
            ctx.lineTo(w * 0.22, h * 0.64);
            ctx.closePath();
            ctx.fill();

            ctx.strokeStyle = root.fill;
            ctx.lineWidth = Math.max(1, w * 0.07);
            if (kind === "speakerOn") {
                for (const r of [0.66, 0.86]) {
                    ctx.beginPath();
                    ctx.arc(w * 0.46, h * 0.5, w * r * 0.5, -Math.PI / 3, Math.PI / 3);
                    ctx.stroke();
                }
            } else {
                ctx.beginPath();
                ctx.moveTo(w * 0.60, h * 0.34); ctx.lineTo(w * 0.88, h * 0.66);
                ctx.moveTo(w * 0.88, h * 0.34); ctx.lineTo(w * 0.60, h * 0.66);
                ctx.stroke();
            }
        }
    }
}
