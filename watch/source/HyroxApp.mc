using Toybox.Application;
using Toybox.WatchUi;

// Entreno abierto. Evita cambiar el menú mientras se está entrenando.
var gPlayer = null;

class HyroxApp extends Application.AppBase {
    var sync;

    function initialize() {
        AppBase.initialize();
        sync = new PlanSync();
    }

    function getInitialView() {
        sync.start(false);
        return [Plan.buildMenu(null), new PlanMenuDelegate()];
    }

    function onStop(state) {
        // Si el sistema cierra la app, el entreno no se pierde.
        if ($.gPlayer != null) {
            $.gPlayer.saveIfOpen();
        }
    }
}
