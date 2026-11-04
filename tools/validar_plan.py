#!/usr/bin/env python3
"""Valida docs/plan.json. Sale con código 1 si la app no podría usar el plan."""
import json
import sys
from datetime import date
from pathlib import Path

DIAS = ["lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo"]
TIPOS = {"intervalo", "cuenta_atras", "amrap"}
MAX_BYTES = 32 * 1024  # Límite por valor de Application.Storage


def es_entero_positivo(valor):
    return isinstance(valor, int) and not isinstance(valor, bool) and valor > 0


def validar_bloque(prefijo, bloque, errores):
    if not bloque.get("nombre"):
        errores.append(f"{prefijo}: falta el nombre")

    descanso = bloque.get("descanso_s")
    if descanso is not None and (not isinstance(descanso, int) or descanso < 0):
        errores.append(f"{prefijo}: descanso_s debe ser null o un entero >= 0")

    timer = bloque.get("timer") or {}
    tipo = timer.get("tipo")
    if tipo not in TIPOS:
        errores.append(f"{prefijo}: tipo de timer no válido: {tipo}")
    elif tipo == "intervalo":
        if not es_entero_positivo(timer.get("cada_s")) or not es_entero_positivo(timer.get("rondas")):
            errores.append(f"{prefijo}: un intervalo necesita cada_s y rondas")
    elif not es_entero_positivo(timer.get("duracion_s")):
        errores.append(f"{prefijo}: {tipo} necesita duracion_s")

    ejercicios = bloque.get("ejercicios")
    roles = bloque.get("roles")
    if bool(ejercicios) == bool(roles):
        errores.append(f"{prefijo}: debe tener ejercicios o roles, no ambos ni ninguno")
    if roles and not (roles.get("A") and roles.get("B")):
        errores.append(f"{prefijo}: roles necesita A y B")


def duracion_segundos(sesion):
    total = 0
    bloques = sesion["bloques"]
    for i, bloque in enumerate(bloques):
        timer = bloque["timer"]
        total += timer["cada_s"] * timer["rondas"] if timer["tipo"] == "intervalo" else timer["duracion_s"]
        if i < len(bloques) - 1:
            total += bloque.get("descanso_s") or 0
    return total


def validar(plan):
    errores = []
    if not es_entero_positivo(plan.get("semana")):
        errores.append("semana debe ser un entero")

    for campo in ("desde", "hasta"):
        try:
            date.fromisoformat(plan.get(campo, ""))
        except ValueError:
            errores.append(f"{campo} debe tener formato AAAA-MM-DD")

    sesiones = plan.get("sesiones")
    if not isinstance(sesiones, list) or not sesiones:
        return errores + ["sesiones debe ser una lista con contenido"]

    vistos = set()
    for sesion in sesiones:
        dia = sesion.get("dia")
        if dia not in DIAS:
            errores.append(f"día no válido (sin acentos): {dia}")
        if dia in vistos:
            errores.append(f"día repetido: {dia}")
        vistos.add(dia)

        if not sesion.get("nombre"):
            errores.append(f"{dia}: falta el nombre")
        try:
            fecha = date.fromisoformat(sesion.get("fecha", ""))
            if dia in DIAS and DIAS[fecha.weekday()] != dia:
                errores.append(f"{dia}: la fecha {fecha} cae en {DIAS[fecha.weekday()]}")
        except ValueError:
            errores.append(f"{dia}: fecha no válida")

        bloques = sesion.get("bloques")
        if not isinstance(bloques, list) or not bloques:
            errores.append(f"{dia}: sin bloques")
            continue
        for i, bloque in enumerate(bloques):
            validar_bloque(f"{dia}/bloque {i + 1}", bloque, errores)
    return errores


def main():
    ruta = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plan.json")
    plan = json.loads(ruta.read_text(encoding="utf-8"))

    errores = validar(plan)
    tamano = len(json.dumps(plan, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    if tamano > MAX_BYTES:
        errores.append(f"el plan ocupa {tamano} bytes (máximo {MAX_BYTES})")

    if errores:
        print("PLAN NO VÁLIDO")
        for error in errores:
            print(f"- {error}")
        return 1

    print(f"Plan válido: semana {plan['semana']}, {tamano} bytes")
    for sesion in plan["sesiones"]:
        segundos = duracion_segundos(sesion)
        print(f"- {sesion['dia']}: {sesion['nombre']} | {len(sesion['bloques'])} bloques | {segundos // 60}:{segundos % 60:02d}")
    for duda in plan.get("dudas", []):
        print(f"DUDA: {duda}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
