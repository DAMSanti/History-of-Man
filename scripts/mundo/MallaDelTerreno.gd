class_name MallaDelTerreno
extends RefCounted
## De un campo de alturas a una malla que se puede dibujar y pisar.
##
## Sale de [TerrainGenerator] porque es un tema cerrado y porque era su mitad
## mas grande: cuatrocientas sesenta y ocho lineas que no llama nadie de fuera
## -una sola llamada externa en todo el proyecto-. Lo que SI se queda en el
## generador son las consultas -`get_height_at`, `get_slope_at`,
## `crossing_difficulty_at`-, que tienen 168 llamadas y son la cara publica de
## la clase.
##
## Lo que hay aqui, en orden:
##
##   - los ARRAYS de vertices, normales, tangentes, color y UV, construidos a
##     mano porque SurfaceTool tardaba treinta y cinco segundos en un millon de
##     vertices;
##   - los NIVELES DE DETALLE y el TROCEADO en cuadrantes, que es lo que deja
##     el recuadro a 26 fotogramas;
##   - la COLISION, que sale del campo de alturas y no de la malla;
##   - y la CACHE en disco, que se salta todo lo anterior cuando el relieve no
##     ha cambiado.
var terreno: TerrainGenerator


func _init(generador: TerrainGenerator) -> void:
	terreno = generador


## Crea el mesh del terreno
func _create_terrain_mesh() -> void:
	# Limpiar mesh anterior
	if terreno._terrain_mesh:
		terreno._terrain_mesh.queue_free()
	if terreno._terrain_collision:
		terreno._terrain_collision.queue_free()

	if terreno._gen_cache != null:
		_create_terrain_mesh_from_cache(terreno._gen_cache)
		return

	var arrays := _construir_arrays()

	# El paso vuelve a hacer falta aqui: es lo que dice si el recuadro es
	# cuadrado, y de eso depende que haga falta colision de malla.
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
	var single_mesh := _malla_para_dibujar(arrays, step_x, step_z)

	terreno._terrain_mesh = MeshInstance3D.new()
	terreno._terrain_mesh.name = "TerrainMesh"
	# Con troceado el nodo raiz no lleva malla: la llevan los trozos, que
	# cuelgan de el. Ver [_split_into_chunks].
	if terreno.terrain_chunks <= 1:
		terreno._terrain_mesh.mesh = single_mesh

	var tmat0 := Time.get_ticks_msec()
	terreno._apply_terrain_material()
	print("[TIMING]   material/texturas de terreno: %d ms" % (Time.get_ticks_msec() - tmat0))

	terreno.add_child(terreno._terrain_mesh)

	var chunk_meshes: Array[ArrayMesh] = []
	if terreno.terrain_chunks > 1:
		var tchunk0 := Time.get_ticks_msec()
		chunk_meshes = _split_into_chunks(arrays)
		print("[TIMING]   _split_into_chunks: %d ms" % (Time.get_ticks_msec() - tchunk0))

	# Crear colisión. Sale del campo de alturas, no de la malla, asi que el
	# troceado no la toca.
	var tcol0 := Time.get_ticks_msec()
	_create_collision(single_mesh)
	print("[TIMING]   _create_collision: %d ms" % (Time.get_ticks_msec() - tcol0))

	_save_generation_cache(single_mesh, chunk_meshes)


## Los arrays de la malla: vertices, normales, tangentes, color, UV e indices.
##
## Se construyen A MANO en vez de con SurfaceTool. SurfaceTool anade vertice a
## vertice desde GDScript y luego recalcula normales y tangentes promediando
## por cara: en una malla de un millon de vertices eso eran unos 35 segundos.
## Aqui las normales salen analiticamente del campo de alturas, que ademas de
## rapido es exacto: no hay que recorrer las caras.
func _construir_arrays() -> Array:
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
	var count := terreno.resolution * terreno.resolution

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	tangents.resize(count * 4)
	colors.resize(count)
	uvs.resize(count)
	uv2s.resize(count)

	var tvert0 := Time.get_ticks_msec()
	for z in range(terreno.resolution):
		var row := z * terreno.resolution
		var zu := maxi(z - 1, 0) * terreno.resolution
		var zd := mini(z + 1, terreno.resolution - 1) * terreno.resolution
		var dz_span := (mini(z + 1, terreno.resolution - 1) - maxi(z - 1, 0)) * step_z

		for x in range(terreno.resolution):
			var idx := row + x
			var height := terreno._height_map[idx]

			vertices[idx] = Vector3(float(x) * step_x, height, float(z) * step_z)
			# UV en coordenadas de mundo para que la textura tile igual
			uvs[idx] = Vector2(float(x) * step_x / 4.0, float(z) * step_z / 4.0)
			# El color de vertice transporta la hidrografia entera al shader, y
			# va gratis porque el triplanar no usaba ninguno de sus canales:
			#   rg = sentido de la corriente, reescalado a 0..1
			#   b  = agua quieta (una laguna no desfila)
			#   a  = lamina de agua
			var flow: Vector2 = terreno._flow_map[idx] if idx < terreno._flow_map.size() else Vector2.ZERO
			var wetness: float = terreno._river_map[idx] if idx < terreno._river_map.size() else 0.0
			colors[idx] = Color(
				flow.x * 0.5 + 0.5,
				flow.y * 0.5 + 0.5,
				1.0 if (wetness > 0.01 and flow.length_squared() < 0.01) else 0.0,
				wetness)

			# UV2 quedo libre al pasar la mascara de region a textura, y ahora
			# transporta dos cosas que se calculan una vez por vertice en vez
			# de por fragmento: curvatura y variacion de parche.
			#
			# La CURVATURA es lo que faltaba para que el terreno deje de verse
			# homogeneo: lo concavo acumula suelo y humedad, lo convexo se
			# erosiona y deja roca. Con pendiente y altitud solos, una ladera
			# entera sale del mismo color.
			var left := maxi(x - 1, 0)
			var right := mini(x + 1, terreno.resolution - 1)
			var laplacian := (
				terreno._height_map[row + left] + terreno._height_map[row + right]
				+ terreno._height_map[zu + x] + terreno._height_map[zd + x]) * 0.25 - height
			var curvature := clampf(laplacian / maxf(terreno.curvature_scale, 0.001), -1.0, 1.0)

			# Variacion a escala de decenas de metros, para que haya manchas de
			# pasto, matorral y roca en vez de un degradado continuo
			var macro := terreno._macro_noise.get_noise_2d(
				float(x) * step_x, float(z) * step_z) * 0.5 + 0.5

			uv2s[idx] = Vector2(curvature * 0.5 + 0.5, macro)

			var xl := maxi(x - 1, 0)
			var xr := mini(x + 1, terreno.resolution - 1)
			var dhdx := (terreno._height_map[row + xr] - terreno._height_map[row + xl]) / (float(xr - xl) * step_x)
			var dhdz := (terreno._height_map[zd + x] - terreno._height_map[zu + x]) / dz_span

			# Normal de un campo de alturas y = h(x,z)
			normals[idx] = Vector3(-dhdx, 1.0, -dhdz).normalized()

			# Tangente a lo largo de +X, que es la direccion de +U
			var tangent := Vector3(1.0, dhdx, 0.0).normalized()
			var t := idx * 4
			tangents[t] = tangent.x
			tangents[t + 1] = tangent.y
			tangents[t + 2] = tangent.z
			# La bitangente debe ir hacia +Z (direccion de +V)
			tangents[t + 3] = -1.0

	print("[TIMING]   bucle de vertices/normales/UV (%d celdas): %d ms" % [
		count, Time.get_ticks_msec() - tvert0])

	# Índices (triángulos) - CCW winding order visto desde arriba
	var tidx0 := Time.get_ticks_msec()
	var indices := PackedInt32Array()
	indices.resize((terreno.resolution - 1) * (terreno.resolution - 1) * 6)
	var i := 0
	for z in range(terreno.resolution - 1):
		for x in range(terreno.resolution - 1):
			var top_left := z * terreno.resolution + x
			var top_right := top_left + 1
			var bottom_left := (z + 1) * terreno.resolution + x
			var bottom_right := bottom_left + 1

			indices[i] = top_left
			indices[i + 1] = top_right
			indices[i + 2] = bottom_left
			indices[i + 3] = top_right
			indices[i + 4] = bottom_right
			indices[i + 5] = bottom_left
			i += 6
	print("[TIMING]   bucle de indices: %d ms" % (Time.get_ticks_msec() - tidx0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## La malla que se dibuja, si es que hay que dibujar una sola.
##
## Con el terreno troceado -el caso normal- devuelve null: la malla la llevan
## los trozos y la colision sale del campo de alturas, asi que construirla
## seria pagar `generate_lods()` dos veces sobre el mismo millon de vertices
## para tirar la primera entera. Medido: de 9 a 19 segundos regalados.
func _malla_para_dibujar(arrays: Array, step_x: float, step_z: float) -> ArrayMesh:
	# Con niveles de detalle. Medido: el recuadro cuesta 29 ms de fotograma con
	# 2,1 millones de triangulos a 1025 vertices por lado, y buena parte de esa
	# malla cae lejos de la camara, donde un vertice cada cuatro metros y uno
	# cada dieciseis dan el mismo pixel. Godot elige el nivel por cuanto ocupa
	# en pantalla; la colision y las consultas de altura NO usan esta malla,
	# asi que simplificarla no afecta a la simulacion.
	#
	# Si el terreno va troceado -el caso normal, ver `terrain_chunks`- esta
	# malla unica NO SE DIBUJA (la llevan los trozos) y la colision cuadrada
	# tampoco la usa (sale de `_height_map` via HeightMapShape3D). Construirla
	# igualmente era pagar generate_lods() dos veces sobre el mismo millon de
	# vertices -una para el conjunto, otra por cada trozo- para tirar la
	# primera entera: medido, 9-19 s regalados. Solo hace falta si no hay
	# trozos, o si el recuadro no es cuadrado y pide colision de verdad.
	var needs_trimesh_collision := terreno.generate_collision and terreno.terrain_chunks > 1 \
		and absf(step_x - step_z) >= 0.0001

	var tlod0 := Time.get_ticks_msec()
	var single_mesh: ArrayMesh = null
	if terreno.terrain_chunks <= 1:
		single_mesh = _mesh_with_lods(arrays)
	elif needs_trimesh_collision:
		# Caso raro -hoy no lo usa ninguna escena: colision pedida sobre un
		# recuadro troceado y no cuadrado. Una malla plana sin LODs basta para
		# un trimesh estatico; generate_lods() aqui seria trabajo tirado otra
		# vez, porque la colision no elige nivel de detalle.
		single_mesh = ArrayMesh.new()
		single_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	print("[TIMING]   _mesh_with_lods: %d ms" % (Time.get_ticks_msec() - tlod0))
	return single_mesh


## Reconstruye lo que deja `_create_terrain_mesh()`, pero desde una cache ya
## valida en vez de recalcularlo: sin bucle de vertices, sin generate_lods.
func _create_terrain_mesh_from_cache(cache: TerrainGenerationCache) -> void:
	terreno._terrain_mesh = MeshInstance3D.new()
	terreno._terrain_mesh.name = "TerrainMesh"
	if terreno.terrain_chunks <= 1:
		terreno._terrain_mesh.mesh = cache.single_mesh

	var tmat0 := Time.get_ticks_msec()
	terreno._apply_terrain_material()
	print("[TIMING]   material/texturas de terreno: %d ms" % (Time.get_ticks_msec() - tmat0))

	terreno.add_child(terreno._terrain_mesh)

	if terreno.terrain_chunks > 1:
		var tchunk0 := Time.get_ticks_msec()
		for i in range(cache.chunk_meshes.size()):
			var piece := MeshInstance3D.new()
			piece.name = "Trozo_%d" % i
			piece.mesh = cache.chunk_meshes[i]
			piece.material_override = terreno._terrain_mesh.material_override
			terreno._terrain_mesh.add_child(piece)
		print("[TIMING]   trozos desde cache (%d): %d ms" % [
			cache.chunk_meshes.size(), Time.get_ticks_msec() - tchunk0])

	var tcol0 := Time.get_ticks_msec()
	_create_collision(cache.single_mesh)
	print("[TIMING]   _create_collision: %d ms" % (Time.get_ticks_msec() - tcol0))


## Ruta de la cache de generacion para el heightmap actual, o "" si este
## terreno no es cacheable -procedural, o sin heightmap con ruta propia.
##
## Se deriva del propio fichero del heightmap: "site_9000.res" cachea en
## "site_9000_mesh_r825.res", al lado. Asi cada sitio tiene su cache, sin tener
## que inventar un id aparte, y coincide con donde ya vive "site_9000.res".
func _cache_base_path() -> String:
	if terreno.height_source != TerrainGenerator.HeightSource.HEIGHTMAP or terreno.heightmap == null:
		return ""
	var src := terreno.heightmap.resource_path
	if src.is_empty():
		return ""
	return "%s/%s_mesh_r%d.res" % [src.get_base_dir(), src.get_file().get_basename(), terreno.resolution]


## Huella de las entalladuras actuales, para invalidar la cache si cambian
## -por ejemplo al fundar el mismo sitio en otra epoca, con otras cuevas
## excavadas en la malla.
func _carvings_hash() -> int:
	return hash(str(terreno.carvings))


## Huella del relieve inventado: lo que se anade por debajo de lo que mide el
## MDT. Ver [TerrainGenerationCache.detail_hash] para por que va todo junto.
func _detail_hash() -> int:
	# La amplitud EFECTIVA, no la del inspector: depende del paso del dato, asi
	# que el mismo sitio con MDT del IGN y con terrarium no comparten malla.
	return hash([terreno._effective_detail_amplitude(), terreno.detail_frequency, terreno.detail_octaves,
		terreno.detail_slope_gain, terreno.detail_slope_max, terreno.shelf_relief_m])


## Si una cache ya cargada sigue describiendo lo que este generador pide ahora.
func _cache_matches(cache: TerrainGenerationCache) -> bool:
	return cache.version == TerrainGenerationCache.CACHE_VERSION \
		and cache.heightmap_pipeline_version == terreno.heightmap.pipeline_version \
		and cache.resolution == terreno.resolution \
		and cache.terrain_size == terreno.terrain_size \
		and cache.heightmap_region_offset == terreno.heightmap_region_offset \
		and is_equal_approx(cache.meters_per_unit, terreno.meters_per_unit) \
		and is_equal_approx(cache.vertical_exaggeration, terreno.vertical_exaggeration) \
		and is_equal_approx(cache.sea_level, terreno.sea_level) \
		and cache.terrain_chunks == terreno.terrain_chunks \
		and cache.carvings_hash == _carvings_hash() \
		and cache.detail_hash == _detail_hash() \
		and cache.height_map.size() == terreno.resolution * terreno.resolution \
		and (terreno.terrain_chunks > 1 or cache.single_mesh != null) \
		and (terreno.terrain_chunks <= 1 or cache.chunk_meshes.size() > 0)


## Carga la cache de disco si hay una y sigue describiendo este terreno.
func _load_generation_cache() -> TerrainGenerationCache:
	if not terreno.use_generation_cache:
		return null
	var path := _cache_base_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var cache := ResourceLoader.load(path) as TerrainGenerationCache
	if cache == null or not _cache_matches(cache):
		return null
	return cache


## Guarda en disco lo que ha costado calcular, para no repetirlo la proxima
## vez que se cargue este mismo sitio. No hace nada si ya se cargo de cache
## -nada ha cambiado- ni si el terreno no tiene heightmap con ruta propia.
func _save_generation_cache(single_mesh: ArrayMesh, chunk_meshes: Array[ArrayMesh]) -> void:
	if terreno._gen_cache != null or not terreno.use_generation_cache:
		return
	var path := _cache_base_path()
	if path.is_empty():
		return

	var cache := TerrainGenerationCache.new()
	cache.version = TerrainGenerationCache.CACHE_VERSION
	cache.heightmap_pipeline_version = terreno.heightmap.pipeline_version
	cache.resolution = terreno.resolution
	cache.terrain_size = terreno.terrain_size
	cache.heightmap_region_offset = terreno.heightmap_region_offset
	cache.meters_per_unit = terreno.meters_per_unit
	cache.vertical_exaggeration = terreno.vertical_exaggeration
	cache.sea_level = terreno.sea_level
	cache.terrain_chunks = terreno.terrain_chunks
	cache.carvings_hash = _carvings_hash()
	cache.detail_hash = _detail_hash()
	cache.height_map = terreno._height_map
	cache.humidity_map = terreno._humidity_map
	cache.geology_map = terreno._geology_map
	cache.relief_map = terreno._relief_map
	cache.river_map = terreno._river_map
	cache.flow_map = terreno._flow_map
	cache.ford_map = terreno._ford_map
	cache.region_map = terreno._region_map
	cache.height_range = terreno._height_range
	cache.single_mesh = single_mesh
	cache.chunk_meshes = chunk_meshes

	var t0 := Time.get_ticks_msec()
	if ResourceSaver.save(cache, path) != OK:
		push_warning("No se pudo guardar la cache de generacion en " + path)
	else:
		print("[TIMING]   cache de generacion guardada (%s): %d ms" % [
			path, Time.get_ticks_msec() - t0])


func _create_collision(mesh: Mesh) -> void:
	if not terreno.generate_collision:
		return

	terreno._terrain_collision = StaticBody3D.new()
	terreno._terrain_collision.name = "TerrainCollision"
	# Capa 1 = "terrain" segun project.godot
	terreno._terrain_collision.collision_layer = 1

	var collision_shape := CollisionShape3D.new()
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)

	if absf(step_x - step_z) < 0.0001:
		# HeightMapShape3D es la forma natural de un campo de alturas y evita
		# construir un ConcavePolygonShape3D con millones de triangulos, que
		# era la otra mitad del tiempo de generacion.
		var shape := HeightMapShape3D.new()
		shape.map_width = terreno.resolution
		shape.map_depth = terreno.resolution

		# La forma usa celdas de 1 unidad centradas en el origen, asi que hay
		# que escalar el nodo. La fisica no admite escalas no uniformes, por eso
		# las alturas se predividen por el paso en vez de escalar solo X y Z.
		var data := PackedFloat32Array()
		data.resize(terreno._height_map.size())
		for i in range(terreno._height_map.size()):
			data[i] = terreno._height_map[i] / step_x
		shape.map_data = data

		collision_shape.shape = shape
		collision_shape.scale = Vector3.ONE * step_x
		collision_shape.position = Vector3(float(terreno.terrain_size.x) * 0.5, 0.0, float(terreno.terrain_size.y) * 0.5)
	else:
		# Terreno no cuadrado: no hay escala uniforme posible, se usa el trimesh
		collision_shape.shape = mesh.create_trimesh_shape()

	terreno._terrain_collision.add_child(collision_shape)
	terreno.add_child(terreno._terrain_collision)


## Rango real de altura del terreno en metros (min, max)
## El material del terreno, para quien quiera pintarle algo encima.
##
## Lo usa el overlay de recursos: en vez de sembrar el mundo de nodos, le pasa
## una textura y deja que el shader la mezcle con el albedo.
## Las mallas del terreno, para quien necesite volver a dibujarlas aparte.
##
## Existe por [GroundCover], que hornea el color del terreno fotografiándolo
## desde arriba con su propio material. Es la única forma de saber de qué color
## es el suelo SIN aproximarlo: el sombreado del terreno mezcla ocho capas por
## curvatura, pendiente y ruido, les aplica oclusión, macro variación y el
## apagado de fuera de región, y reproducir todo eso en GDScript sería duplicar
## medio shader y verlo desincronizarse al primer cambio.
##
## Se devuelven los nodos, no copias: quien los use que los duplique.
func mesh_pieces() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if terreno._terrain_mesh == null:
		return out
	# El nodo raiz lleva malla en el modo de una pieza, y en el troceado no:
	# ahi solo es el padre de los trozos.
	if terreno._terrain_mesh.mesh != null:
		out.append(terreno._terrain_mesh)
	for child in terreno._terrain_mesh.get_children():
		var piece := child as MeshInstance3D
		if piece != null and piece.mesh != null:
			out.append(piece)
	return out


## Malla con niveles de detalle generados, o la de siempre si no se puede.
func _mesh_with_lods(arrays: Array) -> ArrayMesh:
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if not importer.has_method("generate_lods"):
		var plain := ArrayMesh.new()
		plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return plain

	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


## Parte la malla del terreno en una rejilla de trozos.
##
## Cada trozo se construye rebanando los MISMOS arrays de vertices que ya se
## han calculado, asi que ni el relieve ni las normales ni el agua cambian en
## nada: es la misma superficie, dibujada en cuadros.
##
## Los trozos COMPARTEN la fila y la columna del borde -de ahi el `<=` en los
## bucles-, que es lo que evita que se abra una grieta entre cuadros: los
## vertices del limite son literalmente los mismos, con la misma cota y la
## misma normal.
func _split_into_chunks(arrays: Array) -> Array[ArrayMesh]:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]

	var per_chunk := int(ceil(float(terreno.resolution - 1) / float(terreno.terrain_chunks)))
	var made := 0
	# En el mismo orden en que se crean, para poder recrearlos identicos desde
	# cache sin tener que guardar tambien sus coordenadas de trozo.
	var built: Array[ArrayMesh] = []

	for cz in range(terreno.terrain_chunks):
		for cx in range(terreno.terrain_chunks):
			var x0 := cx * per_chunk
			var z0 := cz * per_chunk
			var x1 := mini(x0 + per_chunk, terreno.resolution - 1)
			var z1 := mini(z0 + per_chunk, terreno.resolution - 1)
			if x1 <= x0 or z1 <= z0:
				continue

			var wide := x1 - x0 + 1
			var tall := z1 - z0 + 1
			var count := wide * tall

			var cv := PackedVector3Array()
			var cn := PackedVector3Array()
			var ct := PackedFloat32Array()
			var cc := PackedColorArray()
			var cu := PackedVector2Array()
			var cu2 := PackedVector2Array()
			cv.resize(count)
			cn.resize(count)
			ct.resize(count * 4)
			cc.resize(count)
			cu.resize(count)
			cu2.resize(count)

			for z in range(tall):
				for x in range(wide):
					var src := (z0 + z) * terreno.resolution + (x0 + x)
					var dst := z * wide + x
					cv[dst] = vertices[src]
					cn[dst] = normals[src]
					cc[dst] = colors[src]
					cu[dst] = uvs[src]
					cu2[dst] = uv2s[src]
					for k in range(4):
						ct[dst * 4 + k] = tangents[src * 4 + k]

			var ci := PackedInt32Array()
			ci.resize((wide - 1) * (tall - 1) * 6)
			var i := 0
			for z in range(tall - 1):
				for x in range(wide - 1):
					var top_left := z * wide + x
					var top_right := top_left + 1
					var bottom_left := top_left + wide
					var bottom_right := bottom_left + 1
					ci[i] = top_left
					ci[i + 1] = top_right
					ci[i + 2] = bottom_left
					ci[i + 3] = top_right
					ci[i + 4] = bottom_right
					ci[i + 5] = bottom_left
					i += 6

			var chunk_arrays := []
			chunk_arrays.resize(Mesh.ARRAY_MAX)
			chunk_arrays[Mesh.ARRAY_VERTEX] = cv
			chunk_arrays[Mesh.ARRAY_NORMAL] = cn
			chunk_arrays[Mesh.ARRAY_TANGENT] = ct
			chunk_arrays[Mesh.ARRAY_COLOR] = cc
			chunk_arrays[Mesh.ARRAY_TEX_UV] = cu
			chunk_arrays[Mesh.ARRAY_TEX_UV2] = cu2
			chunk_arrays[Mesh.ARRAY_INDEX] = ci

			var piece_mesh := _mesh_with_lods(chunk_arrays)
			var piece := MeshInstance3D.new()
			piece.name = "Trozo_%d_%d" % [cx, cz]
			piece.mesh = piece_mesh
			# `material_override` NO se hereda de un nodo padre a sus hijos:
			# sin esta linea los trozos salen con el material de serie, que es
			# blanco liso. Es el mismo recurso para todos, asi que cambiarlo
			# -las bandas de altura, la mascara de region, el overlay- sigue
			# afectando a los sesenta y cuatro a la vez.
			piece.material_override = terreno._terrain_mesh.material_override
			terreno._terrain_mesh.add_child(piece)
			built.append(piece_mesh)
			made += 1

	print("Terreno en %d trozos de %d x %d vertices" % [made, per_chunk + 1, per_chunk + 1])
	return built
