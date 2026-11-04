#!/usr/bin/env python3
"""Prepara los conjuntos de datos del panel web a partir de analisis.json.

Uso: python3 tools/panel_datos.py <analisis.json> <carpeta_salida>
Escribe carga.json, actividades.json, series.json, mapa.json y efecto_gym.json (filas JSON).
"""
import json
import sys
from pathlib import Path

src = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)


def write(name, rows):
    (out / f"{name}.json").write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")
    print(name, len(rows), "filas")


# Carga: últimos 180 días
carga = [c for c in src["carga"] if c["ratio"] is not None][-180:]
write("carga", [{"fecha": c["fecha"], "trimp": c["trimp"], "fatiga": c["fatiga"], "forma": c["forma"],
                 "ratio": c["ratio"]} for c in carga])

acts = []
for i, a in enumerate(src["actividades"]):
    acts.append({
        "id": f"{a['fecha']}-{i}", "fecha": a["fecha"], "tipo": a["cat"], "minutos": a["min"], "km": a["km"],
        "fc_media": a["fc"], "carga": a["trimp"], "metros_latido": a.get("mpl"), "deriva_pct": a.get("deriva"),
    })
write("actividades", acts)

write("series", [{"fecha": a["fecha"], "repeticiones": a["series"]["reps"],
                  "ritmo_inicio_s": a["series"]["pace_first"], "ritmo_final_s": a["series"]["pace_second"],
                  "caida_pct": a["series"]["fade_pct"]}
                 for a in src["actividades"] if "series" in a])

dias = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
mapa = []
for d, row in enumerate(src["habitos"]["mapa"]):
    for b in range(8):
        mapa.append({"dia": dias[d], "dia_n": d, "franja": f"{b * 3}-{b * 3 + 3}h", "franja_n": b,
                     "sesiones": sum(row[b * 3:b * 3 + 3])})
write("mapa", mapa)

eg = src.get("efecto_gym")
write("efecto_gym", [] if not eg else [
    {"grupo": "Tras gym (24 h)", "metros_latido": eg["tras_gym"], "carreras": eg["n_tras"]},
    {"grupo": "Resto", "metros_latido": eg["resto"], "carreras": eg["n_resto"]},
])
