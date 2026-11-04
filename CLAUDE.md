# Hyrox Coach y Mi Temporada

Este repositorio tiene dos apps de Connect IQ independientes para Garmin Forerunner 165 Music:

- `watch/`: **Hyrox Coach**, cronometra los entrenos del plan semanal de Hyrox (`docs/plan.json`). Se compila con `build.ps1`.
- `watch-temporada/`: **Mi Temporada**, con mascota, agenda de la semana y retos (`docs/agenda.json` y `docs/retos.json`). Se compila con `build-temporada.ps1`.

No mezcles el código de las dos apps.

## Plan de Hyrox (imagen semanal)

Cuando el usuario adjunte la imagen de la semana:

1. Usa el agente `plan-semanal` para convertirla en `docs/plan.json`.
2. Si el validador falla, no publiques.
3. Si hay dudas que cambien el crono de una sesión, pregúntalas antes de publicar. Las demás, resúmelas después.
4. Haz commit solo de `docs/plan.json` en `main` con el mensaje `Plan semana N` y haz push. GitHub Pages lo publica y el reloj lo descarga al abrir la app.
5. Responde con los días y duraciones de la semana. No muestres el JSON.

La imagen del Hyrox cambia solo `docs/plan.json`. Nunca `docs/agenda.json`.

## Agenda de la semana (dictada)

Cuando el usuario dicte o cuente su semana de entrenos (gym, series, rodaje, tirada, hyrox):

1. Usa el agente `agenda-semanal` para escribir `docs/agenda.json`.
2. Si `tools/validar_agenda.py` falla, no publiques.
3. Haz commit solo de `docs/agenda.json` en `main` con el mensaje `Agenda semana N` y haz push.
4. Responde con los días y sesiones de la semana. No muestres el JSON.

La agenda cambia solo `docs/agenda.json`. Nunca `docs/plan.json`.

## Retos

Los retos están en `docs/retos.json`. Antes de añadir un Hyrox, comprueba la fecha en la web oficial de HYROX. Valida con `tools/validar_retos.py`, haz commit con el mensaje `Retos: ...` y push.

## Sugerencias

`docs/sugerencias.json` tiene ideas de HYROX y Hybrid Day en España y Europa, y carreras populares cerca de Valencia. Cuando el usuario pida actualizarlas:

1. Busca eventos futuros y comprueba cada fecha en la web oficial (hyrox.com/find-my-race, hybrid-day.com, el organizador o carreras.fdmvalencia.es). Pon esa URL en `fuente`. Si no puedes confirmar una fecha, no la añadas.
2. Quita los eventos pasados y los que ya están en `docs/retos.json`.
3. Valida con `tools/validar_sugerencias.py`, haz commit con el mensaje `Sugerencias: ...` y push.

No cambies el código de `watch/` ni de `watch-temporada/` en una actualización semanal.
