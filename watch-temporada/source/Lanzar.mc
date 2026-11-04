using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;
using Toybox.WatchUi;

// Al pulsar una sesión de la agenda:
// - Hyrox: abre la app Hyrox Coach.
// - Gym y carrera: abre el entreno guardado en el reloj cuyo nombre coincida
//   (por ejemplo "Series" o "Empuje"); si no hay ninguno, deja elegir de la lista.
// El reloj siempre pide confirmación antes de salir de la app.
module Lanzar {
    const HYROX_COACH = "manifest-id://5f0c2a7e-9b3d-4c61-a8e4-d17b6c3f9a20";

    function workouts() {
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

    function contains(text, word) {
        return text != null && word != null && word.length() > 0
            && text.toLower().find(word.toLower()) != null;
    }

    // Primero por el detalle ("Empuje"), luego por el tipo ("Series", "Rodaje"...).
    function match(list, row) {
        var keys = [row["detalle"], Semana.tipoLabel(row["tipo"])];
        for (var k = 0; k < keys.size(); k++) {
            for (var i = 0; i < list.size(); i++) {
                if (contains(list[i].getName(), keys[k])) {
                    return list[i];
                }
            }
        }
        return null;
    }

    function exit(intent) {
        try {
            System.exitTo(intent);
        } catch (ex instanceof System.AppNotInstalledException) {
            WatchUi.pushView(Aviso.menu("No está instalada", "Instala Hyrox Coach"), new SoloLecturaDelegate(), WatchUi.SLIDE_LEFT);
        } catch (ex) {
            // Ya hay una confirmación abierta: no hace falta hacer nada.
        }
    }

    function session(row) {
        if (row["cat"].equals(Historial.CAT_HYROX)) {
            exit(new System.Intent(HYROX_COACH, {}));
            return;
        }
        var list = workouts();
        var w = match(list, row);
        if (w != null) {
            exit(w.toIntent());
            return;
        }
        if (list.size() == 0) {
            WatchUi.pushView(Aviso.menu("Sin entrenos guardados", "Créalos en Garmin Connect"), new SoloLecturaDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        var menu = new WatchUi.Menu2({:title => "Elige entreno"});
        for (var i = 0; i < list.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(list[i].getName(), null, i, {}));
        }
        WatchUi.pushView(menu, new WorkoutPickerDelegate(list), WatchUi.SLIDE_LEFT);
    }
}

module Aviso {
    function menu(title, sub) {
        var m = new WatchUi.Menu2({:title => "Aviso"});
        m.addItem(new WatchUi.MenuItem(title, sub, 0, {}));
        return m;
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
