#!/usr/bin/env python3
"""Valida docs/curiosidades.json para Mi Temporada. Sale con código 1 si la app no podría usarlo."""
import json
import sys
from datetime import date
from pathlib import Path

MAX_BYTES = 28 * 1024
MAX_TITULO = 26
MAX_TEXTO = 180


def validar(datos):
    errores = []
    lista = datos.get("curiosidades")
    if not isinstance(lista, list) or not lista:
        return ["curiosidades debe ser una lista con contenido"]
    vistas = set()
    for i, c in enumerate(lista, 1):
        try:
            f = date.fromisoformat(c.get("fecha", ""))
        except (TypeError, ValueError):
            errores.append(f"curiosidad {i}: fecha no válida")
            continue
        if f in vistas:
            errores.append(f"{f}: fecha repetida")
        vistas.add(f)
        for campo, maximo in (("tema", 14), ("titulo", MAX_TITULO), ("texto", MAX_TEXTO)):
            v = c.get(campo)
            if not isinstance(v, str) or not v.strip():
                errores.append(f"{f}: falta {campo}")
            elif len(v) > maximo:
                errores.append(f"{f}: {campo} demasiado largo ({len(v)} > {maximo})")
    return errores


def main():
    ruta = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/curiosidades.json")
    datos = json.loads(ruta.read_text(encoding="utf-8"))
    errores = validar(datos)
    tamano = len(json.dumps(datos, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    if tamano > MAX_BYTES:
        errores.append(f"ocupa {tamano} bytes (máximo {MAX_BYTES})")
    if errores:
        print("CURIOSIDADES NO VÁLIDAS")
        for e in errores:
            print(f"- {e}")
        return 1
    fechas = sorted(c["fecha"] for c in datos["curiosidades"])
    print(f"Curiosidades válidas: {len(fechas)} ({fechas[0]} a {fechas[-1]}), {tamano} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
