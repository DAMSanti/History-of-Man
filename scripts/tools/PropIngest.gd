extends SceneTree
## Trae los modelos de los props y los deja listos para sembrar.
##
## Descarga de [Poly Haven] —CC0, fotogrametría— los modelos que nombra
## [PropModels], les genera los niveles de detalle y guarda una [PropLibrary].
##
## Por qué generar LOD y no decimar: medido en `scripts/tests/PropCosteProbe.gd`,
## una roca de 14.844 triángulos sembrada 2600 veces cuesta 35 ms en crudo y
## 15,9 ms con LOD, que es 1,1 ms más que una caja de doce triángulos. O sea que
## con LOD la complejidad de la malla deja de importar y no hace falta buscar
## modelos de baja resolución: el arte entra tal como viene.
##
## Las URLs NO se construyen a mano. La primera versión sí, y fallaba: las
## texturas de un modelo no viven junto al glTF sino en `Models/jpg/...`, y el
## `.bin` sale siempre de la carpeta 8k. Se lee el mapa `include` que da la API y
## se descarga lo que diga.
##
## Correr con:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path . \
##     --script res://scripts/tools/PropIngest.gd

const API := "https://api.polyhaven.com/files/%s"
const WORK_DIR := "user://prop_ingest"

## Igual que en la ingesta de texturas: en modo `--script` el módulo TLS del
## motor no se registra y cualquier https muere con «SSL module failed to
## initialize». Lo baja `curl`, que viene de serie.
const CURL_ARGS := ["-sSL", "--fail", "--retry", "2", "--max-time", "300"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_DIR))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://models/props"))

	var library := PropLibrary.new()
	var keys: Array = PropModels.CATALOGUE.keys()

	for index in range(keys.size()):
		var key: String = keys[index]
		var entry: Dictionary = PropModels.CATALOGUE[key]
		var slug: String = entry["slug"]
		print("[%d/%d] %s (%s)" % [index + 1, keys.size(), entry["name"], slug])

		var gltf_path := ""
		if entry.has("local"):
			# Pieza que no se puede descargar por script. Se suelta a mano en
			# `PropModels.LOCAL_DIR` y se declara aquí con su autor y licencia.
			gltf_path = ProjectSettings.globalize_path(
				"%s/%s" % [PropModels.LOCAL_DIR, entry["local"]])
			if not FileAccess.file_exists(gltf_path):
				print("   falta el fichero local %s; se salta" % entry["local"])
				continue
		else:
			gltf_path = _fetch_model(slug)
		if gltf_path.is_empty():
			print("   FALLO al traer el modelo; se salta")
			continue

		var mesh := _load_mesh(gltf_path)
		if mesh == null:
			print("   FALLO al leer la malla; se salta")
			continue

		var raw := _triangles(mesh)
		var with_lods := _make_lods(mesh)
		if with_lods == null:
			# No es un fallo: `generate_lods` no simplifica lo que ya es simple,
			# y hay piezas -el pasto- que llegan con menos de mil triangulos.
			print("   sin niveles: la malla ya es bastante simple")
			with_lods = mesh

		var box := with_lods.get_aabb()
		var factor := 1.0
		if box.size.y > 0.0001:
			factor = float(entry["height_m"]) / box.size.y

		_compress_textures(with_lods)
		library.meshes[key] = with_lods
		library.scales[key] = factor
		library.triangles[key] = raw
		print("   %d triangulos · alto de origen %.2f m · factor x%.3f" % [
			raw, box.size.y, factor])

	if not library.is_usable():
		print("")
		print("NO se guarda: falta alguna pieza del catalogo")
		quit(1)
		return

	var error := ResourceSaver.save(library, PropModels.LIBRARY_PATH)
	if error != OK:
		print("no se pudo guardar la biblioteca (error %d)" % error)
		quit(1)
		return

	var bytes := 0
	var file := FileAccess.open(PropModels.LIBRARY_PATH, FileAccess.READ)
	if file:
		bytes = file.get_length()
		file.close()
	print("")
	print("guardado %s · %.1f MB" % [PropModels.LIBRARY_PATH, bytes / 1048576.0])
	_write_credits()
	quit()


## Escribe los créditos de todo lo que se usa.
##
## No es cortesía: una licencia CC-BY OBLIGA a atribuir, y eso se olvida si se
## deja para el final. Se genera desde el catálogo, así que no puede quedarse
## desfasado respecto a lo que de verdad se está usando. Poly Haven es CC0 y no
## lo exige, pero se cita igual —cuesta nada y es de justicia—.
func _write_credits() -> void:
	var lines: Array[String] = []
	lines.append("# Créditos de los assets")
	lines.append("")
	lines.append("Lo genera `scripts/tools/PropIngest.gd` a partir de los")
	lines.append("catálogos, así que no se queda desfasado respecto a lo que de")
	lines.append("verdad se usa. No se edita a mano.")
	lines.append("")
	lines.append("## Texturas del terreno")
	lines.append("")
	lines.append("[ambientCG](https://ambientcg.com), CC0.")
	lines.append("")
	for i in range(TerrainLayers.COUNT):
		var layer: Dictionary = TerrainLayers.CATALOGUE[i]
		lines.append("- %s — `%s`" % [layer["name"], layer["asset"]])
	lines.append("")
	lines.append("## Modelos del suelo")
	lines.append("")
	var pending: Array[String] = []
	for key: String in PropModels.CATALOGUE:
		var entry: Dictionary = PropModels.CATALOGUE[key]
		if entry.has("local"):
			lines.append("- %s — %s, %s. %s" % [entry["name"],
				entry.get("author", "AUTOR SIN DECLARAR"),
				entry.get("license", "LICENCIA SIN DECLARAR"),
				entry.get("source_url", "")])
			if not entry.has("author") or not entry.has("license"):
				pending.append(entry["name"] as String)
		else:
			lines.append("- %s — [Poly Haven](https://polyhaven.com/a/%s), CC0."
				% [entry["name"], entry["slug"]])
	lines.append("")
	if not pending.is_empty():
		lines.append("> AVISO: sin autor o sin licencia declarados: %s."
			% ", ".join(pending))
		lines.append("> Una pieza con licencia CC-BY sin atribuir es un")
		lines.append("> incumplimiento, no un descuido de formato.")
		lines.append("")
	lines.append("## Lo que falta")
	lines.append("")
	for key: String in PropModels.WANTED:
		var want: Dictionary = PropModels.WANTED[key]
		lines.append("- **%s** — %s" % [want["name"], want["note"]])

	var file := FileAccess.open("res://CREDITOS.md", FileAccess.WRITE)
	if file == null:
		print("no se pudieron escribir los creditos")
		return
	file.store_string("
".join(lines) + "
")
	file.close()
	print("creditos en res://CREDITOS.md")


## Descarga el glTF y todo lo que declare su mapa `include`, y devuelve la ruta
## del glTF ya en disco.
func _fetch_model(slug: String) -> String:
	var dir := "%s/%s" % [WORK_DIR, slug]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var listing := "%s/files.json" % dir
	if not FileAccess.file_exists(listing):
		if not _curl(API % slug, listing):
			return ""

	var text := FileAccess.get_file_as_string(listing)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		print("   la API no devolvio nada legible")
		return ""

	var gltf: Variant = (data as Dictionary).get("gltf")
	if not (gltf is Dictionary) or not (gltf as Dictionary).has(PropModels.RES):
		print("   este modelo no tiene glTF en %s" % PropModels.RES)
		return ""
	var entry: Dictionary = (gltf as Dictionary)[PropModels.RES]["gltf"]

	var gltf_path := "%s/%s" % [dir, (entry["url"] as String).get_file()]
	if not FileAccess.file_exists(gltf_path):
		if not _curl(entry["url"] as String, gltf_path):
			return ""

	# Y todo lo que el propio glTF necesita, cada cosa en su sitio relativo
	var include: Dictionary = entry.get("include", {})
	for relative: String in include:
		var target := "%s/%s" % [dir, relative]
		if FileAccess.file_exists(target):
			continue
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(target.get_base_dir()))
		if not _curl(include[relative]["url"] as String, target):
			return ""

	return ProjectSettings.globalize_path(gltf_path)


func _curl(url: String, to_path: String) -> bool:
	var args := CURL_ARGS.duplicate()
	args.append("-o")
	args.append(ProjectSettings.globalize_path(to_path))
	args.append(url)
	var output: Array = []
	if OS.execute("curl", args, output, true) != 0:
		print("   curl fallo: %s" % url)
		return false
	return true


func _load_mesh(path: String) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		return null
	return _merge_meshes(scene)


## Junta TODAS las mallas del glTF en una, cada una como su propia superficie.
##
## Antes se cogía la primera y ya. Y funciona con una roca, que viene de una
## pieza, pero no con una planta: un arbusto llega partido en ramas y hoja
## -porque la hoja lleva alfa y necesita su propio material-, así que quedarse
## con la primera dejaba las ramas peladas. `shrub_02` salía como dos palitos en
## vez de un matorral de metro y pico, y la roseta no salía casi.
##
## Cada malla se trae con la transformación del nodo aplicada, porque en un glTF
## las piezas suelen estar colocadas por el nodo y no por los vértices.
func _merge_meshes(scene: Node) -> ArrayMesh:
	# Pares (malla, transformación acumulada). La transformación se acumula al
	# bajar y NO se pide con `global_transform`: la escena que devuelve
	# `generate_scene` no está dentro del árbol, y ahí `global_transform` avisa y
	# devuelve la identidad, con lo que las piezas de un modelo se apilarían
	# todas en el origen.
	var parts: Array = []
	_collect_meshes(scene, Transform3D.IDENTITY, parts)
	if parts.is_empty():
		return null

	# Se agrupa POR MATERIAL y no una superficie por pieza. `moss_01` llega en
	# doce mallas y `pine_sapling_small` en seis, pero casi todas comparten
	# material: dejarlas sueltas daba doce llamadas de dibujado por cada zona
	# sembrada, o sea más de setecientas sólo para el musgo. Fundidas por
	# material son una.
	var by_material: Dictionary = {}
	var order: Array = []
	for part: Dictionary in parts:
		var mesh: ArrayMesh = part["mesh"]
		if mesh == null:
			continue
		var local: Transform3D = part["xform"]
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			if local != Transform3D.IDENTITY:
				for i in range(verts.size()):
					verts[i] = local * verts[i]
				arrays[Mesh.ARRAY_VERTEX] = verts
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				if not normals.is_empty():
					for i in range(normals.size()):
						normals[i] = (local.basis * normals[i]).normalized()
					arrays[Mesh.ARRAY_NORMAL] = normals

			var material := mesh.surface_get_material(surface)
			var key := material.get_instance_id() if material else 0
			if not by_material.has(key):
				by_material[key] = {"material": material, "tool": SurfaceTool.new()}
				(by_material[key]["tool"] as SurfaceTool).begin(
					Mesh.PRIMITIVE_TRIANGLES)
				order.append(key)
			var tool: SurfaceTool = by_material[key]["tool"]
			tool.append_from(_as_mesh(arrays), 0, Transform3D.IDENTITY)

	var merged := ArrayMesh.new()
	for key: Variant in order:
		var tool: SurfaceTool = by_material[key]["tool"]
		tool.index()
		merged = tool.commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1,
			by_material[key]["material"])
	return merged if merged.get_surface_count() > 0 else null


## `SurfaceTool.append_from` quiere una malla, no un array de arrays.
func _as_mesh(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _collect_meshes(node: Node, above: Transform3D, out: Array) -> void:
	var here := above
	if node is Node3D:
		here = above * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			out.append({"mesh": mesh as ArrayMesh, "xform": here})
	for child in node.get_children():
		_collect_meshes(child, here, out)


## Reconstruye la malla como `ImporterMesh` y le pide los niveles de detalle.
## Es la vía del propio motor —la usa el importador de glTF del editor—, sólo que
## aquí se llama a mano porque esto corre sin editor.
func _make_lods(source: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in range(source.get_surface_count()):
		importer.add_surface(
			source.surface_get_primitive_type(surface),
			source.surface_get_arrays(surface),
			[], {}, source.surface_get_material(surface))

	if not importer.has_method("generate_lods"):
		return null
	# La firma cambia entre versiones de Godot, así que se prueban las dos.
	importer.callv("generate_lods", [25.0, 60.0, []])

	var levels := importer.get_surface_lod_count(0)
	if levels <= 0:
		return null
	var coarse := 0
	for surface in range(importer.get_surface_count()):
		var last := importer.get_surface_lod_count(surface) - 1
		if last >= 0:
			coarse += importer.get_surface_lod_indices(surface, last).size() / 3
	print("   %d superficies · %d niveles · el mas basto de %d triangulos" % [
		importer.get_surface_count(), levels, coarse])
	return importer.get_mesh()


## Comprime a BC7 las texturas que trae el modelo.
##
## Llegan como JPG y el cargador de glTF las deja en RGBA8 crudo: la primera
## biblioteca pesaba 67,6 MB para siete piezas. Es el mismo descuido que ya se
## corrigio en las texturas del terreno, y aqui pesa mas porque son siete
## modelos con tres mapas cada uno.
func _compress_textures(mesh: ArrayMesh) -> void:
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface)
		if not (material is BaseMaterial3D):
			continue
		var base := material as BaseMaterial3D
		for slot: int in [BaseMaterial3D.TEXTURE_ALBEDO,
				BaseMaterial3D.TEXTURE_NORMAL,
				BaseMaterial3D.TEXTURE_ROUGHNESS,
				BaseMaterial3D.TEXTURE_METALLIC,
				BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
			var texture := base.get_texture(slot)
			if texture == null:
				continue
			var image := texture.get_image()
			if image == null or image.is_compressed():
				continue
			if not image.has_mipmaps():
				image.generate_mipmaps()
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			image.compress(Image.COMPRESS_BPTC, Image.COMPRESS_SOURCE_GENERIC)
			base.set_texture(slot, ImageTexture.create_from_image(image))


func _triangles(mesh: ArrayMesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += verts.size() / 3
		else:
			total += indices.size() / 3
	return total
