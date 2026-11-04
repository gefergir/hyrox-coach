#!/usr/bin/env python3
"""Valida docs/retos.json para Mi Temporada. Sale con código 1 si la app no podría usarlo."""
import json
import sys
from datetime import date
from pathlib import Path

TIPOS = {"carrera", "hyrox"}
MAX_BYTES = 8 * 1024


def validar(datos):
    errores = []
    retos = datos.get("retos")
    if not isinstance(retos, list) or not retos:
        return ["retos debe ser una lista con contenido"]
    for i, r in enumerate(retos, 1):
        nombre = r.get("nombre")
        prefijo = f"reto {i} ({nombre})"
        if not isinstance(nombre, str) or not nombre.strip():
            errores.append(f"reto {i}: falta el nombre")
        try:
            date.fromisoformat(r.get("fecha", ""))
        except (TypeError, ValueError):
            errores.append(f"{prefijo}: fecha debe tener formato AAAA-MM-DD")
        if r.get("tipo") not in TIPOS:
            errores.append(f"{prefijo}: tipo debe ser carrera o hyrox")
        km = r.get("distancia_km")
        if isinstance(km, bool) or not isinstance(km, (int, float)) or km <= 0:
            errores.append(f"{prefijo}: distancia_km debe ser un número positivo")
    return errores


def main():
    ruta = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/retos.json")
    datos = json.loads(ruta.read_text(encoding="utf-8"))
    errores = validar(datos)
    tamano = len(json.dumps(datos, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    if tamano > MAX_BYTES:
        errores.append(f"los retos ocupan {tamano} bytes (máximo {MAX_BYTES})")
    if errores:
        print("RETOS NO VÁLIDOS")
        for e in errores:
            print(f"- {e}")
        return 1
    hoy = date.today()
    print(f"Retos válidos: {len(datos['retos'])}, {tamano} bytes")
    for r in sorted(datos["retos"], key=lambda r: r["fecha"]):
        dias = (date.fromisoformat(r["fecha"]) - hoy).days
        print(f"- {r['fecha']} ({dias} días): {r['nombre']} | {r['tipo']} | {r['distancia_km']} km")
    return 0


if __name__ == "__main__":
    sys.exit(main())
