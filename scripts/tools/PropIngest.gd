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

## Techo de triángulos de la malla que se GUARDA.
##
## Los árboles de Poly Haven son escaneos completos: el pino trae 17.182.252
## triángulos y el abeto casi siete millones. Guardarlos enteros dejó la
## biblioteca en 1,3 GB, y eso es geometría, no texturas.
##
## Y no hace falta: un árbol se ve desde treinta metros para arriba. Así que se
## conserva el nivel de detalle más fino que quepa bajo este techo y ese pasa a
## ser la malla BASE, con sus propios niveles por debajo. Lo que se tira es
## detalle que no cabe en pantalla ni acercándose.
const MAX_BASE_TRIS := 24000


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_DIR))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://models/props"))

	var library := PropLibrary.new()
	var keys: Array = PropModels.CATALOGUE.keys()

	for index in range(keys.size()):
		var key: String = keys[index]
		var entry: Dictionary = PropModels.CATALOGUE[key]
		# `slug` sólo lo tienen las piezas que se descargan. Las locales traen
		# `local`, y pedirles `slug` reventaba `_init` a media ingesta: el error
		# aborta la función pero el `SceneTree` sigue vivo sin llegar a `quit()`,
		# así que el proceso se quedaba media hora al dos por ciento de CPU sin
		# imprimir nada y sin terminar. Un fallo de script en `_init` de una
		# herramienta no se ve: se cuelga.
		var slug: String = entry.get("slug", entry.get("local", "?"))
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

		var raw_variants := _load_mesh(gltf_path)
		if raw_variants.is_empty():
			print("   FALLO al leer la malla; se salta")
			continue

		var raw := 0
		var ready: Array[Mesh] = []
		var tallest := 0.0
		for variant: ArrayMesh in raw_variants:
			raw += _triangles(variant)
			var capped := _cap_detail(variant)
			var with_lods := _make_lods(capped)
			if with_lods == null:
				# `generate_lods` no simplifica lo que ya es simple.
				with_lods = capped
			_grade(with_lods, PropModels.grade_of(key))
			_compress_textures(with_lods)
			ready.append(with_lods)
			tallest = maxf(tallest, with_lods.get_aabb().size.y)

		# La talla se calcula sobre la variante MÁS ALTA y se aplica a todas por
		# igual: si cada una se normalizase por su cuenta, tres ramas de tamaños
		# distintos acabarían midiendo lo mismo y se perdería la variedad.
		var factor := 1.0
		if tallest > 0.0001:
			factor = float(entry["height_m"]) / tallest

		print("   %d variantes · %d triangulos · mas alta %.2f m · factor x%.3f" % [
			ready.size(), raw, tallest, factor])

		if entry.has("local"):
			var credit := _read_credit(gltf_path)
			if credit.is_empty():
				print("   SIN atribucion dentro del fichero")
			else:
				library.credits[key] = credit
				print("   «%s» de %s · %s" % [credit.get("title", "?"),
					credit.get("author", "?"), credit.get("license", "?")])

		library.meshes[key] = ready
		library.scales[key] = factor
		library.triangles[key] = raw

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
	_write_credits(library)
	quit()


## Escribe los créditos de todo lo que se usa.
##
## No es cortesía: una licencia CC-BY OBLIGA a atribuir, y eso se olvida si se
## deja para el final. Se genera desde el catálogo, así que no puede quedarse
## desfasado respecto a lo que de verdad se está usando. Poly Haven es CC0 y no
## lo exige, pero se cita igual —cuesta nada y es de justicia—.
func _write_credits(library: PropLibrary) -> void:
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
			var credit: Dictionary = library.credits.get(key, {})
			lines.append("- %s — «%s» de %s, %s. %s" % [entry["name"],
				credit.get("title", "?"),
				credit.get("author", "AUTOR SIN DECLARAR"),
				credit.get("license", "LICENCIA SIN DECLARAR"),
				credit.get("source", "")])
			if not credit.has("author") or not credit.has("license"):
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
	lines.append("## Personas")
	lines.append("")
	lines.append("«Animated Human» de [Quaternius](https://quaternius.com)"
		+ " ([OpenGameArt](https://opengameart.org/content/animated-human-low-poly)),"
		+ " CC0. `scripts/tools/BandaAtlas.gd` hornea sus siete animaciones"
		+ " -reposo, andar, correr, salto, golpe, trabajo, muerte- a textura"
		+ " de vértice para dibujar la banda entera en un solo `MultiMesh`;"
		+ " ver ese fichero para el porqué.")
	lines.append("")
	lines.append("## Fauna")
	lines.append("")
	lines.append("Lobo, caballo, vaca, cerdo, oveja, águila y pájaro pequeño de"
		+ " [Quaternius](https://quaternius.com) —"
		+ " [Animal Pack Vol.2](https://opengameart.org/content/animated-animales-low-poly),"
		+ " [Farm Animals](https://opengameart.org/content/lowpoly-animated-farm-animal-pack)—,"
		+ " CC0. Ciervo, venado y toro del"
		+ " [Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html)"
		+ " del mismo autor, CC0. Pato de [Gobkit](https://gobkit.com), CC0."
		+ " `scripts/tools/FaunaAtlas.gd` los hornea igual que a la banda.")
	lines.append("")
	lines.append("`WildlifeHerds.gd` reparte once mallas entre las doce especies"
		+ " de [Fauna]. La caza mayor ya no anda prestada de caballo ni de oveja"
		+ " —esas dos mallas de granja sólo traen reposo y salto, y por eso"
		+ " jabalí, corzo y rebeco cruzaban el valle con las patas quietas—, pero"
		+ " tres cosas siguen faltando y conviene tenerlas escritas:")
	lines.append("")
	lines.append("- **Cabra montés y rebeco.** No hay bóvido de montaña CC0"
		+ " descargable por script. El rebeco lleva la malla del corzo con otra"
		+ " talla y otro tinte: anda bien, pero comparte silueta con él.")
	lines.append("- **Jabalí.** Tampoco hay suido con ciclo de marcha. Lleva la"
		+ " del toro, que es lo más parecido que anda: cuerpo bajo y macizo con"
		+ " la cabeza pesada delante.")
	lines.append("- **La cuerna del venado.** El `Stag.fbx` trae las astas en una"
		+ " malla aparte, colgada de un hueso, y el horneado a textura de"
		+ " vértice sólo se lleva una malla con pesos. Se hornea el cuerpo; las"
		+ " astas se pierden, que en la época de la berrea se nota.")
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


func _load_mesh(path: String) -> Array[ArrayMesh]:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return []
	var scene := doc.generate_scene(state)
	if scene == null:
		return []
	return _split_variants(scene)


## Separa el glTF en VARIANTES, y junta las piezas de cada una.
##
## Poly Haven empaqueta varios ejemplares en un mismo fichero: `dry_branches`
## trae tres ramas distintas, `nettle_plant` cuatro matas, `pine_sapling_small`
## tres arbolitos. Fusionarlo todo en una malla hacía que CADA instancia fuese
## «las tres ramas a la vez», siempre igual y siempre en la misma disposición.
## Separadas, cada una es una silueta distinta y se alterna entre instancias.
##
## Cómo se distingue una variante de una pieza: por PROXIMIDAD. Las piezas de un
## mismo objeto se tocan —el tronco y la copa comparten sitio— y las variantes
## están puestas una al lado de otra. Así que se agrupan las mallas cuyas cajas
## se solapan, y cada grupo es una variante.
func _split_variants(scene: Node) -> Array[ArrayMesh]:
	var parts: Array = []
	_collect_meshes(scene, Transform3D.IDENTITY, parts)
	if parts.is_empty():
		return []

	# Caja de cada pieza, ya colocada
	var boxes: Array[AABB] = []
	for part: Dictionary in parts:
		var box: AABB = (part["mesh"] as ArrayMesh).get_aabb()
		boxes.append((part["xform"] as Transform3D) * box)

	# Union-find sobre las cajas que se tocan. El margen es pequeño a proposito:
	# con uno grande, dos variantes vecinas se fundirian otra vez.
	var owner: Array[int] = []
	for i in range(parts.size()):
		owner.append(i)
	for i in range(parts.size()):
		for j in range(i + 1, parts.size()):
			if boxes[i].grow(0.02).intersects(boxes[j]):
				var a := _root(owner, i)
				var b := _root(owner, j)
				if a != b:
					owner[b] = a

	var groups: Dictionary = {}
	for i in range(parts.size()):
		var key := _root(owner, i)
		if not groups.has(key):
			groups[key] = ([] as Array)
		(groups[key] as Array).append(parts[i])

	var out: Array[ArrayMesh] = []
	for key: int in groups:
		var merged := _merge_parts(groups[key] as Array)
		if merged != null:
			out.append(merged)
	return out


func _root(owner: Array[int], i: int) -> int:
	while owner[i] != i:
		owner[i] = owner[owner[i]]
		i = owner[i]
	return i


## Junta las piezas de UNA variante, agrupadas por material.
##
## Agrupar por material importa: `moss_01` llega en doce mallas que comparten
## material, y dejarlas como superficies sueltas daba doce llamadas de dibujado
## por cada zona sembrada.
func _merge_parts(parts: Array) -> ArrayMesh:
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


## Saca autor y licencia de dentro del propio .glb.
##
## Sketchfab los incrusta en `asset.extras`, así que la atribución sale del
## fichero y no de que alguien se acuerde de teclearla. Es la diferencia entre
## un crédito que puede quedarse desfasado y uno que no puede.
##
## Se lee el glb a mano -cabecera de doce bytes y el primer trozo, que es el
## JSON- porque `GLTFState` no expone `asset.extras`.
func _read_credit(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_buffer(4).get_string_from_ascii() != "glTF":
		return {}
	file.get_32()  # version
	file.get_32()  # tamaño total
	var chunk_length := file.get_32()
	file.get_32()  # tipo de trozo
	var text := file.get_buffer(chunk_length).get_string_from_utf8()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return {}
	var extras: Variant = ((data as Dictionary).get("asset", {}) as Dictionary) 		.get("extras", {})
	if not (extras is Dictionary):
		return {}
	var out := {}
	for key: String in ["title", "author", "license", "source"]:
		if (extras as Dictionary).has(key):
			out[key] = (extras as Dictionary)[key]
	return out


## Gradúa el color del albedo, horneándolo en la propia textura.
##
## Se hace AQUI y no en un shader por dos razones. Una, que en ejecución no
## cuesta nada: la textura ya viene graduada. Y dos, que los props usan el
## material que trae cada modelo -algunos con alfa para la hoja-, así que meterles
## un shader propio obligaría a replicar ese material a mano y a mantenerlo.
##
## Se desatura hacia el gris de la misma luminancia y despues se tinta, en ese
## orden. Al reves el tinte se diluiria justo en las piezas que mas hay que
## corregir, que es lo que ya se aprendio con las capas del terreno.
##
## Sólo toca el ALBEDO. La normal, la rugosidad y la oclusión describen la
## superficie, no su color, y tocarlas sería estropear el material.
func _grade(mesh: ArrayMesh, grade: Dictionary) -> void:
	var tint: Color = grade["tint"]
	var sat: float = grade["sat"]
	if tint == Color.WHITE and is_equal_approx(sat, 1.0):
		return

	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface)
		if not (material is BaseMaterial3D):
			continue
		var base := material as BaseMaterial3D
		var texture := base.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null or image.is_compressed():
			continue
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)

		var data := image.get_data()
		var count := data.size() / 4
		for i in range(count):
			var o := i * 4
			var r := float(data[o]) / 255.0
			var g := float(data[o + 1]) / 255.0
			var b := float(data[o + 2]) / 255.0
			var lum := 0.299 * r + 0.587 * g + 0.114 * b
			data[o] = int(clampf((lum + (r - lum) * sat) * tint.r, 0.0, 1.0) * 255.0)
			data[o + 1] = int(clampf((lum + (g - lum) * sat) * tint.g, 0.0, 1.0) * 255.0)
			data[o + 2] = int(clampf((lum + (b - lum) * sat) * tint.b, 0.0, 1.0) * 255.0)

		var graded := Image.create_from_data(image.get_width(),
			image.get_height(), image.has_mipmaps(), Image.FORMAT_RGBA8, data)
		base.set_texture(BaseMaterial3D.TEXTURE_ALBEDO,
			ImageTexture.create_from_image(graded))


## Baja la malla al nivel de detalle más fino que quepa bajo `MAX_BASE_TRIS`.
##
## Se pide a `ImporterMesh` que genere los niveles y se coge uno como base
## nueva, remapeando los vértices para no arrastrar los que dejan de usarse: sin
## remapear, la malla seguiría ocupando lo mismo en disco aunque dibujara menos.
func _cap_detail(mesh: ArrayMesh) -> ArrayMesh:
	if _triangles(mesh) <= MAX_BASE_TRIS:
		return mesh

	var importer := ImporterMesh.new()
	for surface in range(mesh.get_surface_count()):
		importer.add_surface(mesh.surface_get_primitive_type(surface),
			mesh.surface_get_arrays(surface), [], {},
			mesh.surface_get_material(surface))
	if not importer.has_method("generate_lods"):
		print("   sin generate_lods: no se puede recortar")
		return mesh
	importer.callv("generate_lods", [25.0, 60.0, []])

	var levels := ""
	for surface in range(importer.get_surface_count()):
		levels += " %d" % importer.get_surface_lod_count(surface)
	print("   recorte: %d superficies, niveles por superficie:%s" % [
		importer.get_surface_count(), levels])

	var out := ArrayMesh.new()
	var total := 0
	for surface in range(importer.get_surface_count()):
		var arrays := importer.get_surface_arrays(surface)
		var chosen: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Del más fino al más basto, quedarse con el primero que quepa
		var share := MAX_BASE_TRIS / maxi(importer.get_surface_count(), 1)
		for level in range(importer.get_surface_lod_count(surface)):
			var indices: PackedInt32Array = importer.get_surface_lod_indices(
				surface, level)
			chosen = indices
			if indices.size() / 3 <= share:
				break
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			_remap(arrays, chosen))
		out.surface_set_material(out.get_surface_count() - 1,
			importer.get_surface_material(surface))
		total += chosen.size() / 3
	print("   recortada a %d triangulos de base" % total)
	return out


## Reconstruye los arrays quedándose sólo con los vértices que usa el índice.
func _remap(arrays: Array, indices: PackedInt32Array) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)

	var mapping: Dictionary = {}
	var order: PackedInt32Array = PackedInt32Array()
	var fresh := PackedInt32Array()
	fresh.resize(indices.size())
	for i in range(indices.size()):
		var old: int = indices[i]
		if not mapping.has(old):
			mapping[old] = order.size()
			order.append(old)
		fresh[i] = mapping[old]

	for channel: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL,
			Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV,
			Mesh.ARRAY_TEX_UV2]:
		var source: Variant = arrays[channel]
		if source == null:
			continue
		# La tangente va en cuatro flotantes por vértice, no en uno
		var stride := 4 if channel == Mesh.ARRAY_TANGENT else 1
		var packed: Variant = _take(source, order, stride)
		if packed != null:
			out[channel] = packed
	out[Mesh.ARRAY_INDEX] = fresh
	return out


func _take(source: Variant, order: PackedInt32Array, stride: int) -> Variant:
	if source is PackedVector3Array:
		var v3 := PackedVector3Array()
		for i: int in order:
			v3.append((source as PackedVector3Array)[i])
		return v3
	if source is PackedVector2Array:
		var v2 := PackedVector2Array()
		for i: int in order:
			v2.append((source as PackedVector2Array)[i])
		return v2
	if source is PackedColorArray:
		var c := PackedColorArray()
		for i: int in order:
			c.append((source as PackedColorArray)[i])
		return c
	if source is PackedFloat32Array:
		var f := PackedFloat32Array()
		for i: int in order:
			for k in range(stride):
				f.append((source as PackedFloat32Array)[i * stride + k])
		return f
	return null


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
