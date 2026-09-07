extends SceneTree
## Hornea la animación de la banda a textura de vértice, sin editor y sin GPU.
##
## `AnimatedMultiMeshInstance3D` (el addon en `addons/animated_multimeshinstance3d`)
## sabe hornear, pero de dos maneras que aquí no sirven:
##
##   - su botón de hornear sólo corre dentro del editor (`_editor_process`
##     mira `Engine.is_editor_hint()`), y un `--script` headless no lo es;
##   - y aunque se llame a mano a `bake_mesh_from_current_skeleton_pose()`,
##     esa función exige el esqueleto REGISTRADO en el servidor de render
##     -«the source mesh must have its skin registered with a valid
##     skeleton»-, y este entorno headless corre sobre el driver `dummy`
##     -sin GPU real-, que nunca completa ese registro.
##
## La salida es hacer el *skinning* a mano: leer la malla en reposo UNA vez
## -vértice, normal, huesos y pesos de `surface_get_arrays`-, y por cada
## fotograma pedirle a `Skeleton3D.get_bone_global_pose()` la pose que puso el
## `AnimationPlayer` -eso SÍ es CPU pura, no toca el servidor de render- y
## combinarla a mano con los pesos. Es el mismo álgebra que hace la GPU al
## dibujar, sólo que aquí se hace una vez, en frío, y se guarda a textura.
##
## Por qué hace falta esto y no perseguir cada persona con un Skeleton3D:
## la banda puede llegar a miles de miembros, y eso no lo aguanta ni un
## AnimationTree por persona ni el hueso-por-hueso de la CPU en cada
## fotograma de la partida. Con la textura de vértice el coste entero pasa a
## la GPU en tiempo de juego, y por eso el mismo sistema que sirve para
## treinta sirve para treinta mil -ver `arbol_impostor.gdshader` para el
## mismo truco aplicado a árboles-.
##
## Correr con:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path . \
##     --script res://scripts/tools/BandaAtlas.gd

const SOURCE_FBX := "res://models/people/source/Animated Human.fbx"
const OUT_DIR := "res://models/people"
const SHADER_PATH := "res://addons/animated_multimeshinstance3d/shaders/vetex_animation_shader.gdshader"

## A cuántos fotogramas por segundo se muestrea cada clip. Los siete clips que
## se usan (fuera los dos `ArmatureAction_00X`, que son basura de exportación
## sin nombre de estado) caben de sobra en el límite de 8192 fotogramas del
## addon incluso a esta resolución.
const SAMPLING_FPS := 12.0

## Cuántas influencias de hueso trae cada vértice. Lo dice la propia malla
## -`arrays[Mesh.ARRAY_BONES].size() / vertex_count`-, no una constante de
## Godot: esta viene exportada a 8, no a las 4 de toda la vida.
const BONES_PER_VERTEX := 8

## Nombre corto -> pista real del FBX. El nombre corto es el que usa el
## juego; la pista real trae el prefijo `Human Armature|` de Blender.
const CLIPS := {
	"idle": "Human Armature|Idle",
	"walk": "Human Armature|Walk",
	"run": "Human Armature|Run",
	"jump": "Human Armature|Jump",
	"punch": "Human Armature|Punch",
	"work": "Human Armature|Working",
	"death": "Human Armature|Death",
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var packed: PackedScene = load(SOURCE_FBX)
	if packed == null:
		print("no se pudo cargar %s" % SOURCE_FBX); quit(); return

	var scene := packed.instantiate()
	root.add_child(scene)
	# El registro de huesos en el nodo tarda unos fotogramas en asentarse.
	for i in range(5):
		await process_frame

	var player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var armature := scene.get_node_or_null("Human Armature") as Node3D
	var skeleton := scene.get_node_or_null("Human Armature/Skeleton3D") as Skeleton3D
	var mesh_instance := scene.get_node_or_null(
		"Human Armature/Skeleton3D/Human_Mesh") as MeshInstance3D
	if player == null or mesh_instance == null or skeleton == null or armature == null:
		print("faltan AnimationPlayer, Skeleton3D, MeshInstance3D o Armature en el FBX")
		quit(); return

	# `Skeleton3D.get_bone_global_pose()` da la pose relativa AL PROPIO NODO
	# Skeleton3D, sin la escala que trae «Human Armature» -x69, herencia de
	# exportar el rig en centímetros desde Blender-. Sin multiplicarla aquí,
	# la malla horneada sale sesenta y nueve veces más pequeña que en la
	# escena normal.
	var armature_transform := armature.transform

	var skin := mesh_instance.skin
	if skin == null:
		print("la malla no trae Skin"); quit(); return

	var mesh := mesh_instance.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var rest_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rest_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bone_idx: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vertex_count := rest_verts.size()
	print("malla: %d vertices, %d bind poses, %d huesos" % [
		vertex_count, skin.get_bind_count(), skeleton.get_bone_count()])

	if bone_idx.size() != vertex_count * BONES_PER_VERTEX:
		print("BONES_PER_VERTEX no cuadra: %d huesos para %d vertices (esperaba %d)" % [
			bone_idx.size(), vertex_count, vertex_count * BONES_PER_VERTEX])
		quit(); return

	# El hueso al que apunta cada `bind pose` del Skin, precalculado una vez:
	# `ARRAY_BONES` indexa posiciones de bind del Skin, no huesos del
	# Skeleton3D directamente. Este FBX ata los binds POR NOMBRE
	# (`get_bind_bone` da -1 para todos): hay que resolver el nombre contra
	# el esqueleto.
	var bind_bone := PackedInt32Array()
	bind_bone.resize(skin.get_bind_count())
	for b in range(skin.get_bind_count()):
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(b))
		if bone < 0:
			print("  bind %d sin hueso resoluble (nombre '%s')" % [b, skin.get_bind_name(b)])
			quit(); return
		bind_bone[b] = bone

	# Un fotograma de margen entre clips: sin él, el último vértice de un
	# clip y el primero del siguiente comparten columna de textura por el
	# redondeo de `ceil`, y la mezcla de dos poses distintas sale como un
	# tirón de goma de un clip a otro.
	var frame_counts: Dictionary = {}
	var total_frames := 0
	for key: String in CLIPS:
		var anim := player.get_animation(CLIPS[key])
		if anim == null:
			print("  falta el clip %s (%s)" % [key, CLIPS[key]]); quit(); return
		var count := maxi(ceili(anim.length * SAMPLING_FPS), 1)
		frame_counts[key] = count
		total_frames += count
	print("fotogramas totales: %d" % total_frames)

	var vertex_image := Image.create_empty(total_frames, vertex_count, false, Image.FORMAT_RGBF)
	var normal_image := Image.create_empty(total_frames, vertex_count, false, Image.FORMAT_RGBF)

	var animation_list: Dictionary = {}
	var cursor := 0
	var skin_matrix: Array[Transform3D] = []
	skin_matrix.resize(skin.get_bind_count())

	for key: String in CLIPS:
		var track_name: String = CLIPS[key]
		var count: int = frame_counts[key]
		animation_list[key] = {"start_frame": cursor, "length": count}
		player.play(track_name)
		for frame_index in range(count):
			player.seek(float(frame_index) / SAMPLING_FPS, true)

			for b in range(skin.get_bind_count()):
				skin_matrix[b] = armature_transform \
					* skeleton.get_bone_global_pose(bind_bone[b]) \
					* skin.get_bind_pose(b)

			var column := cursor + frame_index
			for v in range(vertex_count):
				var base := v * BONES_PER_VERTEX
				var posed_vertex := Vector3.ZERO
				var posed_normal := Vector3.ZERO
				for k in range(BONES_PER_VERTEX):
					var w: float = weights[base + k]
					if w <= 0.0:
						continue
					var m := skin_matrix[bone_idx[base + k]]
					posed_vertex += (m * rest_verts[v]) * w
					posed_normal += (m.basis * rest_normals[v]) * w
				vertex_image.set_pixel(column, v,
					Color(posed_vertex.x, posed_vertex.y, posed_vertex.z))
				var n := posed_normal.normalized()
				normal_image.set_pixel(column, v, Color(n.x, n.y, n.z))
		print("  %-6s %3d fotogramas desde el %d" % [key, count, cursor])
		cursor += count
	player.stop()

	# `.res` -binario- y no `.tres`: son 287 x 4734 floats RGB, y el texto de
	# un `.tres` los guarda en base64, casi cinco veces más pesado que la
	# imagen cruda. El resto de bakeados grandes del proyecto -`arbol_atlas`,
	# `hierba_atlas`- ya usan `.res` por lo mismo.
	var vertex_texture := ImageTexture.create_from_image(vertex_image)
	var normal_texture := ImageTexture.create_from_image(normal_image)
	_save(vertex_texture, OUT_DIR + "/banda_vertex.res")
	_save(normal_texture, OUT_DIR + "/banda_normal.res")

	# Recargados desde el fichero que se acaba de escribir: el objeto recién
	# creado en memoria no lleva `resource_path`, y sin él cada material que
	# lo referencie lo INCRUSTA entero en vez de apuntar al fichero -salieron
	# materiales de 147 MB, uno por variante de piel, con la misma textura
	# duplicada dentro de cada uno-.
	vertex_texture = load(OUT_DIR + "/banda_vertex.res")
	normal_texture = load(OUT_DIR + "/banda_normal.res")

	# Un material por variante de piel/ropa: la textura es lo único que
	# cambia -son paletas de 32x32, no fotografías- así que reaprovechan la
	# misma textura de vértice y normal horneada arriba.
	var shader: Shader = load(SHADER_PATH)
	for skin_name in ["ClothedLightSkin", "ClothedDarkSkin", "NakedLightSkin", "NakedDarkSkin"]:
		var albedo: Texture2D = load(
			"res://models/people/source/textures/%s.png" % skin_name)
		if albedo == null:
			print("  falta la textura %s; se salta" % skin_name)
			continue
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("albedo", albedo)
		material.set_shader_parameter("vertex_animation", vertex_texture)
		material.set_shader_parameter("normal_animation", normal_texture)
		material.set_shader_parameter("total_frame_count", float(total_frames))
		material.set_shader_parameter("total_vertex_count", float(vertex_count))
		material.set_shader_parameter("sampling_fps", SAMPLING_FPS)
		_save(material, OUT_DIR + "/banda_material_%s.tres" % skin_name)

	# La malla en reposo -sin horneado- es la que necesita el MultiMesh: el
	# shader mueve cada vértice según la textura, pero el número de vértices,
	# los UV y los índices salen de aquí.
	_save(mesh, OUT_DIR + "/banda_mesh.res")

	print("")
	print("animation_list (para pegar en el script en tiempo de juego):")
	for key: String in animation_list:
		var entry: Dictionary = animation_list[key]
		print('\t"%s": [%d, %d],' % [key, entry["start_frame"], entry["length"]])

	quit()


func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		print("  FALLO guardando %s (%s)" % [path, error_string(err)])
	else:
		print("  guardado %s" % path)
