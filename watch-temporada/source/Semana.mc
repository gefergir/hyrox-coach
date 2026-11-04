using Toybox.Lang;
using Toybox.WatchUi;

module Semana {
    function tipoLabel(tipo) {
        var labels = {
            "gym" => "Gym",
            "series" => "Series",
            "rodaje" => "Rodaje",
            "tirada" => "Tirada",
            "hyrox" => "Hyrox"
        };
        var label = labels[tipo];
        return label != null ? label : tipo;
    }

    // Una línea por sesión: "Hoy · Gym" / "Hecho · Empuje".
    function buildMenu(acts) {
        var agenda = Datos.agenda();
        var rows = Datos.sesiones(acts);
        var today = Historial.today();
        var title = agenda["semana"] != null ? "Semana " + agenda["semana"] : "Semana";
        var menu = new WatchUi.Menu2({:title => title});
        var focus = -1;

        if (rows.size() == 0) {
            menu.addItem(new WatchUi.MenuItem("Sin sesiones", "Dicta tu semana en Claude", 0, {}));
            return menu;
        }
        for (var i = 0; i < rows.size(); i++) {
            var r = rows[i];
            var dn = r["dn"];
            var day = dn == today ? "Hoy" : Historial.dayShort(dn) + " " + dayOfMonth(dn);
            var state = r["hecho"] ? "Hecho · " : (dn < today ? "No hecho · " : "");
            menu.addItem(new WatchUi.MenuItem(day + " · " + tipoLabel(r["tipo"]), state + r["detalle"], i, {}));
            if (focus < 0 && dn >= today) {
                focus = i;
            }
        }
        menu.setFocus(focus < 0 ? rows.size() - 1 : focus);
        return menu;
    }

    // Día del mes a partir del número de día (inverso de dayNumber, H. Hinnant).
    function dayOfMonth(dn) {
        var z = dn + 719468;
        var era = (z >= 0 ? z : z - 146096) / 146097;
        var doe = z - era * 146097;
        var yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        var doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        var mp = (5 * doy + 2) / 153;
        return doy - (153 * mp + 2) / 5 + 1;
    }
}

class SoloLecturaDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
    }
}
