extends SceneTree
## Qué animaciones trae de verdad cada malla de fauna.
##
## La nota de `FaunaAtlas` da por hecho que el pack de granja "sólo horneó
## reposo y salto" para cerdo y oveja, y de ahí sale que jabalí, corzo y rebeco
## no muevan las patas al andar. Antes de buscar mallas nuevas conviene
## comprobar si el ciclo de marcha estaba ahí y no se cableó.

const SOURCES := [
	"res://models/animals/source/Dog.fbx",
	"res://models/animals/source/Cat.fbx",
	"res://models/animals/source/Deer.fbx",
	"res://models/animals/source/Stag.fbx",
	"res://models/animals/source/Bull.fbx",
]


func _init() -> void:
	for path: String in SOURCES:
		var packed: PackedScene = load(path)
		if packed == null:
			print("%-16s no se pudo abrir" % path.get_file())
			continue
		var root := packed.instantiate()
		var player := _find_player(root)
		if player == null:
			print("%-16s sin AnimationPlayer" % path.get_file())
			root.free()
			continue
		var names: Array[String] = []
		for library: StringName in player.get_animation_library_list():
			var lib := player.get_animation_library(library)
			for clip: StringName in lib.get_animation_list():
				names.append("%s (%.2f s)" % [clip, lib.get_animation(clip).length])
		print("%-16s %s" % [path.get_file(), ", ".join(names)])
		if not OS.get_environment("ARBOL").is_empty():
			_tree(root, "  ")
		root.free()
	quit()


## El árbol de nodos, para saber qué rutas darle a `FaunaAtlas`.
func _tree(node: Node, indent: String) -> void:
	print("%s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_tree(child, indent + "  ")


func _find_player(node: Node) -> AnimationPlayer:
	var player := node as AnimationPlayer
	if player != null:
		return player
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null
