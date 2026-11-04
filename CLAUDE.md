# Hyrox Coach

App de Connect IQ para Garmin Forerunner 165 Music que cronometra entrenos variados a partir de un plan semanal.

## Actualización semanal

Cuando el usuario adjunte la imagen de la semana:

1. Usa el agente `plan-semanal` para convertirla en `docs/plan.json`.
2. Si el validador falla, no publiques.
3. Si hay dudas que cambien el crono de una sesión, pregúntalas antes de publicar. Las demás, resúmelas después.
4. Haz commit de `docs/plan.json` en `main` con el mensaje `Plan semana N` y haz push. GitHub Pages lo publica y el reloj lo descarga al abrir la app.
5. Responde con los días y duraciones de la semana. No muestres el JSON.

No cambies el código de `watch/` en una actualización semanal.
