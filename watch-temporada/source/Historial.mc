using Toybox.Activity;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.UserProfile;

// Lectura del historial de actividades del reloj y utilidades de fechas.
// Las fechas se manejan como "número de día" (días desde 1970-01-01, hora local)
// para comparar sin problemas de zona horaria.
module Historial {
    const MIN_SECS = 600;          // Las actividades de menos de 10 min no cuentan
    const MAX_VALID_M = 1000000;   // El reloj usa 42949672 m como "sin dato"

    const CAT_GYM = "gym";
    const CAT_CARRERA = "carrera";
    const CAT_HYROX = "hyrox";

    // running = carrera, HIIT = hyrox (Hyrox Coach y modo HIIT), training = gym.
    function category(type) {
        if (type == Activity.SPORT_RUNNING) {
            return CAT_CARRERA;
        }
        if (type == Activity.SPORT_HIIT) {
            return CAT_HYROX;
        }
        if (type == Activity.SPORT_TRAINING) {
            return CAT_GYM;
        }
        return null;
    }

    // Categoría de una sesión de la agenda.
    function agendaCategory(tipo) {
        if ("gym".equals(tipo)) {
            return CAT_GYM;
        }
        if ("hyrox".equals(tipo)) {
            return CAT_HYROX;
        }
        return CAT_CARRERA; // series, rodaje, tirada
    }

    // Algoritmo days_from_civil (H. Hinnant).
    function dayNumber(y, m, d) {
        var yy = m <= 2 ? y - 1 : y;
        var era = (yy >= 0 ? yy : yy - 399) / 400;
        var yoe = yy - era * 400;
        var mp = (m + 9) % 12;
        var doy = (153 * mp + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // "2026-11-22" -> número de día.
    function parseDate(text) {
        return dayNumber(
            text.substring(0, 4).toNumber(),
            text.substring(5, 7).toNumber(),
            text.substring(8, 10).toNumber()
        );
    }

    function momentDay(moment) {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return dayNumber(info.year, info.month, info.day);
    }

    function today() {
        return momentDay(Time.now());
    }

    // Número de día -> [año, mes, día] (civil_from_days, H. Hinnant).
    function civil(dn) {
        var z = dn + 719468;
        var era = (z >= 0 ? z : z - 146096) / 146097;
        var doe = z - era * 146097;
        var yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        var doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        var mp = (5 * doy + 2) / 153;
        var d = doy - (153 * mp + 2) / 5 + 1;
        var m = mp < 10 ? mp + 3 : mp - 9;
        var y = yoe + era * 400 + (m <= 2 ? 1 : 0);
        return [y, m, d];
    }

    // Lunes de la semana del día dn.
    function monday(dn) {
        return dn - weekday(dn);
    }

    // "1h 05m" o "45m"
    function fmtDur(secs) {
        var mins = secs / 60;
        if (mins < 60) {
            return mins + "m";
        }
        return (mins / 60) + "h " + (mins % 60).format("%02d") + "m";
    }

    // 0 = lunes ... 6 = domingo.
    function weekday(dn) {
        return ((dn + 3) % 7 + 7) % 7;
    }

    function dayShort(dn) {
        return ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"][weekday(dn)];
    }

    // "6,1" con coma decimal.
    function fmtKm(km) {
        var tenths = (km * 10 + 0.5).toNumber();
        return (tenths / 10) + "," + (tenths % 10);
    }

    // Actividades que cuentan: [{start, dn, cat, secs, km}], en el orden del reloj.
    function load() {
        var list = [];
        if (!(UserProfile has :getUserActivityHistory)) {
            return list;
        }
        var it = UserProfile.getUserActivityHistory();
        var a = it.next();
        while (a != null) {
            var cat = category(a.type);
            if (cat != null && a.startTime != null && a.duration != null) {
                var secs = a.duration.value();
                if (secs >= MIN_SECS) {
                    var km = 0.0;
                    if (a.distance != null && a.distance > 0 && a.distance < MAX_VALID_M) {
                        km = a.distance / 1000.0;
                    }
                    list.add({
                        "start" => a.startTime.value(),
                        "dn" => momentDay(a.startTime),
                        "cat" => cat,
                        "secs" => secs,
                        "km" => km
                    });
                }
            }
            a = it.next();
        }
        return list;
    }
}
