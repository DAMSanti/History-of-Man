@tool
class_name TerrainSurroundCache
extends Resource
## Resultado cacheado de TerrainSurround.build(): las ocho mallas de las
## casillas de alrededor.
##
## Medido en un recuadro de prueba: construirlas cuesta ~28 s, casi todo en
## muestrear el MDT del contorno vertice a vertice y en generate_lods() por
## casilla -ocho veces la misma operacion cara que paga TerrainGenerator una
## vez. El contorno de un sitio no cambia entre partidas, asi que se calcula
## una vez y se guarda aqui. Ver [TerrainSurround], [TerrainGenerationCache].

const CACHE_VERSION := 1
@export var version: int = CACHE_VERSION

## Version del heightmap de contorno (region.pipeline_version) con el que se
## construyo. Si se rehace el contorno, esto cambia y la cache deja de servir.
@export var region_pipeline_version: int = 0

## Parametros con los que se construyo esta cache.
@export var resolution: int = 0
@export var terrain_size: Vector2i = Vector2i.ZERO
@export var meters_per_unit: float = 1.0
@export var vertical_exaggeration: float = 1.0
@export var sea_level: float = 0.0

## Las ocho mallas, en el mismo orden en que build() las genera: dz de -1 a 1,
## dx de -1 a 1, saltando (0,0).
@export var tile_meshes: Array[ArrayMesh] = []

## Cota mas alta de todo el contorno. La necesita `extend_height_ceiling` para
## normalizar el shader, y sin las mallas no se puede recalcular barato.
@export var highest: float = -1e9
