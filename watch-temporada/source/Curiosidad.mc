using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Una curiosidad al día (docs/curiosidades.json). Si un día no tiene la suya,
// se repite una anterior para no dejar el apartado vacío.
module Curiosidad {
    function valid(data) {
        return data instanceof Lang.Dictionary && data["curiosidades"] instanceof Lang.Array;
    }

    function all() {
        var stored = Application.Storage.getValue("curiosidades");
        return valid(stored) ? stored["curiosidades"] : WatchUi.loadResource(Rez.JsonData.CuriosidadesIniciales)["curiosidades"];
    }

    function today() {
        var list = all();
        if (list.size() == 0) {
            return null;
        }
        var dn = Historial.today();
        for (var i = 0; i < list.size(); i++) {
            if (Historial.parseDate(list[i]["fecha"]) == dn) {
                return list[i];
            }
        }
        return list[(dn % list.size() + list.size()) % list.size()];
    }

    function temaColor(tema) {
        var colors = {
            "Espacio" => 0x8B7CFF, "Animales" => 0xFFB347, "Historia" => 0xE0B15C,
            "Valencia" => 0xFF7A3D, "Cuerpo" => 0xFF5C8A, "Ciencia" => 0x4DA8FF,
            "Lenguaje" => 0x00E5A8, "Comida" => 0xF2C94C, "Tecnología" => 0x56CCF2,
            "Geografía" => 0x6FCF97, "Deporte" => 0x00E5A8, "Tradición" => 0xEB5757
        };
        var c = colors[tema];
        return c != null ? c : 0x00E5A8;
    }
}

class CuriosidadView extends WatchUi.View {
    var c;

    function initialize() {
        View.initialize();
        c = Curiosidad.today();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (c == null) {
            Graf.text(dc, w / 2, h / 2, Graphics.FONT_SMALL, "Sin curiosidades", Graf.MUTED);
            return;
        }
        var color = Curiosidad.temaColor(c["tema"]);

        // Cabecera: "¿SABÍAS QUE…?" y etiqueta del tema
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, "¿SABÍAS QUE…?", Graf.MUTED);
        var tag = c["tema"].toUpper();
        var tw = dc.getTextWidthInPixels(tag, Graphics.FONT_XTINY) + 16;
        var th = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((w - tw) / 2, (h * 0.2 - th / 2).toNumber(), tw, th, th / 2);
        Graf.text(dc, w / 2, h * 0.2, Graphics.FONT_XTINY, tag, Graphics.COLOR_BLACK);

        // Título
        var tf = dc.getTextWidthInPixels(c["titulo"], Graphics.FONT_SMALL) <= w * 0.8 ? Graphics.FONT_SMALL : Graphics.FONT_TINY;
        var title = Graphics.fitTextToArea(c["titulo"], tf, w * 0.82, dc.getFontHeight(tf), true);
        Graf.text(dc, w / 2, h * 0.31, tf, title, Graphics.COLOR_WHITE);

        // Línea fina de separación
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((w * 0.42).toNumber(), (h * 0.375).toNumber(), (w * 0.16).toNumber(), 3, 1);

        // Texto en varias líneas dentro de la zona útil de la pantalla redonda
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var text = Graphics.fitTextToArea(c["texto"], Graphics.FONT_XTINY, w * 0.8, fh * 6, true);
        dc.setColor(0xD8DEE9, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.41, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
