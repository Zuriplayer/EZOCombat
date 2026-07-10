# ESO combat and automation limits

Investigacion inicial para EZOCombat. Estado: conceptual, pendiente de pruebas en cliente real.

Fuentes tecnicas:

- UESP ESO Data current: https://esodata.uesp.net/current/index.html
- `RegisterForEvent`: https://esoapi.uesp.net/current/data/r/e/g/RegisterForEvent.html
- Keybindings manager v101047: https://esodata.uesp.net/101047/src/ingame/keybindings/keybindings_manager.lua.html
- Combat overlay usando `EVENT_PLAYER_COMBAT_STATE` e `IsUnitInCombat("player")`: https://esodata.uesp.net/100020/src/ingame/uicombatoverlay/uicombatoverlay.lua.html

## Lo que parece viable

### 1. Teclas adicionales como acciones de addon

Viable si se hace mediante el sistema normal de keybindings de ESO:

- Definir acciones propias con `Bindings.xml`.
- Dejar que el jugador las asigne en el menu de controles.
- Si se recomiendan defaults, registrarlos en el propio addon despues de `EVENT_KEYBINDINGS_LOADED`.
- No depender de servicios externos de la familia para aplicar ni restablecer bindings.

Esto no equivale a cambiar binds del jugador automaticamente. La regla de familia debe seguir siendo: registrar, diagnosticar y pedir confirmacion; no imponer.

### 2. Deteccion de entrada y salida de combate

Viable como disparador informativo:

- `EVENT_PLAYER_COMBAT_STATE`.
- `IsUnitInCombat("player")` para refrescos o comprobaciones.
- Acciones permitidas: mostrar/ocultar UI, cambiar estado interno, avisos, sonidos, timers, diagnostico.

Riesgo: usar entrada/salida de combate como disparador para ejecutar acciones de combate cruza una linea muy distinta. Debe quedar prohibido hasta validacion explicita.

### 3. Deteccion de habilidades, bosses o mecanicas concretas

Viable para alertas, siguiendo el patron de `EZOTakingAim`:

- `EVENT_COMBAT_EVENT`.
- Filtros por `REGISTER_FILTER_ABILITY_ID`.
- Comprobar resultado, objetivo y contexto.
- Mostrar overlay o aviso sonoro.

Esto encaja bien con EZOCombat si se limita a asistencia visual/sonora y no acciona habilidades.

### 4. Perfiles o recomendaciones de binds

Viable como documentacion o diagnostico:

- listar acciones deseadas
- documentar conflictos conocidos con acciones nativas
- sugerir binds preferidos
- no aplicar cambios automaticamente

## Lo que debe considerarse prohibido o de alto riesgo

### 1. Macros de combate

No implementar:

- rotaciones automaticas
- lanzar habilidades en cadena
- cambiar arma y lanzar habilidad en una sola decision automatica
- responder a una condicion de combate ejecutando habilidad
- automatizar synergies, bash, dodge, interrupt, block o ultimate

Aunque alguna llamada parezca accesible, el objetivo del addon no debe ser reemplazar input humano en combate.

### 2. Simular input

No implementar:

- pulsar teclas desde Lua
- reenviar una tecla a otra accion
- leer input global fuera de keybinds declarados
- macros de mando/teclado desde fuera del cliente

ESO Lua no es un runtime de automatizacion del sistema operativo. La familia EZO debe mantenerse dentro de la API publica del juego.

### 3. Acciones protegidas en combate

La API de ESO distingue funciones publicas, protegidas o privadas. Las protegidas pueden fallar si se llaman desde addon, especialmente en combate. Cualquier prototipo que toque barras, slots, inventario, quickslots, equipo o arma debe tratarse como inseguro hasta probarlo.

Senal de alarma: `EVENT_SCRIPT_ACCESS_VIOLATION`.

### 4. Cambio automatico de arma

Analizar con maxima cautela:

- Un keybind propio que el jugador pulse podria abrir UI o registrar una intencion.
- Un disparador automatico que cambie arma al entrar en combate, salir de combate o detectar boss debe tratarse como no aceptable.
- El cambio de arma es una accion de combate; automatizarlo puede ser bloqueo tecnico, ventaja injusta o ambas cosas.

## Matriz de diseno por feature

| Feature | Estado | Encaje recomendado |
| --- | --- | --- |
| Accion keybind "EZOCombat panel" | Viable | `Bindings.xml`, jugador asigna |
| Chords tipo Ctrl+Alt+tecla | Viable si cliente lo acepta | compatible con `EZOKeybinds`, sin depender de el |
| Aviso al entrar/salir de combate | Viable | evento + UI/sonido |
| Overlay de mecanica de boss | Viable | patron `EZOTakingAim` |
| Diagnostico de conflictos de binds | Viable | documentacion local y pruebas en cliente |
| Macro de una tecla para varias habilidades | No | fuera de alcance |
| Cambio de arma automatico por condicion | No | fuera de alcance |
| Cambio de arma por tecla propia | Pendiente | requiere investigar API y restricciones |
| Auto-castear habilidad por evento | No | fuera de alcance |
| Auto-synergy / auto-interrupt / auto-dodge | No | fuera de alcance |

## Preguntas pendientes

- Que acciones exactas de arma/hotbar estan expuestas como keybinds nativos y cuales son protegidas.
- Si un addon puede definir una accion propia que solo abra un menu contextual de combate sin interferir en controles.
- Que fuente verificada usar para inventariar acciones nativas relacionadas con weapon swap.
- Que convenciones de gamepad deben heredarse de `EZOTools` para no romper `rapido-gamepad`.

## Politica provisional

EZOCombat puede ayudar al jugador a ver, decidir y ejecutar manualmente. No debe decidir ni ejecutar combate por el jugador.
