# Roadmap detallado para CityBuilder (Godot 4.5.1)

Resumen rápido: este documento detalla un roadmap por fases con tareas concretas, criterios de aceptación, estimaciones y riesgos. Está pensado para ejecutar con Godot 4.5.1 y prioriza una base de datos/arquitectura sólida antes de la estética.

FASE 0 — Setup y Repositorio (1-2 días)
- Objetivo: configurar entorno, convenciones y repo para desarrollo.
- Tareas:
  - Confirmar Godot 4.5.1 como versión del proyecto y crear `project.godot` con ajustes base.
  - Añadir `.gitignore` recomendado para Godot y carpetas `export_presets.cfg` si aplica.
  - Establecer `TimeManager.gd` como Autoload.
  - Crear un `README.md` con pasos para abrir en Godot (ya hecho).
- Entregables: `.gitignore`, `project.godot`, `README.md` con instrucciones.
- Criterio de aceptación: repositorio clonado y abierto en Godot sin errores de proyecto.

FASE 1 — Arquitectura de Datos (2-4 días)
- Objetivo: crear el ADN del juego usando `Resource` y `Chunk`.
- Tareas:
  - Implementar `RawMaterial.gd` con `@export` para `display_name`, `density`, `melting_point`, `hardness`, `conductivity`.
  - Crear recursos de ejemplo: `materials/Iron.tres`, `materials/Stone.tres`, `materials/Straw.tres`.
  - Implementar `Chunk.gd` para gestionar recursos en celdas del terreno.
  - Añadir persistencia opcional (guardar/leer JSON o usar `ResourceSaver/Loader`).
- Entregables: `scripts/RawMaterial.gd`, `scripts/Chunk.gd`, recursos .tres y ejemplo de carga y guardado.
- Criterio de aceptación: se puede colocar un recurso en el mapa y leerlo correctamente desde `Chunk.get_resources_at()`.

FASE 2 — Mundo Procedural (3-6 días)
- Objetivo: generar un terreno con 3 capas de ruido y poblar recursos.
- Tareas:
  - `TerrainGenerator.gd` con `FastNoiseLite` (capas: Height, Humidity, Geology).
  - Normalizar y exponer parámetros (seed, frequency, octaves) en el Inspector.
  - Crear función `populate_chunk_resources(chunk, materials_map, threshold)` para poblar vetas basadas en geología.
  - Integrar `MultiMeshInstance3D` para árboles/vegetación (`multimesh_trees.gd`) con LOD/instancias y culling.
  - Añadir visualización debug (gizmos o `ImmediateMesh`) para las capas si `debug_mode` es activo.
- Entregables: `scripts/TerrainGenerator.gd`, `scenes/MultiMeshTrees.tscn`, demo `scenes/demo_main.tscn`.
- Criterio de aceptación: el demo muestra un terreno, poblado de recursos y vegetación con `MultiMesh` sin crear miles de nodos individuales.

FASE 3 — Construcción, GridMap y Física Simplificada (4-7 días)
- Objetivo: permitir que el jugador construya y el sistema determine estabilidad estructural.
- Tareas:
  - Integrar `GridMap` y crear `mesh_library` para bloques y muros.
  - `Architecto.gd` con método `can_place_at_world(world_pos, building_weight)` usando `Chunk` para comprobar material abajo.
  - Implementar sistema de colapso: si se retira soporte o material_hardness < (peso / factor), se desencadena colapso.
  - Guardar las reglas de peso por bloque (`BlockData` Resource) y hacer balanceo simple.
- Entregables: `scripts/Architecto.gd`, GridMap demo `building_demo.tscn` y una escena `demo_main` con building placement.
- Criterio de aceptación: el jugador no puede colocar bloques en terrenos débiles; colapso se produce cuando corresponde.

FASE 4 — Tiempo, Estaciones y Sistemas Reactivos (2-4 días)
- Objetivo: crear un `TimeManager` global, señales y efectos de estaciones.
- Tareas:
  - `TimeManager.gd` como autoload con ticks, días y años, y señal `cambio_de_estacion`.
  - Implementar listeners simples (por ejemplo, cultivos que mueren en invierno si no protegidos).
  - Test scripts que subscriben y reaccionan a `TimeManager`.
- Entregables: `scripts/TimeManager.gd`, ejemplo `scenes/farms_demo.tscn` con cambios por temporada.
- Criterio de aceptación: eventos de estación se emiten y los consumidores reaccionan (cambian visual/estado).

FASE 5 — Gráficos y Shaders (5-10 días)
- Objetivo: alta calidad visual usando SDFGI, volumetric fog y triplanar shading.
- Tareas:
  - `scenes/WorldEnvironment.tscn` con `WorldEnvironmentSetup.gd` para activar SDFGI y Fog.
  - `shaders/triplanar.gdshader` con blending por slope y height.
  - Material PBR para el terreno con blending por altura/pendiente y triplanar.
  - Ajustes: ACES tone mapper, volumetric fog tuning y prueba de performance.
- Entregables: `shaders/triplanar.gdshader`, materiales de terreno, `WorldEnvironment.tscn` configurado.
- Criterio de aceptación: terreno se ve natural (no textura estirada), SDFGI encendido y rendimiento > 30 FPS en la escena de demo.

FASE 6 — Gameplay Base: Recolección, Inventario y Economía (4-8 días)
- Objetivo: implementar recolección física, inventario, crafting y almacenaje.
- Tareas:
  - `Inventory` (no global), ítems `ItemResource` (Resource), stacks.
  - Ceramic/Storage nodes en `Chunk` (silos) que reducen peso en el suelo.
  - Workers / UI de recolección y crafting que usan recursos del `Chunk` y de inventarios.
- Entregables: `scripts/inventory.gd`, `scenes/storage_demo.tscn`.
- Criterio de aceptación: jugador puede recoger recursos físicamente del suelo y depositarlos en storages.

FASE 7 — Polishing, QA y Tests (2-6 días)
- Objetivo: asegurar calidad, agregar tests, profiling y UX.
- Tareas:
  - Añadir pruebas con GUT (opcional) para `Chunk`, `TerrainGenerator`, `Architecto`.
  - Performance tuning: batching, MultiMesh, reduce drawcalls, LOD.
  - Perfilado con Godot profiler, solucionar memory leaks.
- Entregables: tests pasados, mejoras de perf, checklist para QA.
- Criterio de aceptación: Tests unitarios cubren lógica crítica; demo de rendimiento estable.

Extensiones y Fase 8 — Opcionales (a futuro)
- Guardado/Load persistente y multiplayer (host-authoritative).
- IA avanzada para trabajadores y NPCs.
- Herramientas editor en Godot: placement wizards, debug panels.

Riesgos y mitigaciones
- SDFGI y efectos avanzados: riesgo de hardware pobre — mitigación: fallback baked lighting y LOD.
- MultiMesh instancing mal usado: riesgo desbordamiento—mitigación: usar pool y limitar instance_count por batch.

Aceptación general del proyecto (MVP)
- Terreno procedural con 3 capas, vegetación con `MultiMesh`, `Chunk` con recursos físicos, `Architecto` para colocar bloques y `TimeManager` funcionando.
- Demostración jugable de: recorrer el mapa, ver vetas de minerales (hidden geology), colocar una estructura y observar si el material soporte lo permite.

Próximo paso inmediato (elige una):
1) Integrar `demo_main.tscn` como escenario que combine `TerrainGenerator`, `Chunk`, `MultiMeshTrees`, `Architecto` y `WorldEnvironment` (recomiendo empezar por aquí).
2) Añadir `GridMap` piso y building demo con un `building_demo.tscn` y probar colapsos.
3) Preparar conjunto de tests GUT para `Chunk`, `Architecto` y `TerrainGenerator`.

Si quieres que implemente ahora cualquiera de los siguientes, dime cuál: 1, 2 o 3.

Fecha de creación: 2025-12-13
