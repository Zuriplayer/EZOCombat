# Patrones de estado de habilidades

EZOCombat no interpreta la ausencia genérica de datos como inactividad. Cada
habilidad que necesita estado inicial o IDs alternativos debe pertenecer a una
estrategia explícita y verificable.

La visibilidad aplica además una protección independiente: si un tracker está
configurado para mostrarse cuando la habilidad está inactiva y el estado sigue
siendo `UNKNOWN`, el icono se muestra provisionalmente. El motor no falsea el
estado como inactivo; únicamente evita que la falta de evidencia oculte el
recordatorio.

## Identidad estable

Una habilidad puede exponer IDs distintos según el morfeo, el recurso, el
estado visual del slot o el efecto producido. `ABILITY_FAMILIES` relaciona
únicamente variantes comprobadas de una misma identidad funcional.

No se agrupan habilidades por nombre localizado, icono o parecido. Los morfeos
con comportamiento o duración distintos permanecen separados.

## Estrategias de proveedor

### Temporizador nativo del slot

Se usa cuando `GetActionSlotEffectTimeRemaining` representa el ciclo real de la
habilidad. Un valor positivo es actividad y, solo para habilidades registradas
en esta estrategia, un cero legible es evidencia inicial de inactividad.

Ejemplos: Arctic Blast, Blighted Blastbones, Cruxweaver Armor y Proximity
Detonation.

### Efecto del jugador

Se usa cuando el estado aparece como buff o efecto del jugador, posiblemente
con un ID distinto al ID equipado. La presencia del efecto es actividad y su
ausencia solo es negativa después de confirmar que la lista de efectos es
legible.

Ejemplo: Crystal Fragments relaciona la habilidad equipada con su efecto de
proc.

### Toggle nativo

Se usa para habilidades que permanecen encendidas hasta una desactivación
explícita. `IsSlotToggled` aporta tanto la señal positiva como la negativa.

Ejemplos: Banner Bearer y la ultimate persistente del oso Warden.

### Ciclo conocido desde el lanzamiento

Se reserva para efectos de suelo u objetivo que no dejan una señal genérica
fiable en el jugador. `EVENT_ACTION_SLOT_ABILITY_USED` inicia una ventana de
duración verificada. La inactividad anterior al primer lanzamiento debe
habilitarse de forma explícita por habilidad.

Ejemplos: Barbed Trap y Fulminating Rune.

## Protección genérica para el primer uso

Muchas habilidades con temporizador nativo no aportan una señal negativa
distinguible antes de lanzarlas por primera vez. Después del primer temporizador
positivo, EZOCombat aprende automáticamente esa capacidad y puede interpretar
su expiración como inactividad observada.

Mientras todavía no exista esa evidencia, los trackers con condición inactiva
usan `unknown-inactive-fallback`: son visibles, pero el estado continúa siendo
`UNKNOWN`. Esto cubre de forma genérica habilidades como Stampede sin registrar
su ID ni inventar una duración.

La protección no muestra trackers deshabilitados o no equipados, no convierte
`UNKNOWN` en actividad y no usa `GetAbilityDuration` como sustituto. Si ESO no
ofrece ninguna señal positiva al lanzar una habilidad, su icono puede seguir
visible durante el efecto y será necesario identificar un proveedor verificable.

## Procedimiento para casos similares

1. Confirmar el ID equipado y cualquier ID efectivo, de proc o de efecto.
2. Capturar `phase`, `source`, `provider`, temporizador, toggle y efectos con
   `/ezocombatdebug` antes de lanzar, durante el efecto y después de expirar.
   `eligibilityReason=unknown-inactive-fallback` identifica la protección de
   visibilidad, no una afirmación de inactividad.
3. Determinar dónde vive la evidencia: slot, jugador, objetivo, suelo, recurso
   de ultimate o toggle.
4. Registrar la estrategia más estrecha que explique señales positivas y
   negativas observadas.
5. Añadir una familia de IDs solo cuando las variantes estén verificadas.
6. Probar primera carga, primer lanzamiento, expiración, cambio de barra,
   cambio de build y `/reloadui` antes de considerar el caso aceptado en ESO.

Las validaciones Lua demuestran estructura y sintaxis, pero no sustituyen esta
prueba dentro del cliente.
