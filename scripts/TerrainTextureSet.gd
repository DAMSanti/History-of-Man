@tool
class_name TerrainTextureSet
extends Resource
## Conjunto de texturas de terreno ya generadas, para poder cachearlas en disco.
## Generarlas cuesta ~4 s porque se pintan pixel a pixel desde GDScript, y ese
## coste se pagaba entero en cada llamada a TerrainGenerator.generate().

## Diccionario nombre -> ImageTexture
@export var textures: Dictionary = {}

## Version del generador. Si se cambia el algoritmo hay que subirla para
## invalidar las caches viejas en disco.
@export var version: int = 1
