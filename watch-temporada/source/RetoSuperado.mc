using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Datos de un reto ya hecho: la actividad de ese día, la comparación con tus carreras
// anteriores y cómo fue la preparación. Todo sale del historial del reloj; el pulso y los
// parciales por km salen del análisis de los FIT (stats.json), si lo hay.
module RetoStats {
    const PREP_DIAS = 56;      // 8 semanas de preparación
    const ANIO = 365;

    // La actividad del día del reto que mejor encaja, o null.
    function actividad(item, acts) {
        var reto = item["reto"];
        var dn = item["dn"];
        var esCarrera = !"hyrox".equals(reto["tipo"]);
        var meta = reto["distancia_km"].toFloat();
        var best = null;
        var bestScore = 0.0;
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] != dn) {
                continue;
            }
            var score;
            if (esCarrera) {
                if (!a["cat"].equals(Historial.CAT_CARRERA) || a["km"] <= 0) {
                    continue;
                }
                score = -(a["km"] - meta).abs();
            } else {
                // Primero las de tipo Hyrox; si no hay, la más larga de ese día.
                score = a["secs"].toFloat() + (a["cat"].equals(Historial.CAT_HYROX) ? 100000.0 : 0.0);
            }
            if (best == null || score > bestScore) {
                best = a;
                bestScore = score;
            }
        }
        return best;
    }

    function esCarrera(item) {
        return !"hyrox".equals(item["reto"]["tipo"]);
    }

    // Segundos por km, o null.
    function ritmo(a) {
        if (a == null || a["km"] < 0.5) {
            return null;
        }
        return (a["secs"] / a["km"]).toNumber();
    }

    // "32:15" o "1:05:20"
    function fmtTiempo(secs) {
        var s = secs.toNumber();
        var h = s / 3600;
        var m = (s % 3600) / 60;
        var r = s % 60;
        if (h > 0) {
            return h + ":" + m.format("%02d") + ":" + r.format("%02d");
        }
        return m + ":" + r.format("%02d");
    }

    // "4:52"
    function fmtRitmo(secsKm) {
        var s = secsKm.toNumber();
        return (s / 60) + ":" + (s % 60).format("%02d");
    }

    // Mejor ritmo en carreras de distancia parecida durante el año anterior al reto: [ritmo, km] o null.
    function mejorAnterior(item, acts) {
        var dn = item["dn"];
        var meta = item["reto"]["distancia_km"].toFloat();
        var best = null;
        var bestKm = 0.0;
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] >= dn || a["dn"] < dn - ANIO || !a["cat"].equals(Historial.CAT_CARRERA)) {
                continue;
            }
            if (a["km"] < meta * 0.8 || a["km"] > meta * 1.3) {
                continue;
            }
            var p = ritmo(a);
            if (p != null && (best == null || p < best)) {
                best = p;
                bestKm = a["km"];
            }
        }
        return best == null ? null : [best, bestKm];
    }

    // Las 8 semanas antes del reto.
    // {"n", "secs", "km", "larga", "semanas" => [8 valores], "ritmo" => s/km medio de carrera o null}
    function preparacion(item, acts) {
        var dn = item["dn"];
        var from = dn - PREP_DIAS;
        var carrera = esCarrera(item);
        var semanas = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        var n = 0;
        var secs = 0;
        var km = 0.0;
        var kmSecs = 0;
        var larga = 0.0;
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] >= dn || a["dn"] < from) {
                continue;
            }
            n += 1;
            secs += a["secs"];
            var w = (a["dn"] - from) / 7;
            if (w > 7) {
                w = 7;
            }
            if (a["cat"].equals(Historial.CAT_CARRERA)) {
                km += a["km"];
                if (a["km"] > 0) {
                    kmSecs += a["secs"];
                }
                if (a["km"] > larga) {
                    larga = a["km"];
                }
                if (carrera) {
                    semanas[w] += a["km"];
                }
            }
            if (!carrera) {
                semanas[w] += 1.0;
            }
        }
        return {
            "n" => n,
            "secs" => secs,
            "km" => km,
            "larga" => larga,
            "semanas" => semanas,
            "ritmo" => km >= 1.0 ? (kmSecs / km).toNumber() : null
        };
    }

    // Datos del análisis de los FIT para la fecha del reto, o null.
    function analisis(fecha) {
        var st = WatchUi.loadResource(Rez.JsonData.Stats);
        if (!(st instanceof Lang.Dictionary) || !(st["retos"] instanceof Lang.Dictionary)) {
            return null;
        }
        var r = st["retos"][fecha];
        return r instanceof Lang.Dictionary ? r : null;
    }
}

class RetoSuperadoView extends WatchUi.View {
    var item;
    var act;
    var mejor;
    var prep;
    var fitData;
    var pages;
    var page;

    function initialize(aItem, aAct, acts) {
        View.initialize();
        item = aItem;
        act = aAct;
        mejor = RetoStats.mejorAnterior(aItem, acts);
        prep = RetoStats.preparacion(aItem, acts);
        fitData = RetoStats.analisis(aItem["reto"]["fecha"]);
        pages = fitData != null ? 4 : 3;
        page = 0;
    }

    function move(delta) {
        page = (page + delta + pages) % pages;
        WatchUi.requestUpdate();
    }

    function color() {
        return RetoStats.esCarrera(item) ? Graf.CARRERA : Graf.HYROX;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (page == 0) {
            drawMedalla(dc);
        } else if (page == 1) {
            drawMarca(dc);
        } else if (page == 2) {
            drawPreparacion(dc);
        } else {
            drawPulso(dc);
        }
        Graf.pageDots(dc, page, pages);
    }

    // --- 1. Medalla ---

    function confeti(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var colores = [Graf.GOLD, Graf.HYROX, Graf.CARRERA, Graf.GYM, 0xFF6FB5];
        var seed = item["dn"] % 65521 + 7;
        for (var i = 0; i < 26; i++) {
            seed = (seed * 75 + 74) % 65537;
            var x = (seed % 1000) * w / 1000;
            seed = (seed * 75 + 74) % 65537;
            var y = (seed % 1000) * h / 1000;
            // Fuera de la zona central, donde va el texto.
            if (x > w * 0.2 && x < w * 0.8 && y > h * 0.1 && y < h * 0.9) {
                continue;
            }
            dc.setColor(colores[i % colores.size()], Graphics.COLOR_TRANSPARENT);
            if (i % 2 == 0) {
                dc.fillRectangle(x, y, 5, 3);
            } else {
                dc.fillCircle(x, y, 2);
            }
        }
    }

    function medalla(dc, cx, cy, r) {
        var cinta = color();
        var top = (cy - r * 2.1).toNumber();
        dc.setColor(cinta, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - r, top], [cx - r * 0.35, top], [cx + r * 0.25, cy - r * 0.6], [cx - r * 0.35, cy - r * 0.6]]);
        dc.setColor(Graf.mixColor(cinta, 0x000000, 0.35), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + r, top], [cx + r * 0.35, top], [cx - r * 0.25, cy - r * 0.6], [cx + r * 0.35, cy - r * 0.6]]);

        dc.setColor(0xB8860B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(Graf.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 0.82).toNumber());
        dc.setColor(0xFFE08A, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, (r * 0.66).toNumber());
        dc.setPenWidth(1);

        var reto = item["reto"];
        var t = RetoStats.esCarrera(item) ? Historial.fmtKm(reto["distancia_km"].toFloat()) + "K" : "HYROX";
        if (t.find(",0K") != null) {
            t = t.substring(0, t.length() - 3) + "K";
        }
        Graf.text(dc, cx, cy, Graphics.FONT_XTINY, t, 0x5A3E00);
    }

    function drawMedalla(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        confeti(dc);
        Graf.text(dc, w / 2, h * 0.11, Graphics.FONT_XTINY, "¡RETO SUPERADO!", Graf.GOLD);
        medalla(dc, w / 2, (h * 0.35).toNumber(), (w * 0.11).toNumber());

        var reto = item["reto"];
        Graf.text(dc, w / 2, h * 0.54, Graphics.FONT_XTINY, Graf.fit(dc, reto["nombre"], Graphics.FONT_XTINY, w * 0.74), Graphics.COLOR_WHITE);
        Graf.text(dc, w / 2, h * 0.67, Graphics.FONT_MEDIUM, RetoStats.fmtTiempo(act["secs"]), Graphics.COLOR_WHITE);

        var p = RetoStats.ritmo(act);
        var linea = RetoStats.esCarrera(item) && p != null
            ? RetoStats.fmtRitmo(p) + " /km · " + Historial.fmtKm(act["km"]) + " km"
            : Historial.fmtDur(act["secs"]);
        Graf.text(dc, w / 2, h * 0.78, Graphics.FONT_XTINY, linea, color());

        var f = reto["fecha"];
        Graf.text(dc, w / 2, h * 0.87, Graphics.FONT_XTINY, f.substring(8, 10) + "/" + f.substring(5, 7) + "/" + f.substring(0, 4), Graf.MUTED);
    }

    // --- 2. Tu marca frente a lo anterior ---

    function diff(dc, y, delta, texto) {
        var w = dc.getWidth();
        var baja = delta < 0;
        var c = baja ? Graf.GOOD : (delta == 0 ? Graf.MUTED : Graf.BAD);
        var s = (baja ? "-" : "+") + delta.abs() + " s/km " + texto;
        Graf.arrow(dc, w * 0.16, y, w * 0.025, baja, c);
        Graf.text(dc, w * 0.53, y, Graphics.FONT_XTINY, Graf.fit(dc, s, Graphics.FONT_XTINY, w * 0.66), c);
    }

    function drawMarca(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "TU MARCA", Graf.GOLD);
        var p = RetoStats.ritmo(act);
        if (!RetoStats.esCarrera(item) || p == null) {
            Graf.text(dc, w / 2, h * 0.32, Graphics.FONT_MEDIUM, RetoStats.fmtTiempo(act["secs"]), Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.44, Graphics.FONT_XTINY, "tiempo total", Graf.MUTED);
            var hx = prep["n"];
            Graf.text(dc, w / 2, h * 0.6, Graphics.FONT_XTINY, hx + " entrenos en 8 semanas", Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.7, Graphics.FONT_XTINY, "Repítelo y compara tu tiempo", Graf.MUTED);
            return;
        }

        Graf.text(dc, w / 2, h * 0.3, Graphics.FONT_MEDIUM, RetoStats.fmtRitmo(p) + " /km", Graphics.COLOR_WHITE);
        Graf.text(dc, w / 2, h * 0.41, Graphics.FONT_XTINY, "ritmo medio", Graf.MUTED);

        if (mejor == null) {
            Graf.text(dc, w / 2, h * 0.56, Graphics.FONT_XTINY, "Primera a esta distancia", Graf.GOLD);
            Graf.text(dc, w / 2, h * 0.64, Graphics.FONT_XTINY, "¡Ya tienes marca que batir!", Graf.MUTED);
        } else if (p < mejor[0]) {
            Graf.text(dc, w / 2, h * 0.56, Graphics.FONT_XTINY, "¡Mejor ritmo del año!", Graf.GOLD);
            diff(dc, h * 0.64, p - mejor[0], "vs " + RetoStats.fmtRitmo(mejor[0]));
        } else {
            diff(dc, h * 0.6, p - mejor[0], "vs tu mejor " + RetoStats.fmtRitmo(mejor[0]));
        }

        var r = prep["ritmo"];
        if (r != null) {
            diff(dc, h * 0.75, p - r, "vs entrenos");
        }
    }

    // --- 3. La preparación ---

    function drawPreparacion(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var carrera = RetoStats.esCarrera(item);
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "PREPARACIÓN · 8 SEM", Graf.GOLD);

        var sem = prep["semanas"];
        var max = 1.0;
        for (var i = 0; i < sem.size(); i++) {
            if (sem[i] > max) {
                max = sem[i];
            }
        }
        var x0 = w * 0.2;
        var bw = w * 0.6 / sem.size();
        var base = h * 0.46;
        var alto = h * 0.24;
        for (var i = 0; i < sem.size(); i++) {
            var bh = (sem[i] / max * alto).toNumber();
            var c = i == sem.size() - 1 ? Graf.GOLD : color();
            dc.setColor(sem[i] > 0 ? c : Graf.PANEL, Graphics.COLOR_TRANSPARENT);
            var x = (x0 + i * bw + 2).toNumber();
            if (bh < 3) {
                bh = 3;
            }
            dc.fillRoundedRectangle(x, (base - bh).toNumber(), (bw - 4).toNumber(), bh, 2);
        }
        Graf.text(dc, w / 2, h * 0.51, Graphics.FONT_XTINY, carrera ? "km por semana" : "entrenos por semana", Graf.MUTED);

        Graf.text(dc, w / 2, h * 0.62, Graphics.FONT_XTINY, prep["n"] + " entrenos · " + Historial.fmtDur(prep["secs"]), Graphics.COLOR_WHITE);
        if (prep["km"] > 0) {
            Graf.text(dc, w / 2, h * 0.71, Graphics.FONT_XTINY, Historial.fmtKm(prep["km"]) + " km corridos", Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.8, Graphics.FONT_XTINY, "Más larga: " + Historial.fmtKm(prep["larga"]) + " km", Graf.MUTED);
        }
    }

    // --- 4. Pulso y parciales (del análisis de los FIT) ---

    function drawPulso(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "PULSO Y PARCIALES", Graf.GOLD);
        var fc = fitData["fc"] != null ? fitData["fc"] + "" : "--";
        var fcm = fitData["fcm"] != null ? fitData["fcm"] + "" : "--";
        Graf.text(dc, w * 0.35, h * 0.24, Graphics.FONT_SMALL, fc, Graphics.COLOR_WHITE);
        Graf.text(dc, w * 0.65, h * 0.24, Graphics.FONT_SMALL, fcm, Graf.BAD);
        Graf.text(dc, w * 0.35, h * 0.32, Graphics.FONT_XTINY, "FC media", Graf.MUTED);
        Graf.text(dc, w * 0.65, h * 0.32, Graphics.FONT_XTINY, "FC máx", Graf.MUTED);

        var p = fitData["p"];
        if (p instanceof Lang.Array && p.size() > 0) {
            var lo = p[0];
            var hi = p[0];
            var best = 0;
            for (var i = 1; i < p.size(); i++) {
                if (p[i] < lo) {
                    lo = p[i];
                    best = i;
                }
                if (p[i] > hi) {
                    hi = p[i];
                }
            }
            var n = p.size();
            var x0 = w * 0.17;
            var bw = w * 0.66 / n;
            var base = h * 0.62;
            var alto = h * 0.2;
            for (var i = 0; i < n; i++) {
                // Más rápido = barra más alta.
                var t = hi > lo ? (hi - p[i]).toFloat() / (hi - lo) : 1.0;
                var bh = (alto * (0.35 + 0.65 * t)).toNumber();
                dc.setColor(i == best ? Graf.GOLD : color(), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle((x0 + i * bw + 1).toNumber(), (base - bh).toNumber(), (bw - 2).toNumber() > 1 ? (bw - 2).toNumber() : 1, bh, 2);
            }
            Graf.text(dc, w / 2, h * 0.67, Graphics.FONT_XTINY, "km más rápido: " + (best + 1) + " (" + RetoStats.fmtRitmo(lo) + ")", Graf.MUTED);
        }

        var m = fitData["m"];
        if (m instanceof Lang.Array && m.size() == 2) {
            var neg = m[1] < m[0];
            Graf.text(dc, w / 2, h * 0.77, Graphics.FONT_XTINY, RetoStats.fmtRitmo(m[0]) + " · " + RetoStats.fmtRitmo(m[1]) + " /km", Graphics.COLOR_WHITE);
            Graf.text(dc, w / 2, h * 0.85, Graphics.FONT_XTINY, neg ? "¡Split negativo!" : "1ª mitad · 2ª mitad", neg ? Graf.GOOD : Graf.MUTED);
        }
    }
}
