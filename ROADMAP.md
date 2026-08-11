# Roadmap detallado para CityBuilder (Godot 4.5.1)

Resumen rápido: roadmap por fases con tareas concretas, criterios de aceptación y riesgos. Ejecutar con Godot 4.5.1. Ver [SPECS.md](SPECS.md) para el contrato técnico de cada módulo.

Este documento se revisó el 2026-08-10 tras una auditoría de código: varias tareas marcadas como completadas en la versión anterior no lo estaban (scripts vacíos referenciados por recursos `.tres`). Las correcciones están reflejadas abajo y detalladas en **FASE 3.5**, que debe resolverse antes de seguir avanzando en construcción/gameplay.

---

## FASE 0 — Setup y Repositorio ✅ COMPLETADA
- ✅ Godot 4.5.1, `project.godot`, `.gitignore`, `TimeManager` como Autoload, `README.md`.
- Criterio de aceptación: ✅ repositorio clonado y abierto en Godot sin errores de proyecto.

---

## FASE 1 — Arquitectura de Datos ✅ COMPLETADA
- ✅ `RawMaterial.gd` con `@export` para propiedades físicas.
- ✅ Recursos: `materials/{Iron,Stone,Straw,Coal,Wood,Copper,Clay}.tres`.
- ✅ `Chunk.gd` para gestionar recursos en celdas del terreno (incluye `serialize()/deserialize()`).
- ⬚ Persistencia real a disco (JSON o `ResourceSaver`) — el método existe pero nada lo invoca.
- Criterio de aceptación: ✅ se puede colocar un recurso en el mapa y leerlo desde `Chunk.get_resources_at()`.

---

## FASE 2 — Mundo Procedural ✅ COMPLETADA
- ✅ `TerrainGenerator.gd` con `FastNoiseLite` (Height, Humidity, Geology) y parámetros en el Inspector (`@tool`).
- ✅ `populate_chunk_resources()` para poblar vetas basadas en geología.
- ✅ `MultiMeshVegetation.gd` para vegetación eficiente vía `MultiMeshInstance3D` con LOD (`visibility_range_begin/end`).
- ⬚ Visualización debug de las capas de ruido (gizmos/`ImmediateMesh`) — `debug_layer`/`show_debug_gizmos` existen como export pero no están implementados.
- Criterio de aceptación: ✅ el demo muestra terreno, recursos y vegetación con `MultiMesh` sin nodos individuales.

---

## FASE 3 — Construcción, GridMap y Física Simplificada 🔶 EN PROGRESO
- ⬚ Integrar `GridMap` y `mesh_library` para bloques y muros (no implementado; los edificios de prueba son `MeshInstance3D` sueltos).
- ✅ `Architecto.gd`: `can_place_at_world()` comprueba dureza del suelo vs. peso.
- ✅ Colapso en cascada simplificado (`_check_cascade_collapse` + `_trigger_collapse`), documentado como heurística de distancia, no un grafo estructural real.
- ⚠️ **`BlockData.gd` está vacío** (0 líneas) pero `buildings/{StoneWall,WoodenFloor,StrawRoof}.tres` declaran `script_class="BlockData"` con propiedades que no existen en ningún script. Corregir en FASE 3.5 antes de dar esta fase por buena.
- ⬚ Los edificios colocados no tienen `CollisionShape3D` → se pueden solapar sin detectarlo por raycast.
- Entregables: ✅ `Architecto.gd`, ⬚ `BlockData.gd` real, ⬚ GridMap demo, ⬚ colisión de edificios.
- Criterio de aceptación: ✅ el jugador no puede colocar bloques en terrenos débiles; ⬚ `BlockData` funcional; ⬚ no se pueden solapar edificios.

---

## FASE 3.5 — Deuda técnica crítica 🔴 PRIORITARIA (bloquea el resto)

Encontrada en auditoría de 2026-08-10. Resolver antes de continuar FASE 3/6, porque construir gameplay sobre estos huecos multiplica el coste de arreglarlos después.

1. **Implementar `BlockData.gd`** con `class_name BlockData extends Resource` y las propiedades que ya usan los `.tres` existentes: `block_name: String`, `weight: float`, `primary_material: RawMaterial`, `dimensions: Vector3`, `is_structural: bool`, `support_factor: float`, `requires_support: bool`, `category: String`, `fire_resistance: float`, `thermal_insulation: float`, `crafting_materials: Array`, `build_time: float`. Verificar que `buildings/*.tres` cargan sin warnings tras el fix.
2. **Implementar `Inventory.gd`** (stacks de `RawMaterial`/items) o eliminar la referencia si se decide posponerlo — no dejarlo como script vacío referenciado como "hecho".
3. **Implementar o eliminar `GameUtils.gd`** — decidir su propósito real o quitarlo del repo si no aporta nada todavía.
4. **Dar colisión a los edificios colocados** (`StaticBody3D` + `CollisionShape3D` por bloque) para que el raycast de `_try_place_building_at_mouse` los detecte y no se solapen.
5. **Unificar señales duplicadas de `TimeManager`**: `cambio_de_estacion` y `season_changed` hacen lo mismo — quedarse con una y actualizar los listeners (`DemoMain`, `WorldEnvironmentSetup`).
6. **Arreglar `CameraController`**: elimina la lectura duplicada de teclas físicas (`Input.is_key_pressed(KEY_W)`, etc.) y deja solo las acciones del `InputMap` (`move_forward`, …) para que el remapeo de controles funcione.
7. Actualizar el ROADMAP/README a medida que se resuelva cada punto (evitar que vuelva a haber checkmarks falsos).

Criterio de aceptación: cero scripts vacíos referenciados por un `.tres` o por otro script; `Inventory`/`GameUtils` implementados o retirados explícitamente.

---

## FASE 4 — Tiempo, Estaciones y Sistemas Reactivos ✅ COMPLETADA
- ✅ `TimeManager.gd` autoload con ticks, días, estaciones, años y señales.
- ⬚ Listeners de gameplay (ej. cultivos que mueren en invierno) — no hay sistema de cultivos todavía.
- ⬚ Tests que se suscriban a `TimeManager` y verifiquen transiciones.
- Criterio de aceptación: ✅ eventos de estación se emiten y los consumidores (`WorldEnvironmentSetup`, `DemoMain`) reaccionan.

---

## FASE 5 — Gráficos y Shaders ✅ COMPLETADA (con nota de rendimiento)
- ✅ `WorldEnvironmentSetup.gd`: SDFGI, niebla volumétrica, ACES, SSAO/SSIL, glow, sol dinámico por hora/estación.
- ✅ `shaders/triplanar.gdshader`: blending por altura y pendiente, sin estiramiento de textura.
- ✅ `TerrainMaterialManager.gd` + `ProceduralTextureGenerator.gd`: material PBR completo con texturas y normal maps procedurales.
- ⬚ **FASE 5.1 (nueva) — Optimizar generación de texturas**: `ProceduralTextureGenerator` genera 8 texturas de 512×512 pixel-a-pixel en GDScript (`Image.set_pixel`) cada vez que se crea el material del terreno, incluyendo cada regeneración en editor (`auto_generate`). Causa un hitch perceptible en el arranque. Opciones: (a) generar una vez y cachear en disco como `.tres`/`.png` reutilizable entre ejecuciones, (b) mover la generación a un compute/fragment shader, (c) al menos sustituir `set_pixel` por escritura directa a `PackedByteArray` + `Image.create_from_data`.
- Criterio de aceptación: ✅ terreno natural con SDFGI; ⬚ generación de texturas sin hitch de arranque.

---

## FASE 6 — Escalado de Mundo: Chunking Real ⬚ PENDIENTE (nueva, antes opcional)

Elevada desde "extensión opcional" porque el diseño de `Chunk` ya asume streaming por fragmentos y actualmente se usa como un único chunk del tamaño de todo el terreno — hay que decidir esto antes de construir gameplay que dependa de tamaño de mundo.

- ⬚ Definir tamaño de chunk fijo (ej. 32×32) y generar `TerrainGenerator`/`Chunk` por rejilla en vez de uno monolítico.
- ⬚ Carga/descarga de chunks según distancia a cámara/jugador.
- ⬚ LOD de terreno (no solo de vegetación) para chunks lejanos.
- Criterio de aceptación: mundo de al menos 512×512 sin caída de FPS por debajo del objetivo (ver SPECS §5), con chunks fuera de rango descargados de memoria.

---

## FASE 7 — Gameplay Base: Recolección, Inventario y Economía ⬚ PENDIENTE
- ⬚ `Inventory.gd` real (ver FASE 3.5, punto 2), `ItemResource` (Resource), stacks.
- ⬚ Storage/silos en `Chunk` que reducen peso de recursos en el suelo al recolectarlos.
- ⬚ Workers / UI de recolección y crafting que usan `Chunk.extract_resource()` e `Inventory`.
- Criterio de aceptación: el jugador puede recoger recursos físicamente del suelo y depositarlos en storages.

---

## FASE 8 — Polishing, QA y Tests ⬚ PENDIENTE
- ⬚ Tests con GUT (o similar) para `Chunk`, `TerrainGenerator`, `Architecto`, y ahora también `BlockData`/`Inventory` una vez existan.
- ⬚ Migrar la composición por código de `DemoMain.gd` a escenas `.tscn` reales con nodos y `@export` de referencias — mejora la editabilidad y permite tests de escena.
- ⬚ Profiling con el profiler de Godot; resolver memory leaks y el hitch de FASE 5.1.
- ⬚ Persistencia real: conectar `Chunk.serialize/deserialize` y `TimeManager.get_time_state/set_time_state` a un `SaveManager` con guardado/carga en disco.
- Criterio de aceptación: tests cubren la lógica crítica; demo de rendimiento estable; se puede guardar y cargar una partida.

---

## Extensiones — Opcionales (a futuro)
- ⬚ Multijugador host-authoritative.
- ⬚ IA avanzada para trabajadores y NPCs.
- ⬚ Herramientas de editor: placement wizards, paneles de debug in-editor.
- ⬚ Exportación a build distribuible (`export_presets.cfg`).

---

## Riesgos y mitigaciones
- SDFGI y efectos avanzados: riesgo de hardware pobre — mitigación: fallback a baked lighting y LOD.
- MultiMesh instancing mal usado: riesgo de desbordamiento — mitigación: usar pool y limitar `instance_count` por batch.
- Deuda técnica silenciosa (scripts vacíos referenciados por recursos): mitigación — no marcar una tarea ✅ sin verificar que el archivo tiene contenido y que carga sin warnings en el editor.
- Chunk único monolítico: mitigación — resolver FASE 6 antes de invertir en contenido que asuma mundos grandes.

---

## Aceptación general del proyecto (MVP)
- ✅ Terreno procedural con 3 capas
- ✅ Vegetación con `MultiMesh`
- ✅ `Chunk` con recursos físicos (como chunk único; falta chunking real, FASE 6)
- ✅ `Architecto` para colocar bloques (falta `BlockData` real, FASE 3.5)
- ✅ `TimeManager` funcionando
- ⬚ Demostración jugable completa: recorrer el mapa, ver vetas de minerales, colocar estructura y observar si el material soporte lo permite (bloqueado por FASE 3.5, punto 4: colisión de edificios).

---

## Archivos Implementados

### Scripts
- ✅ `scripts/RawMaterial.gd` — Propiedades físicas de materiales
- ✅ `scripts/Chunk.gd` — Gestión de recursos por celda
- ✅ `scripts/TerrainGenerator.gd` — Generación procedural con 3 capas de ruido
- ✅ `scripts/MultiMeshVegetation.gd` — Vegetación eficiente con MultiMesh
- ✅ `scripts/Architecto.gd` — Sistema de construcción y colapso estructural
- ✅ `scripts/TimeManager.gd` — Gestión de tiempo, días y estaciones
- ✅ `scripts/WorldEnvironmentSetup.gd` — Configuración de SDFGI, fog, iluminación
- ✅ `scripts/CameraController.gd` — Cámara orbital (input duplicado a limpiar, FASE 3.5)
- ⚠️ `scripts/Inventory.gd` — **vacío**, no implementado (corregido respecto a versión anterior de este documento)
- ⚠️ `scripts/BlockData.gd` — **vacío**, no implementado; recursos `.tres` dependientes de él
- ⚠️ `scripts/GameUtils.gd` — **vacío**, propósito sin definir
- ✅ `scripts/DemoMain.gd` — Integración de todos los sistemas (por código, no por escena)
- ✅ `scripts/ProceduralTextureGenerator.gd` — Texturas procedurales (rendimiento a optimizar, FASE 5.1)
- ✅ `scripts/TerrainMaterialManager.gd` — Gestión de material triplanar
- ✅ `scripts/ResourceVisualizer.gd` — Visualización de recursos del `Chunk` vía MultiMesh

### Shaders
- ✅ `shaders/triplanar.gdshader` — Shader triplanar con blend por altura/pendiente

### Escenas
- ✅ `scenes/demo_main.tscn` — Escena principal (nodo raíz + WorldEnvironment; el resto se crea por código)
- ✅ `scenes/WorldEnvironment.tscn` — Entorno gráfico
- ✅ `scenes/OrbitalCamera.tscn` — Cámara del jugador
- ✅ `scenes/MultiMeshTrees.tscn` — Vegetación instanciada

### Materiales (RawMaterial)
- ✅ `materials/{Iron,Stone,Straw,Coal,Wood,Copper,Clay}.tres`

### Edificios (BlockData)
- ⚠️ `buildings/{StoneWall,WoodenFloor,StrawRoof}.tres` — datos definidos en el `.tres`, pero sin script `BlockData` funcional que los tipe (ver FASE 3.5)

---

## Leyenda
- ✅ Completado
- 🔶 En progreso
- 🔴 Prioritario / bloqueante
- ⚠️ Marcado como completo antes, corregido tras auditoría
- ⬚ Pendiente

---

Fecha de creación: 2025-12-13
Última actualización: 2026-08-10 (auditoría de código + corrección de estado real)
