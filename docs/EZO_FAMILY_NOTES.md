# EZO family notes

## Patrones recogidos

- Namespace global por addon: `EZOTools`, `EZOKeybinds`, `EZOTakingAim`, `EZOCombat`.
- Carga por `EVENT_ADD_ON_LOADED` y desregistro inmediato del evento.
- Manifest `.txt` como fuente de orden de carga.
- `APIVersion` actual de la familia alrededor de `101049 101050`; algunos addons de prueba mantienen una ventana mas amplia.
- `EZOBindings` queda pausado como experimento historico; no usarlo en integraciones nuevas.
- `EZOKeybinds` queda como addon independiente para chording nativo; otros addons no deben depender de el para defaults ni diagnostico.
- Los addons no deben crear dependencias duras entre si salvo necesidad clara; usar `OptionalDependsOn` y comprobar existencia en runtime.
- En input, separar estrictamente modos: `overlay-raton`, `rapido-gamepad`, `rapido-teclado`, `cursor-ui-explicito`.

## Implicacion para EZOCombat

EZOCombat no debe empezar como sistema de macros. Debe empezar como:

- inventario de posibilidades reales de ESO
- acciones manuales propias solo si hay una necesidad real
- prototipos de alertas y ayudas visuales
- documentacion de limites antes de tocar input

## Decisiones iniciales

- Sin SavedVariables de momento.
- Sin LibAddonMenu de momento.
- Sin `Bindings.xml` de momento.
- Sin asignar teclas, limpiar teclas ni sobrescribir binds.
- Slash command minimo: `/ezocombat`.
- Sin registro en servicios externos de bindings.
