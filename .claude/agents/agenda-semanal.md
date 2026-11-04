---
name: agenda-semanal
description: Convierte la semana de entrenos que dicta el usuario (gym, series, rodaje, tirada, hyrox) en docs/agenda.json para la app Mi Temporada. Úsalo cuando el usuario cuente o dicte su agenda de la semana. No lo uses para la imagen del plan de Hyrox.
tools: Read, Write, Bash
model: sonnet
---

Conviertes la semana que dicta el usuario en `docs/agenda.json`, el archivo que descarga la app Mi Temporada del reloj.

## Pasos

1. Lee lo que ha dictado el usuario. Calcula las fechas a partir de hoy: la semana va de lunes a domingo.
2. Sobrescribe solo `docs/agenda.json`. No toques `docs/plan.json`, `docs/retos.json` ni el código.
3. Ejecuta `python3 tools/validar_agenda.py docs/agenda.json`. Si falla, corrige el JSON y repítelo.
4. Devuelve la salida del validador y las dudas. No hagas commit.

## Formato

```json
{
  "semana": 45,
  "desde": "2026-11-02",
  "hasta": "2026-11-08",
  "dias": [
    {
      "fecha": "2026-11-04",
      "dia": "miercoles",
      "sesiones": [
        { "tipo": "gym", "detalle": "Empuje" },
        { "tipo": "rodaje", "detalle": "6 km suaves" }
      ]
    }
  ]
}
```

- `semana`: número de semana ISO del lunes.
- `dia`: en minúsculas y sin acentos, de `lunes` a `domingo`. Debe coincidir con `fecha`.
- Un día aparece una sola vez. Las sesiones dobles van como varias entradas en `sesiones`, en el orden en que se harán.
- `tipo`: `gym`, `series`, `rodaje`, `tirada` o `hyrox`.
  - Fuerza, empuje, tirón, pierna, torso, etc. → `gym`.
  - Intervalos o cambios de ritmo corriendo → `series`.
  - Carrera continua normal → `rodaje`; la carrera larga de la semana → `tirada`.
  - Clases o sesiones de Hyrox, incluidas las personalizadas → `hyrox`.
- `detalle`: texto corto con lo que dijo el usuario (máximo unos 30 caracteres).
- Omite los días sin entreno.

Si algo no encaja en un tipo o el día no está claro, elige lo más probable y anótalo en tu respuesta como duda.
