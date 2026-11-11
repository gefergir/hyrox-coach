using Toybox.Activity;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Resumen al terminar un entreno (plan o Simulacro HYROX).
// El ritmo de carrera solo cuenta los momentos en que de verdad corres: durante los
// ejercicios de carrera y con el GPS por encima de RUN_SPEED. Estaciones, transiciones
// y ratos andando o parado quedan fuera.
module ResumenEntreno {
    const PAGES = 3;
    const RUN_SPEED = 1.9;   // m/s (unos 8:45 /km): por debajo se considera andar o estar parado
    const RUN_COLOR = 0x4DA8FF;
    const ST_COLOR = 0x00E5A8;
    const MUTED = 0x8A9BB8;

    // Acumula el rato de carrera de un tick. Devuelve [ms, metros] a sumar.
    function sample(inRun, dtMs, lastDist) {
        var info = Activity.getActivityInfo();
        var dist = info != null && info.elapsedDistance != null ? info.elapsedDistance : lastDist;
        var speed = info != null && info.currentSpeed != null ? info.currentSpeed : 0.0;
        var dd = dist - lastDist;
        if (dd < 0) {
            dd = 0.0;
        }
        if (inRun && speed >= RUN_SPEED && dtMs > 0 && dtMs <= 3000) {
            return [dtMs, dd, dist];
        }
        return [0, 0.0, dist];
    }

    function distance() {
        var info = Activity.getActivityInfo();
        return info != null && info.elapsedDistance != null ? info.elapsedDistance : 0.0;
    }

    // segs: [{"n" => nombre, "ms" => duración, "run" => bool, "rest" => bool, "rms" => ms corriendo, "rd" => metros corriendo}]
    function build(title, result, totalMs, segs) {
        var info = Activity.getActivityInfo();
        var runMs = 0;
        var runDist = 0.0;
        var runSegs = [];
        var stMs = 0;
        var groups = {};
        var order = [];
        for (var i = 0; i < segs.size(); i++) {
            var s = segs[i];
            if (s["run"]) {
                runMs += s["rms"];
                runDist += s["rd"];
                if (s["rd"] >= 40 && s["rms"] > 0) {
                    runSegs.add([s["n"], (s["rms"] / (s["rd"] / 1000.0) / 1000).toNumber()]);
                }
            } else if (!s["rest"]) {
                stMs += s["ms"];
                if (groups[s["n"]] == null) {
                    groups[s["n"]] = [0, 0];
                    order.add(s["n"]);
                }
                groups[s["n"]][0] = groups[s["n"]][0] + s["ms"];
                groups[s["n"]][1] = groups[s["n"]][1] + 1;
            }
        }
        // Estaciones de más a menos tiempo
        var st = [];
        for (var i = 0; i < order.size(); i++) {
            var item = [order[i], groups[order[i]][0], groups[order[i]][1]];
            var pos = st.size();
            while (pos > 0 && st[pos - 1][1] < item[1]) {
                pos -= 1;
            }
            st = st.slice(0, pos).addAll([item]).addAll(st.slice(pos, null));
        }
        return {
            "title" => title,
            "result" => result,
            "total" => totalMs,
            "runMs" => runMs,
            "runDist" => runDist,
            "pace" => runDist >= 50 ? (runMs / (runDist / 1000.0) / 1000).toNumber() : null,
            "runSegs" => runSegs,
            "stMs" => stMs,
            "st" => st,
            "fcMed" => info != null ? info.averageHeartRate : null,
            "fcMax" => info != null ? info.maxHeartRate : null
        };
    }

    function fmt(ms) {
        var s = ms / 1000;
        if (s >= 3600) {
            return (s / 3600) + ":" + ((s / 60) % 60).format("%02d") + ":" + (s % 60).format("%02d");
        }
        return (s / 60) + ":" + (s % 60).format("%02d");
    }

    function fmtPace(secs) {
        return (secs / 60) + ":" + (secs % 60).format("%02d");
    }

    function fmtKm(m) {
        var t = (m / 10 + 0.5).toNumber();
        return (t / 100) + "," + (t % 100).format("%02d");
    }

    function text(dc, y, font, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function fit(dc, s, font, w) {
        return Graphics.fitTextToArea(s, font, w, dc.getFontHeight(font), true);
    }

    function dots(dc, page) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        for (var i = 0; i < PAGES; i++) {
            dc.setColor(i == page ? Graphics.COLOR_WHITE : 0x3A4A6B, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((w * 0.94).toNumber(), (h / 2 + (i - 1) * h * 0.045).toNumber(), i == page ? 4 : 3);
        }
    }

    // Fila centrada: "Etiqueta" en color y el valor en blanco a continuación.
    function row(dc, y, color, label, value) {
        var w = dc.getWidth();
        var font = Graphics.FONT_XTINY;
        var lw = dc.getTextWidthInPixels(label, font);
        var vw = dc.getTextWidthInPixels(value, font);
        var x = (w - lw - 8 - vw) / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + lw + 8, y, font, value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function draw(dc, s, page) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (page == 0) {
            text(dc, h * 0.12, Graphics.FONT_XTINY, fit(dc, s["title"].toUpper(), Graphics.FONT_XTINY, w * 0.74), ST_COLOR);
            text(dc, h * 0.2, Graphics.FONT_XTINY, fit(dc, s["result"], Graphics.FONT_XTINY, w * 0.7), MUTED);
            text(dc, h * 0.33, Graphics.FONT_NUMBER_MEDIUM, fmt(s["total"]), Graphics.COLOR_WHITE);
            if (s["pace"] != null) {
                row(dc, h * 0.5, RUN_COLOR, "Ritmo", fmtPace(s["pace"]) + " /km");
                row(dc, h * 0.58, RUN_COLOR, "Carrera", fmtKm(s["runDist"]) + " km · " + fmt(s["runMs"]));
            } else {
                row(dc, h * 0.54, RUN_COLOR, "Carrera", "no detectada");
            }
            row(dc, h * 0.66, ST_COLOR, "Estaciones", fmt(s["stMs"]));
            var fc = (s["fcMed"] != null ? s["fcMed"].toString() : "--") + " med · " + (s["fcMax"] != null ? s["fcMax"].toString() : "--") + " máx";
            row(dc, h * 0.74, 0xFF5C8A, "FC", fc);
            text(dc, h * 0.85, Graphics.FONT_XTINY, "UP/DOWN: detalle", 0x3A4A6B);
        } else if (page == 1) {
            drawRun(dc, s);
        } else {
            drawStations(dc, s);
        }
        dots(dc, page);
    }

    function drawRun(dc, s) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        text(dc, h * 0.12, Graphics.FONT_XTINY, "RITMO DE CARRERA", RUN_COLOR);
        if (s["pace"] == null) {
            text(dc, h * 0.45, Graphics.FONT_SMALL, "Sin carrera", Graphics.COLOR_WHITE);
            text(dc, h * 0.55, Graphics.FONT_XTINY, "No se detectaron tramos", MUTED);
            text(dc, h * 0.62, Graphics.FONT_XTINY, "corriendo con GPS", MUTED);
            return;
        }
        text(dc, h * 0.28, Graphics.FONT_NUMBER_MEDIUM, fmtPace(s["pace"]), Graphics.COLOR_WHITE);
        text(dc, h * 0.385, Graphics.FONT_XTINY, "/km · solo corriendo", MUTED);
        text(dc, h * 0.45, Graphics.FONT_XTINY, fmtKm(s["runDist"]) + " km en " + fmt(s["runMs"]), Graphics.COLOR_WHITE);

        var segs = s["runSegs"];
        if (segs.size() < 2) {
            return;
        }
        // Barras: más altas = más rápido
        var best = 0;
        var worst = 0;
        for (var i = 1; i < segs.size(); i++) {
            if (segs[i][1] < segs[best][1]) {
                best = i;
            }
            if (segs[i][1] > segs[worst][1]) {
                worst = i;
            }
        }
        var x0 = w * 0.18;
        var x1 = w * 0.82;
        var yBase = h * 0.7;
        var maxH = h * 0.2;
        var slot = (x1 - x0) / segs.size();
        var fast = segs[best][1].toFloat();
        var slow = segs[worst][1].toFloat();
        for (var i = 0; i < segs.size(); i++) {
            var t = slow > fast ? (slow - segs[i][1]) / (slow - fast) : 1.0;
            var bh = maxH * (0.35 + 0.65 * t);
            var color = i == best ? 0x2ECC71 : (i == worst ? 0xFF5C5C : 0x3D5A8C);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            var bw = slot * 0.65 < 2 ? 2 : slot * 0.65;
            dc.fillRoundedRectangle((x0 + slot * i + (slot - bw) / 2).toNumber(), (yBase - bh).toNumber(), bw.toNumber(), bh.toNumber(), 2);
        }
        dc.setColor(0x2ECC71, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w * 0.5 - 6).toNumber(), h * 0.78, Graphics.FONT_XTINY, "mejor " + fmtPace(segs[best][1]), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xFF5C5C, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w * 0.5 + 6).toNumber(), h * 0.78, Graphics.FONT_XTINY, "peor " + fmtPace(segs[worst][1]), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        text(dc, h * 0.86, Graphics.FONT_XTINY, segs.size() + " tramos de carrera", MUTED);
    }

    function drawStations(dc, s) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        text(dc, h * 0.12, Graphics.FONT_XTINY, "ESTACIONES · " + fmt(s["stMs"]), ST_COLOR);
        var st = s["st"];
        if (st.size() == 0) {
            text(dc, h * 0.45, Graphics.FONT_XTINY, "Sin estaciones registradas", MUTED);
            return;
        }
        var maxMs = st[0][1];
        var y = h * 0.24;
        var n = st.size() < 6 ? st.size() : 6;
        for (var i = 0; i < n; i++) {
            var name = fit(dc, st[i][0], Graphics.FONT_XTINY, w * 0.48);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText((w * 0.17).toNumber(), y, Graphics.FONT_XTINY, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            var times = fmt(st[i][1]) + (st[i][2] > 1 ? " ×" + st[i][2] : "");
            dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText((w * 0.84).toNumber(), y, Graphics.FONT_XTINY, times, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            var bw = (w * 0.67 * st[i][1] / maxMs).toNumber();
            dc.setColor(ST_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle((w * 0.17).toNumber(), (y + h * 0.035).toNumber(), bw < 2 ? 2 : bw, 3, 1);
            y += h * 0.1;
        }
    }
}
