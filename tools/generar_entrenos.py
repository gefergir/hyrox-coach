#!/usr/bin/env python3
"""Genera los entrenos FIT de Mi Temporada a partir de tools/entrenos.json.

Escribe docs/entrenos/<id>.fit y docs/entrenos/index.json. La app los descarga
desde GitHub Pages y, al abrirlos, el reloj arranca la actividad nativa:
fuerza -> Fuerza, correr y series -> Correr.

Uso: python3 tools/generar_entrenos.py
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "entrenos.json"
OUT = ROOT / "docs" / "entrenos"

# Valores del perfil FIT
SPORT_RUNNING, SPORT_TRAINING = 1, 10
SUB_GENERIC, SUB_STRENGTH = 0, 20
DUR_TIME, DUR_DISTANCE, DUR_OPEN, DUR_REPEAT = 0, 1, 5, 6
TARGET_OPEN = 2
ACTIVE, REST, WARMUP, COOLDOWN, RECOVERY = 0, 1, 2, 3, 4
NAME_LEN = 20

CRC_TABLE = [0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
             0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400]


def crc16(data, crc=0):
    for byte in data:
        tmp = CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ CRC_TABLE[byte & 0xF]
        tmp = CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ CRC_TABLE[(byte >> 4) & 0xF]
    return crc


def text(s, size=NAME_LEN):
    raw = s.encode("utf-8")[: size - 1]
    return raw + b"\x00" * (size - len(raw))


# (número de campo, tamaño, tipo base, formato struct)
FILE_ID = (0, [(0, 1, 0x00, "B"), (1, 2, 0x84, "H"), (2, 2, 0x84, "H"), (3, 4, 0x8C, "I"), (4, 4, 0x86, "I")])
WORKOUT = (26, [(8, NAME_LEN, 0x07, f"{NAME_LEN}s"), (4, 1, 0x00, "B"), (11, 1, 0x00, "B"), (6, 2, 0x84, "H")])
STEP = (27, [(254, 2, 0x84, "H"), (0, NAME_LEN, 0x07, f"{NAME_LEN}s"), (1, 1, 0x00, "B"), (2, 4, 0x86, "I"),
             (3, 1, 0x00, "B"), (4, 4, 0x86, "I"), (7, 1, 0x00, "B")])


def definition(local, msg):
    gnum, fields = msg
    out = bytes([0x40 | local, 0, 0]) + struct.pack("<HB", gnum, len(fields))
    for num, size, base, _ in fields:
        out += bytes([num, size, base])
    return out


def record(local, msg, values):
    _, fields = msg
    fmt = "<" + "".join(f[3] for f in fields)
    return bytes([local]) + struct.pack(fmt, *values)


def build(e, serial):
    tipo = e["tipo"]
    if tipo == "fuerza":
        sport, sub = SPORT_TRAINING, SUB_STRENGTH
        steps = [("Fuerza", DUR_OPEN, 0, ACTIVE)]
    elif tipo == "correr":
        sport, sub = SPORT_RUNNING, SUB_GENERIC
        steps = [("Correr", DUR_OPEN, 0, ACTIVE)]
    else:
        sport, sub = SPORT_RUNNING, SUB_GENERIC
        if "metros" in e:
            work = (f"{e['metros']} m", DUR_DISTANCE, e["metros"] * 100, ACTIVE)
        else:
            work = (f"{e['segundos']} s fuerte", DUR_TIME, e["segundos"] * 1000, ACTIVE)
        steps = [
            ("Calentamiento", DUR_OPEN, 0, WARMUP),
            work,
            ("Recuperar", DUR_TIME, e["recuperacion_s"] * 1000, RECOVERY),
            # Repetir desde el paso 1 (trabajo) hasta completar las repeticiones
            ("Repetir", DUR_REPEAT, 1, ACTIVE, e["reps"]),
            ("Vuelta a la calma", DUR_OPEN, 0, COOLDOWN),
        ]

    data = definition(0, FILE_ID) + record(0, FILE_ID, [5, 255, 0, serial, 0])
    data += definition(1, WORKOUT) + record(1, WORKOUT, [text(e["nombre"]), sport, sub, len(steps)])
    data += definition(2, STEP)
    for i, st in enumerate(steps):
        name, dtype, dvalue, intensity = st[:4]
        target_value = st[4] if len(st) > 4 else 0
        data += record(2, STEP, [i, text(name), dtype, dvalue, TARGET_OPEN, target_value, intensity])

    header = struct.pack("<BBHI4s", 14, 0x20, 2132, len(data), b".FIT")
    header += struct.pack("<H", crc16(header))
    body = header + data
    return body + struct.pack("<H", crc16(body))


def main():
    cfg = json.loads(SRC.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    index = []
    for n, e in enumerate(cfg["entrenos"], 1):
        if len(e["nombre"].encode("utf-8")) >= NAME_LEN:
            raise SystemExit(f"Nombre demasiado largo: {e['nombre']}")
        (OUT / f"{e['id']}.fit").write_bytes(build(e, 7000 + n))
        index.append({"nombre": e["nombre"], "tipo": e["tipo"], "archivo": f"entrenos/{e['id']}.fit"})
    (OUT / "index.json").write_text(json.dumps({"entrenos": index}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(index)} entrenos en {OUT}")


if __name__ == "__main__":
    main()
