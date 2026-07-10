# EZOCombat concept

EZOCombat queda creado como cuaderno conceptual para futuras herramientas de combate de la familia EZO.

## Idea base

- Asignar teclas adicionales a flujos relacionados con arma, habilidades y ayudas de combate.
- Explorar macros de mando/teclado solo si son equivalentes a una accion manual permitida por ESO.
- Explorar automatismos seguros en circunstancias como:
  - entrar en combate
  - salir de combate
  - detectar boss o mecanica concreta
  - detectar habilidad enemiga concreta

## Norte del addon

EZOCombat no debe ser un rotador ni un bot. Su territorio natural es:

- alertas
- overlays
- diagnostico
- recomendaciones de binds
- menus rapidos manuales
- acciones manuales propias si estan justificadas

## Limite conceptual

El addon puede reaccionar con informacion. No debe reaccionar con ejecucion de combate.

Ejemplos aceptables:

- "Has entrado en combate" con cambio visual de UI.
- "Boss X esta casteando Y" con sonido y temporizador.
- "Este bind sugerido entra en conflicto con una accion nativa".
- "Pulsa tu keybind manual para abrir un selector EZOCombat".

Ejemplos no aceptables:

- "Al entrar en combate cambia a barra 1".
- "Al salir de combate cambia arma".
- "Si boss X lanza Y, usa habilidad Z".
- "Una tecla lanza varias habilidades secuenciadas".

## Primeras lineas de trabajo posibles

1. `EZOCombatBindings`
   - Definicion de acciones propias solo cuando haya una necesidad real.
   - Sin asignacion automatica.

2. `EZOCombatAlerts`
   - Eventos de combate y filtros por habilidad.
   - Similar a `EZOTakingAim`, pero modular.

3. `EZOCombatState`
   - Entrada/salida de combate.
   - Estado interno para UI, nunca para lanzar acciones.

4. `EZOCombatProfiles`
   - Presets de recomendaciones de binds.
   - Exportables como texto/documentacion.

## No implementar todavia

- `Bindings.xml` hasta decidir las acciones reales.
- SavedVariables hasta necesitar persistencia.
- LibAddonMenu hasta existir opciones reales.
- Hooks de input.
- Cambios de arma.
- Macros de habilidades.
