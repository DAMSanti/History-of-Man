class_name TerrainSurround
extends Node3D
## Las ocho casillas de alrededor del recuadro jugable.
##
## Existe por un motivo puramente visual pero importante: sin ellas el mapa se
## corta a cuchillo y detrás no hay nada. Con ellas el valle sigue hacia el
## horizonte y se entiende que el recuadro es un trozo de algo más grande, que
## es exactamente lo que es.
##
## El relieve NO se inventa: sale del MDT REGIONAL, el mismo de la capa de
## Cantabria. Es basto —111 m por muestra frente a los 5 del recuadro— pero es
## terreno real, y a la distancia a la que se ven la resolución sobra.
##
## Lo que SÍ hay que corregir es la cota. A 111 m por muestra el MDT regional
## se traga los valles estrechos: donde el local dice garganta a 95 m, el
## regional promedia la meseta de alrededor y dice 215. Medido en el borde del
## recuadro de Los Pendios: **119 unidades de desfase medio y 143 de máximo**.
## Sin corregirlo, las casillas salen flotando muy por encima del mapa y con un
## cortado enorme entre medias, que es exactamente como se veían.
##
## La corrección se calcula EN LA COSTURA —la diferencia exacta entre lo que
## dice el terreno jugable y lo que dice el regional en ese mismo punto— y se
## desvanece hacia fuera. Así el empalme es continuo y lo lejano sigue estando
## a su altura general.
##
## Llevan LA MISMA textura que el recuadro jugable, con el mismo shader
## triplanar. No cuesta memoria de vídeo —es el mismo material compartido— y
## lo único que se paga es el sombreado de los píxeles que ocupan, que al
## verse casi siempre en escorzo contra el horizonte son pocos.
##
## Van SIN apagar: se ven exactamente igual que el tablero. Quien marca el
## límite es el corte vertical del borde —una pared, no un tinte—, así que no
## hace falta estropear el color para saber dónde se acaba el mapa.

## Si las casillas de fuera llevan la textura del terreno o el gris plano de
## antes.
@export var textured: bool = true

## Cuánto se apagan respecto al recuadro jugable, de 0 a 1. Con 0 son
## indistinguibles del mapa y se pierde el límite; con 1 vuelven a ser una
## plancha gris.
## Cuánto se apagan respecto al recuadro jugable.
##
## En CERO: las casillas de fuera se ven exactamente igual que el tablero.
## Estuvieron apagadas —0,40 y 0,22, luego 0,28 y 0,14— con el argumento de
## que así se distingue dónde se juega, pero el límite ya lo marca el corte
## vertical del borde, que es una pared y se ve desde cualquier ángulo. Apagar
## además el color era resolver dos veces el mismo problema, y la segunda vez
## estropeaba el paisaje.
##
## Se dejan como exports por si alguna vez conviene volver a separarlos.
@export_range(0.0, 1.0) var outside_desaturation: float = 0.0
@export_range(0.0, 1.0) var outside_dim: float = 0.0

## Vértices por lado de cada casilla.
##
## Es lo que decide si el contorno se ve igual que el tablero o como una loma
## lisa. Con 128 vértices sobre 4 km salen 32 m por vértice, ocho veces más
## basto que los 4 m del recuadro jugable —1025 vértices sobre los mismos
## 4 km—, y por eso las casillas parecían de plastilina al lado del mapa.
##
## Subirlo cuesta geometría y nada más: son ocho casillas, así que el total va
## con el CUADRADO de este número por ocho. En 128 son 131.000 vértices; en
## 513, 2,1 millones; en 1025 —paridad con el tablero— son 8,4 millones, que
## es más de lo que aguanta el presupuesto de fotograma.
##
## No sirve de nada subirlo por encima de lo que da el MDT del contorno: con
## un dato de 15 m por muestra, mallar cada 4 m sólo interpola.
@export var resolution: int = 513

## Color de las casillas de fuera cuando van SIN textura. Gris frío y plano.
const OUTSIDE_COLOR := Color(0.38, 0.39, 0.40)

## Uno solo para las ocho: es el mismo material y compartirlo ahorra siete
## duplicados del shader.
var _shared_material: Material

## Cota más alta de todo el contorno, en unidades de mundo. Decide hasta dónde
## tiene que llegar la normalización de altura del shader.
var _highest: float = -1e9

## LAS LÁMINAS DE AGUA de las casillas que tienen cauce. Ver [aplicar_configuracion].
var laminas: Array[MeshInstance3D] = []

var _terreno: TerrainGenerator = null
var _agua_material: ShaderMaterial = null


## Construye las ocho casillas alrededor del recuadro.
##
## `region` es el MDT regional; `local` el del recuadro, que es quien sabe a
## qué latitud y longitud corresponde cada esquina.
func build(terrain: TerrainGenerator, region: HeightmapData,
		local: HeightmapData) -> void:
	if region == null or local == null or terrain == null:
		return

	_highest = -1e9
	_terreno = terrain
	# El ajuste «Agua» enciende y apaga la lámina en caliente, igual que en el recuadro.
	if not is_in_group(Configuracion.GRUPO):
		add_to_group(Configuracion.GRUPO)

	var size_x := float(terrain.terrain_size.x)
	var size_z := float(terrain.terrain_size.y)

	var cache := _load_cache(terrain, region)
	if cache != null:
		for mesh in cache.tile_meshes:
			var instance := MeshInstance3D.new()
			instance.name = "Fuera_cache_%d" % get_child_count()
			instance.mesh = mesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
		for i in range(cache.lamina_meshes.size()):
			_montar_la_lamina(cache.lamina_meshes[i], cache.lamina_origenes[i], i)
		_highest = cache.highest
		terrain.extend_height_ceiling(_highest)
		_shared_material = _make_material(terrain)
		for child in get_children():
			if child is MeshInstance3D and not laminas.has(child):
				(child as MeshInstance3D).material_override = _shared_material
		aplicar_configuracion()
		return

	# Grados de latitud y longitud que abarca UNA casilla, sacados de lo que
	# abarca el recuadro jugable dentro del mapa local
	var local_size := local.get_world_size_meters()
	if local_size.x <= 0.0 or local_size.y <= 0.0:
		return

	var lon_span := (local.lon_east - local.lon_west) \
		* (size_x * terrain.meters_per_unit / local_size.x)
	var lat_span := (local.lat_north - local.lat_south) \
		* (size_z * terrain.meters_per_unit / local_size.y)

	# Esquina noroeste del recuadro jugable, en grados
	var origin_lon := local.lon_west + (local.lon_east - local.lon_west) \
		* (terrain.heightmap_region_offset.x / local_size.x)
	var origin_lat := local.lat_north - (local.lat_north - local.lat_south) \
		* (terrain.heightmap_region_offset.y / local_size.y)

	var built_meshes: Array[ArrayMesh] = []
	var aguas: Array[ArrayMesh] = []
	var origenes: Array[Vector3] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				continue  # el centro es el mapa de verdad
			# Las cuatro casillas EN ESQUINA van a la mitad de resolución. Son
			# las que caen en diagonal, o sea las que menos se miran y las
			# que están más lejos de la costura, que es donde se nota el
			# salto de detalle. Ahorra un 37% de la geometría del contorno
			# sin que se aprecie.
			var tile_resolution := resolution
			if dx != 0 and dz != 0:
				tile_resolution = maxi(resolution / 2, 8)
			var malla: ArrayMesh = await _build_tile(terrain, region, dx, dz,
				origin_lon, origin_lat, lon_span, lat_span, size_x, size_z,
				tile_resolution, aguas, origenes)
			built_meshes.append(malla)

	# AHORA, con las ocho casillas hechas y sabiendo hasta dónde suben: el
	# shader normaliza la cota contra el techo del recuadro jugable y satura
	# lo que se pase, así que alrededor —donde hay monte más alto— salía todo
	# pintado de roca. Se sube el techo antes de fabricar el material para que
	# la copia salga ya con las bandas buenas.
	terrain.extend_height_ceiling(_highest)

	_shared_material = _make_material(terrain)
	for child in get_children():
		if child is MeshInstance3D and not laminas.has(child):
			(child as MeshInstance3D).material_override = _shared_material
	aplicar_configuracion()

	_save_cache(terrain, region, built_meshes, aguas, origenes)


## Corrección de cota para un punto, medida CONTRA EL TERRENO JUGABLE.
##
## Antes esto se hacía con 64 muestras del contorno y se tomaba la más cercana,
## o sea que entre muestra y muestra el ajuste era escalonado: quedaba un
## desnivel de hasta 43 unidades y se veía el canto del mapa como una franja
## oscura entre el terreno y las casillas. Ese era el «margen».
##
## Ahora se calcula por vértice y es EXACTO en el borde: se recorta el punto
## contra el recuadro, se mira cuánto dice el terreno jugable ahí y cuánto dice
## el MDT del contorno en esa misma coordenada, y la diferencia es la
## corrección. A distancia cero los dos puntos son el mismo, así que el empalme
## encaja al milímetro.
func _seam_offset(terrain: TerrainGenerator, region: HeightmapData,
		point: Vector2, size_x: float, size_z: float,
		origin_lon: float, origin_lat: float,
		lon_span: float, lat_span: float, blend_distance: float) -> float:
	# El punto del borde más cercano
	var edge := Vector2(
		clampf(point.x, 0.0, size_x), clampf(point.y, 0.0, size_z))
	var distance := point.distance_to(edge)

	var played := terrain.get_height_at(Vector3(edge.x, 0.0, edge.y))

	var lon := origin_lon + (edge.x / size_x) * lon_span
	var lat := origin_lat - (edge.y / size_z) * lat_span
	var elevation := region.sample_bilinear(
		region.u_for_lon(lon), region.v_for_lat(lat))
	var outside := (elevation - terrain.sea_level) 		/ terrain.meters_per_unit * terrain.vertical_exaggeration

	var offset := played - outside

	# Se desvanece hacia fuera: junto al borde manda el ajuste exacto, y lejos
	# el relieve queda a su altura real sin arrastrar la corrección
	var t := clampf(distance / maxf(blend_distance, 1.0), 0.0, 1.0)
	return offset * (1.0 - t * t)


func _build_tile(terrain: TerrainGenerator, region: HeightmapData,
		dx: int, dz: int, origin_lon: float, origin_lat: float,
		lon_span: float, lat_span: float, size_x: float, size_z: float,
		resolution: int, aguas: Array[ArrayMesh], origenes: Array[Vector3]) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# El shader lee DOS atributos más que esta malla no tenía, y sin ellos no
	# se ve mal: se ve absurdo.
	#
	# COLOR.a es la lámina de agua de los cauces. Sin array de color, Godot da
	# blanco por defecto —alfa 1— y las ocho casillas saldrían siendo un mar.
	# COLOR.rg es la dirección de la corriente, centrada en 0,5. Se rellena en
	# seco y luego se pinta el agua encima, allí donde el MDT del contorno
	# traiga cauce.
	#
	# UV2 lleva la curvatura y una variación de parcela, centradas también en
	# 0,5. Sin ellas valdrían 0, que el shader lee como «convexo del todo» y
	# tiñe el terreno entero con la variación equivocada.
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	# El shader escribe NORMAL_MAP, y eso EXIGE tangentes. Sin ellas el mapa
	# de normales no se aplica y el terreno sale liso y plastificado: era la
	# mitad de la diferencia de aspecto con el recuadro jugable.
	var tangents := PackedFloat32Array()

	var count := resolution * resolution
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	uv2.resize(count)
	tangents.resize(count * 4)
	colors.fill(Color(0.5, 0.5, 0.0, 0.0))

	# Y LO MISMO EN CRUDO, para tejer la lámina de agua al final: el cauce, la corriente y
	# la cota de cada vértice. El color de arriba ya no basta desde que la casilla tiene
	# lámina propia —lleva la corriente comprimida a 0..1 y no lleva altura ninguna—.
	var alturas := PackedFloat32Array()
	var rios := PackedFloat32Array()
	var flujos := PackedVector2Array()
	alturas.resize(count)
	rios.resize(count)
	flujos.resize(count)

	# El borde SE SOLAPA medio vértice con el recuadro jugable: si encajaran
	# justo, la diferencia de resolución entre los 5 m del local y los 111 m
	# del regional dejaría una rendija por la que se ve el cielo.
	# Solape: la casilla se estira respecto a SU PROPIO centro, no al del
	# recuadro. Estirando respecto al centro del mapa las casillas se alejaban
	# en vez de meterse debajo, y por eso quedaba la rendija: el borde interior
	# de la casilla acababa a 123 unidades por FUERA del mapa en vez de por
	# dentro.
	#
	# Como en la costura las dos cotas coinciden exactamente, el trozo que se
	# mete debajo no se ve y en cambio no deja resquicio.
	var overlap := 1.04
	var tile_centre_x := (float(dx) + 0.5) * size_x
	var tile_centre_z := (float(dz) + 0.5) * size_z

	for z in range(resolution):
		for x in range(resolution):
			var u := float(x) / float(resolution - 1)
			var v := float(z) / float(resolution - 1)

			# Posición en el mundo local, desplazada a la casilla que toca
			var world_x := (float(dx) + u) * size_x
			var world_z := (float(dz) + v) * size_z
			# Estirada respecto al centro de la propia casilla
			world_x = tile_centre_x + (world_x - tile_centre_x) * overlap
			world_z = tile_centre_z + (world_z - tile_centre_z) * overlap

			# La coordenada geográfica se deriva de la posición YA ESTIRADA,
			# no de la del vértice sin estirar. Si no, la cota que se muestrea
			# es la de un sitio y el vértice está en otro: el desfase era del
			# tamaño del solape y volvía a abrir la costura.
			var lon := origin_lon + (world_x / size_x) * lon_span
			var lat := origin_lat - (world_z / size_z) * lat_span

			var mu := region.u_for_lon(lon)
			var mv := region.v_for_lat(lat)
			var elevation := region.sample_bilinear(mu, mv)

			# El agua continúa hacia fuera. Sin esto el Nansa llegaba al borde
			# del recuadro y se cortaba en seco contra la casilla de al lado,
			# que es lo que más delata que el mapa se acaba ahí.
			#
			# Mismo formato de color que el terreno jugable —rg sentido de la
			# corriente, b agua quieta, a lámina— para que el shader no sepa
			# distinguir un vértice de dentro de uno de fuera.
			var wetness := region.sample_river_mask(mu, mv)
			rios[z * resolution + x] = wetness
			if wetness > 0.01:
				var flow := region.sample_flow_meters(
					mu * region.get_world_size_meters().x,
					mv * region.get_world_size_meters().y)
				flujos[z * resolution + x] = flow
				colors[z * resolution + x] = Color(
					flow.x * 0.5 + 0.5,
					flow.y * 0.5 + 0.5,
					1.0 if flow.length_squared() < 0.01 else 0.0,
					wetness)
			# Misma escala vertical que el terreno jugable, o el empalme daría
			# un escalón en el borde
			var height := (elevation - terrain.sea_level) \
				/ terrain.meters_per_unit * terrain.vertical_exaggeration

			# Y corregida contra la costura: sin esto queda 120 unidades por
			# encima del mapa, flotando
			height += _seam_offset(terrain, region, Vector2(world_x, world_z),
				size_x, size_z, origin_lon, origin_lat, lon_span, lat_span,
				size_x * 0.55)

			# El trozo que se mete DEBAJO del mapa jugable se hunde. Sin esto
			# las dos mallas quedan exactamente a la misma cota y se pelean por
			# el mismo pixel: el borde salia como un encaje de manchas verdes y
			# grises, que es z-fighting de manual.
			#
			# En el borde mismo el hundimiento es cero -la costura sigue siendo
			# exacta- y crece deprisa hacia dentro, donde ya lo tapa el terreno.
			var inside_x: float = maxf(0.0, minf(world_x, size_x - world_x))
			var inside_z: float = maxf(0.0, minf(world_z, size_z - world_z))
			var inside: float = minf(inside_x, inside_z)
			if world_x >= 0.0 and world_x <= size_x 					and world_z >= 0.0 and world_z <= size_z:
				height -= inside * 0.35

			vertices[z * resolution + x] = Vector3(world_x, height, world_z)
			alturas[z * resolution + x] = height
			normals[z * resolution + x] = Vector3.UP

	# Segunda pasada: las MISMAS cuentas por vértice que hace el recuadro
	# jugable. Antes aquí sólo se ponían normales y todo lo demás iba a un
	# valor neutro, y ése era el motivo de que el contorno se viera plano:
	#
	#   · sin CURVATURA no hay barrancos oscuros ni contraste cóncavo/convexo,
	#     así que una ladera entera salía del mismo color;
	#   · sin VARIACIÓN DE PARCHE no hay manchas de pasto y matorral;
	#   · sin TANGENTE el mapa de normales no se aplica.
	#
	# El ruido de parcheo se pide prestado al terreno para que las manchas
	# crucen la costura en vez de cambiar de tapiz en el borde.
	var spacing_x := size_x * overlap / float(resolution - 1)
	var spacing_z := size_z * overlap / float(resolution - 1)
	var noise := terrain.get_macro_noise()

	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var here := vertices[idx].y

			var left := vertices[z * resolution + maxi(x - 1, 0)].y
			var right := vertices[z * resolution + mini(x + 1, resolution - 1)].y
			var up := vertices[maxi(z - 1, 0) * resolution + x].y
			var down := vertices[mini(z + 1, resolution - 1) * resolution + x].y

			var dhdx := (right - left) / (spacing_x * 2.0)
			var dhdz := (down - up) / (spacing_z * 2.0)
			normals[idx] = Vector3(-dhdx, 1.0, -dhdz).normalized()

			var tangent := Vector3(1.0, dhdx, 0.0).normalized()
			var t := idx * 4
			tangents[t] = tangent.x
			tangents[t + 1] = tangent.y
			tangents[t + 2] = tangent.z
			tangents[t + 3] = -1.0

			var laplacian := (left + right + up + down) * 0.25 - here
			var curvature := clampf(
				laplacian / maxf(terrain.curvature_scale, 0.001), -1.0, 1.0)

			var macro := 0.5
			if noise:
				macro = noise.get_noise_2d(
					vertices[idx].x, vertices[idx].z) * 0.5 + 0.5

			uv2[idx] = Vector2(curvature * 0.5 + 0.5, macro)

	# El orden de los vertices es el MISMO que usa TerrainGenerator para el
	# mapa jugable, y tiene que serlo: con el orden invertido las caras miran
	# hacia abajo, el motor las descarta por back-face culling y las casillas
	# solo asoman donde la ladera se curva lo suficiente para enseñar el
	# reverso. Se veian como cintas grises flotando en el cielo.
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var top_left := z * resolution + x
			var top_right := top_left + 1
			var bottom_left := top_left + resolution
			var bottom_right := bottom_left + 1
			indices.append_array([top_left, top_right, bottom_left])
			indices.append_array([top_right, bottom_right, bottom_left])

	# Normales de verdad, para que el sombreado enseñe el relieve.
	#
	# OJO: se REASIGNA el resultado. En Godot los PackedVector3Array se pasan
	# por VALOR, asi que la version anterior -que las modificaba dentro de la
	# funcion- trabajaba sobre una copia y dejaba las originales apuntando
	# todas hacia arriba. El fondo salia iluminado plano, sin distinguir un
	# valle de un monte: eso era lo de «las normales mal».
	# Las normales ya salen de la pendiente del campo de alturas, arriba: es
	# la misma cuenta que hace el recuadro jugable y encaja en la costura.

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := _mesh_with_lods(arrays)

	var instance := MeshInstance3D.new()
	instance.name = "Fuera_%d_%d" % [dx, dz]
	instance.mesh = mesh

	# No proyecta sombra sobre el mapa jugable: sería sombra de terreno que no
	# se juega cayendo sobre terreno que sí. El material se pone después, en
	# `build`, cuando ya se sabe hasta dónde sube el conjunto.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

	var box := mesh.get_aabb()
	_highest = maxf(_highest, box.position.y + box.size.y)

	# Y LA LÁMINA DE AGUA de esta casilla, con el mismo tejedor que el recuadro jugable.
	#
	# **El fallo que cierra** (2026-09-19, A/B de la misma vista en el sitio 56): con el
	# ajuste «Agua» en bajo el río cruzaba la raya del mapa y seguía; en alto **se cortaba
	# en una línea recta justo en el borde**. No era la costura ni el cauce —el contorno
	# trae su agua y la pinta en el suelo—: es que desde Alto el río del recuadro se dibuja
	# con una malla de agua encima, y aquí no había ninguna. El agua pintada en el suelo es
	# mucho más apagada, así que el corte salía donde se acababa la malla.
	#
	# Devuelve `null` en una casilla de monte sin cauces, que es lo normal.
	var arriba := 0.03 / maxf(terrain.meters_per_unit, 0.0001) * terrain.vertical_exaggeration
	var sube := AguaDelCauce.LAMINA_SUBE_M / maxf(terrain.meters_per_unit, 0.0001)
	var agua: ArrayMesh = await MallaDelTerreno.tejer_la_lamina(alturas, rios, flujos,
		resolution, spacing_x, spacing_z, arriba, sube * terrain.vertical_exaggeration)
	if agua != null:
		var origen := Vector3(vertices[0].x, 0.0, vertices[0].z)
		aguas.append(agua)
		origenes.append(origen)
		_montar_la_lamina(agua, origen, aguas.size() - 1)
	return mesh


## Cuelga una lámina ya tejida en su sitio. La posición va en el nodo y no en los vértices
## porque [MallaDelTerreno.tejer_la_lamina] teje desde el origen de SU rejilla, y la de una
## casilla del contorno empieza a un tile de distancia del mapa.
func _montar_la_lamina(malla: ArrayMesh, origen: Vector3, cual: int) -> void:
	if malla == null:
		return
	var nodo := MeshInstance3D.new()
	nodo.name = "AguaDeFuera_%d" % cual
	nodo.mesh = malla
	nodo.position = origen
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _agua_material == null:
		_agua_material = MallaDelTerreno.material_del_agua(
			_terreno.meters_per_unit / maxf(_terreno.vertical_exaggeration, 0.0001))
	nodo.material_override = _agua_material
	add_child(nodo)
	laminas.append(nodo)


## El ajuste «Agua», en caliente y con la MISMA regla que el recuadro jugable: la lámina se
## enciende desde [MallaDelTerreno.LAMINA_DESDE], y sólo entonces el shader del suelo hunde
## el lecho debajo. Con reglas distintas a los dos lados de la raya el río cambiaba de
## aspecto al cruzarla, que es justo lo que se veía.
func aplicar_configuracion() -> void:
	if _terreno == null:
		return
	var nivel := MallaDelTerreno.nivel_del_agua(_terreno.agua_con_niveles)
	var encendida := nivel >= MallaDelTerreno.LAMINA_DESDE
	for nodo: MeshInstance3D in laminas:
		nodo.visible = encendida
	if _agua_material != null:
		_agua_material.set_shader_parameter("nivel_de_agua", nivel)
	var suelo := _shared_material as ShaderMaterial
	if suelo != null:
		var hondo := AguaDelCauce.LECHO_M * _terreno.vertical_exaggeration
		hondo /= maxf(_terreno.meters_per_unit, 0.0001)
		suelo.set_shader_parameter("lecho_hondo",
			hondo if encendida and not laminas.is_empty() else 0.0)


## Corte vertical en el límite del recuadro jugable.
##
## Es una pared que baja desde el borde del terreno, no una línea pintada. La
## diferencia importa: un ribete translúcido se confunde con el paisaje y deja
## que el color y el gris se disuelvan el uno en el otro. Una pared da un
## CANTO, y un canto se lee como lo que es —aquí se acaba el mapa— desde
## cualquier ángulo y sin depender de la iluminación.
##
## Además tapa por completo cualquier resquicio entre el recuadro y las
## casillas de fuera, que es de donde venían las rendijas.
## EL MAR DE LAS OCHO CASILLAS, en forma de marco alrededor del recuadro jugable.
##
## **El fallo que cierra** (2026-09-17, jugando): «los ríos/rías en los mapas costeros se
## cortan cuando llegan a las 8 casillas que rodean la casilla principal». No era el
## relieve ni el cauce —el contorno trae su agua de OSM y la pinta igual que el recuadro—:
## era **el mar**. La lámina de agua de [TerrainGenerator._create_water] mide exactamente
## `terrain_size`, o sea el recuadro jugable, así que en un valle de costa la ría llegaba a
## la raya y se acababa el agua de golpe. Tierra adentro no se notaba, y por eso la queja
## hablaba de mapas costeros.
##
## Va como MARCO y no como un plano grande por debajo: dos láminas a la misma cota se
## pelean por el mismo píxel, y el mar del valle es el que lleva las olas finas.
func montar_el_mar(terrain: TerrainGenerator) -> void:
	var agua := terrain.get_node_or_null("Water") as MeshInstance3D
	if agua == null:
		return
	var ancho := float(terrain.terrain_size.x)
	var alto := float(terrain.terrain_size.y)
	var malla := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	# Las cuatro piezas del marco: arriba, abajo, izquierda y derecha del recuadro.
	for pieza: Rect2 in [
			Rect2(-ancho, -alto, ancho * 3.0, alto),
			Rect2(-ancho, alto, ancho * 3.0, alto),
			Rect2(-ancho, 0.0, ancho, alto),
			Rect2(ancho, 0.0, ancho, alto)]:
		var base := vertices.size()
		for esquina: Vector2 in [pieza.position, pieza.position + Vector2(pieza.size.x, 0.0),
				pieza.position + pieza.size, pieza.position + Vector2(0.0, pieza.size.y)]:
			vertices.append(Vector3(esquina.x, 0.0, esquina.y))
			normales.append(Vector3.UP)
			uvs.append(Vector2(esquina.x / maxf(ancho, 0.001),
				esquina.y / maxf(alto, 0.001)))
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var fuera := get_node_or_null("MarDeFuera") as MeshInstance3D
	if fuera == null:
		fuera = MeshInstance3D.new()
		fuera.name = "MarDeFuera"
		add_child(fuera)
	fuera.mesh = malla
	fuera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# EL MISMO MATERIAL que el mar del valle: si fuera otro se vería el cambio justo en la
	# raya, que es lo que se viene a quitar. Sin olas propias: el marco tiene cuatro
	# vértices por pieza y la ola vive en el vértice, así que de lejos es lámina lisa.
	fuera.material_override = agua.material_override
	fuera.position = agua.position


func build_border(terrain: TerrainGenerator) -> void:
	var size_x := float(terrain.terrain_size.x)
	var size_z := float(terrain.terrain_size.y)
	# UN PASO POR MUESTRA DEL TERRENO, no 256 por lado.
	#
	# **El fallo que cierra** (2026-09-19, jugando): «hay un salto… placas grises metidas en
	# el terreno». Con 256 pasos sobre un lado de 4.505 m salía un vértice cada 17,6 m, y el
	# borde de arriba de este faldón es una RECTA entre vértice y vértice. Donde el terreno
	# baja entre dos muestras —un desfiladero, el tajo por donde sale el río— la recta pasa
	# por encima del suelo y el faldón asoma: una tapa gris oscura sobre el valle, del color
	# de este material. Se veía en «Cueva los pendios», justo donde el río corta el borde.
	#
	# El terreno del valle va a 5 m por muestra, así que el faldón va igual: así su borde no
	# puede saltarse un tajo.
	var steps := maxi(int(size_x / maxf(terrain.meters_per_unit, 1.0)), 256)
	var drop := 260.0
	# Y un dedo por debajo del suelo, para que no asome por el redondeo de la interpolación.
	var margen := 1.5

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	for side in range(4):
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var point := Vector2.ZERO
			match side:
				0: point = Vector2(t * size_x, 0.0)
				1: point = Vector2(size_x, t * size_z)
				2: point = Vector2((1.0 - t) * size_x, size_z)
				_: point = Vector2(0.0, (1.0 - t) * size_z)

			# Arriba, justo en la cota del terreno; abajo, hundido. Se toma la cota MÁS BAJA
			# de un pequeño entorno: si el faldón se queda por debajo del suelo no se ve, y
			# si se queda por encima se ve siempre.
			var paso := size_x / float(steps)
			var top := terrain.get_height_at(Vector3(point.x, 0.0, point.y))
			for lado_x: float in [-paso, paso]:
				top = minf(top, terrain.get_height_at(
					Vector3(clampf(point.x + lado_x, 0.0, size_x), 0.0, point.y)))
				top = minf(top, terrain.get_height_at(
					Vector3(point.x, 0.0, clampf(point.y + lado_x, 0.0, size_z))))
			top -= margen
			vertices.append(Vector3(point.x, top, point.y))
			vertices.append(Vector3(point.x, top - drop, point.y))

	var pairs := vertices.size() / 2
	for i in range(pairs - 1):
		var a := i * 2
		indices.append_array([a, a + 1, a + 2])
		indices.append_array([a + 1, a + 3, a + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = "Limite"
	instance.mesh = mesh

	var material := StandardMaterial3D.new()
	# Más oscuro que las casillas de fuera: el canto tiene que separar, no
	# fundirse con lo de detrás
	material.albedo_color = Color(0.16, 0.16, 0.17)
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


static func _compute_normals(vertices: PackedVector3Array,
		indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	var triangle := 0
	while triangle + 2 < indices.size():
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		# El orden del producto es (c-a)×(b-a) y no al reves. Con el orden de
		# vertices del terreno jugable -que es el correcto para que las caras
		# miren arriba- el producto directo da la normal hacia ABAJO, y con
		# ella el sombreado sale invertido: las laderas al sol salen oscuras.
		var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += face
		normals[b] += face
		normals[c] += face
		triangle += 3

	for i in range(normals.size()):
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	return normals


## El material de las casillas de fuera.
##
## Es el MISMO shader triplanar del recuadro jugable, duplicado para poder
## apagarlo sin tocar el original. Duplicar un ShaderMaterial no duplica sus
## texturas: son el mismo recurso, así que esto no cuesta memoria de vídeo.
##
## Se apaga con la máscara de región que el shader ya traía, alimentada con
## una textura de un solo téxel negro: así «fuera» vale 1 en todas partes y el
## apagado es uniforme, sin tener que dibujar ninguna máscara de verdad.
func _make_material(terrain: TerrainGenerator) -> Material:
	if not textured:
		return _flat_material()

	var source := terrain.get_terrain_material()
	if source == null:
		# Sin shader montado -el editor, o si esto se llamara antes de generar
		# el terreno- se cae al gris de siempre. Se avisa por consola: si no,
		# las casillas salen grises y no hay forma de saber que ha pasado.
		push_warning("Alrededores sin textura: el terreno aun no tiene shader")
		return _flat_material()

	var material: ShaderMaterial = source.duplicate()

	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color.BLACK)
	material.set_shader_parameter("region_mask_tex", ImageTexture.create_from_image(image))
	material.set_shader_parameter("use_region_mask", true)
	material.set_shader_parameter("region_world_size", Vector2.ONE)
	material.set_shader_parameter("outside_desaturation", outside_desaturation)
	material.set_shader_parameter("outside_dim", outside_dim)

	# El overlay de recursos es cosa del tablero: fuera no hay nada que marcar
	material.set_shader_parameter("use_overlay", false)

	# NI EL MAPA DE HUMEDAD, que es del recuadro jugable y sólo cubre sus 4,5 km. El shader
	# lo mapea con `humedad_extent`/`humedad_origen`, así que fuera del recuadro las UV se
	# salen de [0,1] y la textura se repite: **bandas rectas y paralelas por todo el
	# contorno, ignorando el relieve**. Se coló al hacer que el suelo de bosque siguiera a la
	# humedad (2026-09-17, GRAFICOS §7.7): el contorno duplica este material y heredaba el
	# mapa sin que nadie lo apagara. Sin él vuelve a la máscara de bosque de siempre, que es
	# procedural y no depende de dónde esté el vértice.
	material.set_shader_parameter("use_humedad", false)

	return material


func _flat_material() -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = OUTSIDE_COLOR
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Malla con niveles de detalle generados.
##
## Medido: el contorno cuesta 34 ms de fotograma con 2,6 millones de
## triangulos, y se ve casi siempre desde tres kilometros. Pagar la malla fina
## a esa distancia es tirar el presupuesto: a partir de cierta lejania, un
## vertice cada ocho metros y uno cada treinta y dos dan el mismo pixel.
##
## `ImporterMesh.generate_lods` hace la simplificacion y Godot elige el nivel
## solo, por cuanto ocupa la malla en pantalla. Si no estuviera disponible en
## tiempo de ejecucion se cae a la malla de siempre, que es lo que habia.
func _mesh_with_lods(arrays: Array) -> ArrayMesh:
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if not importer.has_method("generate_lods"):
		var plain := ArrayMesh.new()
		plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return plain

	# 25 grados para fundir normales y 60 para partirlas: son los valores con
	# los que Godot importa terreno, y en una malla de campo de alturas -sin
	# aristas vivas- apenas importan.
	importer.generate_lods(25.0, 60.0, [])
	var built := importer.get_mesh()
	return built if built != null else importer.get_mesh()


## Ruta de la cache para el contorno de `region`, o "" si no es cacheable.
##
## Se deriva del propio fichero del MDT de contorno, igual que
## TerrainGenerationCache: "site_9000_surround.res" cachea en
## "site_9000_surround_mesh_r513.res", al lado.
func _cache_path(region: HeightmapData) -> String:
	var src := region.resource_path
	if src.is_empty():
		return ""
	return "%s/%s_mesh_r%d.res" % [src.get_base_dir(), src.get_file().get_basename(), resolution]


func _cache_matches(cache: TerrainSurroundCache, terrain: TerrainGenerator,
		region: HeightmapData) -> bool:
	return cache.version == TerrainSurroundCache.CACHE_VERSION \
		and cache.region_pipeline_version == region.pipeline_version \
		and cache.resolution == resolution \
		and cache.terrain_size == terrain.terrain_size \
		and is_equal_approx(cache.meters_per_unit, terrain.meters_per_unit) \
		and is_equal_approx(cache.vertical_exaggeration, terrain.vertical_exaggeration) \
		and is_equal_approx(cache.sea_level, terrain.sea_level) \
		and cache.tile_meshes.size() == 8 \
		and cache.lamina_meshes.size() == cache.lamina_origenes.size()


func _load_cache(terrain: TerrainGenerator, region: HeightmapData) -> TerrainSurroundCache:
	var path := _cache_path(region)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var cache := ResourceLoader.load(path) as TerrainSurroundCache
	if cache == null or not _cache_matches(cache, terrain, region):
		return null
	return cache


func _save_cache(terrain: TerrainGenerator, region: HeightmapData,
		tile_meshes: Array[ArrayMesh], aguas: Array[ArrayMesh],
		origenes: Array[Vector3]) -> void:
	var path := _cache_path(region)
	if path.is_empty() or tile_meshes.size() != 8:
		return

	var cache := TerrainSurroundCache.new()
	cache.version = TerrainSurroundCache.CACHE_VERSION
	cache.region_pipeline_version = region.pipeline_version
	cache.resolution = resolution
	cache.terrain_size = terrain.terrain_size
	cache.meters_per_unit = terrain.meters_per_unit
	cache.vertical_exaggeration = terrain.vertical_exaggeration
	cache.sea_level = terrain.sea_level
	cache.tile_meshes = tile_meshes
	cache.lamina_meshes = aguas
	cache.lamina_origenes = PackedVector3Array(origenes)
	cache.highest = _highest

	var t0 := Time.get_ticks_msec()
	if ResourceSaver.save(cache, path) != OK:
		push_warning("No se pudo guardar la cache del contorno en " + path)
	else:
		print("[TIMING]   cache de contorno guardada (%s): %d ms" % [
			path, Time.get_ticks_msec() - t0])
