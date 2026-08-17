# EZOCombat

Prefer English? Read the [README in English](README.md).

EZOCombat es un asistente visual y manual para las barras de habilidades de **The Elder Scrolls Online**. Nunca lanza habilidades, cambia barras de arma ni simula entradas del jugador.

Soporte, errores y sugerencias: https://discord.gg/ekw8zUAcRm

## Estado Beta

Versión: `0.2.21-beta`

Esta beta funcional aporta la interfaz persistente, la base de prioridades y un motor de estado por evidencias. Los mapas específicos de efectos, umbrales de tiempo restante y catálogos por clase todavía requieren validación independiente en el cliente.

## Requisitos

- Cliente de The Elder Scrolls Online para PC.
- `LibAddonMenu-2.0`.
- Versiones de API de ESO declaradas en el manifiesto: `101049 101050`.
- Addons opcionales para desarrollo y diagnóstico:
  - `LibDebugLogger`
  - `DebugLogViewer`
- Integración opcional con la familia EZO:
  - `EZOCore` para heredar la preferencia de idioma compartida, si está instalado.

## Instalación

1. Descarga o clona este repositorio.
2. Copia la carpeta `EZOCombat` en tu directorio de AddOns de ESO:
   - Live: `Documents/Elder Scrolls Online/live/AddOns/EZOCombat`
   - PTS: `Documents/Elder Scrolls Online/pts/AddOns/EZOCombat`
3. Inicia ESO o ejecuta `/reloadui`.
4. Activa `EZOCombat` desde el menú de complementos si hace falta.

## Funciones Actuales

- Ventana movible con formato EZOArmory que muestra las barras frontal y trasera, incluidas ambas ultimates.
- Selector de sesión `Ver todos los configurados` en la ventana de barras. Muestra temporalmente todos los trackers habilitados que sigan equipados en las barras del perfil actual para poder colocarlos, y recupera la visibilidad normal al desactivarlo o cerrar la ventana.
- Acceso a la ventana desde el panel LAM de EZOCombat, `/ezocombat` o un atajo opcional en los Controles de ESO.
- Detección automática de clase y del rol seleccionado en el Buscador de grupo.
- Selección manual de rol en LAM al desactivar la detección automática. El rol de respaldo es Daño.
- Perfiles persistentes de habilidades seguidas por personaje, clase y rol.
- Iconos HUD creados desde una habilidad de la ventana. Se pueden mover y desactivar con su botón `X` o desde LAM.
- Cada icono HUD visible muestra debajo el binding nativo de teclado o mando de su slot mientras la habilidad esté en la barra de arma activa. El binding se oculta cuando la habilidad solo está en la otra barra.
- Los IDs efectivos específicos de cada barra se resuelven para su propia barra, evitando que variantes dependientes del arma como Bloqueo elemental cambien de identidad seguida al cambiar de arma.
- Condiciones de aparición: mientras esté equipada; mientras esté activa y equipada; y mientras esté inactiva y equipada. Las ultimates normales usan el estado lista para lanzar como estado activo.
- Evidencias de estado por capas mediante temporizadores nativos del slot, toggles nativos, efectos del jugador con el mismo ID, recurso de ultimate y proveedores explícitos por habilidad. La ausencia de datos de API permanece como `UNKNOWN` y no cuenta como inactiva.
- Las familias verificadas de IDs variables de estado se comparan mediante una identidad estable, para que los IDs nativos encadenados o atenuados no rompan el seguimiento slotado, activo o inactivo. Las nuevas familias solo se añaden tras confirmar sus IDs en ESO.
- Blighted Blastbones tiene un proveedor explícito de temporizador nativo del slot, por lo que un temporizador cero legible puede establecer su estado inicial inactivo antes del primer lanzamiento; esta inicialización solo se aplica a habilidades con una señal negativa nativa verificada.
- El estado toggle nativo positivo se acepta y aprende aunque ESO omita el metadato de toggle. Banner Bearer (`217699`) y la ultimate configurada del oso Warden (`92163`) también tienen proveedores toggle explícitos.
- Aprendizaje persistente de capacidades: después de observar un temporizador real de slot o un efecto del jugador con el mismo ID, EZOCombat puede usar la ausencia posterior de ese proveedor como evidencia fiable de inactividad.
- Actividad temporizada verificada para Asalto subterráneo y Fisura profunda del Warden, con sus ventanas activas de 6 y 9 segundos.
- Categorías `Siempre visible` y `P1` a `P5`. Siempre visible evita el filtrado por prioridad, pero sigue respetando la condición equipada, activa o inactiva de la habilidad.
- Gestión global de prioridades en LAM: mostrar todos los niveles elegibles, solo el nivel elegible más alto o los dos niveles elegibles más altos. El modo de dos niveles omite niveles vacíos; por ejemplo, muestra P1 y P3 cuando P2 no contiene habilidades elegibles.
- Localización runtime en inglés y español.
- Diagnóstico opcional desde LAM o `/ezocombatdebug`, usando LibDebugLogger y duplicado opcional al chat.

## Límites Actuales

La beta no deduce estados genéricos de habilidad a partir de datos ausentes. Todavía no incluye:

- porcentajes de cooldown o duración restante;
- mapeo automático cuando la habilidad equipada y el efecto aplicado al jugador usan IDs de habilidad diferentes;
- semántica específica verificada para todas las habilidades de cada clase; las habilidades con toggle usan los metadatos y el estado nativo del slot, pero todavía requieren cobertura dentro del cliente;
- automatización de rotación, lanzamiento, cambio de barra, bloqueo, esquiva, interrupción, sinergia o ultimate.

Las reglas futuras y los mapas alternativos de IDs de efecto se registrarán por `abilityId` solo cuando sus eventos y significado estén confirmados en ESO. Una habilidad sin proveedor verificado permanece como `UNKNOWN`, por lo que no se muestra ni con la condición activa ni con la condición inactiva.

## Uso

1. Abre la ventana de barras desde LAM, `/ezocombat` o el atajo opcional de Controles.
2. Haz clic derecho sobre una habilidad equipada de cualquiera de las dos barras para mantener abierta su configuración.
3. Activa su icono HUD y elige la condición de aparición y la categoría `Siempre visible` o `P1`-`P5` con los selectores de la ventana. LAM ofrece el mismo selector y el modo global de gestión de prioridades.
4. Arrastra un icono visible a la posición HUD deseada. Usa su botón `X` o la casilla LAM para desactivarlo.

## Límites De Seguridad

EZOCombat solo observa la configuración y presenta información. No:

- lanza habilidades;
- cambia barras de arma automáticamente;
- ejecuta rotaciones de combate;
- encadena varias habilidades desde una sola entrada;
- simula input de teclado o gamepad;
- automatiza sinergias, interrupciones, esquivas, bloqueos, ultimates o prebuffs.

El jugador sigue decidiendo y realizando manualmente todas las acciones de combate.

## Notas De Prueba

Comprueba en ESO:

- que `/reloadui` termina sin errores Lua;
- que la ventana se abre desde LAM, `/ezocombat` y un atajo asignado;
- que teclado, ratón, gamepad, chat/Enter, ESC y los menús normales conservan su comportamiento nativo;
- que ambas barras muestran cinco ranuras normales y una ultimate;
- que cambiar una habilidad slotada actualiza la ventana de barras inmediatamente y también después de cerrarla y abrirla de nuevo;
- que un icono seguido desaparece al quitar la habilidad de ambas barras;
- que Bloqueo elemental y otras habilidades sobrescritas por la barra conservan su identidad seguida y su icono elegible al cambiar a la otra barra;
- que Blighted Blastbones, Blastbones y Stalking Blastbones mantienen su seguimiento cuando ESO cambia el ID nativo del slot entre los estados normal y atenuado, incluida la condición inactiva;
- que Blighted Blastbones muestra su tracker inactivo desde la primera carga cuando el temporizador nativo del slot es legible, sin exigir un lanzamiento previo;
- que Deep Fissure permanece activa durante su ventana prevista verificada de nueve segundos y pasa a inactiva al terminar, sin que la sustituya un temporizador nativo parcial del slot;
- que Arctic Blast y otras habilidades con temporizador nativo están activas mientras su contador de slot sea positivo e inactivas al terminar; la capacidad observada debe conservarse tras `/reloadui`;
- que los iconos HUD y la ventana de configuración de EZOCombat se ocultan mientras están abiertas las ruedas radiales o de utilidad interactivas de ESO y regresan al cerrarlas;
- que las habilidades con toggle siguen `IsAbilityDurationToggled` junto con `IsSlotToggled`, mientras que activa y no activa de ultimates normales significan lista y no lista para lanzar;
- que Banner Bearer solo está activo mientras su toggle nativo de slot está encendido y pasa a inactivo al desactivar el banner;
- que las habilidades sin proveedor verificado permanecen como `UNKNOWN` en vez de aparecer como inactivas;
- que `Mostrar todas` mantiene visibles todos los niveles de prioridad elegibles;
- que `Mostrar solo la máxima prioridad visible` muestra únicamente el nivel P elegible con menor número, además de todos los iconos elegibles Siempre visible;
- que `Mostrar las dos máximas prioridades visibles` muestra los dos primeros niveles P que contengan habilidades elegibles, además de todos los iconos elegibles Siempre visible;
- que el binding bajo el icono sigue el modo actual de teclado/mando y se oculta cuando la habilidad no está en la barra activa;
- que arrastrar y desactivar un icono persiste tras `/reloadui`;
- que `Ver todos los configurados` ignora la condición de actividad y el filtro de prioridades solo mientras está marcado, excluye trackers deshabilitados o no equipados y se desactiva al cerrar la ventana de barras;
- que la ventana y los iconos HUD permanecen ocultos fuera de las escenas HUD/HUD UI.

Informa de los problemas indicando versión de API del cliente, versión del addon, idioma, modo de input y texto del error Lua.

Para problemas de estado o de los selectores, activa **Depuración** en LAM, reproduce el problema con la habilidad y usa **Capturar diagnóstico de configuración** o `/ezocombatdebug`. La captura incluye fase, fuente, confianza, temporizador y duración del slot, acumulaciones, toggle, cooldown, recurso de ultimate e IDs actuales de efectos del jugador. Incluye las entradas de EZOCombat de LibDebugLogger en el informe; si esa librería opcional no está disponible, EZOCombat escribe el diagnóstico en el chat.

## Licencia

EZOCombat se publica bajo la licencia MIT. Consulta [LICENSE](LICENSE).
