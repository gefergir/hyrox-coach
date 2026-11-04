using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.WatchUi;

// Utilidades de dibujo compartidas por Resumen y Logros.
module Graf {
    const GYM = 0xFFB347;
    const CARRERA = 0x4DA8FF;
    const HYROX = 0x00E5A8;
    const MUTED = 0x8A9BB8;
    const PANEL = 0x1E2A44;
    const GOOD = 0x2ECC71;
    const BAD = 0xFF5C5C;
    const GOLD = 0xFFC93C;
    const CENTER = 4 | 1; // TEXT_JUSTIFY_VCENTER | TEXT_JUSTIFY_CENTER

    function catColor(cat) {
        if (Historial.CAT_GYM.equals(cat)) {
            return GYM;
        }
        if (Historial.CAT_CARRERA.equals(cat)) {
            return CARRERA;
        }
        return HYROX;
    }

    function text(dc, x, y, font, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function fit(dc, s, font, width) {
        return Graphics.fitTextToArea(s, font, width, dc.getFontHeight(font), true);
    }

    // Puntos de página en el borde derecho.
    function pageDots(dc, page, count) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var step = h * 0.045;
        var y0 = h / 2 - step * (count - 1) / 2;
        for (var i = 0; i < count; i++) {
            dc.setColor(i == page ? Graphics.COLOR_WHITE : 0x3A4A6B, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((w * 0.94).toNumber(), (y0 + i * step).toNumber(), i == page ? 4 : 3);
        }
    }

    // Flecha arriba o abajo para comparaciones.
    function arrow(dc, x, y, size, up, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var s = size.toNumber();
        var xi = x.toNumber();
        var yi = y.toNumber();
        if (up) {
            dc.fillPolygon([[xi - s, yi + s / 2], [xi + s, yi + s / 2], [xi, yi - s]]);
        } else {
            dc.fillPolygon([[xi - s, yi - s / 2], [xi + s, yi - s / 2], [xi, yi + s]]);
        }
    }

    function flame(dc, x, y, s) {
        dc.setColor(0xFF7A3D, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y - s], [x + s * 0.55, y - s * 0.1], [x + s * 0.5, y + s * 0.5],
            [x, y + s * 0.8], [x - s * 0.5, y + s * 0.5], [x - s * 0.55, y - s * 0.1]
        ]);
        dc.setColor(0xFFD54A, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x, y - s * 0.2], [x + s * 0.28, y + s * 0.3], [x, y + s * 0.65], [x - s * 0.28, y + s * 0.3]
        ]);
    }
}

// Resumen en 4 páginas: semana, mes (calendario), por tipo (anillo) y tendencia.
class ResumenView extends WatchUi.View {
    const PAGES = 4;
    const LETRAS = ["L", "M", "X", "J", "V", "S", "D"];

    var page;
    var acts;
    var today;
    var mon;
    var byDay;   // {dn => [min gym, min carrera, min hyrox]}

    function initialize(aActs) {
        View.initialize();
        acts = aActs;
        page = 0;
        today = Historial.today();
        mon = Historial.monday(today);
        byDay = {};
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            var d = byDay[a["dn"]];
            if (d == null) {
                d = [0, 0, 0];
                byDay[a["dn"]] = d;
            }
            var k = Historial.CAT_GYM.equals(a["cat"]) ? 0 : (Historial.CAT_CARRERA.equals(a["cat"]) ? 1 : 2);
            d[k] = d[k] + a["secs"] / 60;
        }
    }

    function move(delta) {
        page = (page + delta + PAGES) % PAGES;
        WatchUi.requestUpdate();
    }

    function dayMins(dn) {
        var d = byDay[dn];
        return d == null ? [0, 0, 0] : d;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (page == 0) {
            drawWeek(dc);
        } else if (page == 1) {
            drawMonth(dc);
        } else if (page == 2) {
            drawTypes(dc);
        } else {
            drawTrend(dc);
        }
        Graf.pageDots(dc, page, PAGES);
    }

    // --- Página 1: semana con barras apiladas por día ---
    function drawWeek(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var t = Resumen.totals(acts, mon, today);
        var lw = Resumen.totals(acts, mon - 7, mon - 1);

        Graf.text(dc, w / 2, h * 0.13, Graphics.FONT_XTINY, "ESTA SEMANA", Graf.HYROX);
        Graf.text(dc, w / 2, h * 0.225, Graphics.FONT_MEDIUM, Historial.fmtDur(t["secs"]), Graphics.COLOR_WHITE);
        var sub = t["n"] + (t["n"] == 1 ? " sesión" : " sesiones");
        if (t["km"] >= 0.1) {
            sub += " · " + Historial.fmtKm(t["km"]) + " km";
        }
        Graf.text(dc, w / 2, h * 0.305, Graphics.FONT_XTINY, sub, Graf.MUTED);

        var dMin = (t["secs"] - lw["secs"]) / 60;
        var up = dMin >= 0;
        var cmp = (up ? "+" : "-") + Historial.fmtDur((up ? dMin : -dMin) * 60) + " vs pasada";
        var cw = dc.getTextWidthInPixels(cmp, Graphics.FONT_XTINY);
        Graf.arrow(dc, w / 2 - cw / 2 - 9, h * 0.365, 5, up, up ? Graf.GOOD : Graf.BAD);
        Graf.text(dc, w / 2 + 4, h * 0.365, Graphics.FONT_XTINY, cmp, up ? Graf.GOOD : Graf.BAD);

        var x0 = w * 0.17;
        var x1 = w * 0.83;
        var yTop = h * 0.43;
        var yBase = h * 0.71;
        var slot = (x1 - x0) / 7;
        var barW = slot * 0.62;
        var maxM = 60;
        for (var d = 0; d < 7; d++) {
            var m = dayMins(mon + d);
            var tot = m[0] + m[1] + m[2];
            maxM = tot > maxM ? tot : maxM;
        }
        dc.setColor(0x2B3D63, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0.toNumber(), yBase.toNumber() + 1, (x1 - x0).toNumber(), 2);
        var colors = [Graf.GYM, Graf.CARRERA, Graf.HYROX];
        for (var d = 0; d < 7; d++) {
            var dn = mon + d;
            var m = dayMins(dn);
            var bx = (x0 + slot * d + (slot - barW) / 2).toNumber();
            var y = yBase;
            var total = m[0] + m[1] + m[2];
            if (total == 0) {
                dc.setColor(dn <= today ? 0x2B3D63 : 0x1A2238, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(bx, (yBase - 4).toNumber(), barW.toNumber(), 4, 2);
            }
            for (var k = 0; k < 3; k++) {
                if (m[k] > 0) {
                    var bh = (yBase - yTop) * m[k] / maxM;
                    dc.setColor(colors[k], Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(bx, (y - bh).toNumber(), barW.toNumber(), bh.toNumber() + 1, 3);
                    y -= bh;
                }
            }
            var isToday = dn == today;
            Graf.text(dc, bx + barW / 2, h * 0.765, Graphics.FONT_XTINY, LETRAS[d], isToday ? Graf.HYROX : Graf.MUTED);
        }
        legend(dc, h * 0.86);
    }

    function legend(dc, y) {
        var w = dc.getWidth();
        var items = [["Gym", Graf.GYM], ["Carrera", Graf.CARRERA], ["Hyrox", Graf.HYROX]];
        var xs = [0.25, 0.50, 0.75];
        for (var i = 0; i < 3; i++) {
            var x = w * xs[i];
            var tw = dc.getTextWidthInPixels(items[i][0], Graphics.FONT_XTINY);
            dc.setColor(items[i][1], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((x - tw / 2 - 6).toNumber(), y.toNumber(), 3);
            Graf.text(dc, x + 2, y, Graphics.FONT_XTINY, items[i][0], Graf.MUTED);
        }
    }

    // --- Página 2: calendario de calor del mes ---
    function drawMonth(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var c = Historial.civil(today);
        var first = Historial.dayNumber(c[0], c[1], 1);
        var next = c[1] == 12 ? Historial.dayNumber(c[0] + 1, 1, 1) : Historial.dayNumber(c[0], c[1] + 1, 1);
        var offset = Historial.weekday(first);

        Graf.text(dc, w / 2, h * 0.13, Graphics.FONT_XTINY, Resumen.MESES[c[1] - 1].toUpper(), Graf.HYROX);
        for (var i = 0; i < 7; i++) {
            Graf.text(dc, w * (0.2 + 0.1 * i), h * 0.215, Graphics.FONT_XTINY, LETRAS[i], Graf.MUTED);
        }
        var r = (w * 0.033).toNumber();
        for (var dn = first; dn < next; dn++) {
            var idx = offset + dn - first;
            var x = (w * (0.2 + 0.1 * (idx % 7))).toNumber();
            var y = (h * (0.29 + 0.072 * (idx / 7))).toNumber();
            var m = dayMins(dn);
            var total = m[0] + m[1] + m[2];
            if (total > 0) {
                var k = m[0] >= m[1] && m[0] >= m[2] ? 0 : (m[1] >= m[2] ? 1 : 2);
                dc.setColor([Graf.GYM, Graf.CARRERA, Graf.HYROX][k], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, total >= 45 ? r : r - 2);
            } else if (dn <= today) {
                dc.setColor(Graf.PANEL, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, r - 2);
            } else {
                dc.setColor(0x1A2238, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, r - 3);
            }
            if (dn == today) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawCircle(x, y, r + 2);
                dc.setPenWidth(1);
            }
        }
        var t = Resumen.totals(acts, first, today);
        var line = t["n"] + " ses · " + Historial.fmtDur(t["secs"]);
        if (t["km"] >= 0.1) {
            line += " · " + Historial.fmtKm(t["km"]) + " km";
        }
        Graf.text(dc, w / 2, h * 0.775, Graphics.FONT_XTINY, line, Graphics.COLOR_WHITE);
        legend(dc, h * 0.855);
    }

    // --- Página 3: anillo con el reparto por tipo del mes ---
    function drawTypes(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var c = Historial.civil(today);
        var first = Historial.dayNumber(c[0], c[1], 1);
        var t = Resumen.totals(acts, first, today);
        var counts = [t["gym"], t["carrera"], t["hyrox"]];
        var colors = [Graf.GYM, Graf.CARRERA, Graf.HYROX];
        var names = ["Gym", "Carrera", "Hyrox"];
        var total = counts[0] + counts[1] + counts[2];

        Graf.text(dc, w / 2, h * 0.13, Graphics.FONT_XTINY, "TIPOS DEL MES", Graf.HYROX);
        var cx = (w / 2).toNumber();
        var cy = (h * 0.44).toNumber();
        var r = (w * 0.19).toNumber();
        var pen = (w * 0.07).toNumber();
        dc.setPenWidth(pen);
        if (total == 0) {
            dc.setColor(Graf.PANEL, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
        } else {
            var start = 90.0;
            for (var k = 0; k < 3; k++) {
                if (counts[k] == 0) {
                    continue;
                }
                var span = 360.0 * counts[k] / total;
                dc.setColor(colors[k], Graphics.COLOR_TRANSPARENT);
                if (span >= 359.5) {
                    dc.drawCircle(cx, cy, r);
                } else {
                    var a0 = start.toNumber();
                    var a1 = (start - span + 2).toNumber(); // pequeño hueco entre tramos
                    dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, (a0 + 360) % 360, (a1 + 720) % 360);
                }
                start -= span;
            }
        }
        dc.setPenWidth(1);
        Graf.text(dc, cx, cy - h * 0.025, Graphics.FONT_MEDIUM, total.toString(), Graphics.COLOR_WHITE);
        Graf.text(dc, cx, cy + h * 0.055, Graphics.FONT_XTINY, total == 1 ? "sesión" : "sesiones", Graf.MUTED);

        for (var k = 0; k < 3; k++) {
            var y = h * (0.72 + 0.065 * k);
            var pct = total > 0 ? (counts[k] * 100 + total / 2) / total : 0;
            var s = names[k] + "  " + counts[k] + " · " + pct + "%";
            var tw = dc.getTextWidthInPixels(s, Graphics.FONT_XTINY);
            dc.setColor(colors[k], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((w / 2 - tw / 2 - 8).toNumber(), y.toNumber(), 4);
            Graf.text(dc, w / 2 + 2, y, Graphics.FONT_XTINY, s, Graphics.COLOR_WHITE);
        }
    }

    // --- Página 4: tendencia de las últimas 8 semanas ---
    function drawTrend(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.13, Graphics.FONT_XTINY, "8 SEMANAS", Graf.HYROX);

        var weeks = [];
        var maxM = 60;
        var sum = 0;
        for (var i = 7; i >= 0; i--) {
            var start = mon - 7 * i;
            var end = i == 0 ? today : start + 6;
            var m = Resumen.totals(acts, start, end)["secs"] / 60;
            weeks.add([start, m]);
            maxM = m > maxM ? m : maxM;
            if (i > 0) {
                sum += m;
            }
        }
        var avg = sum / 7;
        var x0 = w * 0.15;
        var x1 = w * 0.85;
        var yTop = h * 0.25;
        var yBase = h * 0.62;
        var slot = (x1 - x0) / 8;
        var barW = slot * 0.62;
        for (var i = 0; i < 8; i++) {
            var m = weeks[i][1];
            var bh = (yBase - yTop) * m / maxM;
            var bx = (x0 + slot * i + (slot - barW) / 2).toNumber();
            dc.setColor(i == 7 ? Graf.HYROX : 0x3D5A8C, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, (yBase - bh).toNumber(), barW.toNumber(), bh.toNumber() + 2, 3);
        }
        Graf.text(dc, x0 + slot, h * 0.665, Graphics.FONT_XTINY, "hace 8", Graf.MUTED);
        Graf.text(dc, x1 - slot / 2, h * 0.665, Graphics.FONT_XTINY, "esta", Graf.HYROX);
        // Línea de la media (discontinua)
        var ay = (yBase - (yBase - yTop) * avg / maxM).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var x = x0; x < x1; x += 8) {
            dc.drawLine(x.toNumber(), ay, (x + 4).toNumber(), ay);
        }
        Graf.text(dc, w / 2, h * 0.735, Graphics.FONT_XTINY, "Media " + Historial.fmtDur(avg * 60) + "/sem", Graphics.COLOR_WHITE);

        var racha = Resumen.racha(acts, today);
        var s = "Racha: " + racha + (racha == 1 ? " semana" : " semanas");
        var tw = dc.getTextWidthInPixels(s, Graphics.FONT_XTINY);
        Graf.flame(dc, w / 2 - tw / 2 - 10, h * 0.82, 9);
        Graf.text(dc, w / 2 + 6, h * 0.82, Graphics.FONT_XTINY, s, 0xFFB347);
    }
}

// Logros como carrusel de medallas.
class LogrosView extends WatchUi.View {
    var sel;
    var stats;
    var unlocked;

    function initialize(acts, lvl) {
        View.initialize();
        stats = Logros.stats(acts, lvl);
        unlocked = Logros.unlocked();
        // Empieza por el primer logro pendiente.
        sel = 0;
        for (var i = 0; i < Logros.LIST.size(); i++) {
            if (unlocked[Logros.LIST[i][0]] == null) {
                sel = i;
                break;
            }
        }
    }

    function move(delta) {
        var n = Logros.LIST.size();
        sel = (sel + delta + n) % n;
        WatchUi.requestUpdate();
    }

    function icon(dc, id, cx, cy, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var x = cx.toNumber();
        var y = cy.toNumber();
        if (id.equals("primer")) {
            var pts = [];
            for (var i = 0; i < 10; i++) {
                var r = i % 2 == 0 ? s : s * 0.45;
                var a = Math.PI / 2 + i * Math.PI / 5;
                pts.add([(cx + r * Math.cos(a)).toNumber(), (cy - r * Math.sin(a)).toNumber()]);
            }
            dc.fillPolygon(pts);
        } else if (id.equals("diez")) {
            dc.drawText(x, y, Graphics.FONT_MEDIUM, "10K", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (id.equals("cien")) {
            dc.drawText(x, (cy - s * 0.2).toNumber(), Graphics.FONT_SMALL, "100", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(x, (cy + s * 0.55).toNumber(), Graphics.FONT_XTINY, "km", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (id.equals("hyrox10")) {
            // Pesa rusa
            dc.fillCircle(x, (cy + s * 0.2).toNumber(), (s * 0.6).toNumber());
            dc.setPenWidth((s * 0.2).toNumber() + 1);
            dc.drawArc(x, (cy - s * 0.35).toNumber(), (s * 0.38).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
            dc.setPenWidth(1);
        } else if (id.equals("racha4")) {
            dc.fillPolygon([
                [x, (cy - s).toNumber()], [(cx + s * 0.55).toNumber(), (cy - s * 0.1).toNumber()],
                [(cx + s * 0.5).toNumber(), (cy + s * 0.5).toNumber()], [x, (cy + s * 0.8).toNumber()],
                [(cx - s * 0.5).toNumber(), (cy + s * 0.5).toNumber()], [(cx - s * 0.55).toNumber(), (cy - s * 0.1).toNumber()]
            ]);
        } else if (id.equals("reto")) {
            dc.fillPolygon([
                [(cx - s * 0.7).toNumber(), (cy - s * 0.8).toNumber()], [(cx + s * 0.7).toNumber(), (cy - s * 0.8).toNumber()],
                [(cx + s * 0.25).toNumber(), (cy + s * 0.15).toNumber()], [(cx - s * 0.25).toNumber(), (cy + s * 0.15).toNumber()]
            ]);
            dc.fillRectangle((cx - s * 0.1).toNumber(), (cy + s * 0.1).toNumber(), (s * 0.2).toNumber() + 1, (s * 0.45).toNumber());
            dc.fillRectangle((cx - s * 0.45).toNumber(), (cy + s * 0.5).toNumber(), (s * 0.9).toNumber(), (s * 0.25).toNumber() + 1);
        } else {
            // Corona
            dc.fillPolygon([
                [(cx - s * 0.8).toNumber(), (cy + s * 0.5).toNumber()], [(cx - s * 0.8).toNumber(), (cy - s * 0.5).toNumber()],
                [(cx - s * 0.4).toNumber(), (cy).toNumber()], [x, (cy - s * 0.75).toNumber()],
                [(cx + s * 0.4).toNumber(), (cy).toNumber()], [(cx + s * 0.8).toNumber(), (cy - s * 0.5).toNumber()],
                [(cx + s * 0.8).toNumber(), (cy + s * 0.5).toNumber()]
            ]);
        }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var list = Logros.LIST;
        var got = 0;
        for (var i = 0; i < list.size(); i++) {
            if (unlocked[list[i][0]] != null) {
                got += 1;
            }
        }
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "LOGROS " + got + "/" + list.size(), Graf.HYROX);

        // Fila de puntos: dorado conseguido, gris pendiente; el seleccionado más grande
        var dx = w * 0.065;
        var x0 = w / 2 - dx * (list.size() - 1) / 2;
        for (var i = 0; i < list.size(); i++) {
            var x = (x0 + dx * i).toNumber();
            var y = (h * 0.195).toNumber();
            var done = unlocked[list[i][0]] != null;
            dc.setColor(done ? Graf.GOLD : 0x3A4A6B, Graphics.COLOR_TRANSPARENT);
            if (i == sel) {
                dc.fillCircle(x, y, 6);
            } else if (done) {
                dc.fillCircle(x, y, 4);
            } else {
                dc.drawCircle(x, y, 4);
            }
        }

        var e = list[sel];
        var id = e[0];
        var done = unlocked[id] != null;
        var value = stats[id].toFloat();
        var goal = e[3].toFloat();
        var p = done ? 1.0 : (value / goal > 1.0 ? 1.0 : value / goal);

        // Medalla con anillo de progreso
        var cx = (w / 2).toNumber();
        var cy = (h * 0.43).toNumber();
        var R = (w * 0.15).toNumber();
        var ring = R + (w * 0.045).toNumber();
        dc.setPenWidth((w * 0.025).toNumber());
        dc.setColor(Graf.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, ring);
        if (p > 0) {
            dc.setColor(done ? Graf.GOLD : Graf.HYROX, Graphics.COLOR_TRANSPARENT);
            if (p >= 0.999) {
                dc.drawCircle(cx, cy, ring);
            } else {
                var end = (90 - 360 * p).toNumber();
                dc.drawArc(cx, cy, ring, Graphics.ARC_CLOCKWISE, 90, (end + 360) % 360);
            }
        }
        dc.setPenWidth(1);
        dc.setColor(done ? 0xE0A800 : 0x2A3550, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, R);
        dc.setColor(done ? Graf.GOLD : 0x33415F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, R - (w * 0.02).toNumber());
        icon(dc, id, cx, cy, R * 0.55, done ? 0x6B4A00 : Graf.MUTED);

        Graf.text(dc, w / 2, h * 0.665, Graphics.FONT_SMALL, Graf.fit(dc, e[1], Graphics.FONT_SMALL, w * 0.8), Graphics.COLOR_WHITE);
        Graf.text(dc, w / 2, h * 0.74, Graphics.FONT_XTINY, "Premio: " + e[2], Graf.MUTED);
        if (done) {
            var c = Historial.civil(unlocked[id]);
            Graf.text(dc, w / 2, h * 0.815, Graphics.FONT_XTINY, "¡Conseguido el " + c[2] + "/" + c[1] + "!", Graf.GOLD);
        } else {
            var unit = id.equals("diez") || id.equals("cien") ? " km" : "";
            Graf.text(dc, w / 2, h * 0.815, Graphics.FONT_XTINY,
                Logros.fmtValue(id, stats[id]) + " / " + e[3] + unit, Graphics.COLOR_WHITE);
            var bw = w * 0.36;
            var bx = ((w - bw) / 2).toNumber();
            var by = (h * 0.865).toNumber();
            dc.setColor(Graf.PANEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, by, bw.toNumber(), 6, 3);
            if (p > 0) {
                dc.setColor(Graf.HYROX, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(bx, by, (bw * p).toNumber() + 1, 6, 3);
            }
        }
    }
}

// UP/DOWN o deslizar cambia de página; START también avanza.
class PagerDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(aView) {
        BehaviorDelegate.initialize();
        view = aView;
    }

    function onNextPage() {
        view.move(1);
        return true;
    }

    function onPreviousPage() {
        view.move(-1);
        return true;
    }

    function onSelect() {
        view.move(1);
        return true;
    }
}
