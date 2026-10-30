import QtQuick
import org.kde.kirigami as Kirigami

// Button-less controller silhouette with the battery level cut out of it.
// variant 0 = classic (wide, small digits + %), 1 = bold (tall body, big digits),
// 2 = gauge (bold, with the body filled left-to-right by the battery level)
Canvas {
    id: badge

    property int variant: 0
    property int level: -1
    property color color: Kirigami.Theme.textColor
    property bool charging: false
    property color chargingColor: Kirigami.Theme.positiveTextColor

    readonly property real unitW: variant === 0 ? 32 : 28
    readonly property real unitH: 20

    antialiasing: true

    onVariantChanged: requestPaint()
    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()
    onChargingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function classicPath(ctx) {
        ctx.beginPath();
        ctx.moveTo(8, 1);
        ctx.lineTo(24, 1);
        ctx.bezierCurveTo(28.5, 1, 30.5, 3, 31.2, 7);          // right shoulder
        ctx.lineTo(31.8, 14);
        ctx.bezierCurveTo(32.2, 18, 30.5, 19.6, 28.2, 19.6);   // right grip
        ctx.bezierCurveTo(26.2, 19.6, 25.2, 18.4, 24, 16.6);
        ctx.bezierCurveTo(23.2, 15.4, 22.4, 15, 21, 15);
        ctx.lineTo(11, 15);                                     // gap between grips
        ctx.bezierCurveTo(9.6, 15, 8.8, 15.4, 8, 16.6);
        ctx.bezierCurveTo(6.8, 18.4, 5.8, 19.6, 3.8, 19.6);    // left grip
        ctx.bezierCurveTo(1.5, 19.6, -0.2, 18, 0.2, 14);
        ctx.lineTo(0.8, 7);
        ctx.bezierCurveTo(1.5, 3, 3.5, 1, 8, 1);               // left shoulder
        ctx.closePath();
    }

    // taller body with short grips, leaving room for big digits
    function boldPath(ctx) {
        ctx.beginPath();
        ctx.moveTo(7, 0.8);
        ctx.lineTo(10.2, 0.8);
        ctx.quadraticCurveTo(14, 1.9, 17.8, 0.8);                // dip between the shoulders
        ctx.lineTo(21, 0.8);
        ctx.bezierCurveTo(25.4, 0.8, 27.3, 2.5, 27.6, 6);       // right shoulder
        ctx.lineTo(27.9, 14.6);
        ctx.bezierCurveTo(28.1, 18.5, 26.9, 19.8, 25, 19.8);    // right grip
        ctx.bezierCurveTo(23.2, 19.8, 22.3, 18.6, 21.4, 17.2);
        ctx.bezierCurveTo(20.9, 16.4, 20.3, 15.8, 19.2, 15.8);
        ctx.lineTo(8.8, 15.8);                                   // gap between grips
        ctx.bezierCurveTo(7.7, 15.8, 7.1, 16.4, 6.6, 17.2);
        ctx.bezierCurveTo(5.7, 18.6, 4.8, 19.8, 3, 19.8);       // left grip
        ctx.bezierCurveTo(1.1, 19.8, -0.1, 18.5, 0.1, 14.6);
        ctx.lineTo(0.4, 6);
        ctx.bezierCurveTo(0.7, 2.5, 2.6, 0.8, 7, 0.8);          // left shoulder
        ctx.closePath();
    }

    function fontSpec(weight, px) {
        return weight + " " + px + "px '" + Kirigami.Theme.defaultFont.family + "'";
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width <= 0 || height <= 0)
            return;

        const s = Math.min(width / unitW, height / unitH);
        const ox = (width - unitW * s) / 2;
        const oy = (height - unitH * s) / 2;
        const known = level >= 0;

        ctx.save();
        ctx.translate(ox, oy);
        ctx.scale(s, s);
        if (variant === 0)
            classicPath(ctx);
        else
            boldPath(ctx);
        ctx.fillStyle = color;
        if (variant === 2 && known) {
            // empty part dimmed, charged part solid
            ctx.clip();
            ctx.globalAlpha = 0.38;
            ctx.fillRect(0, 0, unitW, unitH);
            ctx.globalAlpha = 1;
            ctx.fillRect(0, 0, unitW * Math.min(level, 100) / 100, unitH);
        } else {
            ctx.fill();
        }
        ctx.restore();

        // text area inside the body, above the grips
        const box = variant === 0
            ? { x: 4.5, w: 23, top: 3.6, cap: 8.6, pct: 0.6, weight: "bold" }
            : { x: 2.4, w: 23.2, top: 3.4, cap: 10.2, pct: 0, weight: "800" };
        const boxX = ox + box.x * s;
        const boxW = box.w * s;
        const capH = box.cap * s;
        const centerY = oy + (box.top + box.cap / 2) * s;

        const digits = known ? String(level) : "–";
        const pct = known && box.pct > 0 ? "%" : "";

        // digits large, % smaller, both shrunk together to fit
        let size = capH / 0.72;
        ctx.font = fontSpec(box.weight, size);
        let wDigits = ctx.measureText(digits).width;
        ctx.font = fontSpec(box.weight, size * box.pct);
        let wPct = pct ? ctx.measureText(pct).width : 0;
        const gapRatio = pct ? 0.04 : 0;
        const total = wDigits + wPct + size * gapRatio;
        if (total > boxW) {
            const f = boxW / total;
            size *= f;
            wDigits *= f;
            wPct *= f;
        }
        const gap = size * gapRatio;

        const baseline = centerY + size * 0.72 / 2;
        let x = boxX + (boxW - (wDigits + gap + wPct)) / 2;

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "black";
        ctx.textBaseline = "alphabetic";
        ctx.font = fontSpec(box.weight, size);
        ctx.fillText(digits, x, baseline);
        if (pct) {
            x += wDigits + gap;
            ctx.font = fontSpec(box.weight, size * box.pct);
            ctx.fillText(pct, x, baseline);
        }

        if (charging) {
            ctx.globalCompositeOperation = "source-over";
            ctx.beginPath();
            const dotY = variant === 0 ? 17.6 : 18.1;
            ctx.arc(ox + unitW / 2 * s, oy + dotY * s, 1.5 * s, 0, 2 * Math.PI);
            ctx.fillStyle = chargingColor;
            ctx.fill();
        }
    }
}
