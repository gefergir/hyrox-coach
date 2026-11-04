# Hyrox Coach

Cronometra en tu Forerunner 165 Music los entrenos de la imagen semanal y los guarda como actividades de Garmin.

## Puesta en marcha (una sola vez)

1. Sube esta carpeta a un repositorio público de GitHub llamado `hyrox-coach`. El plan de entrenos será visible para cualquiera.
2. En GitHub, ve a **Settings > Pages** y publica la rama `main`, carpeta `/docs`. Tu plan quedará en `https://TU_USUARIO.github.io/hyrox-coach/plan.json`.
3. Instala el [SDK de Connect IQ](https://developer.garmin.com/connect-iq/sdk/) y, desde el SDK Manager, descarga el dispositivo Forerunner 165 Music.
4. Genera una clave de desarrollador. Con la extensión Monkey C de VS Code, usa **Monkey C: Generate a Developer Key**.
5. Compila:

   ```powershell
   .\build.ps1 -PlanUrl "https://TU_USUARIO.github.io/hyrox-coach/plan.json" -DevKey "C:\ruta\developer_key"
   ```

6. Conecta el reloj por USB y copia `watch\bin\HyroxCoach.prg` en `GARMIN\APPS`, sin subcarpetas. Si no aparece, reinicia el reloj.

Para probarla antes en el simulador, abre el proyecto `watch` con la extensión de VS Code y usa **Run > Start Debugging**.

## Cada semana

1. Abre Claude Code en el móvil, en este repositorio.
2. Adjunta la imagen y escribe: `Plan de esta semana`.
3. Abre la app en el reloj, con el móvil cerca y conectado. El plan anterior se sobrescribe. Si no se actualiza, elige **Actualizar plan**. GitHub Pages puede tardar unos minutos en publicar el cambio.

## Botones durante el entreno

| Botón | Acción |
|---|---|
| START | Empezar, pausar o salir al terminar |
| BACK | Marcar una ronda, cambiar de rol, marcar el final del trabajo o saltar el descanso |
| Pantalla táctil | Sin función, para evitar pulsaciones accidentales |

La pausa también permite saltar el bloque, guardar o descartar.

Cada entreno se guarda en Garmin Connect con una vuelta por paso. El nombre de cada paso se graba en el campo `paso` del archivo FIT, aunque Garmin Connect podría no mostrarlo.
