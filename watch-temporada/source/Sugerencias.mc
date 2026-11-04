using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Ideas de HYROX, Hybrid Day y carreras de la provincia de Valencia (docs/sugerencias.json).
// Menú por tipo -> lista ordenada por fecha -> ficha con toda la información.
module Sugerencias {
    const MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
    const TIPOS = ["carrera", "hyrox", "hybrid"];

    function tipoLabel(tipo) {
        if ("hyrox".equals(tipo)) {
            return "HYROX";
        }
        if ("hybrid".equals(tipo)) {
            return "Hybrid Day";
        }
        return "Carrera";
    }

    function tipoColor(tipo) {
        if ("hyrox".equals(tipo)) {
            return 0x00E5A8;
        }
        if ("hybrid".equals(tipo)) {
            return 0xFF7A3D;
        }
        return 0x4DA8FF;
    }

    // "2026-12-13" -> "13 dic"
    function fmtFecha(text) {
        return text.substring(8, 10).toNumber() + " " + MESES[text.substring(5, 7).toNumber() - 1];
    }

    function fmtRango(s) {
        var fin = s["fecha_fin"];
        if (fin == null || fin.equals(s["fecha"])) {
            return fmtFecha(s["fecha"]);
        }
        if (fin.substring(5, 7).equals(s["fecha"].substring(5, 7))) {
            return s["fecha"].substring(8, 10).toNumber() + "-" + fmtFecha(fin);
        }
        return fmtFecha(s["fecha"]) + "-" + fmtFecha(fin);
    }

    function distancias(s) {
        var ds = s["distancias"];
        if (ds instanceof Lang.Array && ds.size() > 0) {
            var text = "";
            for (var i = 0; i < ds.size(); i++) {
                text += (i > 0 ? " · " : "") + ds[i];
            }
            return text;
        }
        if (s["distancia_km"] != null) {
            return Historial.fmtKm(s["distancia_km"].toFloat()) + " km";
        }
        return null;
    }

    // Las que no han pasado, del tipo pedido (o todas con null), ordenadas por fecha.
    function upcoming(tipo) {
        var list = Datos.sugerencias()["sugerencias"];
        var today = Historial.today();
        var out = [];
        for (var i = 0; i < list.size(); i++) {
            var s = list[i];
            if (tipo != null && !tipo.equals(s["tipo"])) {
                continue;
            }
            var end = s["fecha_fin"] != null ? s["fecha_fin"] : s["fecha"];
            if (Historial.parseDate(end) < today) {
                continue;
            }
            var dn = Historial.parseDate(s["fecha"]);
            var pos = out.size();
            while (pos > 0 && Historial.parseDate(out[pos - 1]["fecha"]) > dn) {
                pos -= 1;
            }
            out = out.slice(0, pos).addAll([s]).addAll(out.slice(pos, null));
        }
        return out;
    }

    function buildMenu() {
        var menu = new WatchUi.Menu2({:title => "Sugerencias"});
        for (var i = 0; i < TIPOS.size(); i++) {
            var items = upcoming(TIPOS[i]);
            var sub = items.size() == 0 ? "Ninguna por ahora"
                : (items.size() == 1 ? "1 próxima" : items.size() + " próximas") + " · " + fmtRango(items[0]);
            var label = "carrera".equals(TIPOS[i]) ? "Carreras (Valencia)" : tipoLabel(TIPOS[i]);
            menu.addItem(new WatchUi.MenuItem(label, sub, TIPOS[i], {}));
        }
        return menu;
    }

    function buildList(tipo) {
        var items = upcoming(tipo);
        var title = "carrera".equals(tipo) ? "Carreras" : tipoLabel(tipo);
        var menu = new WatchUi.Menu2({:title => title});
        if (items.size() == 0) {
            menu.addItem(new WatchUi.MenuItem("Sin sugerencias", "Se actualizan cada mes", 0, {}));
            return [menu, items];
        }
        for (var i = 0; i < items.size(); i++) {
            var s = items[i];
            var sub = fmtRango(s) + " · " + s["lugar"];
            menu.addItem(new WatchUi.MenuItem(s["nombre"], sub, i, {}));
        }
        return [menu, items];
    }
}

class SugerenciasDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var r = Sugerencias.buildList(item.getId());
        WatchUi.pushView(r[0], new SugerenciasListDelegate(r[1]), WatchUi.SLIDE_LEFT);
    }
}

class SugerenciasListDelegate extends WatchUi.Menu2InputDelegate {
    var items;

    function initialize(aItems) {
        Menu2InputDelegate.initialize();
        items = aItems;
    }

    function onSelect(item) {
        var i = item.getId();
        if (i < items.size()) {
            WatchUi.pushView(new SugerenciaView(items[i]), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

// Ficha de una sugerencia.
class SugerenciaView extends WatchUi.View {
    var s;

    function initialize(aS) {
        View.initialize();
        s = aS;
    }

    // Icono de ubicación (gota).
    function pin(dc, x, y, r, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - r / 2, r);
        dc.fillPolygon([[x - r, y - r / 2], [x + r, y - r / 2], [x, y + r + r / 2]]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - r / 2, r / 2);
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var color = Sugerencias.tipoColor(s["tipo"]);
        var today = Historial.today();
        var dn = Historial.parseDate(s["fecha"]);

        // Etiqueta del tipo
        var tag = Sugerencias.tipoLabel(s["tipo"]).toUpper();
        var tw = dc.getTextWidthInPixels(tag, Graphics.FONT_XTINY) + 16;
        var th = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((w - tw) / 2, (h * 0.12 - th / 2).toNumber(), tw, th, th / 2);
        Graf.text(dc, w / 2, h * 0.12, Graphics.FONT_XTINY, tag, Graphics.COLOR_BLACK);

        // Nombre (hasta dos líneas)
        var nf = dc.getTextWidthInPixels(s["nombre"], Graphics.FONT_SMALL) <= w * 0.76 ? Graphics.FONT_SMALL : Graphics.FONT_TINY;
        var name = Graphics.fitTextToArea(s["nombre"], nf, w * 0.76, dc.getFontHeight(nf) * 2, true);
        Graf.text(dc, w / 2, h * 0.255, nf, name, Graphics.COLOR_WHITE);

        // Cuenta atrás
        var days = dn - today;
        var when = days <= 0 ? "¡Es hoy!" : (days == 1 ? "Mañana" : "En " + days + " días");
        Graf.text(dc, w / 2, h * 0.395, Graphics.FONT_MEDIUM, when, color);

        // Fecha y hora
        var fecha = Historial.dayShort(dn) + " " + Sugerencias.fmtRango(s);
        if (s["hora"] != null) {
            fecha += " · " + s["hora"];
        }
        Graf.text(dc, w / 2, h * 0.495, Graphics.FONT_TINY, fecha, Graphics.COLOR_WHITE);

        // Lugar con icono
        var lugar = s["lugar"];
        var lw = dc.getTextWidthInPixels(lugar, Graphics.FONT_TINY);
        pin(dc, (w / 2 - lw / 2 - 10).toNumber(), (h * 0.575).toNumber(), 5, color);
        Graf.text(dc, w / 2 + 6, h * 0.575, Graphics.FONT_TINY, lugar, Graf.MUTED);

        // Distancias, precio y circuito
        var y = h * 0.665;
        var ds = Sugerencias.distancias(s);
        if (ds != null) {
            Graf.text(dc, w / 2, y, Graphics.FONT_TINY, Graf.fit(dc, ds, Graphics.FONT_TINY, w * 0.8), Graphics.COLOR_WHITE);
            y += h * 0.08;
        }
        var extra = "";
        if (s["precio_desde"] != null) {
            extra = s["precio_desde"] == 0 ? "Gratis" : "Desde " + s["precio_desde"].toNumber() + " €";
        }
        if (s["circuito"] != null) {
            extra += (extra.length() > 0 ? " · " : "") + s["circuito"];
        }
        if (extra.length() > 0) {
            Graf.text(dc, w / 2, y, Graphics.FONT_XTINY, Graf.fit(dc, extra, Graphics.FONT_XTINY, w * 0.74), Graf.MUTED);
            y += h * 0.07;
        }

        // Fuente (dominio)
        var src = s["fuente"];
        if (src != null) {
            var host = src;
            var p = host.find("://");
            if (p != null) {
                host = host.substring(p + 3, host.length());
            }
            var slash = host.find("/");
            if (slash != null) {
                host = host.substring(0, slash);
            }
            // Solo el dominio principal: "inscripciones.cronorunner.com" -> "cronorunner.com"
            var dot = host.find(".");
            while (dot != null && host.substring(dot + 1, host.length()).find(".") != null) {
                host = host.substring(dot + 1, host.length());
                dot = host.find(".");
            }
            Graf.text(dc, w / 2, h * 0.87, Graphics.FONT_XTINY, host, 0x5A6B8C);
        }
    }
}
