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
| UP / DOWN | Antes de empezar, elegir el bloque inicial. Se sigue en orden ascendente y se vuelve al principio (3, 4, 5, 1, 2) |
| START | Empezar, pausar o salir al terminar |
| BACK | Terminar el ejercicio en curso (intervalos y cuenta atrás), cambiar de rol, contar una ronda en un AMRAP o saltar el descanso |
| Pantalla táctil | Sin función, para evitar pulsaciones accidentales |

Si un ejercicio es de carrera ("Run"), la pantalla muestra el ritmo actual y la sesión usa el GPS.

La pausa también permite saltar el bloque, guardar o descartar.

Cada entreno se guarda en Garmin Connect con una vuelta por ejercicio (un AMRAP es una sola vuelta por bloque) y otra por cada descanso. El nombre de cada paso se graba en el campo `paso` del archivo FIT, aunque Garmin Connect podría no mostrarlo.

# Mi Temporada

Segunda app, independiente, en `watch-temporada/`. Tiene cinco apartados:

- **Mascota**: un osito que gana músculo con tus entrenos (gym: brazos y torso; carrera: piernas; Hyrox: todo). Lee el historial del reloj al abrir la app. Cuenta 1 punto por minuto y 5 por km corrido; las actividades de menos de 10 minutos no cuentan. Se pone triste tras 5 días sin entrenar.
- **Semana**: tu agenda (`docs/agenda.json`) con «Hoy» y lo ya hecho.
- **Retos**: tus carreras y Hyrox (`docs/retos.json`), con los días que faltan y un semáforo estimado.
- **Sugerencias**: HYROX, Hybrid Day y carreras cerca de Valencia (`docs/sugerencias.json`).
- **Info**: cómo gana puntos la mascota.

Compila con:

```powershell
.\build-temporada.ps1 -BaseUrl "https://TU_USUARIO.github.io/hyrox-coach/"
```

y copia `watch-temporada\bin\MiTemporada.prg` en `GARMIN\APPS`.

Para cambiar la agenda, dicta tu semana a Claude en este repositorio: solo se modifica `docs/agenda.json`.
