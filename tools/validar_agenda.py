#!/usr/bin/env python3
"""Valida docs/agenda.json para Mi Temporada. Sale con código 1 si la app no podría usarla."""
import json
import sys
from datetime import date
from pathlib import Path

DIAS = ["lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo"]
TIPOS = {"gym", "series", "rodaje", "tirada", "hyrox"}
MAX_BYTES = 16 * 1024


def validar(agenda):
    errores = []
    semana = agenda.get("semana")
    if not isinstance(semana, int) or isinstance(semana, bool) or semana <= 0:
        errores.append("semana debe ser un entero positivo")

    limites = {}
    for campo in ("desde", "hasta"):
        try:
            limites[campo] = date.fromisoformat(agenda.get(campo, ""))
        except (TypeError, ValueError):
            errores.append(f"{campo} debe tener formato AAAA-MM-DD")

    dias = agenda.get("dias")
    if not isinstance(dias, list) or not dias:
        return errores + ["dias debe ser una lista con contenido"]

    vistas = set()
    for d in dias:
        try:
            fecha = date.fromisoformat(d.get("fecha", ""))
        except (TypeError, ValueError):
            errores.append(f"fecha no válida: {d.get('fecha')}")
            continue
        etiqueta = d.get("dia")
        if etiqueta not in DIAS:
            errores.append(f"{fecha}: día no válido (minúsculas y sin acentos): {etiqueta}")
        elif DIAS[fecha.weekday()] != etiqueta:
            errores.append(f"{fecha}: cae en {DIAS[fecha.weekday()]}, no en {etiqueta}")
        if fecha in vistas:
            errores.append(f"{fecha}: fecha repetida; usa varias sesiones en el mismo día")
        vistas.add(fecha)
        if len(limites) == 2 and not (limites["desde"] <= fecha <= limites["hasta"]):
            errores.append(f"{fecha}: fuera del rango desde/hasta")

        sesiones = d.get("sesiones")
        if not isinstance(sesiones, list) or not sesiones:
            errores.append(f"{fecha}: sesiones debe ser una lista con contenido")
            continue
        for i, s in enumerate(sesiones, 1):
            if s.get("tipo") not in TIPOS:
                errores.append(f"{fecha}/sesión {i}: tipo debe ser uno de {sorted(TIPOS)}")
            if not isinstance(s.get("detalle"), str) or not s["detalle"].strip():
                errores.append(f"{fecha}/sesión {i}: falta el detalle")
    return errores


def main():
    ruta = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/agenda.json")
    agenda = json.loads(ruta.read_text(encoding="utf-8"))
    errores = validar(agenda)
    tamano = len(json.dumps(agenda, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    if tamano > MAX_BYTES:
        errores.append(f"la agenda ocupa {tamano} bytes (máximo {MAX_BYTES})")
    if errores:
        print("AGENDA NO VÁLIDA")
        for e in errores:
            print(f"- {e}")
        return 1
    print(f"Agenda válida: semana {agenda['semana']}, {tamano} bytes")
    for d in sorted(agenda["dias"], key=lambda d: d["fecha"]):
        print(f"- {d['dia']} {d['fecha']}: " + " + ".join(f"{s['tipo']} ({s['detalle']})" for s in d["sesiones"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
