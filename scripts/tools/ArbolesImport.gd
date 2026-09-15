extends SceneTree
## Trae a Godot los árboles que genera EZ-Tree: un [ArbolModelo] por variante.
##
## GRAFICOS §7.1. Lee `scripts/tools/arboles/salida/*.json` —lo deja
## `generar.mjs`—, escala cada árbol a su altura en metros, le pone la corteza y la
## hoja de `models/arboles/texturas/` (CC0, ambientCG; ver `texturas.py`) y guarda
## `models/arboles/<especie>_<variante>.res`.
##
##   godot --headless --path . --import
##   godot --headless --path . --script res://scripts/tools/ArbolesImport.gd

const FUENTE := "res://scripts/tools/arboles/salida"
const TEXTURAS := "res://models/arboles/texturas"
const NIVELES := 3


func _init() -> void:
	var ficheros: Array[String] = []
	for nombre: String in DirAccess.get_files_at(FUENTE):
		if nombre.ends_with("_lod0.json"):
			ficheros.append(nombre.trim_suffix("_lod0.json"))
	ficheros.sort()
	var materiales := {}
	for base: String in ficheros:
		var modelo := ArbolModelo.new()
		for n in range(NIVELES):
			var datos: Dictionary = JSON.parse_string(
				FileAccess.get_file_as_string("%s/%s_lod%d.json" % [FUENTE, base, n]))
			modelo.especie = String(datos["especie"])
			modelo.variante = int(datos["variante"])
			# LA ALTURA DEL NIVEL 0 MANDA en los tres: si cada nivel se escalara a su
			# propia caja, el relevo entre niveles haría crecer o menguar el árbol.
			if n == 0:
				modelo.alto_m = float(datos["alto_m"])
				modelo.set_meta("escala", modelo.alto_m / float(datos["alto_generado"]))
			var escala := float(modelo.get_meta("escala"))
			if not materiales.has(modelo.especie):
				materiales[modelo.especie] = [_corteza(modelo.especie), _hoja(modelo.especie)]
			var malla := ArrayMesh.new()
			_superficie(malla, datos["ramas"], escala, materiales[modelo.especie][0])
			_superficie(malla, datos["hojas"], escala, materiales[modelo.especie][1])
			modelo.niveles.append(malla)
		modelo.remove_meta("escala")
		var ruta := ArbolModelo.ruta(modelo.especie, modelo.variante)
		var error := ResourceSaver.save(modelo, ruta, ResourceSaver.FLAG_COMPRESS)
		print("%-26s %6d / %5d / %5d triángulos · %.1f m · %s" % [ruta.get_file(),
			modelo.triangulos(0), modelo.triangulos(1), modelo.triangulos(2), modelo.alto_m,
			"ok" if error == OK else "ERROR %d" % error])
	quit()


func _superficie(malla: ArrayMesh, datos: Dictionary, escala: float, material: Material) -> void:
	var plana: Array = datos["posicion"]
	var normales_planas: Array = datos["normal"]
	var uv_planas: Array = datos["uv"]
	@warning_ignore("integer_division")
	var cuantos := plana.size() / 3
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(cuantos)
	normales.resize(cuantos)
	uvs.resize(cuantos)
	for i in range(cuantos):
		vertices[i] = Vector3(plana[i * 3], plana[i * 3 + 1], plana[i * 3 + 2]) * escala
		normales[i] = Vector3(normales_planas[i * 3], normales_planas[i * 3 + 1],
			normales_planas[i * 3 + 2])
		# Three pone el origen de la UV abajo; Godot, arriba.
		uvs[i] = Vector2(uv_planas[i * 2], 1.0 - float(uv_planas[i * 2 + 1]))
	var indices := PackedInt32Array()
	for x: Variant in datos["indice"]:
		indices.append(int(x))
	# Three considera delantera la cara en sentido antihorario y Godot la horaria:
	# se da la vuelta a cada triángulo. Sin esto las ramas se ven por dentro (el
	# mismo fallo que dejó negra la pared de la cueva, GRAFICOS §7.2).
	for t in range(0, indices.size() - 2, 3):
		var tmp := indices[t + 1]
		indices[t + 1] = indices[t + 2]
		indices[t + 2] = tmp
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malla.surface_set_material(malla.get_surface_count() - 1, material)


func _corteza(especie: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("%s/%s_corteza_color.jpg" % [TEXTURAS, especie])
	m.normal_enabled = true
	m.normal_texture = load("%s/%s_corteza_normal.jpg" % [TEXTURAS, especie])
	m.roughness_texture = load("%s/%s_corteza_rugosidad.jpg" % [TEXTURAS, especie])
	m.roughness = 1.0
	# SIN MAPA DE NORMALES si la malla no trae tangentes. EZ-Tree no las da y el
	# importador tampoco las calcula: se generan con el `SurfaceTool` más adelante si
	# la corteza sale negra, igual que pasó con la roca de las cuevas.
	m.normal_enabled = false
	return m


func _hoja(especie: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("%s/%s_hoja.png" % [TEXTURAS, especie])
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	# A dos caras: la tarjeta de hoja se ve desde los dos lados.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	# Un poco de luz a través: una copa a contraluz no es una mancha negra.
	m.backlight_enabled = true
	m.backlight = Color(0.22, 0.26, 0.12)
	return m
