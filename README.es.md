# EZOCombat

Prefer English? Read the [README in English](README.md).

EZOCombat es un asistente visual y manual para las barras de habilidades de **The Elder Scrolls Online**. Nunca lanza habilidades, cambia barras de arma ni simula entradas del jugador.

Soporte, errores y sugerencias: https://discord.gg/ekw8zUAcRm

## Estado Beta

Versión: `0.2.39-beta`

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
- Acceso a la ventana desde el panel LAM de EZOCombat, `/ezocombat` o el atajo predeterminado `Mayusculas+NumPad 3` cuando esa entrada exacta está libre.
- Detección automática de clase y del rol seleccionado en el Buscador de grupo.
- Selección manual de rol en LAM al desactivar la detección automática. El rol de respaldo es Daño.
- Perfiles persistentes de habilidades seguidas por personaje, clase y rol.
- Iconos HUD creados desde una habilidad de la ventana. El modo manual conserva la posición independiente de cada icono con el ratón; los modos automáticos vertical y horizontal mueven el grupo completo. Se pueden desactivar con su botón `X` o mediante el editor de habilidad seleccionada en LAM.
- Tamaño de iconos HUD configurable entre 32 y 128 píxeles para el personaje desde LAM. El cambio redimensiona los trackers existentes sin alterar sus posiciones superiores izquierdas guardadas.
- Organización HUD manual, vertical por prioridad y horizontal por prioridad. El modo vertical coloca `Siempre visible`, P1, P2, P3, P4 y P5 de arriba abajo y distribuye en paralelo los iconos con la misma prioridad. El modo horizontal coloca esos grupos de izquierda a derecha y apila verticalmente los iconos de igual prioridad.
- Las disposiciones automáticas reservan celdas estables a partir de todos los trackers habilitados que sigan equipados en el perfil actual. Las condiciones de actividad y la política `Mostrar todas`/máxima/dos máximas solo ocultan o muestran esas celdas, por lo que los cambios normales de estado de combate y de barra no redistribuyen los demás iconos. Los grupos crean filas o columnas adicionales si lo exige el tamaño de pantalla.
- La alineación, separación de iconos y separación entre grupos de prioridad se configuran en LAM. Cada perfil de clase/rol guarda posiciones normalizadas distintas para vertical y horizontal al mover el grupo con el ratón, mientras que volver a manual recupera las posiciones individuales intactas. La integración opcional `family.layout` de EZOCore puede previsualizar temporalmente todas las celdas configuradas para colocar el grupo.
- Cada icono HUD visible muestra debajo el binding nativo de teclado o mando de su slot mientras la habilidad esté en la barra de arma activa. El binding se oculta cuando la habilidad solo está en la otra barra.
- Los IDs efectivos específicos de cada barra se resuelven para su propia barra, evitando que variantes dependientes del arma como Bloqueo elemental cambien de identidad seguida al cambiar de arma.
- Condiciones de aparición: mientras esté equipada; mientras esté activa y equipada; y mientras esté inactiva y equipada. Las ultimates normales usan el estado lista para lanzar como estado activo.
- Evidencias de estado por capas mediante temporizadores nativos del slot, toggles nativos, efectos del jugador con el mismo ID, recurso de ultimate y proveedores explícitos por habilidad. La ausencia de datos de API permanece como `UNKNOWN`; un tracker habilitado, equipado y configurado para inactividad se muestra provisionalmente hasta disponer de evidencia positiva, sin falsear el estado interno.
- Las familias verificadas de IDs variables de estado se comparan mediante una identidad estable, para que los IDs nativos encadenados o atenuados no rompan el seguimiento slotado, activo o inactivo. Las nuevas familias solo se añaden tras confirmar sus IDs en ESO.
- Crystal Fragments usa una familia de proc explícita: su identidad equipada (`114716`), la variante de lanzamiento del proc (`46324`) y el efecto de proc del jugador (`46327`) se relacionan sin depender de nombres localizados. La presencia del efecto es evidencia activa y su ausencia verificada es evidencia inactiva.
- Blighted Blastbones tiene un proveedor explícito de temporizador nativo del slot, por lo que un temporizador cero legible puede establecer su estado inicial inactivo antes del primer lanzamiento; esta inicialización solo se aplica a habilidades con una señal negativa nativa verificada.
- Cruxweaver Armor usa su temporizador nativo explícito, incluido un cero legible como evidencia inicial de inactividad. Barbed Trap y las dos variantes efectivas por recurso de Fulminating Rune usan ciclos explícitos de lanzamiento de 20 segundos y pueden estar inactivas antes del primer lanzamiento, porque su actividad útil se representa en el suelo o el objetivo y no mediante un efecto genérico fiable del jugador.
- Proximity Detonation normaliza su ID efectivo (`63302`) y su ID base de progresión (`61487`) y usa la estrategia de temporizador nativo, permitiendo que un cero legible establezca la inactividad antes del primer lanzamiento sin mezclar el morfeo diferente Inevitable Detonation.
- El estado toggle nativo positivo se acepta y aprende aunque ESO omita el metadato de toggle. Banner Bearer (`217699`) y la ultimate configurada del oso Warden (`92163`) también tienen proveedores toggle explícitos.
- Aprendizaje persistente de capacidades: después de observar un temporizador real de slot o un efecto del jugador con el mismo ID, EZOCombat puede usar la ausencia posterior de ese proveedor como evidencia fiable de inactividad.
- Protección genérica para el primer uso: un tracker con condición inactiva cuyo estado siga en `UNKNOWN` permanece visible con el motivo de depuración `unknown-inactive-fallback`. Cualquier temporizador, efecto, toggle o estado de recurso de ultimate observado recupera inmediatamente la visibilidad activa/inactiva normal. Esto cubre habilidades de duración nativa como Stampede sin mantener una lista de IDs.
- Los proveedores de estado siguen patrones documentados y explícitos para temporizador nativo, efectos del jugador, toggles, recurso de ultimate y ciclos de lanzamiento verificados. La ausencia genérica de evidencia permanece como `UNKNOWN`; consulta los [patrones de estado](docs/ABILITY_STATE_PATTERNS.md).
- Actividad temporizada verificada para Asalto subterráneo y Fisura profunda del Warden, con sus ventanas activas de 6 y 9 segundos.
- Categorías `Siempre visible` y `P1` a `P5`. Siempre visible evita el filtrado por prioridad, pero sigue respetando la condición equipada, activa o inactiva de la habilidad.
- Gestión global de prioridades en LAM: mostrar todos los niveles elegibles, solo el nivel elegible más alto o los dos niveles elegibles más altos. El modo de dos niveles omite niveles vacíos; por ejemplo, muestra P1 y P3 cuando P2 no contiene habilidades elegibles.
- La sección de habilidades seguidas de LAM usa un selector del perfil actual con controles de activación y prioridad. Los trackers equipados siguen el orden de ranuras de la barra frontal y después la trasera; los configurados no equipados quedan identificados. Se actualiza al cambiar el contenido de las barras, crear un tracker o cambiar el perfil de rol activo, tanto en LAM independiente como integrado en EZOCore.
- Las secciones LAM usan el icono informativo morado para la ayuda general de la sección; cada ajuste conserva su ayuda específica en el propio campo.
- Marco de objetivo enemigo PvP limitado por defecto a jugadores enemigos atacables en zonas AvA y campos de batalla activos. Muestra el nombre, la salud nativa actual/máxima y su porcentaje, los iconos de clase y alianza, el nivel o CP y el rango AvA cuando ESO proporciona esos datos.
- Alerta configurable de salud baja que muestra un icono de aviso durante cinco segundos cuando el objetivo enemigo cruza por debajo del porcentaje elegido. Los eventos de daño repetidos no reinician el temporizador.
- Alcance explícito de prueba PvE con dummy para el marco de objetivo. Al seleccionarlo en LAM, el marco puede seguir el objetivo atacable actual de la retícula fuera de PvP para verificar salud, movimiento y alerta de salud baja con dummies.
- Previsualización de posición del marco de objetivo movible solo con ratón, con posición persistente. Al activar el modo mover desde una escena HUD, solicita a ESO el modo UI de ratón y muestra una previsualización estable en vez de los datos vivos del objetivo, de modo que perder el objetivo actual de la retícula durante la colocación no oculta el marco. En el alcance PvP predeterminado solo está disponible en escenas HUD PvP; en el alcance de prueba con dummy también está disponible fuera de PvP para verificarlo. La integración opcional `family.layout` de EZOCore registra el mismo modo mover como `ezocombat.pvp_target` y conserva la casilla LAM local como fallback.
- Cono de daño PvP invertido opcional usando el texto de combate nativo de ESO. Su vértice comienza sobre la cabeza del objetivo, se abre hacia arriba y permite ajustar la distancia del vértice, la anchura, la separación de filas y la separación de impactos repetidos. El alcance predeterminado solo se aplica al daño PvP contra jugadores.
- Alcance explícito de prueba PvE con dummy para el cono de daño invertido. Al seleccionarlo, EZOCombat también permite objetivos monstruo/dummy fuera de PvP y restaura el slot/nube SCT anterior antes de cambiar entre el alcance PvP y el de prueba.
- Localización runtime en inglés y español.
- Diagnóstico opcional desde LAM o `/ezocombatdebug`, usando LibDebugLogger y duplicado opcional al chat.

## Límites Actuales

La beta no deduce estados genéricos de habilidad a partir de datos ausentes. Todavía no incluye:

- porcentajes de cooldown o duración restante;
- mapeo automático cuando la habilidad equipada y el efecto aplicado al jugador usan IDs de habilidad diferentes;
- semántica específica verificada para todas las habilidades de cada clase; las habilidades con toggle usan los metadatos y el estado nativo del slot, pero todavía requieren cobertura dentro del cliente;
- automatización de rotación, lanzamiento, cambio de barra, bloqueo, esquiva, interrupción, sinergia o ultimate.
- un foco persistente separado del objetivo actual `reticleover` de ESO; el marco PvP sigue al jugador enemigo atacable seleccionado actualmente;
- la salud del objetivo PvP cuando ESO no expone un valor máximo válido.

Las reglas futuras y los mapas alternativos de IDs de efecto se registrarán por `abilityId` solo cuando sus eventos y significado estén confirmados en ESO. Una habilidad sin proveedor verificado permanece como `UNKNOWN`: su condición activa no se muestra, mientras que el recordatorio con condición inactiva se muestra provisionalmente. Si ESO nunca ofrece evidencia positiva, el recordatorio puede permanecer visible durante el uso hasta añadir un proveedor verificado.

## Uso

1. Abre la ventana de barras desde LAM, `/ezocombat` o su atajo de Controles de ESO (`Mayusculas+NumPad 3` por defecto cuando está libre).
2. Haz clic derecho sobre una habilidad equipada de cualquiera de las dos barras para mantener abierta su configuración.
3. Activa su icono HUD y elige la condición de aparición y la categoría `Siempre visible` o `P1`-`P5` con los selectores de la ventana. En LAM puedes seleccionar cualquier habilidad configurada para editar su activación y prioridad, además del modo global de gestión de prioridades.
4. Elige **Manual**, **Vertical por prioridad** u **Horizontal por prioridad** en LAM. En manual, arrastra cada icono visible de forma independiente. En un modo automático, arrastra con el ratón cualquier icono visible para mover el grupo completo; puedes ajustar la alineación y ambas separaciones, y cada orientación conserva su propia posición. Usa `Ver todos los configurados` para colocar todos los trackers habilitados y equipados.
5. En la sección de objetivo enemigo PvP, activa el marco y la alerta de salud baja, elige **Solo PvP** para PvP real o **Prueba PvE con dummy** para verificarlo en dummy, elige el umbral y activa **Mover marco de objetivo PvP** para arrastrar su previsualización con el ratón.
6. Para probar el daño flotante opcional, activa **Usar cono de daño PvP invertido** en la sección de daño flotante PvP, elige **Solo PvP** o **Prueba PvE con dummy** y ajusta la distancia del vértice, la anchura, la separación de filas y la separación mínima del texto.

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
- que el marco de objetivo PvP se inicializa sin errores de textura de borde de `BackdropControl` y mantiene visible el relleno sólido de salud;
- que la ventana se abre desde LAM, `/ezocombat` y un atajo asignado;
- que teclado, ratón, gamepad, chat/Enter, ESC y los menús normales conservan su comportamiento nativo;
- que ambas barras muestran cinco ranuras normales y una ultimate;
- que cambiar una habilidad slotada actualiza la ventana de barras inmediatamente y también después de cerrarla y abrirla de nuevo;
- que un icono seguido desaparece al quitar la habilidad de ambas barras;
- que Bloqueo elemental y otras habilidades sobrescritas por la barra conservan su identidad seguida y su icono elegible al cambiar a la otra barra;
- que Blighted Blastbones, Blastbones y Stalking Blastbones mantienen su seguimiento cuando ESO cambia el ID nativo del slot entre los estados normal y atenuado, incluida la condición inactiva;
- que Crystal Fragments aparece con la condición activa en cuanto se carga el proc, mantiene la asociación al cambiar de barra y vuelve a inactiva inmediatamente al consumir o perder el proc;
- que Blighted Blastbones muestra su tracker inactivo desde la primera carga cuando el temporizador nativo del slot es legible, sin exigir un lanzamiento previo;
- que Deep Fissure permanece activa durante su ventana prevista verificada de nueve segundos y pasa a inactiva al terminar, sin que la sustituya un temporizador nativo parcial del slot;
- que Arctic Blast y otras habilidades con temporizador nativo están activas mientras su contador de slot sea positivo e inactivas al terminar; la capacidad observada debe conservarse tras `/reloadui`;
- que los iconos HUD y la ventana de configuración de EZOCombat se ocultan mientras están abiertas las ruedas radiales o de utilidad interactivas de ESO y regresan al cerrarlas;
- que las habilidades con toggle siguen `IsAbilityDurationToggled` junto con `IsSlotToggled`, mientras que activa y no activa de ultimates normales significan lista y no lista para lanzar;
- que Banner Bearer solo está activo mientras su toggle nativo de slot está encendido y pasa a inactivo al desactivar el banner;
- que las habilidades sin proveedor verificado permanecen como `UNKNOWN`; su condición activa queda oculta, mientras que un tracker habilitado y equipado con condición inactiva permanece provisionalmente visible con `eligibilityReason=unknown-inactive-fallback`;
- que Cruxweaver Armor aparece antes del primer lanzamiento al configurarla como inactiva, se oculta durante su temporizador nativo activo y reaparece cuando termina;
- que Barbed Trap y Fulminating Rune aparecen antes del primer lanzamiento al configurarlas como inactivas, se ocultan al lanzarlas y reaparecen tras su ciclo explícito de 20 segundos;
- que Proximity Detonation aparece antes del primer lanzamiento al configurarla como inactiva, se oculta durante su cuenta atrás nativa de ocho segundos y reaparece después de detonar;
- que Stampede aparece antes del primer lanzamiento al configurarla como inactiva, se oculta cuando ESO inicia su temporizador nativo de efecto en suelo de 15 segundos y reaparece al expirar, también al cambiar de arma;
- que `Mostrar todas` mantiene visibles todos los niveles de prioridad elegibles;
- que `Mostrar solo la máxima prioridad visible` muestra únicamente el nivel P elegible con menor número, además de todos los iconos elegibles Siempre visible;
- que `Mostrar las dos máximas prioridades visibles` muestra los dos primeros niveles P que contengan habilidades elegibles, además de todos los iconos elegibles Siempre visible;
- que manual, vertical y horizontal cambian entre sí sin sobrescribir las posiciones manuales guardadas;
- que vertical ordena Siempre visible y P1-P5 hacia abajo, coloca en una fila los iconos de igual prioridad y conserva las celdas vacías cuando la condición oculta temporalmente trackers configurados;
- que horizontal ordena esos grupos de izquierda a derecha, apila los iconos de igual prioridad y conserva sus celdas con los filtros máxima y dos máximas;
- que cambiar de barra no reordena las celdas automáticas solo porque cambie la barra de arma activa; sustituir o mover una habilidad equipada sí recalcula intencionadamente la rejilla configurada;
- que arrastrar cualquier icono de una disposición automática mueve el grupo completo sin saltos, y las posiciones vertical y horizontal siguen siendo independientes después de `/reloadui`;
- que las alineaciones Inicio, Centro y Final, ambas separaciones, el ajuste automático de filas/columnas, el restablecimiento de posición y el cambio de resolución funcionan sin solapamientos con tamaños de icono entre 32 y 128 píxeles;
- que el selector de habilidades configuradas de LAM solo lista el perfil activo de clase y rol, sigue el orden actual de ranuras frontal/trasera, identifica los trackers configurados no equipados, se actualiza al cambiar el contenido de las barras, crear un tracker o cambiar de perfil sin reabrir Ajustes y edita únicamente la habilidad seleccionada, tanto en LAM independiente como integrado en EZOCore;
- que cambiar el tamaño de los iconos HUD entre 32 y 128 píxeles redimensiona todos los trackers del personaje actual, conserva sus posiciones guardadas y permanece aplicado tras `/reloadui`;
- que el binding bajo el icono sigue el modo actual de teclado/mando y se oculta cuando la habilidad no está en la barra activa;
- que arrastrar y desactivar un icono persiste tras `/reloadui`;
- que el icono sigue el cursor sin saltos mientras se arrastra, incluso si durante el arrastre se producen refrescos del estado de combate o del HUD;
- que `Ver todos los configurados` ignora la condición de actividad y el filtro de prioridades solo mientras está marcado, excluye trackers deshabilitados o no equipados y se desactiva al cerrar la ventana de barras;
- que en **Solo PvP** el marco de objetivo permanece oculto en PvE, contra NPCs, contra jugadores aliados y cuando no existe un jugador enemigo atacable;
- que en **Prueba PvE con dummy** el marco sigue el objetivo atacable actual de la retícula fuera de PvP, incluidos dummies, mientras los campos de clase/alianza/rango quedan ocultos si ESO no proporciona datos;
- que el marco de objetivo PvP se actualiza al cambiar de objetivo y cuando cambia la salud nativa del objetivo;
- que los iconos de clase y alianza, el nivel/CP, el rango y los valores de salud solo aparecen cuando ESO proporciona datos válidos;
- que la alerta de salud baja aparece una vez cuando el objetivo cruza el umbral configurado, dura cinco segundos, no se prolonga con daño repetido y puede activarse de nuevo después de recuperarse;
- que activar el modo de mover el marco desde LAM de EZOCombat o desde `family.layout` de EZOCore solicita el modo UI de ratón desde HUD/HUD UI, muestra una previsualización temporal solo en las escenas HUD elegibles para el alcance seleccionado, el arrastre con ratón conserva la posición y desactivar el modo elimina la previsualización;
- que la superficie `ezocombat.pvp_target` de EZOCore aparece solo cuando EZOCore está instalado y no puede activar el modo edición si la propia función del marco de objetivo PvP está desactivada;
- que el marco PvP y el aviso se ocultan mientras están abiertas las ruedas radiales o de utilidad interactivas de ESO y regresan al cerrarlas;
- que en **Solo PvP** el cono de daño opcional cambia la posición SCT nativa solo en zonas AvA o campos de batalla activos, coloca el vértice más cerca de la cabeza del objetivo y restaura la posición y la nube SCT anteriores al desactivarlo o salir de PvP;
- que en **Prueba PvE con dummy** el cono de daño opcional puede ajustarse con objetivos monstruo/dummy fuera de PvP y restaura la posición/nube SCT anterior al desactivarlo o al volver al alcance Solo PvP;
- que el cono de daño PvP opcional se aplica de forma independiente a las nubes SCT de teclado y mando, y no crea input de combate ni duplica eventos de combate;
- que la ventana y los iconos HUD permanecen ocultos fuera de las escenas HUD/HUD UI.

Informa de los problemas indicando versión de API del cliente, versión del addon, idioma, modo de input y texto del error Lua.

Para problemas de estado o de los selectores, activa **Depuración** en LAM, reproduce el problema con la habilidad y usa **Capturar diagnóstico de configuración** o `/ezocombatdebug`. La captura incluye el ID estable de habilidad, el ID de efecto asociado, fase, fuente, confianza, temporizador y duración del slot, acumulaciones, toggle, cooldown, recurso de ultimate e IDs actuales de efectos del jugador. Incluye las entradas de EZOCombat de LibDebugLogger en el informe; si esa librería opcional no está disponible, EZOCombat escribe el diagnóstico en el chat.

## Licencia

EZOCombat se publica bajo la licencia MIT. Consulta [LICENSE](LICENSE).
