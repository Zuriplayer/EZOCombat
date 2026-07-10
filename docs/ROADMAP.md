# Roadmap provisional

## Fase 0 - Concepto

Estado actual.

- Repo inicial creado.
- Addon minimo sin automatizacion.
- Documentacion de limites y riesgos.
- Sin dependencias de servicios externos de bindings.

## Fase 1 - Inventario tecnico

- Escanear acciones nativas relacionadas con weapon swap, quickslots, synergy y ultimate.
- Documentar nombres de accion, capas y categorias desde fuentes verificadas de ESO.
- Confirmar en cliente real que cualquier accion manual respeta teclado, gamepad, chat y menus.
- Decidir si `EZOCombat` necesita `Bindings.xml`.

## Fase 2 - Alertas seguras

- Crear modulo de estado de combate.
- Crear patron reusable de alerta por `abilityId`.
- Migrar aprendizajes de `EZOTakingAim` sin acoplarlo ni romperlo.
- Validar rendimiento con filtros de evento.

## Fase 3 - Bindings manuales

- Definir una o dos acciones manuales de bajo riesgo.
- Anadir `Bindings.xml` solo si hay accion real.
- Validar teclado, gamepad, chat, `Enter`, `ESC` y menus.

## Fase 4 - UI opcional

Solo si hace falta:

- panel LAM
- presets de alertas
- diagnostico de binds

## Criterios de avance

- Cada feature debe indicar si es informativa, manual o automatica.
- Las automaticas de combate quedan descartadas por defecto.
- Cualquier accion ligada a arma/habilidad requiere prueba en cliente real y revision separada.
