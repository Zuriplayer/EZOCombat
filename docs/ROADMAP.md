# Roadmap

## Fase 1 - Base de barras y perfiles

Implementada estáticamente en `0.2.17-beta`; requiere validación dentro de ESO.

- Ventana HUD movible con las dos barras y sus ultimates.
- Acceso desde LAM, `/ezocombat` y un binding propio asignado por el jugador.
- Perfiles persistentes por personaje, clase detectada y rol.
- Rol automático desde el Buscador de grupo, con selección manual como alternativa.
- Iconos HUD que solo participan mientras su habilidad esté equipada.
- Condiciones de aparición equipada, activa y no activa basadas en un estado trivalente: activo, inactivo o desconocido.
- Categoría Siempre visible y prioridades P1-P5 con política global: todas, solo el nivel elegible más alto o los dos niveles elegibles más altos.
- Binding nativo de teclado o mando bajo el icono, visible solo cuando la habilidad está en la barra activa.

## Fase 2 - Estados por habilidad

- Motor por evidencias implementado: temporizador de slot, toggle, efecto del jugador con el mismo ID, recurso de ultimate, predicción explícita y estado desconocido.
- Mantener proveedores y mapas de efectos por `abilityId` para las excepciones que no cubran el contador del slot ni los efectos coincidentes del jugador.
- Validar dentro de ESO el estado activo/inactivo del oso Warden mediante su señal nativa de toggle; los morphs de Shalk ya cubren sus temporizadores previstos de 6 y 9 segundos.
- No usar la ausencia de un buff o evento como prueba genérica de que una habilidad está inactiva.

## Fase 3 - Umbrales

- Añadir porcentajes de recurso, cooldown o duración restante solo donde el dato sea fiable.
- Aplicar los umbrales antes de ordenar los iconos por prioridad.

## Fase 4 - Catálogos de clase y rol

- Mantener catálogos separados para Warden y las demás clases.
- Separar contenido DD, Tank y Healer sin inferir el rol desde la barra o el equipo.
- Reutilizar el mismo motor de perfiles, condiciones y prioridades.

## Criterios de avance

- Cada función debe indicar si es informativa, manual o automática.
- La automatización de combate está descartada.
- La validación estática no sustituye `/reloadui`, HUD/HUD UI, teclado, ratón, gamepad, chat/Enter y ESC.
