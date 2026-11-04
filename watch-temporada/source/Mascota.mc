using Toybox.Application;
using Toybox.Attention;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Puntos de la mascota. Se guardan en Storage y solo suben: si el reloj borra
// actividades antiguas, los puntos ya sumados se conservan.
module Mascota {
    const MAX_LEVEL = 15;
    const SAD_DAYS = 5;
    const PTS_PER_KM = 5;
    // La mascota nace este día en nivel 0: solo cuentan los entrenos desde aquí.
    // Si se cambia, los puntos guardados se reinician.
    const INICIO = "2026-11-04";

    function points() {
        var pts = Application.Storage.getValue("pts");
        if (!(pts instanceof Lang.Dictionary)) {
            pts = {"gym" => 0, "carrera" => 0, "hyrox" => 0};
        }
        return pts;
    }

    // Suma las actividades posteriores a la última ya contada (por startTime).
    function update(acts) {
        if (!INICIO.equals(Application.Storage.getValue("inicio"))) {
            Application.Storage.setValue("pts", {"gym" => 0, "carrera" => 0, "hyrox" => 0});
            Application.Storage.deleteValue("ultimo");
            Application.Storage.deleteValue("ultimoDia");
            Application.Storage.setValue("inicio", INICIO);
        }
        var inicioDn = Historial.parseDate(INICIO);
        var pts = points();
        var ultimo = Application.Storage.getValue("ultimo");
        var ultimoDia = Application.Storage.getValue("ultimoDia");
        if (ultimo == null) {
            ultimo = 0;
        }
        var maxStart = ultimo;
        var gain = {"gym" => 0, "carrera" => 0, "hyrox" => 0};
        var gained = false;
        for (var i = 0; i < acts.size(); i++) {
            var a = acts[i];
            if (a["dn"] < inicioDn) {
                continue;
            }
            if (a["start"] > ultimo) {
                var p = a["secs"] / 60;
                if (a["cat"].equals(Historial.CAT_CARRERA)) {
                    p += (a["km"] * PTS_PER_KM).toNumber();
                }
                pts[a["cat"]] = pts[a["cat"]] + p;
                gain[a["cat"]] = gain[a["cat"]] + p;
                gained = true;
                if (a["start"] > maxStart) {
                    maxStart = a["start"];
                }
            }
            if (ultimoDia == null || a["dn"] > ultimoDia) {
                ultimoDia = a["dn"];
            }
        }
        Application.Storage.setValue("pts", pts);
        Application.Storage.setValue("ultimo", maxStart);
        // La vista de la mascota lo celebra la próxima vez que se abra.
        if (gained) {
            Application.Storage.setValue("ganancia", gain);
        }
        if (ultimoDia != null) {
            Application.Storage.setValue("ultimoDia", ultimoDia);
        }
    }

    function total(pts) {
        return pts["gym"] + pts["carrera"] + pts["hyrox"];
    }

    // Puntos acumulados necesarios para alcanzar un nivel: 250, 750, 1500, ...
    function threshold(level) {
        return 125 * level * (level + 1);
    }

    function level(totalPts) {
        var l = 0;
        while (l < MAX_LEVEL && totalPts >= threshold(l + 1)) {
            l += 1;
        }
        return l;
    }

    function daysWithoutTraining() {
        // Sin entrenos todavía: se cuenta desde el día en que nació.
        var last = Application.Storage.getValue("ultimoDia");
        if (last == null) {
            last = Historial.parseDate(INICIO);
        }
        return Historial.today() - last;
    }

    function isSad() {
        return daysWithoutTraining() >= SAD_DAYS;
    }
}

class MascotaView extends WatchUi.View {
    const OUTLINE = 0x3B2416;
    const COLOR_GYM = 0xFFB347;
    const COLOR_CARRERA = 0x4DA8FF;
    const COLOR_HYROX = 0x00E5A8;
    // Puntos de una parte del cuerpo con los que alcanza su músculo máximo.
    const MUSCLE_FULL = 12000.0;

    const ANIM_FRAMES = 90;   // 9 s a 10 fps; luego la pantalla queda quieta

    var frame;
    var timer;
    var gain;       // puntos nuevos desde la última vez {gym, carrera, hyrox}
    var gainTotal;
    var pose;       // 0 nada, 1 bíceps (gym), 2 trote (carrera), 3 salto (hyrox)
    var levelUp;
    var logro;
    var acc;

    function initialize() {
        View.initialize();
        frame = ANIM_FRAMES;
        timer = null;
    }

    function onShow() {
        var pts = Mascota.points();
        var lvl = Mascota.level(Mascota.total(pts));
        var store = Application.Storage;

        gain = store.getValue("ganancia");
        store.deleteValue("ganancia");
        pose = 0;
        gainTotal = 0;
        if (gain != null) {
            gainTotal = gain["gym"] + gain["carrera"] + gain["hyrox"];
            pose = 1;
            if (gain["carrera"] > gain["gym"] && gain["carrera"] >= gain["hyrox"]) {
                pose = 2;
            } else if (gain["hyrox"] > gain["gym"]) {
                pose = 3;
            }
        }

        var seen = store.getValue("nivelVisto");
        levelUp = seen != null && lvl > seen;
        store.setValue("nivelVisto", lvl);
        logro = store.getValue("logroNuevo");
        store.deleteValue("logroNuevo");

        acc = {};
        for (var i = 0; i < Logros.LIST.size(); i++) {
            acc[Logros.LIST[i][0]] = Logros.tiene(Logros.LIST[i][0]);
        }

        if ((levelUp || logro != null) && (Attention has :vibrate)) {
            Attention.vibrate([new Attention.VibeProfile(80, 200), new Attention.VibeProfile(0, 100), new Attention.VibeProfile(80, 300)]);
        }
        frame = 0;
        timer = new Timer.Timer();
        timer.start(method(:onTick), 100, true);
    }

    function onHide() {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
    }

    function onTick() {
        frame += 1;
        if (frame >= ANIM_FRAMES && timer != null) {
            timer.stop();
            timer = null;
        }
        WatchUi.requestUpdate();
    }

    // Movimiento del fotograma actual, en unidades u.
    function animState() {
        var t = frame.toFloat();
        var an = {
            "y" => Math.sin(t * 0.3) * 0.12,
            "liftL" => 0.0,
            "liftR" => 0.0,
            "flex" => 0.0,
            "blink" => frame % 30 >= 28
        };
        if (frame < 45) {
            if (pose == 1) {
                an["flex"] = Math.sin(t * 0.3).abs();
            } else if (pose == 2) {
                var s = Math.sin(t * 0.6);
                an["liftL"] = s > 0 ? s * 0.9 : 0.0;
                an["liftR"] = s < 0 ? -s * 0.9 : 0.0;
                an["y"] = -Math.sin(t * 1.2).abs() * 0.3;
            } else if (pose == 3) {
                an["y"] = -Math.sin(t * 0.35).abs() * 1.6;
            }
        }
        return an;
    }

    // Confeti al subir de nivel y "+puntos" flotando tras un entreno nuevo.
    function drawEffects(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (levelUp && frame < 70) {
            var colors = [0xFF5C8A, 0xFFD54A, 0x00E5A8, 0x4DA8FF, 0xFFFFFF];
            for (var i = 0; i < 22; i++) {
                var x = w * ((i * 37 + 11) % 100) / 100.0;
                var y = h * (((i * 53 + frame * (3 + i % 4) * 4) % 560) / 1000.0);
                dc.setColor(colors[i % colors.size()], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x.toNumber(), y.toNumber(), 4 + i % 3, 6 + i % 2);
            }
        }
        if (gain != null && gainTotal > 0 && frame < 40) {
            var color = pose == 2 ? COLOR_CARRERA : (pose == 3 ? COLOR_HYROX : COLOR_GYM);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.74, h * (0.36 - frame * 0.004), Graphics.FONT_SMALL, "+" + gainTotal,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function clamp(v) {
        return v > 1.0 ? 1.0 : v;
    }

    function fe(dc, x, y, rx, ry) {
        var a = rx.toNumber();
        var b = ry.toNumber();
        dc.fillEllipse(x.toNumber(), y.toNumber(), a < 1 ? 1 : a, b < 1 ? 1 : b);
    }

    function fc(dc, x, y, r) {
        var rr = r.toNumber();
        dc.fillCircle(x.toNumber(), y.toNumber(), rr < 1 ? 1 : rr);
    }

    // Osito de dibujo animado. Ocupa siempre lo mismo: lo que cambia es el músculo.
    // Gym muscula brazos y torso, carrera las piernas, hyrox todo el cuerpo.
    // Empieza muy flaquito. En el nivel máximo no cabe y solo se le ven las piernas.
    // an: {y, liftL, liftR, flex, blink} en unidades u; acc: accesorios desbloqueados.
    function drawPet(dc, pts, lvl, sad, an, acc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var mU = clamp((pts["gym"] + pts["hyrox"]) / MUSCLE_FULL);      // brazos y torso
        var mL = clamp((pts["carrera"] + pts["hyrox"]) / MUSCLE_FULL);  // piernas
        var u = w * 0.028 * (lvl >= Mascota.MAX_LEVEL ? 5.0 : 1.0);
        var cx = w / 2.0;
        var groundY = h * 0.50;
        var baseY = groundY + an["y"] * u;
        var liftL = an["liftL"] * u;
        var liftR = an["liftR"] * u;
        var o = 0.22 * u < 2 ? 2 : 0.22 * u;   // grosor del contorno

        var fur = sad ? 0x9FB3C8 : 0xFFB347;
        var furDark = sad ? 0x7F93A8 : 0xF09A2A;
        var belly = sad ? 0xD8E3EE : 0xFFE3B0;
        var muscleLine = sad ? 0xB4C4D6 : 0xF5C98A;
        var pink = sad ? 0xC7A9BC : 0xFF8FA3;
        var band = acc["racha4"] == true ? 0xFFD54A : (sad ? 0x6FA79A : 0x00E5A8);
        var shoe = acc["diez"] == true ? 0xE53935 : furDark;
        var gold = 0xFFD54A;

        // Medidas fijas
        var legH = 2.3 * u;
        var bodyRy = 2.8 * u;
        var bodyCy = baseY - legH - 1.9 * u;
        var headR = 3.6 * u;
        var headCy = bodyCy - 5.1 * u;

        // Medidas que dependen del músculo
        var legRx = (0.38 + 0.72 * mL) * u;
        var bodyRx = (1.75 + 1.35 * mU) * u;
        var armRx = (0.36 + 0.55 * mU) * u;
        var armRy = 1.7 * u;
        var bicepR = (0.15 + 0.85 * mU) * u * (1.0 + 0.35 * an["flex"]);
        var handR = (0.55 + 0.4 * mU) * u;
        var armX = bodyRx + 0.25 * u + armRx * 0.4;
        if (!sad && armX < 3.0 * u + armRx) {
            armX = 3.0 * u + armRx;   // brazos en alto: que no queden detrás de la cabeza
        }
        var armCy = sad ? bodyCy + 0.5 * u : bodyCy - 2.2 * u;
        var handCy = sad ? armCy + armRy : armCy - armRy;
        var legX = 0.55 * u + legRx;

        // Sombra en el suelo
        dc.setColor(sad ? 0x4C6152 : 0x3F8F4A, Graphics.COLOR_TRANSPARENT);
        var shadowK = 1.0 - (groundY - baseY) / (4.0 * u);
        fe(dc, cx, groundY + 0.35 * u, 3.0 * u * (shadowK < 0.5 ? 0.5 : shadowK), 0.55 * u);

        // Silueta: primero todos los contornos y luego los rellenos, para que se fundan.
        var shapes = [
            [cx - legX, baseY - legH / 2 - 0.3 * u - liftL, legRx, legH / 2 + 0.5 * u, furDark],
            [cx + legX, baseY - legH / 2 - 0.3 * u - liftR, legRx, legH / 2 + 0.5 * u, furDark],
            [cx - legX, baseY - legH * 0.7 - liftL, legRx * (1.0 + 0.35 * mL), legH * 0.4, furDark],
            [cx + legX, baseY - legH * 0.7 - liftR, legRx * (1.0 + 0.35 * mL), legH * 0.4, furDark],
            [cx - legX - 0.2 * u, baseY - 0.35 * u - liftL, 1.05 * u, 0.6 * u, shoe],
            [cx + legX + 0.2 * u, baseY - 0.35 * u - liftR, 1.05 * u, 0.6 * u, shoe],
            [cx - armX, armCy, armRx, armRy, fur],
            [cx + armX, armCy, armRx, armRy, fur],
            [cx - armX - armRx * 0.5, armCy, bicepR, bicepR * 1.1, fur],
            [cx + armX + armRx * 0.5, armCy, bicepR, bicepR * 1.1, fur],
            [cx, bodyCy, bodyRx, bodyRy, fur],
            [cx, bodyCy - 1.7 * u, bodyRx * (1.0 + 0.15 * mU), 1.1 * u, fur],
            [cx - 2.6 * u, headCy - 2.8 * u, 1.15 * u, 1.15 * u, fur],
            [cx + 2.6 * u, headCy - 2.8 * u, 1.15 * u, 1.15 * u, fur],
            [cx, headCy, headR, headR * 0.93, fur],
            [cx - armX, handCy, handR, handR, furDark],
            [cx + armX, handCy, handR, handR, furDark]
        ];
        dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < shapes.size(); i++) {
            var p = shapes[i];
            fe(dc, p[0], p[1], p[2] + o, p[3] + o);
        }
        for (var i = 0; i < shapes.size(); i++) {
            var p = shapes[i];
            dc.setColor(p[4], Graphics.COLOR_TRANSPARENT);
            fe(dc, p[0], p[1], p[2], p[3]);
        }

        // Barriga: lisa si está flaquito; pectorales y abdominales cuando se muscula.
        dc.setColor(belly, Graphics.COLOR_TRANSPARENT);
        fe(dc, cx, bodyCy + 0.5 * u, bodyRx * 0.62, bodyRy * 0.68);
        if (mU > 0.3) {
            dc.setColor(muscleLine, Graphics.COLOR_TRANSPARENT);
            var pw = bodyRx * 0.3;
            fe(dc, cx - pw, bodyCy - 0.7 * u, pw * 0.85, 0.55 * u);
            fe(dc, cx + pw, bodyCy - 0.7 * u, pw * 0.85, 0.55 * u);
            var rows = mU > 0.6 ? 3 : 2;
            var aw = bodyRx * 0.2;
            for (var r = 0; r < rows; r++) {
                var ay = bodyCy + 0.35 * u + r * 0.75 * u;
                dc.fillRoundedRectangle((cx - aw - 0.08 * u).toNumber(), ay.toNumber(), aw.toNumber(), (0.55 * u).toNumber(), (0.2 * u).toNumber() + 1);
                dc.fillRoundedRectangle((cx + 0.08 * u).toNumber(), ay.toNumber(), aw.toNumber(), (0.55 * u).toNumber(), (0.2 * u).toNumber() + 1);
            }
        }
        dc.setColor(pink, Graphics.COLOR_TRANSPARENT);
        fc(dc, cx - 2.6 * u, headCy - 2.8 * u, 0.55 * u);
        fc(dc, cx + 2.6 * u, headCy - 2.8 * u, 0.55 * u);

        // Cinta deportiva en la frente
        dc.setColor(band, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth((0.7 * u).toNumber() < 2 ? 2 : (0.7 * u).toNumber());
        dc.drawArc(cx.toNumber(), headCy.toNumber(), (headR * 0.78).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 38, 142);

        // Ojos grandes con brillo
        var ey = headCy + 0.2 * u;
        for (var side = -1; side <= 1; side += 2) {
            var ex = cx + side * 1.35 * u;
            if (an["blink"] && !sad) {
                dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(o.toNumber());
                dc.drawArc(ex.toNumber(), (ey + 0.35 * u).toNumber(), (0.75 * u).toNumber() + 1, Graphics.ARC_COUNTER_CLOCKWISE, 25, 155);
                continue;
            }
            dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
            fe(dc, ex, ey, 0.9 * u + o * 0.7, 1.1 * u + o * 0.7);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            fe(dc, ex, ey, 0.9 * u, 1.1 * u);
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            fc(dc, ex + side * -0.05 * u, ey + (sad ? 0.45 : 0.2) * u, 0.6 * u);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            fc(dc, ex - 0.2 * u, ey + (sad ? 0.2 : -0.1) * u, 0.23 * u);
            if (sad) {
                // Párpado caído y ceja de pena (más alta junto a la nariz)
                dc.setColor(fur, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle((ex - 1.25 * u).toNumber(), (ey - 1.55 * u).toNumber(), (2.5 * u).toNumber(), (1.2 * u).toNumber());
                dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(o.toNumber());
                dc.drawLine((ex - 0.9 * u).toNumber(), (ey - 0.35 * u).toNumber(), (ex + 0.9 * u).toNumber(), (ey - 0.35 * u).toNumber());
                dc.drawLine((ex - side * 0.85 * u).toNumber(), (ey - 1.95 * u).toNumber(), (ex + side * 0.75 * u).toNumber(), (ey - 1.4 * u).toNumber());
            }
        }

        // Mofletes
        dc.setColor(pink, Graphics.COLOR_TRANSPARENT);
        fe(dc, cx - 2.45 * u, headCy + 1.35 * u, 0.7 * u, 0.42 * u);
        fe(dc, cx + 2.45 * u, headCy + 1.35 * u, 0.7 * u, 0.42 * u);

        // Boca
        var my = headCy + 1.5 * u;
        if (sad) {
            dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(o.toNumber());
            dc.drawArc(cx.toNumber(), (my + 0.85 * u).toNumber(), (0.7 * u).toNumber() + 1, Graphics.ARC_COUNTER_CLOCKWISE, 35, 145);
            var tx = cx - 1.8 * u;
            var ty = ey + 1.45 * u;
            dc.setColor(0x6EC6FF, Graphics.COLOR_TRANSPARENT);
            fc(dc, tx, ty, 0.3 * u);
            dc.fillPolygon([
                [(tx - 0.28 * u).toNumber(), ty.toNumber()],
                [(tx + 0.28 * u).toNumber(), ty.toNumber()],
                [tx.toNumber(), (ty - 0.65 * u).toNumber()]
            ]);
        } else {
            dc.setColor(0x6B1E2B, Graphics.COLOR_TRANSPARENT);
            fc(dc, cx, my, 0.8 * u);
            dc.setColor(fur, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle((cx - 0.95 * u).toNumber(), (my - 0.95 * u).toNumber(), (1.9 * u).toNumber() + 1, (0.95 * u).toNumber());
            dc.setColor(0xFF6F8A, Graphics.COLOR_TRANSPARENT);
            fe(dc, cx, my + 0.5 * u, 0.4 * u, 0.2 * u);
            dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth((o * 0.7).toNumber() < 1 ? 1 : (o * 0.7).toNumber());
            dc.drawLine((cx - 0.8 * u).toNumber(), my.toNumber(), (cx + 0.8 * u).toNumber(), my.toNumber());
        }

        // --- Accesorios de los logros ---
        if (acc["primer"] == true) {
            // Muñequeras
            var wy = sad ? handCy - handR * 0.95 : handCy + handR * 0.95;
            dc.setColor(0x00E5A8, Graphics.COLOR_TRANSPARENT);
            for (var side = -1; side <= 1; side += 2) {
                var wx = cx + side * armX;
                dc.fillRoundedRectangle((wx - armRx * 1.25).toNumber(), (wy - 0.25 * u).toNumber(), (armRx * 2.5).toNumber() + 1, (0.5 * u).toNumber() + 1, 2);
            }
        }
        if (acc["cien"] == true) {
            // Dorsal de carrera en la barriga
            var dw = 1.8 * u;
            var dy = bodyCy + 0.4 * u;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle((cx - dw / 2).toNumber(), dy.toNumber(), dw.toNumber(), (1.2 * u).toNumber(), 2);
            dc.setColor(0xE53935, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle((cx - dw / 2).toNumber(), dy.toNumber(), dw.toNumber(), (0.25 * u).toNumber() + 1);
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle((cx - 0.5 * u).toNumber(), (dy + 0.5 * u).toNumber(), (1.0 * u).toNumber(), (0.18 * u).toNumber() + 1);
            dc.fillRectangle((cx - 0.5 * u).toNumber(), (dy + 0.8 * u).toNumber(), (0.7 * u).toNumber(), (0.18 * u).toNumber() + 1);
        }
        if (acc["hyrox10"] == true) {
            // Medalla al cuello
            dc.setColor(0x3D7BFF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth((0.3 * u).toNumber() + 1);
            dc.drawLine((cx - 1.0 * u).toNumber(), (bodyCy - 2.4 * u).toNumber(), cx.toNumber(), (bodyCy - 1.0 * u).toNumber());
            dc.drawLine((cx + 1.0 * u).toNumber(), (bodyCy - 2.4 * u).toNumber(), cx.toNumber(), (bodyCy - 1.0 * u).toNumber());
            dc.setColor(OUTLINE, Graphics.COLOR_TRANSPARENT);
            fc(dc, cx, bodyCy - 0.6 * u, 0.62 * u + 1);
            dc.setColor(gold, Graphics.COLOR_TRANSPARENT);
            fc(dc, cx, bodyCy - 0.6 * u, 0.55 * u);
        }
        if (acc["nivel10"] == true) {
            // Corona
            var ct = headCy - headR * 0.93;
            var cw = 1.4 * u;
            dc.setColor(gold, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [(cx - cw).toNumber(), (ct + 0.2 * u).toNumber()],
                [(cx - cw).toNumber(), (ct - 0.9 * u).toNumber()],
                [(cx - cw / 2).toNumber(), (ct - 0.3 * u).toNumber()],
                [cx.toNumber(), (ct - 1.2 * u).toNumber()],
                [(cx + cw / 2).toNumber(), (ct - 0.3 * u).toNumber()],
                [(cx + cw).toNumber(), (ct - 0.9 * u).toNumber()],
                [(cx + cw).toNumber(), (ct + 0.2 * u).toNumber()]
            ]);
        }
        if (acc["reto"] == true) {
            // Trofeo junto a los pies
            var tx2 = cx + 4.2 * u;
            var tb = groundY;
            dc.setColor(gold, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [(tx2 - 0.9 * u).toNumber(), (tb - 2.4 * u).toNumber()],
                [(tx2 + 0.9 * u).toNumber(), (tb - 2.4 * u).toNumber()],
                [(tx2 + 0.3 * u).toNumber(), (tb - 1.2 * u).toNumber()],
                [(tx2 - 0.3 * u).toNumber(), (tb - 1.2 * u).toNumber()]
            ]);
            dc.fillRectangle((tx2 - 0.15 * u).toNumber(), (tb - 1.3 * u).toNumber(), (0.3 * u).toNumber() + 1, (0.8 * u).toNumber());
            dc.fillRectangle((tx2 - 0.6 * u).toNumber(), (tb - 0.5 * u).toNumber(), (1.2 * u).toNumber(), (0.4 * u).toNumber() + 1);
        }
        dc.setPenWidth(1);
    }

    // Mensaje de la mascota según cómo vas.
    function mood(sad, lvl) {
        if (sad) {
            var d = Mascota.daysWithoutTraining();
            return d == null ? "¡Vamos a entrenar!" : "Te echo de menos · " + d + " días";
        }
        if (lvl >= Mascota.MAX_LEVEL) {
            return "¡Ya no quepo!";
        }
        if (Application.Storage.getValue("ultimoDia") == null) {
            return "¡Hola! ¿Entrenamos?";
        }
        return Mascota.daysWithoutTraining() <= 1 ? "¡Qué bien entrenamos!" : "¡Sigue así!";
    }

    // Mezcla dos colores RGB: t = 0 -> a, t = 1 -> b.
    function mix(a, b, t) {
        var r = ((a >> 16) & 0xFF) + ((((b >> 16) & 0xFF) - ((a >> 16) & 0xFF)) * t).toNumber();
        var g = ((a >> 8) & 0xFF) + ((((b >> 8) & 0xFF) - ((a >> 8) & 0xFF)) * t).toNumber();
        var bl = (a & 0xFF) + (((b & 0xFF) - (a & 0xFF)) * t).toNumber();
        return (r << 16) | (g << 8) | bl;
    }

    // Cielo en degradado con nubes; gris y con lluvia si está triste.
    function drawSky(dc, sad, frame) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var top = sad ? 0x2E3440 : 0x1F3B73;
        var bottom = sad ? 0x6B7686 : 0x7EC8F0;
        var limit = (h * 0.56).toNumber();
        var bands = 14;
        for (var i = 0; i < bands; i++) {
            dc.setColor(mix(top, bottom, i.toFloat() / (bands - 1)), Graphics.COLOR_TRANSPARENT);
            var y0 = limit * i / bands;
            dc.fillRectangle(0, y0, w, limit * (i + 1) / bands - y0 + 1);
        }
        // Nubes
        var cloud = sad ? 0x9AA3B0 : 0xFFFFFF;
        var clouds = [[0.24, 0.24, 1.0], [0.76, 0.18, 0.8]];
        dc.setColor(cloud, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < clouds.size(); i++) {
            var cx = w * clouds[i][0];
            var cy = h * clouds[i][1];
            var k = w * 0.035 * clouds[i][2];
            dc.fillEllipse(cx.toNumber(), cy.toNumber(), (k * 1.9).toNumber(), (k * 0.8).toNumber());
            dc.fillCircle((cx - k * 0.6).toNumber(), (cy - k * 0.4).toNumber(), (k * 0.8).toNumber());
            dc.fillCircle((cx + k * 0.5).toNumber(), (cy - k * 0.6).toNumber(), (k * 1.0).toNumber());
        }
        if (sad) {
            // Llovizna bajo la nube grande
            dc.setColor(0x9CC9F5, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var i = 0; i < 5; i++) {
                var x = w * (0.18 + i * 0.03);
                var y = h * (0.28 + ((i * 17 + frame * 12) % 90) / 1000.0);
                dc.drawLine(x.toNumber(), y.toNumber(), (x - w * 0.01).toNumber(), (y + h * 0.035).toNumber());
            }
            dc.setPenWidth(1);
        }
    }

    // Colina de césped bajo la mascota.
    function drawHill(dc, sad) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(sad ? 0x5E7563 : 0x5DBB63, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(w / 2, (h * 0.575).toNumber(), (w * 0.62).toNumber(), (h * 0.085).toNumber());
        dc.setColor(sad ? 0x748C79 : 0x7FD67F, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(w / 2, (h * 0.505).toNumber(), (w * 0.34).toNumber(), (h * 0.016).toNumber());
    }

    function stat(dc, x, y, label, value, color) {
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, center);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + dc.getFontHeight(Graphics.FONT_XTINY) * 0.85, Graphics.FONT_XTINY, value.toString(), center);
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var pts = Mascota.points();
        var tot = Mascota.total(pts);
        var lvl = Mascota.level(tot);
        var sad = Mascota.isSad();
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        if (acc == null) {
            acc = {};
        }
        drawSky(dc, sad, frame);
        drawHill(dc, sad);
        drawPet(dc, pts, lvl, sad, animState(), acc);
        drawEffects(dc);
        dc.setColor(0x14213D, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (h * 0.555).toNumber(), w, h);

        // Mensaje
        dc.setColor(sad ? 0xB4C4D6 : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var msg = mood(sad, lvl);
        if (levelUp && frame < 70) {
            msg = "¡Subo al nivel " + lvl + "!";
        } else if (logro != null && frame < 70) {
            msg = "¡Logro: " + logro + "!";
        } else if (gain != null && gainTotal > 0 && frame < 60) {
            msg = "+" + gainTotal + " puntos. ¡Gracias!";
        }
        dc.drawText(w / 2, h * 0.575, Graphics.FONT_XTINY,
            Graphics.fitTextToArea(msg, Graphics.FONT_XTINY, w * 0.84, dc.getFontHeight(Graphics.FONT_XTINY), true), center);

        // Barra de nivel: "Nivel 8 [=====    ] 9"
        var barW = w * 0.46;
        var barH = (h * 0.04).toNumber();
        var barX = (w - barW) / 2;
        var barY = (h * 0.63).toNumber();
        var frac = 1.0;
        if (lvl < Mascota.MAX_LEVEL) {
            var lo = Mascota.threshold(lvl);
            frac = (tot - lo).toFloat() / (Mascota.threshold(lvl + 1) - lo);
        }
        dc.setColor(0x2B3D63, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX.toNumber(), barY, barW.toNumber(), barH, barH / 2);
        dc.setColor(COLOR_HYROX, Graphics.COLOR_TRANSPARENT);
        var fill = (barW * frac).toNumber();
        if (fill > barH) {
            dc.fillRoundedRectangle(barX.toNumber(), barY, fill, barH, barH / 2);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX - w * 0.03, barY + barH / 2, Graphics.FONT_XTINY, "Nv " + lvl, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (lvl < Mascota.MAX_LEVEL) {
            dc.drawText(barX + barW + w * 0.03, barY + barH / 2, Graphics.FONT_XTINY, (lvl + 1).toString(), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var next = lvl >= Mascota.MAX_LEVEL
            ? "¡Nivel máximo!"
            : (Mascota.threshold(lvl + 1) - tot) + " pts para subir";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.715, Graphics.FONT_XTINY, next, center);

        // Contadores con nombre y color
        var y = h * 0.79;
        stat(dc, w * 0.265, y, "Gym", pts["gym"], COLOR_GYM);
        stat(dc, w * 0.50, y, "Carrera", pts["carrera"], COLOR_CARRERA);
        stat(dc, w * 0.735, y, "Hyrox", pts["hyrox"], COLOR_HYROX);
    }
}
