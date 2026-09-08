# SPECS.md — CityBuilder ("History of Man")

Especificación técnica del proyecto. Documenta qué existe, cómo encajan las piezas, y qué contratos debe respetar cualquier código nuevo. No es un tutorial: es la referencia para tomar decisiones de diseño consistentes.

Motor: **Godot 4.5.1** · Lenguaje: **GDScript** · Renderer: **Forward+**

---

## 1. Visión general

Simulador de construcción de ciudades en 3D con:
- Terreno procedural (altura / humedad / geología) generado por ruido.
- Recursos físicos (minerales, madera, piedra) distribuidos en el terreno y extraíbles.
- Construcción con reglas físicas simplificadas (dureza del suelo vs. peso del edificio) y colapso estructural.
- Ciclo de tiempo (ticks → días → estaciones → años) que retroalimenta iluminación y clima.
- Gráficos PBR con SDFGI, niebla volumétrica y shader triplanar para el terreno.

> Nota de identidad: `project.godot` define `config/name="CityBuilder"`, y así se refieren a sí mismos el README y el ROADMAP originales. El repositorio se llama "History of Man". Mientras no se decida un nombre único, este documento usa **CityBuilder** para el proyecto técnico.

---

## 2. Arquitectura

### 2.1 Autoloads (globales)
- `TimeManager` (`scripts/TimeManager.gd`) — único autoload declarado en `project.godot`. Gestiona ticks/días/estaciones/años y emite `tick_advance`, `day_changed`, `season_changed`, `year_changed`, `time_paused`.

### 2.2 Patrón de composición actual
`scripts/DemoMain.gd` construye **todo el árbol de escena por código** en `_ready()` (`TerrainGenerator.new()`, `Chunk.new()`, `MultiMeshVegetation.new()`, `Architecto.new()`, cámara, UI de debug…). La única escena real es `scenes/demo_main.tscn`, que solo contiene el nodo raíz `DemoMain` + `WorldEnvironment.tscn` instanciado.

**Esto es deliberado para el prototipo pero es deuda a medio plazo**: impide previsualizar/editar el mundo en el editor, dificulta el reuso de nodos como escenas independientes, y hace que cualquier ajuste fino (posición de cámara, materiales de vegetación) solo se pueda hacer recompilando el script. Ver ROADMAP para el plan de migración a escenas `.tscn` reales con `@export` de referencias a nodos.

### 2.3 Flujo de arranque (`DemoMain._ready`)
```
_load_materials() → _setup_terrain() → _setup_chunk() → _setup_vegetation()
→ _setup_architecto() → _setup_resource_visualizer() → _setup_camera() → _setup_ui()
→ _connect_signals() → terrain.generate() → _populate_resources() → _visualize_resources()
→ _spawn_test_buildings()
```

---

## 3. Módulos y contratos

### 3.1 `RawMaterial` (`scripts/RawMaterial.gd`) — `Resource`, `@tool`
Propiedades físicas de un material: `density`, `melting_point`, `hardness` (0-10), `conductivity`, `category`, `is_flammable`, `base_value`. Métodos puros: `calculate_weight(volume)`, `can_support_weight(weight, area)`, `would_melt_at(temp)`, `would_ignite_at(temp)`, `to_dict()/from_dict()`.
Instancias `.tres` en `materials/`: Iron, Stone, Straw, Coal, Wood, Copper, Clay.

### 3.2 `Chunk` (`scripts/Chunk.gd`) — `Node3D`
Almacena depósitos de recursos (`ResourceDeposit`: material, amount, quality) en un `Dictionary[Vector2i, Array[ResourceDeposit]]` indexado por celda. API: `add_resource_at`, `get_resources_at`, `extract_resource`, `remove_resource_at`, `get_hardest_material_at`, `get_total_weight_at`, `serialize()/deserialize()`.

**Contrato de diseño no cumplido actualmente**: `Chunk` está pensado para representar *un fragmento* del mundo (streaming por chunks), pero `DemoMain` instancia un único `Chunk` cuyo `chunk_size` es igual a `terrain_size` completo. No hay chunking real ni carga/descarga por proximidad. Cualquier trabajo de "mundo grande" requiere resolver esto primero (ver ROADMAP FASE 6).

### 3.3 `TerrainGenerator` (`scripts/TerrainGenerator.gd`) — `Node3D`, `@tool`
Genera 3 mapas `PackedFloat32Array` (altura, humedad, geología) vía `FastNoiseLite`, construye un único mesh (`SurfaceTool`) + colisión trimesh, y expone consultas de mundo: `get_height_at`, `get_humidity_at`, `get_geology_at`, `get_slope_at`, `populate_chunk_resources(chunk, materials_map, threshold)`, `get_vegetation_positions(...)`.
Regla de recursos: geología > `threshold` → hierro; geología < `1 - threshold` → carbón; pendiente > 0.5 → piedra.

Limitación conocida: todo el terreno es **un solo mesh monolítico** sin LOD ni subdivisión — válido para el tamaño de demo (128×128) pero no escala a mundos grandes.

### 3.4 `Architecto` (`scripts/Architecto.gd`) — `Node`
Valida colocación de edificios: `hardness_suelo / (peso / weight_factor) >= safety_factor`, y pendiente máxima 0.7. Gestiona colapso en cascada (`_check_cascade_collapse`) cuando se retira un soporte, con animación vía `Tween`.

Simplificaciones explícitas (aceptadas para el MVP, documentadas como riesgo):
- El registro de edificios usa `Dictionary[Vector3, BuildingData]` con la posición exacta como clave — sensible a error de punto flotante y no soporta dos edificios que difieran solo en Y.
- La detección de "soporte" es un chequeo de distancia (`< 2.0` y `pos.y > removed.y`), no un grafo de dependencias estructurales real.
- Los edificios colocados (`MeshInstance3D` puro, ver `DemoMain._place_building_at`) **no tienen `CollisionShape3D`**, por lo que el raycast de colocación no los detecta: se pueden solapar edificios sin aviso.

### 3.5 `TimeManager` (`scripts/TimeManager.gd`) — `Node`, autoload
Ticks configurables (`ticks_per_second`, `ticks_per_day`, `days_per_season`, `seasons_per_year`), `time_speed` como multiplicador, pausa. Expone `get_time_state()/set_time_state()` pensado para guardado, pero **nada llama a estos métodos todavía** (no hay sistema de guardado).

### 3.6 `WorldEnvironmentSetup` (`scripts/WorldEnvironmentSetup.gd`) — `Node3D`
Configura `Environment` (SDFGI, SSAO, SSIL, niebla volumétrica, tone mapping ACES, glow) y un `DirectionalLight3D`. Se suscribe a `TimeManager.tick_advance`/`season_changed` para mover el sol y variar niebla/cielo según hora y estación.

### 3.7 `MultiMeshVegetation` (`scripts/MultiMeshVegetation.gd`) — `MultiMeshInstance3D`
Puebla vegetación consultando `TerrainGenerator.get_vegetation_positions()` (humedad/pendiente/altura), con soporte de LOD vía `visibility_range_begin/end`. Límite configurable de instancias (`max_instances`).

### 3.8 `ResourceVisualizer` (`scripts/ResourceVisualizer.gd`) — `Node3D`
Genera un `MultiMeshInstance3D` por tipo de material presente en el `Chunk` (mesh de "roca" para stone/clay, mesh de "cristal" para el resto), coloreado según `_material_colors`. Se conecta a las señales del `Chunk` pero **el refresco automático está deshabilitado a propósito** (`_on_resource_added/_removed` son no-ops) — hay que llamar `refresh_all()` manualmente.

### 3.9 `TerrainMaterialManager` / `ProceduralTextureGenerator` (`scripts/*.gd`) — `RefCounted`, `@tool`
`ProceduralTextureGenerator` genera 4 texturas de albedo (grass/rock/snow/sand) + 4 normal maps a 512×512 **pixel a pixel en GDScript** (`Image.set_pixel` en bucle anidado, ~2M iteraciones totales) cada vez que se crea el material del terreno. `TerrainMaterialManager` las aplica al shader `shaders/triplanar.gdshader` (blend por altura + pendiente, triplanar mapping).

Impacto: genera un hitch perceptible en el arranque y se repite en cada `TerrainGenerator.generate()` (incluyendo regeneraciones en editor con `auto_generate`). Ver ROADMAP FASE 5.1.

### 3.10 `CameraController` (`scripts/CameraController.gd`) — `Camera3D`
Cámara orbital: WASD/acciones de movimiento, rotación con click derecho + arrastre, zoom con scroll/Q/E. **Duplica el chequeo de movimiento**: lee tanto teclas físicas (`Input.is_key_pressed(KEY_W)`) como acciones del InputMap (`move_forward`, etc.) para el mismo eje, lo cual anula el remapeo de teclas configurado en `project.godot` (ver ROADMAP).

### 3.11 Módulos declarados pero **vacíos** ⚠️
- `scripts/BlockData.gd` — **0 líneas**. `buildings/StoneWall.tres`, `WoodenFloor.tres`, `StrawRoof.tres` declaran `script_class="BlockData"` y propiedades (`block_name`, `weight`, `primary_material`, `support_factor`, `is_structural`, …) que **no existen en ningún script**. Godot no podrá resolver estas propiedades como una clase tipada; se cargan como `Resource` genérico y las propiedades específicas del `.tres` se pierden o generan advertencias.
- `scripts/Inventory.gd` — **0 líneas**. Referenciado como "completado" en el ROADMAP anterior; no es así.
- `scripts/GameUtils.gd` — **0 líneas**.

Esto es la prioridad #1 de la deuda técnica (ver ROADMAP, Fase 3.5).

---

## 4. Convenciones

- GDScript tipado estáticamente donde sea posible (`var x: Type := value`); el código existente ya sigue este patrón de forma consistente — mantenerlo.
- Comentarios de documentación con `##` sobre `@export` y funciones públicas (patrón ya establecido en `Chunk.gd`, `RawMaterial.gd`).
- Español para nombres de dominio del juego que ya están en español en el código existente (`Architecto`, señales como `cambio_de_estacion`) — **inconsistencia existente**: `TimeManager` emite tanto `cambio_de_estacion` como `season_changed` con el mismo propósito (ver deuda técnica). Nuevo código debe usar inglés para nombres de sistema (ya es el patrón dominante) y evitar duplicar señales.
- Escenas de recursos físicos (`RawMaterial`, `BlockData`) se guardan como `.tres` en `materials/` y `buildings/` respectivamente.
- Capas de física ya nombradas en `project.godot`: `terrain` (1), `buildings` (2), `resources` (3), `player` (4) — usarlas consistentemente; actualmente nada asigna capas explícitas a los `CollisionShape3D` creados por código.

---

## 5. Requisitos no funcionales

- **Rendimiento objetivo**: 60 FPS en hardware de gama media con un terreno de 128×128 y ≤3000 instancias de vegetación (configuración actual del demo). No hay medición ni profiling automatizado todavía.
- **Escalado de mundo**: fuera de alcance del MVP actual (un único `Chunk`/mesh cubre todo el mundo). Cualquier expansión a mundos más grandes requiere chunking real primero.
- **Plataforma**: Windows/desktop vía editor Godot 4.5.1; sin build de exportación configurada (`export_presets.cfg` no existe).
- **Persistencia**: no implementada. `Chunk.serialize/deserialize` y `TimeManager.get_time_state/set_time_state` son las únicas piezas preparadas para ello.
- **Tests**: no hay suite de pruebas (GUT u otro) — mencionado como pendiente en el ROADMAP desde la Fase 3.

---

## 6. Fuera de alcance (por ahora)

- Multijugador.
- IA de NPCs/trabajadores.
- Guardado/carga persistente en disco.
- Exportación a build distribuible.
- Editor de niveles/herramientas custom más allá de los gizmos de `@tool`.
