@tool
class_name TerrainGenerationCache
extends Resource
## Resultado cacheado de un TerrainGenerator.generate() sobre un heightmap real.
##
## Medido: para un recuadro local, generar los mapas derivados (muestrear el
## MDT vertice a vertice) cuesta ~10 s y construir la malla con sus niveles de
## detalle otros ~14 s. Para la capa regional son ~16 s y ~28 s. Ninguno de los
## dos cambia entre partidas si el sitio es el mismo: el terreno no cambia, asi
## que se generan una vez y se guardan aqui.
##
## La cache la escribe y la lee TerrainGenerator; ver `_cache_base_path`,
## `_load_generation_cache` y `_save_generation_cache`.

## Version del algoritmo de generacion. Subirla invalida las caches en disco.
##
## v2: se anade `detail_hash`. Hasta v1 los parametros del relieve inventado no
## entraban en la comprobacion, asi que cambiarlos cargaba la malla vieja sin
## avisar. Las caches de v1 no dicen con que detalle se hicieron, y por eso no
## sirven.
##
## v3 (2026-09-13): se anade `carvings_colocadas`. Las bocas de cueva se mueven
## al generar si caen en el agua o donde no se llega —ver [Bocas]—, y una cache
## que no guarda donde quedaron no sabe donde excavo. Las reglas de [Bocas] no
## piden subirla: entran en `carvings_hash` con [Bocas.REGLAS].
## v4 (2026-09-13): la boca de una cueva hunde el relieve cincuenta metros, como
## una sima. Una cache de v3 tiene el terreno sin hundir.
## v5 (2026-09-15): el UV del terreno lleva dónde rompe el agua —el rápido y la orilla,
## ver [AguaDelCauce]— y no coordenadas de mundo. Una de v4 no tiene espuma.
## v6 (2026-09-15): el UV.x lleva la caída en bruto y no el rápido ya umbralizado; los
## umbrales pasan al shader.
## v7 (2026-09-15): la orilla se hornea por dentro de la línea del agua
## (`AguaDelCauce.LINEA_DEL_AGUA`), no en la ribera mojada.
## v8 (2026-09-15): la caída se hornea suavizada con sus vecinas (`AguaDelCauce.caida_suave`).
## v9 (2026-09-15): y la corriente del color de vértice también (`AguaDelCauce.corriente_suave`).
## v10 (2026-09-16): cada cuadro se parte por su diagonal (`MallaDelTerreno.diagonal_principal`).
const CACHE_VERSION := 10
## **El valor por defecto es 0, no la versión, y no se toca** (2026-09-15): Godot no escribe
## en el fichero una propiedad que vale su valor por defecto. Con `= CACHE_VERSION`, la
## versión se guardaba igual al defecto de entonces —no quedaba escrita— y al leerla con
## la versión subida valía el defecto nuevo: **subir la versión no invalidaba nada**.
## Visto al pasar a v5: una caché de v4 del sitio 56 leía `version` 5 y se usaba.
@export var version: int = 0

## Version del heightmap fuente (HeightmapData.pipeline_version) con el que se
## genero. Si RegionMap rehace el recuadro -mismo fichero, contenido nuevo-
## esto sube y la cache vieja deja de servir sin que nadie tenga que acordarse
## de borrarla.
@export var heightmap_pipeline_version: int = 0

## Parametros de generacion con los que se hizo esta cache. Si alguno no
## coincide con los del TerrainGenerator actual, la cache no sirve.
@export var resolution: int = 0
@export var terrain_size: Vector2i = Vector2i.ZERO
@export var heightmap_region_offset: Vector2 = Vector2.ZERO
@export var meters_per_unit: float = 1.0
@export var vertical_exaggeration: float = 1.0
@export var sea_level: float = 0.0
@export var terrain_chunks: int = 1

## Hash de las entalladuras (bocas de cueva) con las que se genero. Cambia si
## cambian los emplazamientos excavados en la malla para esta epoca.
@export var carvings_hash: int = 0

## Donde se excavaron de verdad, tras [Bocas.colocar]. Ver
## [TerrainGenerator.carvings_colocadas].
@export var carvings_colocadas: Array[Dictionary] = []

## Hash del relieve INVENTADO: amplitud, frecuencia y octavas del detalle, su
## ganancia por pendiente, y el relieve de plataforma. Van juntos porque son
## un solo concepto -cuanto se anade a mano por debajo del dato- y porque
## ninguno de los seis se toca sin querer volver a mirar el terreno.
##
## Antes no estaban en la comprobacion, y esa era la trampa: la amplitud del
## detalle es justo el parametro que uno quiere probar a ojo, y probarlo
## cargaba la malla anterior. Cuatro valores distintos daban cuatro capturas
## identicas.
@export var detail_hash: int = 0

## Mapas derivados, tal como los deja TerrainGenerator._generate_maps(). Hacen
## falta enteros: get_height_at, get_slope_at y el resto de consultas de
## juego -Navgrid incluido- leen de aqui, no de la malla.
@export var height_map: PackedFloat32Array = PackedFloat32Array()
@export var humidity_map: PackedFloat32Array = PackedFloat32Array()
@export var geology_map: PackedFloat32Array = PackedFloat32Array()
@export var relief_map: PackedFloat32Array = PackedFloat32Array()
@export var river_map: PackedFloat32Array = PackedFloat32Array()
@export var flow_map: PackedVector2Array = PackedVector2Array()
@export var ford_map: PackedFloat32Array = PackedFloat32Array()
@export var region_map: PackedFloat32Array = PackedFloat32Array()
@export var height_range: Vector2 = Vector2.ZERO

## Malla final. Solo uno de los dos se rellena, segun terrain_chunks:
## `single_mesh` cuando el terreno es una sola pieza, `chunk_meshes` cuando
## esta troceado (el caso normal: ver TerrainGenerator.terrain_chunks).
@export var single_mesh: ArrayMesh
@export var chunk_meshes: Array[ArrayMesh] = []
