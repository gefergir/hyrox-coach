using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Attention;
using Toybox.FitContributor;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Position;
using Toybox.Sensor;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

const ST_READY = 0;
const ST_RUNNING = 1;
const ST_PAUSED = 2;
const ST_DONE = 3;

class PlayerView extends WatchUi.View {
    var sesion;
    var steps;
    var idx;
    var state;
    var doneText;

    var session;
    var lapField;
    var usesGps;
    var ticker;

    var accumMs;    // Tiempo activo acumulado antes de la última reanudación
    var runStart;
    var stepStart;  // Tiempo activo en el que empezó el paso actual

    var laps;       // Rondas marcadas con LAP en el paso actual
    var workMarked; // En un intervalo, LAP ya marcó el final del trabajo
    var warned;     // Ya se avisó de que quedan 3 segundos

    function initialize(aSesion) {
        View.initialize();
        sesion = aSesion;
        steps = Plan.buildSteps(aSesion);
        idx = 0;
        state = $.ST_READY;
        doneText = "";
        session = null;
        lapField = null;
        usesGps = "carrera".equals(aSesion["deporte"]);
        ticker = null;
        accumMs = 0;
        runStart = 0;
        stepStart = 0;
        resetStepMarks();
        $.gPlayer = self;
    }

    function resetStepMarks() {
        laps = 0;
        workMarked = false;
        warned = false;
    }

    // --- Ciclo de vida de la vista ---

    function onShow() {
        ticker = new Timer.Timer();
        ticker.start(method(:onTick), 500, true);
    }

    function onHide() {
        if (ticker != null) {
            ticker.stop();
            ticker = null;
        }
    }

    function onPosition(info) {
    }

    // --- Tiempo ---

    function activeMs() {
        if (state == $.ST_RUNNING) {
            return accumMs + (System.getTimer() - runStart);
        }
        return accumMs;
    }

    function stepLeftMs() {
        return steps[idx]["secs"] * 1000 - (activeMs() - stepStart);
    }

    function onTick() {
        // El bucle recupera los pasos vencidos si la vista estuvo oculta.
        while (state == $.ST_RUNNING && stepLeftMs() <= 0) {
            autoAdvance();
        }
        if (state == $.ST_RUNNING && !warned && stepLeftMs() <= 3000) {
            warned = true;
            vibrate(150);
        }
        WatchUi.requestUpdate();
    }

    function vibrate(ms) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, ms)]);
        }
    }

    // --- Grabación ---

    function begin() {
        if (steps.size() == 0) {
            return;
        }
        var name = sesion["nombre"];
        if (name.length() > 15) {
            name = name.substring(0, 15);
        }
        var options = usesGps
            ? {:name => name, :sport => Activity.SPORT_RUNNING}
            : {:name => name, :sport => Activity.SPORT_TRAINING, :subSport => Activity.SUB_SPORT_CARDIO_TRAINING};

        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        if (usesGps) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        }

        session = ActivityRecording.createSession(options);
        lapField = session.createField(
            "paso",
            0,
            FitContributor.DATA_TYPE_STRING,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :count => 32}
        );
        session.start();

        accumMs = 0;
        stepStart = 0;
        runStart = System.getTimer();
        state = $.ST_RUNNING;
        vibrate(500);
    }

    function pause() {
        accumMs = activeMs();
        state = $.ST_PAUSED;
        session.stop();
        openPauseMenu();
    }

    function resume() {
        session.start();
        runStart = System.getTimer();
        state = $.ST_RUNNING;
    }

    function openPauseMenu() {
        var menu = new WatchUi.Menu2({:title => "Pausa"});
        menu.addItem(new WatchUi.MenuItem("Reanudar", null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem("Saltar bloque", null, :skip, {}));
        menu.addItem(new WatchUi.MenuItem("Guardar", null, :save, {}));
        menu.addItem(new WatchUi.MenuItem("Descartar", null, :discard, {}));
        WatchUi.pushView(menu, new PauseMenuDelegate(self), WatchUi.SLIDE_UP);
    }

    function writeLap(label) {
        if (label.length() > 28) {
            label = label.substring(0, 28);
        }
        lapField.setData(label);
        session.addLap();
    }

    function lapLabel() {
        var step = steps[idx];
        if (step["kind"] == $.KIND_INTERVAL) {
            return step["name"] + " R" + step["round"] + (workMarked ? " resto" : "");
        }
        if (step["kind"] == $.KIND_ROUNDS) {
            return step["name"] + " R" + (laps + 1);
        }
        return step["name"];
    }

    // El paso termina porque se agotó su tiempo.
    function autoAdvance() {
        var secs = steps[idx]["secs"];
        writeLap(lapLabel());
        stepStart += secs * 1000;
        goTo(idx + 1);
    }

    // El paso termina antes de tiempo porque lo pide el usuario.
    function jumpTo(target) {
        writeLap(lapLabel());
        stepStart = activeMs();
        goTo(target);
    }

    function goTo(target) {
        idx = target;
        resetStepMarks();
        if (idx >= steps.size()) {
            idx = steps.size() - 1;
            finish("Guardado");
        } else {
            vibrate(500);
        }
    }

    function skipBlock() {
        resume();
        var current = steps[idx]["block"];
        var target = idx + 1;
        while (target < steps.size() && steps[target]["block"] == current) {
            target += 1;
        }
        jumpTo(target);
    }

    function finish(text) {
        accumMs = activeMs();
        state = $.ST_DONE;
        if (session.isRecording()) {
            session.stop();
        }
        session.save();
        closeRecording();
        doneText = text;
        vibrate(1000);
    }

    function discard() {
        state = $.ST_DONE;
        session.discard();
        closeRecording();
        doneText = "Descartado";
    }

    function closeRecording() {
        session = null;
        lapField = null;
        Sensor.setEnabledSensors([]);
        if (usesGps) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        }
    }

    function saveIfOpen() {
        if (session != null) {
            finish("Guardado");
        }
    }

    function leave() {
        $.gPlayer = null;
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // --- Botones ---

    function onStartKey() {
        if (state == $.ST_READY) {
            begin();
        } else if (state == $.ST_RUNNING) {
            pause();
        } else if (state == $.ST_PAUSED) {
            openPauseMenu();
        } else {
            leave();
        }
        WatchUi.requestUpdate();
    }

    function onLapKey() {
        if (state == $.ST_READY || state == $.ST_DONE) {
            leave();
            return;
        }
        if (state != $.ST_RUNNING) {
            return;
        }

        var kind = steps[idx]["kind"];
        if (kind == $.KIND_REST) {
            jumpTo(idx + 1);
        } else if (kind == $.KIND_ROUNDS) {
            writeLap(lapLabel());
            laps += 1;
            vibrate(150);
        } else if (!workMarked) {
            writeLap(lapLabel());
            workMarked = true;
            vibrate(150);
        }
        WatchUi.requestUpdate();
    }

    // --- Pantalla ---

    function formatSecs(secs) {
        return Lang.format("$1$:$2$", [secs / 60, (secs % 60).format("%02d")]);
    }

    function joinList(list) {
        var text = "";
        for (var i = 0; i < list.size(); i++) {
            text += (i > 0 ? " + " : "") + list[i];
        }
        return text;
    }

    function stepLines(step) {
        var data = step["data"];
        if (data == null) {
            return [];
        }
        var roles = data["roles"];
        if (roles != null) {
            // Cada LAP intercambia los roles de la pareja.
            var first = laps % 2 == 0 ? roles["A"] : roles["B"];
            var second = laps % 2 == 0 ? roles["B"] : roles["A"];
            return ["Tú: " + joinList(first), "Pareja: " + joinList(second)];
        }
        return data["ejercicios"];
    }

    function stepCaption(step) {
        var kind = step["kind"];
        if (kind == $.KIND_INTERVAL) {
            return "Ronda " + step["round"] + "/" + step["rounds"] + (workMarked ? " · hecho" : "");
        }
        if (kind == $.KIND_ROUNDS) {
            var data = step["data"];
            return (data["roles"] != null ? "Cambios: " : "Rondas: ") + laps;
        }
        return "LAP para seguir";
    }

    function stepColor(kind) {
        if (kind == $.KIND_INTERVAL) {
            return 0x00E5A8;
        }
        return kind == $.KIND_ROUNDS ? 0xFF9F1C : 0x4DA8FF;
    }

    function drawCentered(dc, y, font, text, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            y,
            font,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function fitLine(dc, text, font, widthRatio) {
        return Graphics.fitTextToArea(
            text,
            font,
            dc.getWidth() * widthRatio,
            dc.getFontHeight(font),
            true
        );
    }

    function totalMinutes() {
        var total = 0;
        for (var i = 0; i < steps.size(); i++) {
            total += steps[i]["secs"];
        }
        return total / 60;
    }

    function drawReady(dc, h) {
        var white = Graphics.COLOR_WHITE;
        var gray = Graphics.COLOR_LT_GRAY;
        drawCentered(dc, h * 0.28, Graphics.FONT_SMALL, Plan.dayLabel(sesion["dia"]), 0x00E5A8);
        drawCentered(dc, h * 0.42, Graphics.FONT_TINY, fitLine(dc, sesion["nombre"], Graphics.FONT_TINY, 0.85), white);
        var summary = sesion["bloques"].size() + " bloques · " + totalMinutes() + " min";
        drawCentered(dc, h * 0.56, Graphics.FONT_XTINY, summary, gray);
        drawCentered(dc, h * 0.74, Graphics.FONT_XTINY, "START para empezar", white);
    }

    function drawDone(dc, h) {
        drawCentered(dc, h * 0.34, Graphics.FONT_MEDIUM, doneText, 0x00E5A8);
        drawCentered(dc, h * 0.50, Graphics.FONT_NUMBER_MEDIUM, formatSecs(accumMs / 1000), Graphics.COLOR_WHITE);
        drawCentered(dc, h * 0.70, Graphics.FONT_XTINY, "START para salir", Graphics.COLOR_LT_GRAY);
    }

    function drawStep(dc, h) {
        var white = Graphics.COLOR_WHITE;
        var gray = Graphics.COLOR_LT_GRAY;
        var step = steps[idx];
        var color = stepColor(step["kind"]);
        var secondsLeft = (stepLeftMs() + 999) / 1000;
        if (secondsLeft < 0) {
            secondsLeft = 0;
        }

        drawCentered(dc, h * 0.13, Graphics.FONT_XTINY, fitLine(dc, step["name"], Graphics.FONT_XTINY, 0.62), color);
        var caption = state == $.ST_PAUSED ? "PAUSA" : stepCaption(step);
        drawCentered(dc, h * 0.22, Graphics.FONT_XTINY, caption, state == $.ST_PAUSED ? Graphics.COLOR_RED : gray);
        drawCentered(dc, h * 0.39, Graphics.FONT_NUMBER_HOT, formatSecs(secondsLeft), white);

        var lines = stepLines(step);
        var y = h * 0.58;
        var count = lines.size() > 3 ? 3 : lines.size();
        for (var i = 0; i < count; i++) {
            drawCentered(dc, y, Graphics.FONT_XTINY, fitLine(dc, lines[i], Graphics.FONT_XTINY, 0.86), white);
            y += h * 0.085;
        }

        var info = Activity.getActivityInfo();
        var hr = info != null && info.currentHeartRate != null ? info.currentHeartRate.toString() : "--";
        drawCentered(dc, h * 0.87, Graphics.FONT_XTINY, formatSecs(activeMs() / 1000) + "  FC " + hr, gray);
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var h = dc.getHeight();
        if (state == $.ST_READY) {
            drawReady(dc, h);
        } else if (state == $.ST_DONE) {
            drawDone(dc, h);
        } else {
            drawStep(dc, h);
        }
    }
}

// InputDelegate separa botones y gestos: un toque con sudor no pausa ni marca vueltas.
class PlayerDelegate extends WatchUi.InputDelegate {
    var player;

    function initialize(view) {
        InputDelegate.initialize();
        player = view;
    }

    function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_ENTER) {
            player.onStartKey();
        } else if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) {
            player.onLapKey();
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

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {
    var player;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        player = view;
    }

    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (id == :resume) {
            player.resume();
        } else if (id == :skip) {
            player.skipBlock();
        } else if (id == :save) {
            player.finish("Guardado");
        } else if (id == :discard) {
            WatchUi.pushView(
                new WatchUi.Confirmation("¿Descartar el entreno?"),
                new DiscardDelegate(player),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        player.resume();
    }
}

class DiscardDelegate extends WatchUi.ConfirmationDelegate {
    var player;

    function initialize(view) {
        ConfirmationDelegate.initialize();
        player = view;
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            player.discard();
        }
        return true;
    }
}
