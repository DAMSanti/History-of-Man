# CityBuilder - Godot 4.5.1 Project Roadmap & Starter Implementation

Breve: este repositorio contiene una implementación inicial siguiendo tu FASE 1-4, con scripts base y escenas de ejemplo. Usa Godot 4.5.1.

-**Setup rápido**
- Abrir el proyecto en Godot 4.5.1.
- El archivo `project.godot` incluye `TimeManager` como Autoload por defecto; si abres el proyecto manualmente, verifica en Project Settings > Autoload que `TimeManager.gd` esté registrado con el nombre `TimeManager`.
- Agregar `scenes/WorldEnvironment.tscn` a la escena principal para activar SDFGI y Volumetric Fog.

**Fase 1 — Arquitectura de Datos**
- `scripts/RawMaterial.gd`:
  - Recurso (Resource) con `@export` para `density`, `melting_point`, `hardness`, `conductivity` y `display_name`.
  - Crea recursos en el inspector (New Resource > RawMaterial) y guárdalos como `.tres` (ej: `materials/iron.tres`).
- `scripts/Chunk.gd`:
  - Nodo `Chunk` que representa un fragmento de mapa y guarda recursos físicos en celdas (posicionadas por `cell_size`).
  - Funciones: `add_resource_at(world_pos, material, amount)`, `get_resources_at(world_pos)`, `remove_resource_at(world_pos, index)`.

**Fase 2 — Mundo Procedural**
- `scripts/TerrainGenerator.gd`:
  - Usa `FastNoiseLite` para 3 capas: altura/height, humedad/humidity y geología/geology.
  - Geología es invisible por defecto: no lo pintes directamente; úsalo para spawn de recursos (menas).
- `scenes/MultiMeshTrees.tscn` + `scripts/multimesh_trees.gd`:
  - Ejemplo de `MultiMeshInstance3D` para colocar miles de instancias (árboles) sobre el terreno según humedad y pendiente.
  - No uses nodos individuales para cada árbol.

**Fase 3 — Construcción y Física**
- `scripts/Architecto.gd`:
  - Comprueba el material debajo (obtenido desde el `Chunk`) antes de colocar una construcción.
  - Lógica simplificada: `if material.hardness < (building_weight / 100) -> no place`.
  - Funciones: `can_place_at_world(world_pos, building_weight)`, `place_building(world_pos, weight, building_scene)`.
- `scripts/TimeManager.gd` (Singleton):
  - Gestiona ticks, días y años.
  - Señales: `cambio_de_estacion(new_season)` y `tick_advance(...)` para que otros nodos escuchen y reaccionen.

**Fase 4 — Gráficos y Shaders**
- `scenes/WorldEnvironment.tscn` + `scripts/WorldEnvironmentSetup.gd`:
  - Activa `SDFGI`, `Volumetric Fog`, y `Tone Mapping = ACES` al iniciar la escena.
- `shaders/triplanar.gdshader`:
  - Shader de terreno tri-planar para evitar estiramiento de textura en pendientes.

**Roadmap detallado (por fases)**

FASE 1 (2-4 días)
- Crear `RawMaterial` y solo un par de `res://materials/` (ej: `materials/Iron.tres`, `materials/Stone.tres`, `materials/Straw.tres`).
+
+Ejemplo: Popular un `Chunk` con vetas de hierro usando `TerrainGenerator`: 
+```gdscript
+var terrain = $Terrain as TerrainGenerator
+terrain.generate()
+var chunk = $Chunk as Chunk
+var iron = load("res://materials/Iron.tres") as RawMaterial
+terrain.populate_chunk_resources(chunk, {"iron": iron}, 0.7)
+```
+Esto coloca depósitos de hierro en ubicaciones donde la capa de geología supera el umbral.

- Implementar `Chunk` y testear con una pequeña cuadrícula 8x8, colocando recursos a mano en `chunks`.

FASE 2 (3-6 días)
- Implementar `TerrainGenerator` con parámetros visibles en Inspector y un sistema de preview para debug (visualizar height_map con planes o gizmos).
- Crear sistema de distribución simple: si `geology(x,y) > 0.66` entonces vetas de hierro; < 0.33 carbón; mezclar con ruido.
- Poblar vegetación con `MultiMeshInstance3D` (ese ejemplo ya proveído), y añadir LOD simple y `Frustum Culling`.

FASE 3 (4-8 días)
- `Architecto` para comprobar solidez de colocación (hardness vs weight). Añadir tests unitarios o GUT (opcional).
- Añadir GridMap con `mesh_library`, y una función que calcula 'peso' de la estructura (sumar pesos por bloque). Si `material_abajo.dureza < peso_structure` entonces COLAPSO.
- Crear el sistema de físicas estructurales simples: colapso en cascada si se retira soporte.

FASE 4 (5-10 días)
- Ajustar `WorldEnvironment` con presets SDFGI, Fog y ACES.
- Implementar shader tri-planar y crear materiales de terreno (roca, grass, snow) con blending por altura y pendiente (slope).
- Performance tuning: prueba en escenarios grandes, y transforma varios árboles/rocas con `MultiMesh`.

Extensiones (Siguientes fases, opcional)
- Sistema de recogida/colección física (entidades re-colectan recursos en chunks), almacenamiento físico con sacos, montones, etc.
- Sistema de IA, NPCs y automatas que trabajan según estaciones.

**Comandos útiles (Windows)**
Abrir Godot con el proyecto (con Godot 4.5.1 instalado):
```
godot --path "g:/Proyectos/CityBuilder"
```
Recargar recursos (.tres) desde el Inspector para probar materiales creados.

**Notas y recomendaciones**
- Evita instanciar nodos por cada planta/árbol: usa `MultiMeshInstance3D`.
- Guarda datos de materiales y chunk a disco si necesitas persistencia.
- Prueba performance con herramientas de Godot (profiler) conforme vayas puliendo el mundo.

Si quieres, puedo:
- integrar un ejemplo de GridMap y un `building.tscn` demo
- añadir sistema simple de minas (veins) basado en `geology`
- preparar tests automatizados y ejemplos de uso para los scripts creados

Dime cuál de los siguientes pasos quieres que implemente ahora: (a) Integrar Quick demo (escena principal) con todas las piezas, (b) añadir GridMap building demo, (c) mejorar la generación y mostrar vetas en escena.
