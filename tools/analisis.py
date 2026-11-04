#!/usr/bin/env python3
"""Análisis profundo de los entrenos a partir de los FIT del reloj.

Calcula lo que el Forerunner 165 y Garmin Connect no dan:
- Carga diaria (TRIMP de Banister), fatiga (7 d), forma (42 d), ratio agudo:crónico.
- Metros por latido en carrera (eficiencia aeróbica) y deriva del pulso en carreras largas.
- Caída de ritmo en series (primera mitad frente a segunda).
- Efecto gym: eficiencia de las carreras en las 24 h siguientes a una sesión de gym.
- Parciales por estación de Hyrox Coach y del Simulacro HYROX.
- Hábitos: mapa día x hora, descanso entre sesiones y reparto por tipo.

Uso: python3 tools/analisis.py <carpeta_fit> <salida_completa.json> <salida_reloj.json>
La salida completa (con todo el detalle) es para el panel web; la del reloj es un resumen pequeño.
Ninguna de las dos lleva posiciones GPS.
"""
import datetime as dt
import json
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

FIT_EPOCH = dt.datetime(1989, 12, 31, tzinfo=dt.timezone.utc)
CATS = {1: "carrera", 10: "gym", 62: "hyrox"}

BASE = {  # tipo base FIT -> (formato struct, valor inválido)
    0x00: ("B", 0xFF), 0x01: ("b", 0x7F), 0x02: ("B", 0xFF), 0x83: ("h", 0x7FFF), 0x84: ("H", 0xFFFF),
    0x85: ("i", 0x7FFFFFFF), 0x86: ("I", 0xFFFFFFFF), 0x07: (None, None), 0x88: ("f", None),
    0x89: ("d", None), 0x0A: ("B", 0x00), 0x8B: ("H", 0x0000), 0x8C: ("I", 0x00000000), 0x0D: (None, None),
    0x8E: ("q", None), 0x8F: ("Q", None), 0x90: ("Q", None),
}


def decode(raw, base, endian):
    fmt, invalid = BASE.get(base, (None, None))
    if base == 0x07:
        return raw.split(b"\0")[0].decode("utf-8", "replace") or None
    if fmt is None:
        return raw
    size = struct.calcsize(fmt)
    if len(raw) < size:
        return None
    if len(raw) > size:  # arrays: nos quedamos con el primero
        raw = raw[:size]
    v = struct.unpack(endian + fmt, raw)[0]
    if invalid is not None and v == invalid:
        return None
    return v


def parse(path):
    """Devuelve {"session": {...}, "records": [...], "laps": [...], "profile": {...}}."""
    data = Path(path).read_bytes()
    hsize = data[0]
    end = hsize + struct.unpack("<I", data[4:8])[0]
    pos = hsize
    defs = {}
    dev_names = {}  # (dev_index, field_num) -> nombre
    out = {"session": None, "records": [], "laps": [], "profile": {}}
    last_ts = None
    while pos < end:
        h = data[pos]
        pos += 1
        if h & 0x80:  # cabecera de timestamp comprimido
            local = (h >> 5) & 0x3
            offset = h & 0x1F
            is_def = False
            has_dev = False
            if last_ts is not None:
                ts = (last_ts & ~0x1F) + offset
                if ts < last_ts:
                    ts += 0x20
                last_ts = ts
        else:
            local = h & 0x0F
            is_def = bool(h & 0x40)
            has_dev = bool(h & 0x20)
        if is_def:
            endian = ">" if data[pos + 1] == 1 else "<"
            gnum = struct.unpack(endian + "H", data[pos + 2:pos + 4])[0]
            n = data[pos + 4]
            pos += 5
            fields = []
            for _ in range(n):
                fields.append((data[pos], data[pos + 1], data[pos + 2]))
                pos += 3
            devf = []
            if has_dev:
                nd = data[pos]
                pos += 1
                for _ in range(nd):
                    devf.append((data[pos], data[pos + 1], data[pos + 2]))
                    pos += 3
            defs[local] = (gnum, fields, devf, endian)
            continue
        gnum, fields, devf, endian = defs[local]
        v = {}
        for num, size, base in fields:
            v[num] = decode(data[pos:pos + size], base, endian)
            pos += size
        dv = {}
        for num, size, idx in devf:
            raw = data[pos:pos + size]
            pos += size
            name = dev_names.get((idx, num))
            if name:
                dv[name] = raw.split(b"\0")[0].decode("utf-8", "replace")
        if 253 in v and v[253] is not None:
            last_ts = v[253]
        if gnum == 206:  # field_description
            dev_names[(v.get(0), v.get(1))] = v.get(3)
        elif gnum == 3:  # user_profile
            out["profile"] = {"gender": v.get(1), "rest_hr": v.get(8), "max_hr": v.get(11) if 11 in v else None}
        elif gnum == 20:  # record
            spd = v.get(73) if v.get(73) is not None else v.get(6)
            out["records"].append({
                "t": v.get(253) if v.get(253) is not None else last_ts,
                "hr": v.get(3),
                "d": v[5] / 100 if v.get(5) is not None else None,
                "v": spd / 1000 if spd is not None else None,
            })
        elif gnum == 19:  # lap
            out["laps"].append({
                "start": v.get(2), "secs": v[8] / 1000 if v.get(8) else None,
                "dist": v[9] / 100 if v.get(9) is not None else None,
                "hr": v.get(15), "intensity": v.get(23), "name": dv.get("paso") or dv.get("tramo"),
            })
        elif gnum == 18:  # session
            out["session"] = {
                "sport": v.get(5), "sub": v.get(6), "start": v.get(2),
                "secs": v[8] / 1000 if v.get(8) else 0, "dist": v[9] / 100 if v.get(9) else 0,
                "avg_hr": v.get(16), "max_hr": v.get(17),
            }
    return out


def local_dt(ts):
    return (FIT_EPOCH + dt.timedelta(seconds=ts)).astimezone()


def trimp(records, rest, hrmax, k):
    """TRIMP de Banister sumando muestra a muestra (minutos x reserva x 0,64·e^(k·reserva))."""
    total = 0.0
    prev = None
    for r in records:
        if r["t"] is None or r["hr"] is None:
            prev = r
            continue
        if prev is not None and prev["t"] is not None and prev["hr"] is not None:
            dtm = (r["t"] - prev["t"]) / 60.0
            if 0 < dtm <= 0.5:  # descarta pausas
                hrr = max(0.0, min(1.0, (prev["hr"] - rest) / (hrmax - rest)))
                total += dtm * hrr * 0.64 * math.exp(k * hrr)
        prev = r
    return total


def efficiency(records, skip_s=300):
    """Metros por latido: velocidad (m/min) / pulso (lpm), sin los primeros minutos."""
    if not records or records[0]["t"] is None:
        return None
    t0 = records[0]["t"]
    pts = [r for r in records if r["t"] is not None and r["t"] - t0 >= skip_s and r["hr"] and r["v"] and r["v"] > 1.5]
    if len(pts) < 60:
        return None
    return sum(r["v"] * 60 / r["hr"] for r in pts) / len(pts), pts


def decoupling(pts):
    half = len(pts) // 2
    ef = lambda ps: sum(r["v"] * 60 / r["hr"] for r in ps) / len(ps)
    a, b = ef(pts[:half]), ef(pts[half:])
    return (a - b) / a * 100 if a else None


def series_fade(laps, session_pace):
    """Caída de ritmo entre la primera y la segunda mitad de las repeticiones.

    Solo cuenta como series si hay recuperaciones entre medias, las repeticiones tienen
    una distancia parecida y son claramente más rápidas que el ritmo medio de la sesión
    (así no se cuelan las vueltas automáticas de 1 km de un rodaje)."""
    rec = [l for l in laps if l["intensity"] in (1, 4)]
    cand = [l for l in laps if l["intensity"] in (0, None) and l["dist"] and l["secs"] and 150 <= l["dist"] <= 2100]
    if len(cand) < 4 or len(rec) < 3:
        return None
    dists = sorted(l["dist"] for l in cand)
    med = dists[len(dists) // 2]
    reps = [l for l in cand if abs(l["dist"] - med) <= med * 0.15]
    reps = [l for l in reps if l["secs"] / (l["dist"] / 1000) < session_pace * 0.95]
    if len(reps) < 4:
        return None
    paces = [l["secs"] / (l["dist"] / 1000) for l in reps]
    h = len(paces) // 2
    first, second = sum(paces[:h]) / h, sum(paces[h:]) / (len(paces) - h)
    return {"reps": len(paces), "pace_first": first, "pace_second": second, "fade_pct": (second - first) / first * 100}


def ewma(series, days):
    a = 1 - math.exp(-1 / days)
    out = []
    v = 0.0
    for x in series:
        v = v + a * (x - v)
        out.append(v)
    return out


def main():
    src, out_full, out_watch = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    acts = []
    profile = {}
    for f in sorted(src.glob("*.fit")):
        try:
            p = parse(f)
        except Exception as e:  # noqa
            print("No se pudo leer", f.name, e)
            continue
        if p["profile"]:
            profile = p["profile"]
        s = p["session"]
        if not s or s["sport"] not in CATS or not s["start"] or s["secs"] < 600:
            continue
        acts.append({"file": f.name, "cat": CATS[s["sport"]], "s": s, "records": p["records"], "laps": p["laps"]})
    acts.sort(key=lambda a: a["s"]["start"])

    # Pulso en reposo y máximo de referencia
    rest = profile.get("rest_hr") or 55
    peaks = sorted(a["s"]["max_hr"] for a in acts if a["s"]["max_hr"])
    hrmax = profile.get("max_hr") or (peaks[int(len(peaks) * 0.98) - 1] if peaks else 190)
    k = 1.67 if profile.get("gender") == 0 else 1.92  # 0 = mujer en el perfil FIT

    rows = []
    for a in acts:
        s = a["s"]
        start = local_dt(s["start"])
        row = {
            "fecha": start.date().isoformat(), "hora": start.hour, "dow": start.weekday(),
            "cat": a["cat"], "min": round(s["secs"] / 60, 1), "km": round(s["dist"] / 1000, 2),
            "fc": s["avg_hr"], "trimp": round(trimp(a["records"], rest, hrmax, k), 1),
        }
        if a["cat"] == "carrera":
            e = efficiency(a["records"])
            if e:
                row["mpl"] = round(e[0], 3)
                if s["secs"] >= 2700:
                    row["deriva"] = round(decoupling(e[1]), 1)
            pace = s["secs"] / (s["dist"] / 1000) if s["dist"] else 9999
            fade = series_fade(a["laps"], pace)
            if fade:
                row["series"] = {k2: round(v, 1) for k2, v in fade.items()}
        named = [l for l in a["laps"] if l["name"] and l["secs"]]
        if named:
            row["tramos"] = [{"n": l["name"], "s": round(l["secs"])} for l in named]
        rows.append(row)

    # Carga diaria -> fatiga (7 d), forma (42 d), ratio agudo:crónico
    if rows:
        d0 = dt.date.fromisoformat(rows[0]["fecha"])
        d1 = dt.date.today()
        days = [(d0 + dt.timedelta(n)) for n in range((d1 - d0).days + 1)]
        load = defaultdict(float)
        for r in rows:
            load[r["fecha"]] += r["trimp"]
        series = [load[d.isoformat()] for d in days]
        atl, ctl = ewma(series, 7), ewma(series, 42)
        carga = [{"fecha": d.isoformat(), "trimp": round(x, 1), "fatiga": round(a, 1), "forma": round(c, 1),
                  "ratio": round(a / c, 2) if c > 1 else None}
                 for d, x, a, c in zip(days, series, atl, ctl)]
    else:
        carga = []

    # Efecto gym: eficiencia de carreras <= 24 h después de gym frente al resto
    gym_days = {r["fecha"] for r in rows if r["cat"] == "gym"}
    after, normal = [], []
    for r in rows:
        if r["cat"] == "carrera" and "mpl" in r:
            prev = (dt.date.fromisoformat(r["fecha"]) - dt.timedelta(1)).isoformat()
            (after if (prev in gym_days or r["fecha"] in gym_days) else normal).append(r["mpl"])
    efecto_gym = None
    if len(after) >= 3 and len(normal) >= 3:
        a_m, n_m = sum(after) / len(after), sum(normal) / len(normal)
        efecto_gym = {"tras_gym": round(a_m, 3), "resto": round(n_m, 3), "dif_pct": round((a_m - n_m) / n_m * 100, 1),
                      "n_tras": len(after), "n_resto": len(normal)}

    # Hábitos
    heat = [[0] * 24 for _ in range(7)]
    for r in rows:
        heat[r["dow"]][r["hora"]] += 1
    fechas = sorted({r["fecha"] for r in rows})
    gaps = [(dt.date.fromisoformat(b) - dt.date.fromisoformat(a)).days for a, b in zip(fechas, fechas[1:])]
    habitos = {
        "mapa": heat,
        "descanso_medio": round(sum(gaps) / len(gaps), 2) if gaps else None,
        "descanso_max": max(gaps) if gaps else None,
    }

    # Hyrox por estaciones (de las sesiones con tramos con nombre)
    estaciones = defaultdict(list)
    for r in rows:
        for t in r.get("tramos", []):
            estaciones[t["n"]].append({"fecha": r["fecha"], "s": t["s"]})

    full = {
        "generado": dt.datetime.now().isoformat(timespec="minutes"),
        "referencias": {"fc_reposo": rest, "fc_max": hrmax, "coef": k},
        "actividades": rows, "carga": carga, "efecto_gym": efecto_gym,
        "habitos": habitos, "estaciones": estaciones,
    }
    out_full.parent.mkdir(parents=True, exist_ok=True)
    out_full.write_text(json.dumps(full, ensure_ascii=False, indent=1), encoding="utf-8")

    # Resumen para el reloj (pequeño)
    runs = [r for r in rows if "mpl" in r]
    last = carga[-1] if carga else {}
    weekly_mpl = defaultdict(list)
    for r in runs:
        d = dt.date.fromisoformat(r["fecha"])
        weekly_mpl[(d - dt.timedelta(d.weekday())).isoformat()].append(r["mpl"])
    mpl_trend = [[w, round(sum(v) / len(v), 3)] for w, v in sorted(weekly_mpl.items())][-12:]
    deriva = [[r["fecha"], r["deriva"]] for r in runs if "deriva" in r][-8:]
    series = [[r["fecha"], r["series"]["fade_pct"], r["series"]["reps"]] for r in rows if "series" in r][-6:]
    watch = {
        "generado": full["generado"][:10],
        "carga": [[c["fecha"], c["fatiga"], c["forma"]] for c in carga[-56:]],
        "hoy": {"fatiga": last.get("fatiga"), "forma": last.get("forma"), "ratio": last.get("ratio")},
        "mpl": mpl_trend, "deriva": deriva, "series": series, "efecto_gym": efecto_gym,
        "mapa": heat, "descanso_medio": habitos["descanso_medio"],
        "estaciones": {n: [x["s"] for x in v[-6:]] for n, v in estaciones.items()},
    }
    out_watch.write_text(json.dumps(watch, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    print(f"{len(rows)} entrenos analizados · FC reposo {rest} · FC máx {hrmax}")
    print(f"Hoy: fatiga {last.get('fatiga')} · forma {last.get('forma')} · ratio {last.get('ratio')}")
    print(f"Carreras con eficiencia: {len(runs)} · con deriva: {len(deriva)} · series detectadas: {len(series)}")
    print(f"Efecto gym: {efecto_gym}")
    print(f"Descanso medio: {habitos['descanso_medio']} días · estaciones con datos: {list(estaciones)}")
    print(f"Resumen reloj: {out_watch.stat().st_size} bytes")


if __name__ == "__main__":
    main()
