using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

const KIND_INTERVAL = 0; // Salida cada X segundos, N rondas
const KIND_ROUNDS = 1;   // Cuenta atrás en la que LAP suma rondas
const KIND_REST = 2;     // Descanso entre bloques

module Plan {
    const STORAGE_KEY = "plan";

    function isValid(data) {
        return data instanceof Lang.Dictionary
            && data["sesiones"] instanceof Lang.Array
            && data["sesiones"].size() > 0;
    }

    // El plan descargado tiene prioridad sobre el incluido al compilar.
    function load() {
        var stored = Application.Storage.getValue(STORAGE_KEY);
        if (isValid(stored)) {
            return stored;
        }
        return WatchUi.loadResource(Rez.JsonData.PlanInicial);
    }

    // Sobrescribe el plan completo de la semana anterior.
    function save(data) {
        Application.Storage.setValue(STORAGE_KEY, data);
    }

    function dayLabel(dia) {
        var labels = {
            "lunes" => "Lunes",
            "martes" => "Martes",
            "miercoles" => "Miércoles",
            "jueves" => "Jueves",
            "viernes" => "Viernes",
            "sabado" => "Sábado",
            "domingo" => "Domingo"
        };
        var label = labels[dia];
        return label != null ? label : dia;
    }

    function todayKey() {
        // Gregorian.day_of_week: 1 = domingo ... 7 = sábado.
        var keys = ["domingo", "lunes", "martes", "miercoles", "jueves", "viernes", "sabado"];
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return keys[info.day_of_week - 1];
    }

    function buildMenu(status) {
        var plan = load();
        var sesiones = plan["sesiones"];
        var menu = new WatchUi.Menu2({:title => "Semana " + plan["semana"]});
        var today = todayKey();
        var focus = 0;

        for (var i = 0; i < sesiones.size(); i++) {
            var sesion = sesiones[i];
            menu.addItem(new WatchUi.MenuItem(dayLabel(sesion["dia"]), sesion["nombre"], i, {}));
            if (today.equals(sesion["dia"])) {
                focus = i;
            }
        }
        menu.addItem(new WatchUi.MenuItem("Actualizar plan", status, :sync, {}));
        menu.setFocus(focus);
        return menu;
    }

    // Convierte los bloques de una sesión en una lista de pasos con crono.
    function buildSteps(sesion) {
        var bloques = sesion["bloques"];
        var steps = [];

        for (var i = 0; i < bloques.size(); i++) {
            var bloque = bloques[i];
            var timer = bloque["timer"];

            if ("intervalo".equals(timer["tipo"])) {
                var total = timer["rondas"];
                for (var r = 1; r <= total; r++) {
                    steps.add({
                        "kind" => $.KIND_INTERVAL,
                        "block" => i,
                        "name" => bloque["nombre"],
                        "secs" => timer["cada_s"],
                        "round" => r,
                        "rounds" => total,
                        "data" => bloque
                    });
                }
            } else {
                steps.add({
                    "kind" => $.KIND_ROUNDS,
                    "block" => i,
                    "name" => bloque["nombre"],
                    "secs" => timer["duracion_s"],
                    "round" => 0,
                    "rounds" => 0,
                    "data" => bloque
                });
            }

            var rest = bloque["descanso_s"];
            if (rest != null && rest > 0 && i < bloques.size() - 1) {
                steps.add({
                    "kind" => $.KIND_REST,
                    "block" => i,
                    "name" => "Descanso",
                    "secs" => rest,
                    "round" => 0,
                    "rounds" => 0,
                    "data" => null
                });
            }
        }
        return steps;
    }
}

class PlanMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :sync) {
            item.setSubLabel("Actualizando...");
            WatchUi.requestUpdate();
            Application.getApp().sync.start(true);
            return;
        }

        var sesiones = Plan.load()["sesiones"];
        if (id < sesiones.size()) {
            var view = new PlayerView(sesiones[id]);
            WatchUi.pushView(view, new PlayerDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }
}

class PlanSync {
    var manual;

    function initialize() {
        manual = false;
    }

    function start(isManual) {
        manual = isManual;
        if (Config.PLAN_URL.length() == 0) {
            finish("Sin URL configurada", manual);
            return;
        }
        Communications.makeWebRequest(
            Config.PLAN_URL,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    function onResponse(code, data) {
        if (code != 200 || !Plan.isValid(data)) {
            finish("Error " + code, manual);
            return;
        }

        var changed = Plan.load()["semana"] != data["semana"];
        try {
            Plan.save(data);
        } catch (ex) {
            finish("Sin espacio", manual);
            return;
        }
        finish("Plan actualizado", manual || changed);
    }

    function finish(status, refresh) {
        if (refresh && $.gPlayer == null) {
            WatchUi.switchToView(Plan.buildMenu(status), new PlanMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}
