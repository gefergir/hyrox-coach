using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

// Vista rápida en la lista de widgets: nivel de la mascota, la sesión de hoy y el
// próximo reto. Solo lee lo que la app deja preparado en Storage ("glance"), para
// gastar la mínima memoria.
(:glance)
class TemporadaGlance extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function dayNumber(y, m, d) {
        var yy = m <= 2 ? y - 1 : y;
        var era = (yy >= 0 ? yy : yy - 399) / 400;
        var yoe = yy - era * 400;
        var mp = (m + 9) % 12;
        var doy = (153 * mp + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    function onUpdate(dc) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = dayNumber(info.year, info.month, info.day);
        var g = Application.Storage.getValue("glance");

        var l1 = "Mi Temporada";
        var l2 = "Abre la app";
        var l3 = "";
        if (g instanceof Lang.Dictionary) {
            var sad = today - g["ultimoDia"] >= 5;
            l1 = "Nivel " + g["nivel"] + (sad ? " · te echa de menos" : "");
            var hoy = g["agenda"][today];
            l2 = hoy != null ? "Hoy: " + hoy : "Hoy: descanso";
            var retos = g["retos"];
            for (var i = 0; i < retos.size(); i++) {
                var days = retos[i][0] - today;
                if (days >= 0) {
                    l3 = (days == 0 ? "¡Hoy! " : days + " d · ") + retos[i][1];
                    break;
                }
            }
        }

        var h = dc.getHeight();
        var lines = l3.length() > 0 ? [l1, l2, l3] : [l1, l2];
        var colors = [0x00E5A8, Graphics.COLOR_WHITE, Graphics.COLOR_LT_GRAY];
        for (var i = 0; i < lines.size(); i++) {
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, h * (i + 0.5) / lines.size(), Graphics.FONT_GLANCE, lines[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
