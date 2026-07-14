# EZOCombat

Prefer English? Read the [README in English](README.md).
EZOCombat es un addon en beta pública temprana para **The Elder Scrolls Online**, centrado en investigar asistencia de combate segura para la familia de addons EZO.

El alcance actual es intencionadamente pequeño: el addon carga, aplica localización en inglés/español, expone el comando básico `/ezocombat` y documenta los límites de seguridad previstos para futuros asistentes visuales de combate. No automatiza el combate.

Soporte, errores y sugerencias: https://discord.gg/ekw8zUAcRm

## Estado Beta

Versión: `0.1.1-beta`

Esta beta está pensada para visibilidad pública, feedback y pruebas controladas. Las funciones de ayuda de combate siguen en fase de diseño/prototipo.

## Requisitos

- Cliente de The Elder Scrolls Online para PC.
- Versiones de API de ESO declaradas en el manifiesto: `101049 101050`.
- Addons opcionales para desarrollo/diagnóstico:
  - `LibDebugLogger`
  - `DebugLogViewer`
- Integración opcional con la familia EZO:
  - `EZOCore` para heredar la preferencia de idioma compartida, si está instalado

No se necesita ningún runtime externo ni librería Lua de terceros para el uso normal.

## Instalación

1. Descarga o clona este repositorio.
2. Copia la carpeta `EZOCombat` en tu directorio de AddOns de ESO:
   - Live: `Documents/Elder Scrolls Online/live/AddOns/EZOCombat`
   - PTS: `Documents/Elder Scrolls Online/pts/AddOns/EZOCombat`
3. Inicia ESO o ejecuta `/reloadui`.
4. Activa `EZOCombat` desde el menú de complementos si hace falta.

## Funciones Actuales

- Arranque mínimo del addon mediante `EVENT_ADD_ON_LOADED`.
- Textos runtime en inglés y español según el idioma del cliente de ESO.
- Preferencia de idioma heredada opcionalmente desde `EZOCore`, con fallback al idioma del cliente de ESO.
- Mensaje de carga confirmando que no hay automatización de combate activa.
- Comando `/ezocombat`, que muestra el estado conceptual actual.
- Documentación pública para el diseño futuro de ayudas de combate.
- Límites de seguridad explícitos entre asistencia visual y automatización de combate.

## Opciones Actuales

EZOCombat no tiene actualmente panel de LibAddonMenu, SavedVariables, atajos de teclado ni opciones configurables por el usuario.

## Dirección Prevista

La dirección prevista es un asistente de combate visual y manual:

- detectar habilidades configuradas en la barra de acciones
- observar si las habilidades marcadas parecen producir daño
- avisar visualmente cuando una habilidad marcada parezca fallar o dejar de hacer ticks
- dar soporte a teclado/ratón y gamepad sin cambiar el comportamiento del input

Estas funciones todavía no están implementadas en esta beta.

## Límites De Seguridad

EZOCombat actualmente no realiza acciones de combate. El trabajo futuro debe mantenerse dentro de estos límites:

- no lanzar habilidades
- no cambiar barras de arma automáticamente
- no ejecutar rotaciones de combate
- no encadenar varias habilidades desde una sola entrada
- no simular input de teclado o gamepad
- no automatizar sinergias, interrupciones, esquivas, bloqueos, ultimate ni prebuffs

El addon puede proporcionar información visual, recordatorios y diagnósticos. El jugador debe seguir decidiendo y realizando manualmente todas las acciones de combate.

## Notas De Prueba

Para esta beta, comprueba:

- el addon aparece en la lista de complementos de ESO
- el addon carga sin errores Lua
- `/reloadui` termina correctamente
- el mensaje de carga aparece en el idioma configurado
- si `EZOCore` está instalado, EZOCombat refleja los cambios de idioma heredados
- `/ezocombat` muestra el mensaje de estado localizado
- los controles de teclado y gamepad se comportan exactamente igual que antes de activar el addon
- no se crea ningún panel, overlay, atajo de teclado ni entrada de SavedVariables

Informa de los problemas indicando versión del cliente de ESO, versión del addon, idioma, modo de input y cualquier texto de error Lua.

## Licencia

EZOCombat se publica bajo la licencia MIT. Consulta [LICENSE](LICENSE).
