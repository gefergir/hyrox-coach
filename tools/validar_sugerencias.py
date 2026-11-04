#!/usr/bin/env python3
"""Valida docs/sugerencias.json para Mi Temporada. Sale con código 1 si la app no podría usarlo."""
import json
import sys
from datetime import date
from pathlib import Path

TIPOS = {"hyrox", "hybrid", "carrera"}
MAX_BYTES = 12 * 1024


def fecha(valor):
    try:
        return date.fromisoformat(valor)
    except (TypeError, ValueError):
        return None


def validar(datos):
    errores = []
    if fecha(datos.get("actualizado")) is None:
        errores.append("actualizado debe tener formato AAAA-MM-DD")
    lista = datos.get("sugerencias")
    if not isinstance(lista, list) or not lista:
        return errores + ["sugerencias debe ser una lista con contenido"]
    for i, s in enumerate(lista, 1):
        prefijo = f"sugerencia {i} ({s.get('nombre')})"
        for campo in ("nombre", "lugar", "fuente"):
            if not isinstance(s.get(campo), str) or not s[campo].strip():
                errores.append(f"{prefijo}: falta {campo}")
        if s.get("tipo") not in TIPOS:
            errores.append(f"{prefijo}: tipo debe ser hyrox, hybrid o carrera")
        inicio = fecha(s.get("fecha"))
        if inicio is None:
            errores.append(f"{prefijo}: fecha debe tener formato AAAA-MM-DD")
        if "fecha_fin" in s:
            fin = fecha(s["fecha_fin"])
            if fin is None or (inicio and fin < inicio):
                errores.append(f"{prefijo}: fecha_fin no válida")
        km = s.get("distancia_km")
        if km is not None and (isinstance(km, bool) or not isinstance(km, (int, float)) or km <= 0):
            errores.append(f"{prefijo}: distancia_km debe ser un número positivo u omitirse")
        if isinstance(s.get("fuente"), str) and not s["fuente"].startswith("https://"):
            errores.append(f"{prefijo}: fuente debe ser una URL https")
    return errores


def main():
    ruta = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/sugerencias.json")
    datos = json.loads(ruta.read_text(encoding="utf-8"))
    errores = validar(datos)
    tamano = len(json.dumps(datos, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    if tamano > MAX_BYTES:
        errores.append(f"las sugerencias ocupan {tamano} bytes (máximo {MAX_BYTES})")
    if errores:
        print("SUGERENCIAS NO VÁLIDAS")
        for e in errores:
            print(f"- {e}")
        return 1
    hoy = date.today()
    futuras = [s for s in datos["sugerencias"] if date.fromisoformat(s.get("fecha_fin", s["fecha"])) >= hoy]
    print(f"Sugerencias válidas: {len(datos['sugerencias'])} ({len(futuras)} futuras), {tamano} bytes")
    for s in sorted(datos["sugerencias"], key=lambda s: s["fecha"]):
        print(f"- {s['fecha']} {s['tipo']:>7} | {s['nombre']} ({s['lugar']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
