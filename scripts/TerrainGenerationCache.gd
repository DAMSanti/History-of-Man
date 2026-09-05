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
const CACHE_VERSION := 1
@export var version: int = CACHE_VERSION

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
