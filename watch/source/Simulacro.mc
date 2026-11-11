using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Application;
using Toybox.Attention;
using Toybox.FitContributor;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Position;
using Toybox.Sensor;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

// Simulacro HYROX: 8 x (1 km de carrera + estación), en el orden oficial.
// BACK cierra el tramo actual y empieza el siguiente. Compara cada tramo con tu mejor simulacro.
module Simulacro {
    // [nombre, es carrera]
    const TRAMOS = [
        ["Run 1 · 1 km", true], ["SkiErg 1000 m", false],
        ["Run 2 · 1 km", true], ["Sled Push 50 m", false],
        ["Run 3 · 1 km", true], ["Sled Pull 50 m", false],
        ["Run 4 · 1 km", true], ["Burpee Broad Jump 80 m", false],
        ["Run 5 · 1 km", true], ["Row 1000 m", false],
        ["Run 6 · 1 km", true], ["Farmers Carry 200 m", false],
        ["Run 7 · 1 km", true], ["Sandbag Lunges 100 m", false],
        ["Run 8 · 1 km", true], ["Wall Balls 100", false]
    ];
    const BEST_KEY = "simBest";   // {"total" => ms, "splits" => [ms...]}

    function best() {
        var b = Application.Storage.getValue(BEST_KEY);
        return b instanceof Lang.Dictionary ? b : null;
    }

    function fmt(ms) {
        var s = ms / 1000;
        if (s >= 3600) {
            return (s / 3600) + ":" + ((s / 60) % 60).format("%02d") + ":" + (s % 60).format("%02d");
        }
        return (s / 60) + ":" + (s % 60).format("%02d");
    }

    function fmtDelta(ms) {
        var sign = ms < 0 ? "-" : "+";
        return sign + fmt(ms < 0 ? -ms : ms);
    }
}

class SimView extends WatchUi.View {
    const READY = 0;
    const RUNNING = 1;
    const PAUSED = 2;
    const DONE = 3;

    var state;
    var idx;
    var splits;
    var session;
    var field;
    var ticker;
    var accum;       // ms activos acumulados antes de la última reanudación
    var runStart;
    var segStart;    // ms activos en que empezó el tramo
    var segDist;     // distancia (m) al empezar el tramo
    var result;      // texto del final
    var record;
    var segs;        // tramos para el resumen
    var segRunMs;
    var segRunDist;
    var lastTickAt;
    var lastDist;
    var summary;
    var donePage;

    function initialize() {
        View.initialize();
        state = READY;
        idx = 0;
        splits = [];
        session = null;
        ticker = null;
        accum = 0;
        runStart = 0;
        segStart = 0;
        segDist = 0.0;
        result = "";
        record = false;
        segs = [];
        segRunMs = 0;
        segRunDist = 0.0;
        lastTickAt = 0;
        lastDist = 0.0;
        summary = null;
        donePage = 0;
        $.gPlayer = self;
    }

    function onShow() {
        ticker = new Timer.Timer();
        ticker.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (ticker != null) {
            ticker.stop();
            ticker = null;
        }
    }

    function onTick() {
        if (state == RUNNING) {
            var now = System.getTimer();
            var r = ResumenEntreno.sample(Simulacro.TRAMOS[idx][1], now - lastTickAt, lastDist);
            segRunMs += r[0];
            segRunDist += r[1];
            lastDist = r[2];
            lastTickAt = now;
        }
        WatchUi.requestUpdate();
    }

    function recordSeg(ms) {
        var tramo = Simulacro.TRAMOS[idx];
        segs.add({"n" => tramo[0], "ms" => ms, "run" => tramo[1], "rest" => false, "rms" => segRunMs, "rd" => segRunDist});
        segRunMs = 0;
        segRunDist = 0.0;
    }

    function onPosition(info) {
    }

    function active() {
        return state == RUNNING ? accum + (System.getTimer() - runStart) : accum;
    }

    function distance() {
        var info = Activity.getActivityInfo();
        return info != null && info.elapsedDistance != null ? info.elapsedDistance : 0.0;
    }

    function vibrate(ms) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, ms)]);
        }
    }

    function begin() {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        session = ActivityRecording.createSession({:name => "Simulacro HYROX", :sport => Activity.SPORT_HIIT, :subSport => Activity.SUB_SPORT_GENERIC});
        field = session.createField("tramo", 0, FitContributor.DATA_TYPE_STRING, {:mesgType => FitContributor.MESG_TYPE_LAP, :count => 32});
        session.start();
        accum = 0;
        segStart = 0;
        segDist = 0.0;
        runStart = System.getTimer();
        lastTickAt = runStart;
        lastDist = 0.0;
        state = RUNNING;
        vibrate(500);
    }

    // BACK: cierra el tramo actual.
    function nextSegment() {
        var now = active();
        splits.add(now - segStart);
        recordSeg(now - segStart);
        field.setData(Simulacro.TRAMOS[idx][0]);
        session.addLap();
        segStart = now;
        segDist = distance();
        idx += 1;
        if (idx >= Simulacro.TRAMOS.size()) {
            finish(true);
        } else {
            vibrate(300);
        }
    }

    function pause() {
        accum = active();
        state = PAUSED;
        session.stop();
        var menu = new WatchUi.Menu2({:title => "Pausa"});
        menu.addItem(new WatchUi.MenuItem("Reanudar", null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem("Guardar", "Sin terminar: no cuenta como récord", :save, {}));
        menu.addItem(new WatchUi.MenuItem("Descartar", null, :discard, {}));
        WatchUi.pushView(menu, new SimPauseDelegate(self), WatchUi.SLIDE_UP);
    }

    function resume() {
        session.start();
        runStart = System.getTimer();
        lastTickAt = runStart;
        lastDist = ResumenEntreno.distance();
        state = RUNNING;
    }

    function finish(complete) {
        accum = active();
        state = DONE;
        if (session.isRecording()) {
            session.stop();
        }
        session.save();
        closeRecording();
        var total = accum;
        result = "Guardado";
        if (complete) {
            var b = Simulacro.best();
            if (b == null || total < b["total"]) {
                Application.Storage.setValue(Simulacro.BEST_KEY, {"total" => total, "splits" => splits});
                record = true;
                result = b == null ? "¡Primer simulacro!" : "¡Nuevo récord! " + Simulacro.fmtDelta(total - b["total"]);
            } else {
                result = "Récord: " + Simulacro.fmt(b["total"]) + " (" + Simulacro.fmtDelta(total - b["total"]) + ")";
            }
        }
        if (!complete && idx < Simulacro.TRAMOS.size() && total - segStart > 1000) {
            recordSeg(total - segStart);
        }
        summary = ResumenEntreno.build("Simulacro HYROX", result, total, segs);
        donePage = 0;
        vibrate(1000);
    }

    function onUpDown(delta) {
        if (state == DONE && summary != null) {
            donePage = (donePage + delta + ResumenEntreno.PAGES) % ResumenEntreno.PAGES;
            WatchUi.requestUpdate();
        }
    }

    function discard() {
        state = DONE;
        session.discard();
        closeRecording();
        result = "Descartado";
    }

    function closeRecording() {
        session = null;
        Sensor.setEnabledSensors([]);
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function saveIfOpen() {
        if (session != null) {
            finish(false);
        }
    }

    function leave() {
        $.gPlayer = null;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onStartKey() {
        if (state == READY) {
            begin();
        } else if (state == RUNNING) {
            pause();
        } else if (state == DONE) {
            leave();
        }
        WatchUi.requestUpdate();
    }

    function onLapKey() {
        if (state == READY || state == DONE) {
            leave();
        } else if (state == RUNNING) {
            nextSegment();
            WatchUi.requestUpdate();
        }
    }

    function text(dc, y, font, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Puntos de progreso de los 16 tramos alrededor del borde superior.
    function progress(dc) {
        var w = dc.getWidth();
        var n = Simulacro.TRAMOS.size();
        var step = w * 0.045;
        var x0 = w / 2 - step * (n - 1) / 2;
        for (var i = 0; i < n; i++) {
            var run = Simulacro.TRAMOS[i][1];
            var color = i < idx ? (run ? 0x4DA8FF : 0x00E5A8) : (i == idx ? Graphics.COLOR_WHITE : 0x2B3D63);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((x0 + i * step).toNumber(), (dc.getHeight() * 0.1).toNumber(), i == idx ? 4 : 3);
        }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var h = dc.getHeight();
        var white = Graphics.COLOR_WHITE;
        var gray = Graphics.COLOR_LT_GRAY;
        var b = Simulacro.best();

        if (state == READY) {
            text(dc, h * 0.24, Graphics.FONT_SMALL, "Simulacro", 0x00E5A8);
            text(dc, h * 0.34, Graphics.FONT_MEDIUM, "HYROX", white);
            text(dc, h * 0.47, Graphics.FONT_XTINY, "8 km + 8 estaciones", gray);
            text(dc, h * 0.56, Graphics.FONT_XTINY, b != null ? "Récord: " + Simulacro.fmt(b["total"]) : "Sin récord todavía", gray);
            text(dc, h * 0.70, Graphics.FONT_XTINY, "BACK cierra cada tramo", white);
            text(dc, h * 0.78, Graphics.FONT_XTINY, "START para empezar", white);
            return;
        }
        if (state == DONE && summary != null) {
            ResumenEntreno.draw(dc, summary, donePage);
            return;
        }
        if (state == DONE) {
            text(dc, h * 0.25, Graphics.FONT_SMALL, result.length() > 0 ? Graphics.fitTextToArea(result, Graphics.FONT_SMALL, dc.getWidth() * 0.8, dc.getFontHeight(Graphics.FONT_SMALL) * 2, true) : "", record ? 0xFFC93C : 0x00E5A8);
            text(dc, h * 0.45, Graphics.FONT_NUMBER_MEDIUM, Simulacro.fmt(accum), white);
            text(dc, h * 0.62, Graphics.FONT_XTINY, idx + "/" + Simulacro.TRAMOS.size() + " tramos", gray);
            text(dc, h * 0.78, Graphics.FONT_XTINY, "START para salir", gray);
            return;
        }

        progress(dc);
        var tramo = Simulacro.TRAMOS[idx];
        var isRun = tramo[1];
        var color = isRun ? 0x4DA8FF : 0x00E5A8;
        var seg = active() - segStart;

        text(dc, h * 0.2, Graphics.FONT_XTINY, (idx + 1) + "/" + Simulacro.TRAMOS.size() + (state == PAUSED ? " · PAUSA" : ""), state == PAUSED ? Graphics.COLOR_RED : gray);
        text(dc, h * 0.29, Graphics.FONT_SMALL, Graphics.fitTextToArea(tramo[0], Graphics.FONT_SMALL, dc.getWidth() * 0.82, dc.getFontHeight(Graphics.FONT_SMALL), true), color);
        text(dc, h * 0.45, Graphics.FONT_NUMBER_HOT, Simulacro.fmt(seg), white);

        // Comparación con el mismo tramo del récord
        if (b != null && b["splits"] instanceof Lang.Array && idx < b["splits"].size()) {
            var d = seg - b["splits"][idx];
            text(dc, h * 0.6, Graphics.FONT_TINY, Simulacro.fmtDelta(d) + " vs récord", d <= 0 ? 0x2ECC71 : 0xFF5C5C);
        }

        // En carrera: metros del tramo y ritmo
        if (isRun) {
            var m = distance() - segDist;
            var pace = "--:--";
            if (m > 20 && seg > 0) {
                pace = Simulacro.fmt((seg * 1000.0 / m).toNumber());
            }
            text(dc, h * 0.7, Graphics.FONT_XTINY, m.toNumber() + " m · " + pace + " /km", gray);
        }

        var info = Activity.getActivityInfo();
        var hr = info != null && info.currentHeartRate != null ? info.currentHeartRate.toString() : "--";
        text(dc, h * 0.84, Graphics.FONT_XTINY, "Total " + Simulacro.fmt(active()) + "  FC " + hr, gray);
    }
}

class SimDelegate extends WatchUi.InputDelegate {
    var view;

    function initialize(aView) {
        InputDelegate.initialize();
        view = aView;
    }

    function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_ENTER) {
            view.onStartKey();
        } else if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) {
            view.onLapKey();
        } else if (key == WatchUi.KEY_UP) {
            view.onUpDown(-1);
        } else if (key == WatchUi.KEY_DOWN) {
            view.onUpDown(1);
        }
        return true;
    }

    function onTap(event) {
        return true;
    }

    function onSwipe(event) {
        return true;
    }

    function onHold(event) {
        return true;
    }
}

class SimPauseDelegate extends WatchUi.Menu2InputDelegate {
    var view;

    function initialize(aView) {
        Menu2InputDelegate.initialize();
        view = aView;
    }

    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (id == :resume) {
            view.resume();
        } else if (id == :save) {
            view.finish(false);
        } else if (id == :discard) {
            view.discard();
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        view.resume();
    }
}
