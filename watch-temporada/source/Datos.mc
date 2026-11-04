using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.WatchUi;

// Agenda y retos: lo descargado de GitHub Pages tiene prioridad sobre lo incluido al compilar.
module Datos {
    function agendaValida(data) {
        return data instanceof Lang.Dictionary && data["dias"] instanceof Lang.Array;
    }

    function retosValidos(data) {
        return data instanceof Lang.Dictionary && data["retos"] instanceof Lang.Array;
    }

    function agenda() {
        var stored = Application.Storage.getValue("agenda");
        return agendaValida(stored) ? stored : WatchUi.loadResource(Rez.JsonData.AgendaInicial);
    }

    function sugerenciasValidas(data) {
        return data instanceof Lang.Dictionary && data["sugerencias"] instanceof Lang.Array;
    }

    function sugerencias() {
        var stored = Application.Storage.getValue("sugerencias");
        return sugerenciasValidas(stored) ? stored : WatchUi.loadResource(Rez.JsonData.SugerenciasInicial);
    }

    function retos() {
        var stored = Application.Storage.getValue("retos");
        return retosValidos(stored) ? stored : WatchUi.loadResource(Rez.JsonData.RetosInicial);
    }

    // Sesiones de la agenda cruzadas con el historial:
    // [{dn, tipo, detalle, cat, hecho}], ordenadas por día.
    // Cada actividad del día cubre como mucho una sesión de su categoría.
    function sesiones(acts) {
        var dias = agenda()["dias"];
        var rows = [];
        // Ordena los días por fecha (inserción; son pocos).
        var ordered = [];
        for (var i = 0; i < dias.size(); i++) {
            var dn = Historial.parseDate(dias[i]["fecha"]);
            var pos = ordered.size();
            while (pos > 0 && ordered[pos - 1][0] > dn) {
                pos -= 1;
            }
            ordered = ordered.slice(0, pos).addAll([[dn, dias[i]]]).addAll(ordered.slice(pos, null));
        }
        for (var k = 0; k < ordered.size(); k++) {
            var dayN = ordered[k][0];
            var lista = ordered[k][1]["sesiones"];
            var used = [];
            for (var j = 0; j < acts.size(); j++) {
                used.add(false);
            }
            for (var s = 0; s < lista.size(); s++) {
                var cat = Historial.agendaCategory(lista[s]["tipo"]);
                var hecho = false;
                for (var j = 0; j < acts.size(); j++) {
                    if (!used[j] && acts[j]["dn"] == dayN && acts[j]["cat"].equals(cat)) {
                        used[j] = true;
                        hecho = true;
                        break;
                    }
                }
                rows.add({
                    "dn" => dayN,
                    "tipo" => lista[s]["tipo"],
                    "detalle" => lista[s]["detalle"],
                    "cat" => cat,
                    "hecho" => hecho
                });
            }
        }
        return rows;
    }
}

// Descarga agenda.json, retos.json y sugerencias.json al abrir la app y los guarda para usarlos sin conexión.
class Sync {
    function initialize() {
    }

    function start() {
        if (Config.BASE_URL.length() == 0) {
            return;
        }
        request("agenda.json", method(:onAgenda));
    }

    function request(file, callback) {
        Communications.makeWebRequest(
            Config.BASE_URL + file,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    function onAgenda(code, data) {
        if (code == 200 && Datos.agendaValida(data)) {
            store("agenda", data);
        }
        request("retos.json", method(:onRetos));
    }

    function onRetos(code, data) {
        if (code == 200 && Datos.retosValidos(data)) {
            store("retos", data);
        }
        request("sugerencias.json", method(:onSugerencias));
    }

    function onSugerencias(code, data) {
        if (code == 200 && Datos.sugerenciasValidas(data)) {
            store("sugerencias", data);
        }
    }

    function store(key, data) {
        try {
            Application.Storage.setValue(key, data);
        } catch (ex) {
            // Sin espacio: se sigue usando la última copia guardada.
        }
    }
}
