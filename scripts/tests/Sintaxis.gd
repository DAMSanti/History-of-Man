extends SceneTree
## Carga los scripts del juego y dice cuáles no compilan.
##
## Un fallo de sintaxis en `SettlementSim` cuelga la tanda de pruebas entera sin
## decir dónde; esto lo señala en dos segundos.

func _init() -> void:
	var bad := 0
	for path: String in _walk("res://scripts"):
		var script: Resource = load(path)
		if script == null:
			print("NO COMPILA: %s" % path)
			bad += 1
	print("revisados, %d rotos" % bad)
	quit(1 if bad > 0 else 0)


func _walk(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_walk(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
