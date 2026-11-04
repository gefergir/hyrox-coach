using Toybox.Lang;
using Toybox.WatchUi;

// Ideas de Hyrox, Hybrid Day y carreras populares (docs/sugerencias.json).
module Sugerencias {
    const MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

    function tipoLabel(tipo) {
        if ("hyrox".equals(tipo)) {
            return "Hyrox";
        }
        if ("hybrid".equals(tipo)) {
            return "Hybrid Day";
        }
        return "Carrera";
    }

    // "2026-12-13" -> "13 dic"
    function fmtFecha(text) {
        return text.substring(8, 10).toNumber() + " " + MESES[text.substring(5, 7).toNumber() - 1];
    }

    function fmtRango(s) {
        var fin = s["fecha_fin"];
        if (fin == null || fin.equals(s["fecha"])) {
            return fmtFecha(s["fecha"]);
        }
        if (fin.substring(5, 7).equals(s["fecha"].substring(5, 7))) {
            return s["fecha"].substring(8, 10).toNumber() + "-" + fmtFecha(fin);
        }
        return fmtFecha(s["fecha"]) + "-" + fmtFecha(fin);
    }

    // Solo las que no han pasado, ordenadas por fecha.
    function upcoming() {
        var list = Datos.sugerencias()["sugerencias"];
        var today = Historial.today();
        var out = [];
        for (var i = 0; i < list.size(); i++) {
            var s = list[i];
            var end = s["fecha_fin"] != null ? s["fecha_fin"] : s["fecha"];
            if (Historial.parseDate(end) < today) {
                continue;
            }
            var dn = Historial.parseDate(s["fecha"]);
            var pos = out.size();
            while (pos > 0 && out[pos - 1][0] > dn) {
                pos -= 1;
            }
            out = out.slice(0, pos).addAll([[dn, s]]).addAll(out.slice(pos, null));
        }
        return out;
    }

    function buildMenu() {
        var items = upcoming();
        var menu = new WatchUi.Menu2({:title => "Sugerencias"});
        if (items.size() == 0) {
            menu.addItem(new WatchUi.MenuItem("Sin sugerencias", "Pide a Claude que las actualice", 0, {}));
            return menu;
        }
        for (var i = 0; i < items.size(); i++) {
            var s = items[i][1];
            var sub = tipoLabel(s["tipo"]) + " · " + fmtRango(s) + " · " + s["lugar"];
            if (s["distancia_km"] != null) {
                sub += " · " + Historial.fmtKm(s["distancia_km"].toFloat()) + " km";
            }
            menu.addItem(new WatchUi.MenuItem(s["nombre"], sub, i, {}));
        }
        return menu;
    }
}
