class_name PropLibrary
extends Resource
## Las mallas de los props, ya con niveles de detalle y a escala.
##
## Se guardan juntas por lo mismo que los arrays del terreno: se cargan a la vez
## y tienen que estar de acuerdo. Y se guardan las MALLAS, no las escenas, porque
## lo que consume [ResourceProps] es un `Mesh` para un `MultiMesh`.
##
## Las genera `scripts/tools/PropIngest.gd`.

## Clave del catálogo -> Array de mallas, una por VARIANTE.
##
## Son varias porque Poly Haven empaqueta varios ejemplares en un fichero: tres
## ramas distintas, cuatro matas, tres arbolitos. Cada una es una silueta propia
## y se alterna entre instancias; fusionarlas daba un prop que siempre era «las
## tres ramas a la vez».
@export var meshes: Dictionary = {}

## Clave -> factor por el que hay que multiplicar la instancia para que la pieza
## mida lo que dice `PropModels.CATALOGUE[...]["height_m"]`.
##
## Va aparte y no horneado en los vértices para no reescribir la malla: el
## `MultiMesh` ya lleva una transformación por instancia, así que el factor entra
## ahí y sale gratis.
@export var scales: Dictionary = {}

## Cuántos triángulos tenía cada malla al llegar, para poder ver de un vistazo
## si alguna se ha colado sin LOD.
@export var triangles: Dictionary = {}

## Clave -> autor, licencia, título y URL de las piezas que no son CC0.
##
## Se lee de dentro del propio .glb —Sketchfab lo incrusta en `asset.extras`— y
## no se teclea a mano, así que la atribución no puede quedarse desfasada ni
## salir mal escrita. De aquí sale CREDITOS.md.
@export var credits: Dictionary = {}


func has(key: String) -> bool:
	return meshes.has(key) and not (meshes[key] as Array).is_empty()


## Cuántas siluetas distintas hay de esta pieza.
func variants(key: String) -> int:
	if not has(key):
		return 0
	return (meshes[key] as Array).size()


func mesh(key: String, variant: int = 0) -> Mesh:
	if not has(key):
		return null
	var list: Array = meshes[key]
	return list[clampi(variant, 0, list.size() - 1)] as Mesh


func scale_for(key: String) -> float:
	return float(scales.get(key, 1.0))


## Si la biblioteca cubre todo lo que el catálogo pide ahora mismo.
func is_usable() -> bool:
	for key: String in PropModels.CATALOGUE:
		if not has(key):
			return false
	return true


func describe() -> String:
	var parts: Array[String] = []
	for key: String in PropModels.CATALOGUE:
		if has(key):
			parts.append("%s %d variantes %d tri x%.2f" % [key, variants(key),
				int(triangles.get(key, 0)), scale_for(key)])
	return ", ".join(parts)
