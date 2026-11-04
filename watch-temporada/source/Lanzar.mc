using Toybox.Application;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;
using Toybox.WatchUi;

// Al pulsar una sesión de la agenda:
// - hyrox: abre la app Hyrox Coach.
// - gym: abre el entreno "Fuerza" (arranca la actividad nativa Fuerza).
// - rodaje y tirada: abre "Correr libre" (arranca la actividad nativa Correr).
// - series: deja elegir la serie; el reloj guía cada repetición.
// Los entrenos los descarga la app desde GitHub Pages (docs/entrenos).
// El reloj siempre pide confirmación antes de salir de la app.
module Lanzar {
    const HYROX_COACH = "manifest-id://5f0c2a7e-9b3d-4c61-a8e4-d17b6c3f9a20";
    const FUERZA = "Fuerza";
    const CORRER = "Correr libre";

    // Entrenos descargados por esta app: {nombre => Workout}
    function appWorkouts() {
        var map = {};
        if (!(PersistedContent has :getAppWorkouts)) {
            return map;
        }
        var it = PersistedContent.getAppWorkouts();
        var w = it.next();
        while (w != null) {
            map[w.getName()] = w;
            w = it.next();
        }
        return map;
    }

    // Todos los entrenos del reloj (incluidos los copiados por USB o creados en Garmin Connect).
    function allWorkouts() {
        var list = [];
        if (!(PersistedContent has :getWorkouts)) {
            return list;
        }
        var it = PersistedContent.getWorkouts();
        var w = it.next();
        while (w != null) {
            list.add(w);
            w = it.next();
        }
        return list;
    }

    // Busca por nombre: primero los descargados por la app y luego todos.
    function find(name) {
        var w = appWorkouts()[name];
        if (w != null) {
            return w;
        }
        var all = allWorkouts();
        for (var i = 0; i < all.size(); i++) {
            if (name.equals(all[i].getName())) {
                return all[i];
            }
        }
        return null;
    }

    function isSeries(name) {
        var n = name.toLower();
        return n.find("serie") != null || n.find("fartlek") != null;
    }

    function exit(intent) {
        try {
            System.exitTo(intent);
        } catch (ex instanceof System.AppNotInstalledException) {
            aviso("Falta Hyrox Coach", "Instálala en el reloj");
        } catch (ex) {
            // Ya hay una confirmación abierta.
        }
    }

    function aviso(title, sub) {
        var m = new WatchUi.Menu2({:title => "Aviso"});
        m.addItem(new WatchUi.MenuItem(title, sub, 0, {}));
        WatchUi.pushView(m, new SoloLecturaDelegate(), WatchUi.SLIDE_LEFT);
    }

    function openNamed(name) {
        var w = find(name);
        if (w != null) {
            exit(w.toIntent());
        } else {
            aviso("Falta «" + name + "»", "Abre la app con el móvil");
        }
    }

    function session(row) {
        var tipo = row["tipo"];
        if ("hyrox".equals(tipo)) {
            exit(new System.Intent(HYROX_COACH, {}));
        } else if ("gym".equals(tipo)) {
            openNamed(FUERZA);
        } else if ("series".equals(tipo)) {
            seriesMenu(row);
        } else {
            openNamed(CORRER);
        }
    }

    function seriesMenu(row) {
        // Series de la app (en el orden del catálogo) y luego las demás del reloj.
        var list = [];
        var seen = {};
        var index = Application.Storage.getValue("entrenosIndex");
        if (index instanceof Lang.Dictionary && index["entrenos"] instanceof Lang.Array) {
            var e = index["entrenos"];
            for (var i = 0; i < e.size(); i++) {
                if ("series".equals(e[i]["tipo"])) {
                    var w = find(e[i]["nombre"]);
                    if (w != null && seen[w.getName()] == null) {
                        list.add(w);
                        seen[w.getName()] = true;
                    }
                }
            }
        }
        var all = allWorkouts();
        for (var i = 0; i < all.size(); i++) {
            var name = all[i].getName();
            if (seen[name] == null && isSeries(name)) {
                list.add(all[i]);
                seen[name] = true;
            }
        }
        if (list.size() == 0) {
            aviso("Sin series todavía", "Abre la app con el móvil");
            return;
        }
        var menu = new WatchUi.Menu2({:title => "Elige serie"});
        var focus = 0;
        var detalle = row["detalle"] != null ? row["detalle"].toLower() : "";
        for (var i = 0; i < list.size(); i++) {
            var name = list[i].getName();
            menu.addItem(new WatchUi.MenuItem(name, null, i, {}));
            if (detalle.find(name.toLower()) != null) {
                focus = i;
            }
        }
        menu.setFocus(focus);
        WatchUi.pushView(menu, new WorkoutPickerDelegate(list), WatchUi.SLIDE_LEFT);
    }
}

class WorkoutPickerDelegate extends WatchUi.Menu2InputDelegate {
    var list;

    function initialize(aList) {
        Menu2InputDelegate.initialize();
        list = aList;
    }

    function onSelect(item) {
        Lanzar.exit(list[item.getId()].toIntent());
    }
}

class SemanaDelegate extends WatchUi.Menu2InputDelegate {
    var rows;

    function initialize(aRows) {
        Menu2InputDelegate.initialize();
        rows = aRows;
    }

    function onSelect(item) {
        var id = item.getId();
        if (rows != null && id < rows.size()) {
            Lanzar.session(rows[id]);
        }
    }
}
