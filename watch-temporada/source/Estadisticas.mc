using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.WatchUi;

// Estadísticas avanzadas que el reloj no calcula por sí mismo. Salen del análisis de los FIT
// (tools/analisis.py) y van dentro de la app: carga, eficiencia, series, hábitos y HYROX.
class EstadisticasView extends WatchUi.View {
    const PAGES = 5;
    const LETRAS = ["L", "M", "X", "J", "V", "S", "D"];

    var page;
    var st;

    function initialize() {
        View.initialize();
        page = 0;
        st = WatchUi.loadResource(Rez.JsonData.Stats);
    }

    function move(delta) {
        page = (page + delta + PAGES) % PAGES;
        WatchUi.requestUpdate();
    }

    function hayDato(key) {
        return st instanceof Lang.Dictionary && st[key] != null;
    }

    function pct(v) {
        var t = (v.abs() * 10 + 0.5).toNumber();
        return (v < 0 ? "-" : "+") + (t / 10) + "," + (t % 10) + " %";
    }

    function dec2(v) {
        var t = (v * 100 + 0.5).toNumber();
        return (t / 100) + "," + (t % 100).format("%02d");
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (!hayDato("carga")) {
            Graf.text(dc, w / 2, h * 0.4, Graphics.FONT_SMALL, "Sin análisis", Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.52, Graphics.FONT_XTINY, "Conecta el reloj al PC y", Graf.MUTED);
            Graf.text(dc, w / 2, h * 0.6, Graphics.FONT_XTINY, "pide «analiza mis entrenos»", Graf.MUTED);
            return;
        }
        if (page == 0) {
            drawLoad(dc);
        } else if (page == 1) {
            drawEfficiency(dc);
        } else if (page == 2) {
            drawSeries(dc);
        } else if (page == 3) {
            drawHabits(dc);
        } else {
            drawHyrox(dc);
        }
        Graf.pageDots(dc, page, PAGES);
        Graf.text(dc, w / 2, h * 0.94, Graphics.FONT_XTINY, "datos " + st["generado"].substring(8, 10) + "/" + st["generado"].substring(5, 7), 0x3A4A6B);
    }

    // --- 1. Carga: indicador del ratio agudo:crónico ---
    function ratioAngle(r) {
        var c = r < 0.5 ? 0.5 : (r > 2.0 ? 2.0 : r);
        return 180 - (c - 0.5) / 1.5 * 180;
    }

    function drawLoad(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "CARGA", Graf.HYROX);
        var cx = w / 2;
        var cy = (h * 0.47).toNumber();
        var r = (w * 0.27).toNumber();
        var pen = (w * 0.045).toNumber();
        var zones = [[0.5, 0.8, Graf.CARRERA], [0.8, 1.3, Graf.GOOD], [1.3, 1.5, 0xFFB000], [1.5, 2.0, Graf.BAD]];
        dc.setPenWidth(pen);
        for (var i = 0; i < zones.size(); i++) {
            dc.setColor(zones[i][2], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, ratioAngle(zones[i][0]).toNumber() - 1, ratioAngle(zones[i][1]).toNumber() + 1);
        }
        dc.setPenWidth(1);

        var hoy = st["hoy"];
        var ratio = hoy["ratio"];
        if (ratio != null) {
            var a = Math.toRadians(ratioAngle(ratio));
            var tip = [(cx + Math.cos(a) * (r - pen)).toNumber(), (cy - Math.sin(a) * (r - pen)).toNumber()];
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(cx, cy, tip[0], tip[1]);
            dc.setPenWidth(1);
            dc.fillCircle(cx, cy, 5);
            var zone = ratio < 0.8 ? "Carga baja" : (ratio <= 1.3 ? "Zona óptima" : (ratio <= 1.5 ? "Precaución" : "Riesgo alto"));
            var zc = ratio < 0.8 ? Graf.CARRERA : (ratio <= 1.3 ? Graf.GOOD : (ratio <= 1.5 ? 0xFFB000 : Graf.BAD));
            Graf.text(dc, w / 2, h * 0.56, Graphics.FONT_MEDIUM, dec2(ratio), Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.64, Graphics.FONT_XTINY, zone, zc);
        }
        Graf.text(dc, w / 2, h * 0.705, Graphics.FONT_XTINY,
            "Fatiga " + hoy["fatiga"].toNumber() + " · Forma " + hoy["forma"].toNumber(), Graf.MUTED);

        // Mini gráfico de 8 semanas: fatiga (verde) y forma (blanco)
        var serie = st["carga"];
        var x0 = w * 0.24;
        var x1 = w * 0.76;
        var y0 = h * 0.76;
        var y1 = h * 0.86;
        var maxV = 1.0;
        for (var i = 0; i < serie.size(); i++) {
            maxV = serie[i][1] > maxV ? serie[i][1] : maxV;
            maxV = serie[i][2] > maxV ? serie[i][2] : maxV;
        }
        for (var k = 1; k <= 2; k++) {
            dc.setColor(k == 1 ? Graf.HYROX : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            for (var i = 1; i < serie.size(); i++) {
                var xa = x0 + (x1 - x0) * (i - 1) / (serie.size() - 1);
                var xb = x0 + (x1 - x0) * i / (serie.size() - 1);
                dc.drawLine(xa.toNumber(), (y1 - (y1 - y0) * serie[i - 1][k] / maxV).toNumber(),
                    xb.toNumber(), (y1 - (y1 - y0) * serie[i][k] / maxV).toNumber());
            }
        }
    }

    // --- 2. Eficiencia: metros por latido y deriva ---
    function drawEfficiency(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "EFICIENCIA", Graf.HYROX);
        var mpl = st["mpl"];
        if (mpl.size() == 0) {
            Graf.text(dc, w / 2, h / 2, Graphics.FONT_XTINY, "Sin carreras con pulso", Graf.MUTED);
            return;
        }
        var last = mpl[mpl.size() - 1][1];
        Graf.text(dc, w / 2, h * 0.22, Graphics.FONT_MEDIUM, dec2(last) + " m", Graphics.COLOR_WHITE);
        if (mpl.size() >= 4) {
            var base = (mpl[0][1] + mpl[1][1] + mpl[2][1]) / 3.0;
            var d = (last - base) / base * 100;
            var cmp = pct(d) + " desde hace " + mpl.size() + " sem";
            var cw = dc.getTextWidthInPixels(cmp, Graphics.FONT_XTINY);
            Graf.arrow(dc, w / 2 - cw / 2 - 9, h * 0.3, 5, d >= 0, d >= 0 ? Graf.GOOD : Graf.BAD);
            Graf.text(dc, w / 2 + 4, h * 0.3, Graphics.FONT_XTINY, cmp, d >= 0 ? Graf.GOOD : Graf.BAD);
        }

        var minV = 99.0;
        var maxV = 0.0;
        for (var i = 0; i < mpl.size(); i++) {
            minV = mpl[i][1] < minV ? mpl[i][1] : minV;
            maxV = mpl[i][1] > maxV ? mpl[i][1] : maxV;
        }
        var lo = minV * 0.9;
        var span = maxV - lo > 0.01 ? maxV - lo : 0.01;
        var x0 = w * 0.17;
        var x1 = w * 0.83;
        var yTop = h * 0.37;
        var yBase = h * 0.62;
        var slot = (x1 - x0) / mpl.size();
        for (var i = 0; i < mpl.size(); i++) {
            var bh = (yBase - yTop) * (mpl[i][1] - lo) / span;
            var bx = (x0 + slot * i + slot * 0.2).toNumber();
            dc.setColor(i == mpl.size() - 1 ? Graf.HYROX : 0x3D5A8C, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, (yBase - bh).toNumber(), (slot * 0.6).toNumber(), bh.toNumber() + 2, 2);
        }
        Graf.text(dc, w / 2, h * 0.665, Graphics.FONT_XTINY, "Más alto = más en forma", Graf.MUTED);

        var der = st["deriva"];
        if (der.size() > 0) {
            var dv = der[der.size() - 1][1];
            var good = dv < 5;
            Graf.text(dc, w / 2, h * 0.75, Graphics.FONT_XTINY, "Deriva última larga: " + pct(dv), good ? Graf.GOOD : 0xFFB000);
            Graf.text(dc, w / 2, h * 0.82, Graphics.FONT_XTINY, good ? "Buena base aeróbica" : "Pulso sube al final", Graf.MUTED);
        }
    }

    // --- 3. Series y efecto gym ---
    function drawSeries(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "SERIES", Graf.HYROX);
        var ser = st["series"];
        if (ser.size() == 0) {
            Graf.text(dc, w / 2, h * 0.35, Graphics.FONT_XTINY, "Aún sin series detectadas", Graf.MUTED);
        } else {
            var sum = 0.0;
            var maxA = 3.0;
            for (var i = 0; i < ser.size(); i++) {
                sum += ser[i][1];
                maxA = ser[i][1].abs() > maxA ? ser[i][1].abs() : maxA;
            }
            var avg = sum / ser.size();
            Graf.text(dc, w / 2, h * 0.22, Graphics.FONT_MEDIUM, pct(avg), avg <= 3 ? Graf.GOOD : Graf.BAD);
            Graf.text(dc, w / 2, h * 0.3, Graphics.FONT_XTINY, "media de tus últimas " + ser.size(), Graf.MUTED);
            var x0 = w * 0.2;
            var x1 = w * 0.8;
            var yMid = h * 0.47;
            var half = h * 0.1;
            var slot = (x1 - x0) / ser.size();
            dc.setColor(0x2B3D63, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0.toNumber(), yMid.toNumber(), (x1 - x0).toNumber(), 1);
            for (var i = 0; i < ser.size(); i++) {
                var v = ser[i][1];
                var bh = half * v.abs() / maxA;
                var bx = (x0 + slot * i + slot * 0.2).toNumber();
                dc.setColor(v > 0 ? Graf.BAD : Graf.GOOD, Graphics.COLOR_TRANSPARENT);
                if (v > 0) {
                    dc.fillRoundedRectangle(bx, (yMid - bh).toNumber(), (slot * 0.6).toNumber(), bh.toNumber() + 2, 2);
                } else {
                    dc.fillRoundedRectangle(bx, yMid.toNumber(), (slot * 0.6).toNumber(), bh.toNumber() + 2, 2);
                }
            }
            Graf.text(dc, w / 2, h * 0.61, Graphics.FONT_XTINY, "Rojo: aflojas al final", Graf.MUTED);
        }

        var eg = st["efecto_gym"];
        if (eg != null) {
            var d = eg["dif_pct"];
            Graf.text(dc, w / 2, h * 0.71, Graphics.FONT_XTINY, "EFECTO GYM", Graf.GYM);
            Graf.text(dc, w / 2, h * 0.78, Graphics.FONT_TINY, pct(d) + " eficiencia", d >= 0 ? Graf.GOOD : Graf.BAD);
            Graf.text(dc, w / 2, h * 0.85, Graphics.FONT_XTINY, "en carreras tras gym", Graf.MUTED);
        }
    }

    // --- 4. Hábitos: mapa de calor día x franja de 3 h ---
    function drawHabits(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "CUÁNDO ENTRENAS", Graf.HYROX);
        var mapa = st["mapa"];
        var grid = [];
        var maxC = 1;
        var bestD = 0;
        var bestB = 0;
        for (var d = 0; d < 7; d++) {
            var row = [];
            for (var b = 0; b < 8; b++) {
                var c = mapa[d][b * 3] + mapa[d][b * 3 + 1] + mapa[d][b * 3 + 2];
                row.add(c);
                if (c > maxC) {
                    maxC = c;
                    bestD = d;
                    bestB = b;
                }
            }
            grid.add(row);
        }
        var cell = (w * 0.06).toNumber();
        var gap = 3;
        var x0 = (w / 2 - (cell + gap) * 4 + gap / 2 + w * 0.03).toNumber();
        var y0 = (h * 0.18).toNumber();
        for (var d = 0; d < 7; d++) {
            var y = y0 + d * (cell + gap);
            Graf.text(dc, x0 - cell / 2 - 6, y + cell / 2, Graphics.FONT_XTINY, LETRAS[d], Graf.MUTED);
            for (var b = 0; b < 8; b++) {
                var c = grid[d][b];
                var col = c == 0 ? 0x161E33 : Graf.mixColor(0x14423A, Graf.HYROX, c.toFloat() / maxC);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x0 + b * (cell + gap), y, cell, cell, 3);
            }
        }
        var yl = y0 + 7 * (cell + gap) + 8;
        var labels = [[0, "0h"], [4, "12h"], [7, "21h"]];
        for (var i = 0; i < labels.size(); i++) {
            Graf.text(dc, x0 + labels[i][0] * (cell + gap) + cell / 2, yl, Graphics.FONT_XTINY, labels[i][1], Graf.MUTED);
        }
        var dias = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"];
        Graf.text(dc, w / 2, h * 0.8, Graphics.FONT_XTINY, "Pico: " + dias[bestD] + " " + (bestB * 3) + "-" + (bestB * 3 + 3) + "h", Graphics.COLOR_WHITE);
        if (st["descanso_medio"] != null) {
            var dm = st["descanso_medio"];
            Graf.text(dc, w / 2, h * 0.86, Graphics.FONT_XTINY, "Entrenas cada " + dec2(dm) + " días", Graf.MUTED);
        }
    }

    // --- 5. HYROX por estaciones ---
    function drawHyrox(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "HYROX", Graf.HYROX);
        var est = st["estaciones"];
        var keys = est instanceof Lang.Dictionary ? est.keys() : [];
        if (keys.size() == 0) {
            Graf.text(dc, w / 2, h * 0.42, Graphics.FONT_SMALL, "Pendiente", Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.52, Graphics.FONT_XTINY, "Haz un Simulacro HYROX o", Graf.MUTED);
            Graf.text(dc, w / 2, h * 0.59, Graphics.FONT_XTINY, "entrena con Hyrox Coach", Graf.MUTED);
            Graf.text(dc, w / 2, h * 0.66, Graphics.FONT_XTINY, "y analiza de nuevo", Graf.MUTED);
            return;
        }
        var y = h * 0.22;
        var shown = 0;
        for (var i = 0; i < keys.size() && shown < 7; i++) {
            var list = est[keys[i]];
            if (list.size() == 0) {
                continue;
            }
            var last = list[list.size() - 1];
            var name = Graf.fit(dc, keys[i], Graphics.FONT_XTINY, w * 0.42);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText((w * 0.16).toNumber(), y, Graphics.FONT_XTINY, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            var t = (last / 60) + ":" + (last % 60).format("%02d");
            var color = Graphics.COLOR_WHITE;
            if (list.size() > 1) {
                var prev = list[list.size() - 2];
                color = last <= prev ? Graf.GOOD : Graf.BAD;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText((w * 0.84).toNumber(), y, Graphics.FONT_XTINY, t, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            y += h * 0.085;
            shown += 1;
        }
    }
}
