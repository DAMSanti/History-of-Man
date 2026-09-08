class_name TerrainTextureArrays
extends Resource
## Las texturas del terreno, ya empaquetadas y comprimidas a BC7.
##
## Van las tres tandas juntas en un recurso y no sueltas porque siempre se
## cargan a la vez y tienen que estar de acuerdo: mismo número de capas, mismo
## tamaño y el mismo orden que [TerrainLayers.Layer]. Separarlas permitiría
## cargar un albedo de ocho capas con un ORM de seis, que es un fallo silencioso
## y feo.
##
## Lo que se guarda son las IMÁGENES y no los `Texture2DArray` ya montados:
## `ImageTextureLayered` no expone sus imágenes como propiedad, así que
## `ResourceSaver` guardaba el recurso con los tres arrays vacíos y un tamaño de
## 0,0 MB tan tranquilo. Los `Image` sí serializan, y montar el array al cargar
## no cuesta nada porque ya vienen comprimidos y con mipmaps.
##
## Los genera `scripts/tools/TerrainTextureIngest.gd`.

## Color. RGB; el alfa no se usa.
@export var albedo_images: Array[Image] = []

## Normal en convención OpenGL, que es la que espera Godot.
@export var normal_images: Array[Image] = []

## R oclusión · G rugosidad · B metálico · A altura.
##
## La altura viaja en el alfa porque BC7 lo trae sin coste extra, y es la que
## alimenta el parallax. Antes ni se descargaba.
@export var orm_images: Array[Image] = []

## Lado en píxeles de cada capa.
@export var size: int = 0

## Cuántas capas. Se guarda para poder comprobar que coincide con
## [TerrainLayers.COUNT] antes de usarlo.
@export var layers: int = 0

var _albedo: Texture2DArray
var _normal: Texture2DArray
var _orm: Texture2DArray


## Si el recurso describe lo que el juego espera ahora mismo.
func is_usable() -> bool:
	return layers == TerrainLayers.COUNT \
		and albedo_images.size() == layers \
		and normal_images.size() == layers \
		and orm_images.size() == layers


func albedo() -> Texture2DArray:
	if _albedo == null:
		_albedo = _build(albedo_images)
	return _albedo


func normal() -> Texture2DArray:
	if _normal == null:
		_normal = _build(normal_images)
	return _normal


func orm() -> Texture2DArray:
	if _orm == null:
		_orm = _build(orm_images)
	return _orm


func _build(images: Array[Image]) -> Texture2DArray:
	if images.is_empty():
		return null
	var array := Texture2DArray.new()
	if array.create_from_images(images) != OK:
		push_error("TerrainTextureArrays: no se pudo montar el array")
		return null
	return array
