using Toybox.Lang;
using Toybox.WatchUi;

// Resumen semanal y mensual de todos los entrenos que cuentan (10 min o más).
module Resumen {
    const MESES = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
                   "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];

    // Totales entre dos días (incluidos): {n, secs, km, gym, carrera, hyrox}
    function totals(acts, from, to) {
        var t = {"n" => 0, "secs" => 0, "km" => 0.0, "gym" => 0, "carrera" => 0, "hyrox" => 0};
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] >= from && a["dn"] <= to) {
                t["n"] = t["n"] + 1;
                t["secs"] = t["secs"] + a["secs"];
                t["km"] = t["km"] + a["km"];
                t[a["cat"]] = t[a["cat"]] + 1;
            }
        }
        return t;
    }

    function line(t) {
        if (t["n"] == 0) {
            return "Sin entrenos";
        }
        var text = t["n"] + " ses · " + Historial.fmtDur(t["secs"]);
        if (t["km"] >= 0.1) {
            text += " · " + Historial.fmtKm(t["km"]) + " km";
        }
        return text;
    }

    function signed(n) {
        return n > 0 ? "+" + n : n.toString();
    }

    // "+1 ses · +35m · -2,0 km"
    function delta(now, before) {
        var dMin = (now["secs"] - before["secs"]) / 60;
        var dKm = now["km"] - before["km"];
        var km = (dKm >= 0 ? "+" : "-") + Historial.fmtKm(dKm >= 0 ? dKm : -dKm);
        return signed(now["n"] - before["n"]) + " ses · " + signed(dMin) + "m · " + km + " km";
    }

    function byType(t) {
        return "Gym " + t["gym"] + " · Carr. " + t["carrera"] + " · Hyrox " + t["hyrox"];
    }

    // Semanas seguidas (hasta la última completa, o la actual si ya llega) con 3+ entrenos.
    function racha(acts, today) {
        var counts = {};
        for (var i = 0; i < acts.size(); i++) {
            var w = Historial.monday(acts[i]["dn"]);
            counts[w] = counts[w] == null ? 1 : counts[w] + 1;
        }
        var wk = Historial.monday(today);
        if (counts[wk] == null || counts[wk] < 3) {
            wk -= 7; // la semana actual aún puede completarse
        }
        var n = 0;
        while (counts[wk] != null && counts[wk] >= 3) {
            n += 1;
            wk -= 7;
        }
        return n;
    }

    function buildMenu(acts) {
        var today = Historial.today();
        var mon = Historial.monday(today);
        var week = totals(acts, mon, today);
        var lastWeek = totals(acts, mon - 7, mon - 1);

        var c = Historial.civil(today);
        var monthStart = Historial.dayNumber(c[0], c[1], 1);
        var py = c[1] == 1 ? c[0] - 1 : c[0];
        var pm = c[1] == 1 ? 12 : c[1] - 1;
        var lastMonthStart = Historial.dayNumber(py, pm, 1);
        var month = totals(acts, monthStart, today);
        var lastMonth = totals(acts, lastMonthStart, monthStart - 1);
        var rachaN = racha(acts, today);

        var items = [
            ["Esta semana", line(week)],
            ["Semana pasada", line(lastWeek)],
            ["Cambio semanal", delta(week, lastWeek)],
            [MESES[c[1] - 1], line(month)],
            [MESES[pm - 1], line(lastMonth)],
            ["Cambio mensual", delta(month, lastMonth)],
            [MESES[c[1] - 1] + " por tipo", byType(month)],
            ["Racha", rachaN == 1 ? "1 semana con 3+ entrenos" : rachaN + " semanas con 3+ entrenos"]
        ];
        var menu = new WatchUi.Menu2({:title => "Resumen"});
        for (var i = 0; i < items.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(items[i][0], items[i][1], i, {}));
        }
        return menu;
    }
}
