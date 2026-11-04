using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// Logros desde el día en que nació la mascota. Cada uno le da un accesorio.
// Una vez conseguidos se guardan y no se pierden.
module Logros {
    // [id, nombre, accesorio, objetivo]
    const LIST = [
        ["primer", "Primer entreno", "Muñequeras", 1],
        ["diez", "Primer 10K", "Zapatillas rojas", 10],
        ["cien", "100 km corriendo", "Dorsal", 100],
        ["hyrox10", "10 sesiones Hyrox", "Medalla", 10],
        ["racha4", "4 semanas seguidas", "Cinta dorada", 4],
        ["reto", "Reto completado", "Trofeo", 1],
        ["nivel10", "Nivel 10", "Corona", 10]
    ];

    function unlocked() {
        var u = Application.Storage.getValue("logros");
        return u instanceof Lang.Dictionary ? u : {};
    }

    function tiene(id) {
        return unlocked()[id] != null;
    }

    // Valores actuales de cada logro (solo actividades desde el inicio de la mascota).
    function stats(acts, lvl) {
        var inicio = Historial.parseDate(Mascota.INICIO);
        var today = Historial.today();
        var n = 0;
        var maxKm = 0.0;
        var sumKm = 0.0;
        var hyrox = 0;
        var weeks = {};
        var byDay = {};
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] < inicio) {
                continue;
            }
            n += 1;
            if (a["cat"].equals(Historial.CAT_CARRERA)) {
                sumKm += a["km"];
                if (a["km"] > maxKm) {
                    maxKm = a["km"];
                }
            } else if (a["cat"].equals(Historial.CAT_HYROX)) {
                hyrox += 1;
            }
            var w = Historial.monday(a["dn"]);
            weeks[w] = weeks[w] == null ? 1 : weeks[w] + 1;
            byDay[a["dn"].toString() + a["cat"]] = true;
        }

        // Mejor racha de semanas con 3+ entrenos
        var best = 0;
        var cur = 0;
        for (var wk = Historial.monday(inicio); wk <= today; wk += 7) {
            if (weeks[wk] != null && weeks[wk] >= 3) {
                cur += 1;
                best = cur > best ? cur : best;
            } else {
                cur = 0;
            }
        }

        // Reto completado: entrenaste su tipo el día del reto
        var retoOk = 0;
        var retos = Datos.retos()["retos"];
        for (var i = 0; i < retos.size(); i++) {
            var dn = Historial.parseDate(retos[i]["fecha"]);
            var cat = "hyrox".equals(retos[i]["tipo"]) ? Historial.CAT_HYROX : Historial.CAT_CARRERA;
            if (dn >= inicio && dn <= today && byDay[dn.toString() + cat] != null) {
                retoOk = 1;
            }
        }

        return {
            "primer" => n,
            "diez" => maxKm,
            "cien" => sumKm,
            "hyrox10" => hyrox,
            "racha4" => best,
            "reto" => retoOk,
            "nivel10" => lvl
        };
    }

    // Desbloquea los nuevos. Devuelve el nombre del último conseguido o null.
    function update(acts, lvl) {
        var s = stats(acts, lvl);
        var u = unlocked();
        var nuevo = null;
        for (var i = 0; i < LIST.size(); i++) {
            var id = LIST[i][0];
            if (u[id] == null && s[id] >= LIST[i][3]) {
                u[id] = Historial.today();
                nuevo = LIST[i][1];
            }
        }
        Application.Storage.setValue("logros", u);
        if (nuevo != null) {
            Application.Storage.setValue("logroNuevo", nuevo);
        }
        return nuevo;
    }

    function fmtValue(id, v) {
        if (id.equals("diez") || id.equals("cien")) {
            return Historial.fmtKm(v);
        }
        return v.toNumber().toString();
    }

    function buildMenu(acts, lvl) {
        var s = stats(acts, lvl);
        var u = unlocked();
        var got = 0;
        for (var i = 0; i < LIST.size(); i++) {
            if (u[LIST[i][0]] != null) {
                got += 1;
            }
        }
        var menu = new WatchUi.Menu2({:title => "Logros " + got + "/" + LIST.size()});
        for (var i = 0; i < LIST.size(); i++) {
            var id = LIST[i][0];
            var sub;
            if (u[id] != null) {
                var c = Historial.civil(u[id]);
                sub = "Hecho " + c[2] + "/" + c[1] + " · " + LIST[i][2];
            } else {
                sub = fmtValue(id, s[id]) + "/" + LIST[i][3] + " · " + LIST[i][2];
            }
            menu.addItem(new WatchUi.MenuItem(LIST[i][1], sub, i, {}));
        }
        return menu;
    }
}
