using Toybox.WatchUi;

// Cómo gana puntos la mascota, en frases cortas que caben en el reloj.
module Info {
    function buildMenu() {
        var lines = [
            ["Abre la app", "Suma lo que entrenes"],
            ["1 punto por minuto", "Gym, carrera e Hyrox"],
            ["+5 puntos por km", "Solo al correr"],
            ["Mínimo 10 minutos", "Lo más corto no cuenta"],
            ["Gym", "Brazos y torso (Fuerza)"],
            ["Carrera", "Piernas (Correr)"],
            ["Hyrox", "Todo el cuerpo (HIIT)"],
            ["Hyrox Coach cuenta", "Graba como HIIT"],
            ["Sube de nivel", "Barra verde: lo que falta"],
            ["Nunca encoge", "Los puntos no se pierden"],
            ["5 días sin entrenar", "Se pone triste"],
            ["Nivel 15", "¡Ya no cabe en pantalla!"],
            ["Semana: pulsa sesión", "Abre Hyrox o tu entreno"],
            ["Entrenos de Garmin", "Llámalos Series, Empuje..."]
        ];
        var menu = new WatchUi.Menu2({:title => "Info"});
        for (var i = 0; i < lines.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(lines[i][0], lines[i][1], i, {}));
        }
        return menu;
    }
}
