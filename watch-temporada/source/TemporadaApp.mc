using Toybox.Application;
using Toybox.WatchUi;

class TemporadaApp extends Application.AppBase {
    var sync;

    function initialize() {
        AppBase.initialize();
        sync = new Sync();
    }

    function getInitialView() {
        // Suma a la mascota las actividades nuevas y descarga agenda y retos.
        Mascota.update(Historial.load());
        sync.start();

        var menu = new WatchUi.Menu2({:title => "Mi Temporada"});
        menu.addItem(new WatchUi.MenuItem("Mascota", null, :mascota, {}));
        menu.addItem(new WatchUi.MenuItem("Semana", null, :semana, {}));
        menu.addItem(new WatchUi.MenuItem("Retos", null, :retos, {}));
        menu.addItem(new WatchUi.MenuItem("Sugerencias", null, :sugerencias, {}));
        menu.addItem(new WatchUi.MenuItem("Info", "Cómo gana puntos", :info, {}));
        return [menu, new MainMenuDelegate()];
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :info) {
            WatchUi.pushView(Info.buildMenu(), new SoloLecturaDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :sugerencias) {
            WatchUi.pushView(Sugerencias.buildMenu(), new SoloLecturaDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :mascota) {
            WatchUi.pushView(new MascotaView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        var acts = Historial.load();
        if (id == :semana) {
            WatchUi.pushView(Semana.buildMenu(acts), new SoloLecturaDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :retos) {
            WatchUi.pushView(Retos.buildMenu(acts), new RetosDelegate(acts), WatchUi.SLIDE_LEFT);
        }
    }
}
