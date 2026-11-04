using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

const SEM_VERDE = 0;
const SEM_AMBAR = 1;
const SEM_ROJO = 2;
const SEM_SIN_DATOS = 3;
const SEM_PASADO = 4;

// Semáforo de cada reto. Es una estimación a partir de las últimas 4 semanas.
module Retos {
    const VENTANA = 28;

    // Retos ordenados por fecha: [{reto, dn}].
    function ordered() {
        var list = Datos.retos()["retos"];
        var out = [];
        for (var i = 0; i < list.size(); i++) {
            var dn = Historial.parseDate(list[i]["fecha"]);
            var pos = out.size();
            while (pos > 0 && out[pos - 1]["dn"] > dn) {
                pos -= 1;
            }
            out = out.slice(0, pos).addAll([{"reto" => list[i], "dn" => dn}]).addAll(out.slice(pos, null));
        }
        return out;
    }

    // Sesiones de la agenda de una categoría ya vencidas: [hechas, planificadas].
    function cumplimiento(rows, cat, today) {
        var done = 0;
        var planned = 0;
        for (var i = 0; i < rows.size(); i++) {
            var r = rows[i];
            if (!r["cat"].equals(cat)) {
                continue;
            }
            if (r["dn"] < today || (r["dn"] == today && r["hecho"])) {
                planned += 1;
                if (r["hecho"]) {
                    done += 1;
                }
            }
        }
        return [done, planned];
    }

    // {"sem" => SEM_*, "motivo" => texto}
    function evaluate(item, acts, rows, today) {
        var reto = item["reto"];
        if (item["dn"] < today) {
            return {"sem" => $.SEM_PASADO, "motivo" => "Ya pasó"};
        }
        var from = today - VENTANA;
        if ("hyrox".equals(reto["tipo"])) {
            return evaluateHyrox(acts, rows, today, from);
        }
        return evaluateCarrera(reto["distancia_km"].toFloat(), acts, rows, today, from);
    }

    function evaluateCarrera(dist, acts, rows, today, from) {
        var runs = 0;
        var sumKm = 0.0;
        var longest = 0.0;
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] > from && a["dn"] <= today && a["cat"].equals(Historial.CAT_CARRERA)) {
                runs += 1;
                sumKm += a["km"];
                if (a["km"] > longest) {
                    longest = a["km"];
                }
            }
        }
        if (runs < 3) {
            return {"sem" => $.SEM_SIN_DATOS, "motivo" => runs + " carreras en 4 semanas"};
        }
        var weekly = sumKm / 4.0;
        var reqLong = dist * 0.75;
        var reqWeekly = dist <= 10 ? dist : dist * 1.3;
        var c = cumplimiento(rows, Historial.CAT_CARRERA, today);
        var rc = c[1] > 0 ? c[0].toFloat() / c[1] : 2.0;
        var rl = longest / reqLong;
        var rw = weekly / reqWeekly;

        var sem = $.SEM_AMBAR;
        if (rl < 0.6 || rw < 0.5 || rc < 0.4) {
            sem = $.SEM_ROJO;
        } else if (rl >= 1.0 && rw >= 1.0 && rc >= 0.7) {
            sem = $.SEM_VERDE;
        }

        // El motivo es el factor más flojo.
        var motivo = "Tirada más larga: " + Historial.fmtKm(longest) + " km";
        if (rw < rl && rw <= rc) {
            motivo = "Media semanal: " + Historial.fmtKm(weekly) + " km";
        } else if (rc < rl && rc < rw) {
            motivo = "Agenda: " + c[0] + "/" + c[1] + " carreras hechas";
        }
        return {"sem" => sem, "motivo" => motivo};
    }

    function evaluateHyrox(acts, rows, today, from) {
        var n = 0;
        var all = 0;
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] > from && a["dn"] <= today) {
                all += 1;
                if (a["cat"].equals(Historial.CAT_HYROX)) {
                    n += 1;
                }
            }
        }
        if (all < 3) {
            return {"sem" => $.SEM_SIN_DATOS, "motivo" => all + " entrenos en 4 semanas"};
        }
        var c = cumplimiento(rows, Historial.CAT_HYROX, today);
        var rc = c[1] > 0 ? c[0].toFloat() / c[1] : 2.0;
        var sem = $.SEM_AMBAR;
        if (n < 4 || rc < 0.4) {
            sem = $.SEM_ROJO;
        } else if (n >= 8 && rc >= 0.7) {
            sem = $.SEM_VERDE;
        }
        var motivo = "Sesiones Hyrox (4 sem): " + n;
        if (rc < 0.7 && n >= 4) {
            motivo = "Agenda: " + c[0] + "/" + c[1] + " hyrox hechos";
        }
        return {"sem" => sem, "motivo" => motivo};
    }

    function semLabel(sem) {
        if (sem == $.SEM_VERDE) {
            return "Verde";
        }
        if (sem == $.SEM_AMBAR) {
            return "Ámbar";
        }
        if (sem == $.SEM_ROJO) {
            return "Rojo";
        }
        if (sem == $.SEM_PASADO) {
            return "Ya pasó";
        }
        return "Sin datos suficientes";
    }

    function semColor(sem) {
        if (sem == $.SEM_VERDE) {
            return 0x2ECC71;
        }
        if (sem == $.SEM_AMBAR) {
            return 0xFFB000;
        }
        if (sem == $.SEM_ROJO) {
            return 0xFF3B30;
        }
        return Graphics.COLOR_DK_GRAY;
    }

    function daysText(days) {
        if (days < 0) {
            return "Ya pasó";
        }
        if (days == 0) {
            return "¡Es hoy!";
        }
        return days == 1 ? "Falta 1 día" : "Faltan " + days + " días";
    }

    function buildMenu(acts) {
        var items = ordered();
        var rows = Datos.sesiones(acts);
        var today = Historial.today();
        var menu = new WatchUi.Menu2({:title => "Retos"});
        for (var i = 0; i < items.size(); i++) {
            var ev = evaluate(items[i], acts, rows, today);
            var sub = daysText(items[i]["dn"] - today);
            if (ev["sem"] != $.SEM_PASADO) {
                sub += " · " + (ev["sem"] == $.SEM_SIN_DATOS ? "sin datos" : semLabel(ev["sem"]) + " (est.)");
            }
            menu.addItem(new WatchUi.MenuItem(items[i]["reto"]["nombre"], sub, i, {}));
        }
        return menu;
    }
}

class RetosDelegate extends WatchUi.Menu2InputDelegate {
    var acts;

    function initialize(aActs) {
        Menu2InputDelegate.initialize();
        acts = aActs;
    }

    function onSelect(item) {
        var items = Retos.ordered();
        var i = item.getId();
        if (i < items.size()) {
            var today = Historial.today();
            var ev = Retos.evaluate(items[i], acts, Datos.sesiones(acts), today);
            WatchUi.pushView(new RetoView(items[i], ev, today), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

class RetoView extends WatchUi.View {
    var item;
    var ev;
    var today;

    function initialize(aItem, aEv, aToday) {
        View.initialize();
        item = aItem;
        ev = aEv;
        today = aToday;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var reto = item["reto"];
        var sem = ev["sem"];

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var name = Graphics.fitTextToArea(reto["nombre"], Graphics.FONT_TINY, w * 0.72, dc.getFontHeight(Graphics.FONT_TINY) * 2, true);
        dc.drawText(w / 2, h * 0.17, Graphics.FONT_TINY, name, center);

        var f = reto["fecha"];
        var info = f.substring(8, 10) + "/" + f.substring(5, 7) + "/" + f.substring(0, 4)
            + " · " + Historial.fmtKm(reto["distancia_km"].toFloat()) + " km";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.29, Graphics.FONT_XTINY, info, center);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.38, Graphics.FONT_SMALL, Retos.daysText(item["dn"] - today), center);

        var r = (w * 0.09).toNumber();
        var cy = (h * 0.55).toNumber();
        dc.setColor(Retos.semColor(sem), Graphics.COLOR_TRANSPARENT);
        if (sem == $.SEM_SIN_DATOS || sem == $.SEM_PASADO) {
            dc.setPenWidth(3);
            dc.drawCircle(w / 2, cy, r);
            dc.setPenWidth(1);
        } else {
            dc.fillCircle(w / 2, cy, r);
        }

        var label = Retos.semLabel(sem);
        if (sem != $.SEM_SIN_DATOS && sem != $.SEM_PASADO) {
            label += " · estimación";
        }
        dc.setColor(Retos.semColor(sem) == Graphics.COLOR_DK_GRAY ? Graphics.COLOR_LT_GRAY : Retos.semColor(sem), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.70, Graphics.FONT_XTINY, label, center);

        var motivo = Graphics.fitTextToArea(ev["motivo"], Graphics.FONT_XTINY, w * 0.78, dc.getFontHeight(Graphics.FONT_XTINY), true);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.80, Graphics.FONT_XTINY, motivo, center);
    }
}
