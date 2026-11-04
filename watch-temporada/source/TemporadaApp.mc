using Toybox.Application;
using Toybox.WatchUi;

class TemporadaApp extends Application.AppBase {
    var sync;

    // El constructor también se ejecuta para la vista rápida: aquí no se crea nada pesado.
    function initialize() {
        AppBase.initialize();
        sync = null;
    }

    (:glance)
    function getGlanceView() {
        return [new TemporadaGlance()];
    }

    function getInitialView() {
        // Suma a la mascota las actividades nuevas, revisa los logros,
        // prepara la vista rápida y descarga agenda, retos y sugerencias.
        var acts = Historial.load();
        Mascota.update(acts);
        var lvl = Mascota.level(Mascota.total(Mascota.points()));
        Logros.update(acts, lvl);
        Datos.saveGlance(lvl);
        sync = new Sync();
        sync.start();

        var menu = new WatchUi.Menu2({:title => "Mi Temporada"});
        menu.addItem(new WatchUi.MenuItem("Mascota", null, :mascota, {}));
        menu.addItem(new WatchUi.MenuItem("Semana", null, :semana, {}));
        menu.addItem(new WatchUi.MenuItem("Resumen", "Semana y mes", :resumen, {}));
        menu.addItem(new WatchUi.MenuItem("Retos", null, :retos, {}));
        menu.addItem(new WatchUi.MenuItem("Logros", null, :logros, {}));
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
            WatchUi.pushView(Sugerencias.buildMenu(), new SugerenciasDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :mascota) {
            WatchUi.pushView(new MascotaView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        var acts = Historial.load();
        if (id == :semana) {
            WatchUi.pushView(Semana.buildMenu(acts), new SemanaDelegate(Datos.sesiones(acts)), WatchUi.SLIDE_LEFT);
        } else if (id == :resumen) {
            var rv = new ResumenView(acts);
            WatchUi.pushView(rv, new PagerDelegate(rv), WatchUi.SLIDE_LEFT);
        } else if (id == :retos) {
            WatchUi.pushView(Retos.buildMenu(acts), new RetosDelegate(acts), WatchUi.SLIDE_LEFT);
        } else if (id == :logros) {
            var lvl = Mascota.level(Mascota.total(Mascota.points()));
            var lv = new LogrosView(acts, lvl);
            WatchUi.pushView(lv, new PagerDelegate(lv), WatchUi.SLIDE_LEFT);
        }
    }
}
