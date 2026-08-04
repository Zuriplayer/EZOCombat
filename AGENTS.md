# EZOCombat - AI Development Rules


<!-- EZO-SHARED-LAM-START -->
## Estándar LAM compartido

Antes de crear o modificar ajustes LibAddonMenu, leer y aplicar:
`E:\DEV\EZOFamilyDocs\docs\ezo-lam-settings-style.md`

Las reglas específicas de este addon tienen prioridad. Si el archivo compartido
no está accesible, no modificar LAM e indicarlo explícitamente.
<!-- EZO-SHARED-LAM-END -->
Este proyecto es un addon conceptual para The Elder Scrolls Online (ESO).

La referencia canonica del proyecto es `E:\DEV\EZOCombat`.

## Reglas obligatorias

- No inventar APIs de ESO.
- No implementar automatizacion de combate sin validacion explicita.
- No interceptar teclas globalmente.
- No simular pulsaciones, macros externas ni rotaciones.
- No usar `os.*`, `io.*`, `require()` ni librerias no soportadas por ESO.
- No depender de `EZOBindings`; fue un experimento pausado de la familia EZO.
- No depender de `EZOKeybinds`; si el jugador lo usa, debe funcionar como addon independiente de chording.

## Antes de tocar input o UI

Indicar siempre:

- Modo afectado.
- Modos que no deben cambiar.
- Trigger exacto.
- Resultado esperado.
- Resultado prohibido.

Validar mentalmente como minimo:

- `overlay-raton`
- `rapido-gamepad`
- `rapido-teclado`
- chat / `Enter`
- `ESC` / menus del juego

## Convenciones de la familia EZO

- Inicializacion en `EVENT_ADD_ON_LOADED`.
- Namespace global unico: `EZOCombat = EZOCombat or {}`.
- Textos visibles via `lang/en.lua` y `lang/es.lua`.
- Manifest actualizado cuando se anadan archivos.
- Cambios pequenos, revisables y centrados.

## HUD, Overlay Y Escenas

Cualquier aviso, barra, icono, overlay o indicador persistente de EZOCombat debe
estar integrado con las escenas HUD de ESO.

Reglas:

- No dejar `TopLevelWindow` visible globalmente en todas las escenas.
- Registrar controles visuales como `ZO_SimpleSceneFragment` o `ZO_HUDFadeSceneFragment`.
- Anadir los fragmentos solo a `HUD_SCENE` y `HUD_UI_SCENE`.
- Mantener un guard central tipo `IsHudScene()` que solo permita mostrar si
  `SCENE_MANAGER:IsShowing("hud")` o `SCENE_MANAGER:IsShowing("hudui")`.
- Todo `RefreshVisibility`, `Refresh` o `Update` debe hacer `SetHidden(true)` fuera de HUD/HUD_UI.
- Registrar `SCENE_MANAGER:RegisterCallback("SceneStateChanged", ...)` para refrescar visibilidad.
- No usar listas negativas de escenas como Tales of Tribute, Champion Points,
  inventario, mapa, crafting o configuracion de addons.
- El modo mover/desbloquear solo puede previsualizar controles en HUD/HUD_UI.
- Textos visibles siempre localizados EN/ES.
- Antes de usar APIs de escena nuevas, verificar en UESP ESO Data.

## Versionado y APIVersion

- Para cualquier cambio visible del addon, actualizar version con `.\tools\bump-version.ps1 -Patch` o `.\tools\bump-version.ps1 -Version x.y.z`.
- Si el cambio se prepara para release o hay parche de ESO, comprobar la API actual con `/script d(GetAPIVersion())` o fuente fiable ESOUI/UESP.
- `## APIVersion` controla si ESO muestra el addon como desactualizado en la pantalla de complementos/addons.
- No adivinar `## APIVersion`; solo cambiarlo si el valor actual esta verificado.
- Usar `.\tools\bump-version.ps1 -Patch -ApiVersion <api_actual>` para actualizar version y API.
- Mantener como maximo dos valores en `## APIVersion`; ESO ignora entradas adicionales.
- Antes de commit/release ejecutar `.\tools\bump-version.ps1 -Check -ApiVersion <api_actual>` y `git diff --check`.

## Politica provisional

EZOCombat puede ayudar al jugador a ver, decidir y ejecutar manualmente. No debe decidir ni ejecutar combate por el jugador.

## Documentación

- Toda modificación funcional, de configuración, comportamiento, alcance o requisitos debe incluir en el mismo trabajo la revisión y actualización de `README.md` y `README.es.md`.
- Ambos README deben mantenerse equivalentes y sincronizados.
- Ningún README debe anunciar funciones, límites o requisitos que no coincidan con el código actual.
- Deben actualizarse las secciones afectadas: funciones, límites de seguridad, requisitos, instalación y pruebas.
- Antes de cerrar cualquier cambio se debe comprobar expresamente que ambos README siguen completos y actualizados.

<!-- EZO-ESO-UPDATE-START -->
## Baseline obligatorio de ESO

Antes de analizar, modificar, validar, versionar o publicar este proyecto, leer
`..\EZOFamilyDocs\docs\eso-updates\current.md` y aplicar la política enlazada.

Baseline vigente: `U51-PTS-v12.1.0`.

- La matriz por addon vive en `..\EZOFamilyDocs\data\eso-update-baseline.json`.
- U51 sigue siendo PTS provisional hasta que exista verificación explícita.
- No cambiar `## APIVersion` por inferencia; verificarla en el cliente o en una
  fuente fiable de API.
- Si estos archivos no están disponibles, detener el trabajo sensible a
  compatibilidad e indicar el bloqueo.

Fuente remota de respaldo:
https://github.com/Zuriplayer/EZOFamilyDocs/blob/main/docs/eso-updates/current.md
<!-- EZO-ESO-UPDATE-END -->
