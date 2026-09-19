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
## Por cuadro de la rejilla, 1 si se parte de arriba-izquierda a abajo-derecha: ver
## [diagonal_principal]. Lo llena el bucle de índices y lo reusan los trozos.
var _diagonales := PackedByteArray()


func _init(generador: TerrainGenerator) -> void:
	terreno = generador


## Crea el mesh del terreno
func _create_terrain_mesh(ceder: Callable = Callable()) -> void:
	# Limpiar mesh anterior
	if terreno._terrain_mesh:
		terreno._terrain_mesh.queue_free()
	if terreno._terrain_collision:
		terreno._terrain_collision.queue_free()

	if terreno._gen_cache != null:
		await _create_terrain_mesh_from_cache(terreno._gen_cache, ceder)
		return

	var arrays := await _construir_arrays(ceder)

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

	if ceder.is_valid():
		await ceder.call()
	var tmat0 := Time.get_ticks_msec()
	terreno._apply_terrain_material()
	print("[TIMING]   material/texturas de terreno: %d ms" % (Time.get_ticks_msec() - tmat0))
	if ceder.is_valid():
		await ceder.call()

	terreno.add_child(terreno._terrain_mesh)
	_construir_simas()

	var chunk_meshes: Array[ArrayMesh] = []
	if terreno.terrain_chunks > 1:
		var tchunk0 := Time.get_ticks_msec()
		chunk_meshes = await _split_into_chunks(arrays, ceder)
		print("[TIMING]   _split_into_chunks: %d ms" % (Time.get_ticks_msec() - tchunk0))

	# Crear colisión. Sale del campo de alturas, no de la malla, asi que el
	# troceado no la toca.
	var tcol0 := Time.get_ticks_msec()
	_create_collision(single_mesh)
	print("[TIMING]   _create_collision: %d ms" % (Time.get_ticks_msec() - tcol0))

	await _save_generation_cache(single_mesh, chunk_meshes, ceder)


## Los arrays de la malla: vertices, normales, tangentes, color, UV e indices.
##
## Se construyen A MANO en vez de con SurfaceTool. SurfaceTool anade vertice a
## vertice desde GDScript y luego recalcula normales y tangentes promediando
## por cara: en una malla de un millon de vertices eso eran unos 35 segundos.
## Aqui las normales salen analiticamente del campo de alturas, que ademas de
## rapido es exacto: no hay que recorrer las caras.
func _construir_arrays(ceder: Callable = Callable()) -> Array:
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
		if ceder.is_valid() and z % 16 == 0:
			await ceder.call()
		var row := z * terreno.resolution
		var zu := maxi(z - 1, 0) * terreno.resolution
		var zd := mini(z + 1, terreno.resolution - 1) * terreno.resolution
		var dz_span := (mini(z + 1, terreno.resolution - 1) - maxi(z - 1, 0)) * step_z

		for x in range(terreno.resolution):
			var idx := row + x
			var height := terreno._height_map[idx]

			vertices[idx] = Vector3(float(x) * step_x, height, float(z) * step_z)
			# El color de vertice transporta la hidrografia entera al shader, y
			# va gratis porque el triplanar no usaba ninguno de sus canales:
			#   rg = sentido de la corriente, reescalado a 0..1
			#   b  = agua quieta (una laguna no desfila)
			#   a  = lamina de agua
			var flow: Vector2 = terreno._flow_map[idx] if idx < terreno._flow_map.size() else Vector2.ZERO
			var wetness: float = terreno._river_map[idx] if idx < terreno._river_map.size() else 0.0
			# Para dibujar, la corriente suavizada: ver [AguaDelCauce.corriente_suave].
			if wetness > 0.02 and terreno._river_map.size() >= terreno.resolution * terreno.resolution:
				flow = AguaDelCauce.corriente_suave(terreno._flow_map, terreno._river_map, terreno.resolution, x, z)
			colors[idx] = Color(
				flow.x * 0.5 + 0.5,
				flow.y * 0.5 + 0.5,
				1.0 if (wetness > 0.01 and flow.length_squared() < 0.01) else 0.0,
				wetness)
			# EL UV LLEVA DÓNDE ROMPE EL AGUA: x la caída del cauce, y la espuma de orilla. Iba
			# en coordenadas de mundo para texturizar, y el shader no lo leía: texturiza
			# por posición. Se calcula aquí y no en el shader para poder probarlo, y
			# sólo donde hay agua, que son pocas celdas. Ver [AguaDelCauce].
			if wetness >= AguaDelCauce.LINEA_DEL_AGUA:
				uvs[idx] = _agua_de_la_celda(x, z, step_x)

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
	#
	# SALVO EL RUEDO DE UNA SIMA. La rejilla del relieve tiene un punto cada
	# cinco metros, así que un agujero de dos no le cabe: sale cuadrado y del
	# tamaño de la rejilla. Ahí se quita la rejilla y se cose un embudo fino en su
	# sitio, ver [_construir_simas].
	var tidx0 := Time.get_ticks_msec()
	var simas := terreno.simas()
	var indices := PackedInt32Array()
	indices.resize((terreno.resolution - 1) * (terreno.resolution - 1) * 6)
	_diagonales.resize((terreno.resolution - 1) * (terreno.resolution - 1))
	var i := 0
	for z in range(terreno.resolution - 1):
		if ceder.is_valid() and z % 32 == 0:
			await ceder.call()
		for x in range(terreno.resolution - 1):
			if _en_el_ruedo_de_una_sima(simas,
					Vector2((float(x) + 0.5) * step_x, (float(z) + 0.5) * step_z)):
				continue
			var top_left := z * terreno.resolution + x
			var top_right := top_left + 1
			var bottom_left := (z + 1) * terreno.resolution + x
			var bottom_right := bottom_left + 1
			var principal := diagonal_principal(terreno._height_map, terreno.resolution, x, z)
			_diagonales[z * (terreno.resolution - 1) + x] = 1 if principal else 0
			_poner_el_cuadro(indices, i, top_left, top_right, bottom_left, bottom_right, principal)
			i += 6
	indices.resize(i)
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


## Cuánto se sale del círculo la boca de la sima, en proporción a su radio. Un
## agujero perfectamente redondo canta a geometría puesta.
const MORDIDA_DE_LA_BOCA := 0.30

## Cuánto se estrecha el pozo de la boca al fondo: a una doceava parte. Es lo
## que hace que la curva se note —el embudo de gravedad cae a plomo cerca del
## eje— sin que el fondo llegue a cerrarse del todo.
const ESTRECHO_DEL_POZO := 0.08

## A cuántos metros de hondura ya no se ve nada. Seis: lo justo para que se lea
## la roca de la boca y el ojo entienda que aquello sigue hacia abajo.
const OSCURO_A_LOS := 6.0


## Un triángulo de la pared de roca del pozo, con los datos por vértice que pide
## el shader del terreno. Orientado como [_muro].
func _roca_del_pozo(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3,
		hacia: Vector3) -> void:
	var giro := (p1 - p0).cross(p2 - p0)
	if giro.length_squared() < 0.000001:
		return
	var orden: Array[Vector3] = [p0, p1, p2]
	if giro.dot(hacia) < 0.0:
		orden = [p0, p2, p1]
	var normal := giro.normalized()
	if giro.dot(hacia) < 0.0:
		normal = -normal
	for v: Vector3 in orden:
		st.set_uv(_agua_del_punto(v))
		st.set_uv2(_uv2_del_punto(v))
		st.set_color(_color_del_punto(v))
		st.set_normal(normal)
		st.set_tangent(Plane(normal.cross(Vector3.UP).normalized(), -1.0))
		st.add_vertex(v)


## Un triángulo de la pared del pozo, con su color por vértice y mirando hacia
## `hacia`. El orden se elige y no se da por supuesto: la cara delantera es la
## que deja `(v1−v0)×(v2−v0)` hacia ese lado.
static func _muro(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3,
		hacia: Vector3, c0: Color, c1: Color, c2: Color) -> void:
	var giro := (p1 - p0).cross(p2 - p0)
	if giro.length_squared() < 0.000001:
		return
	var orden: Array = [[p0, c0], [p1, c1], [p2, c2]]
	if giro.dot(hacia) < 0.0:
		orden = [[p0, c0], [p2, c2], [p1, c1]]
	for v: Array in orden:
		st.set_color(v[1])
		st.add_vertex(v[0])


## La tangente del relieve en un punto, como la calcula la rejilla: a lo largo
## de +X, con la bitangente hacia +Z. Ver [_construir_arrays].
func _tangente_del_punto(p: Vector3) -> Plane:
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var dhdx := (terreno.get_height_at(p + Vector3(step_x, 0.0, 0.0))
		- terreno.get_height_at(p - Vector3(step_x, 0.0, 0.0))) / (2.0 * step_x)
	return Plane(Vector3(1.0, dhdx, 0.0).normalized(), -1.0)


## La normal del relieve en un punto, como la calcula la rejilla: del campo de
## alturas, no de las caras. Ver [_construir_arrays].
func _normal_del_punto(p: Vector3) -> Vector3:
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
	var dhdx := (terreno.get_height_at(p + Vector3(step_x, 0.0, 0.0))
		- terreno.get_height_at(p - Vector3(step_x, 0.0, 0.0))) / (2.0 * step_x)
	var dhdz := (terreno.get_height_at(p + Vector3(0.0, 0.0, step_z))
		- terreno.get_height_at(p - Vector3(0.0, 0.0, step_z))) / (2.0 * step_z)
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


## La curvatura y la mancha de un punto, como las calcula la rejilla para el
## shader —ver [_construir_arrays]—. Sin esto el parche de una sima se pintaba
## con otra capa y se veía un cerco más oscuro alrededor del agujero.
func _uv2_del_punto(p: Vector3) -> Vector2:
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
	var x := clampi(int(round(p.x / step_x)), 0, terreno.resolution - 1)
	var z := clampi(int(round(p.z / step_z)), 0, terreno.resolution - 1)
	var row := z * terreno.resolution
	var zu := maxi(z - 1, 0) * terreno.resolution
	var zd := mini(z + 1, terreno.resolution - 1) * terreno.resolution
	var left := maxi(x - 1, 0)
	var right := mini(x + 1, terreno.resolution - 1)
	var height := terreno._height_map[row + x]
	var laplacian := (terreno._height_map[row + left] + terreno._height_map[row + right]
		+ terreno._height_map[zu + x] + terreno._height_map[zd + x]) * 0.25 - height
	var curvature := clampf(laplacian / maxf(terreno.curvature_scale, 0.001), -1.0, 1.0)
	var macro := terreno._macro_noise.get_noise_2d(
		float(x) * step_x, float(z) * step_z) * 0.5 + 0.5
	return Vector2(curvature * 0.5 + 0.5, macro)


## La lámina del río, para Alto y Ultra (GRAFICOS §7.3): una malla aparte con las celdas
## de agua, a la cota de la superficie —el relieve LiDAR es el agua—, con el mismo color
## y UV que el terreno, y su shader. El terreno hunde el lecho debajo sólo al dibujar.
## Va entera y no troceada: son pocas celdas —un 2-3 % del valle—.
var lamina: MeshInstance3D = null

## A PARTIR DE QUÉ ESCALÓN de «Agua» hay lámina de río. Estaba escrito como un `2` suelto
## aquí dentro, y el contorno —que no tenía lámina— no podía preguntarlo: por eso al subir
## el ajuste el río del recuadro cambiaba de aspecto y el de las ocho casillas no.
const LAMINA_DESDE := 2

## EL AGUA SE DIBUJA ANTES QUE LA NIEBLA, y por eso va en prioridad negativa.
##
## Queja del usuario (2026-09-19): «cuando hay niebla, a medida que acerco la cámara, el
## agua del río aparece por encima de la niebla». Las dos son **materiales transparentes**
## —el agua lleva `blend_mix` y la niebla de valle se dibuja como una caja con
## `depth_test_disabled`—, y las dos estaban en prioridad 0: el orden entre ellas lo
## decidía la distancia, o sea el azar de dónde estuviera la cámara. Por eso «al acercarse».
##
## Se baja el AGUA en vez de subir la niebla porque los rótulos de parajes, nasas y trampas
## ya ocupan las prioridades 1 a 4 y tienen que seguir leyéndose por encima de la niebla.
## Queda: agua (-1) → niebla (0) → rótulos (1-4).
##
## **El arreglo es estructural y NO está confirmado en captura.** Dos materiales
## transparentes en la misma prioridad se ordenan por distancia a la cámara, así que el
## orden cambiaba al moverse —que es exactamente lo que se veía—; darle un orden explícito
## quita la ambigüedad por construcción. Pero el A/B que se intentó el 2026-09-19 **no
## sirve**: la niebla de valle se anima con un ruido 3D, las dos corridas fueron a 40 y a
## 21 fps, y las capturas cogen el ruido en fases distintas —35,8/255 de diferencia media
## repartida por todo el recorte, que es niebla y no agua—. Para confirmarlo hace falta una
## sonda que **congele la fase de la niebla** en las dos pasadas.
const DEBAJO_DE_LA_NIEBLA := -1


## El escalón de «Agua» que le toca a un terreno. Cero si ese terreno no los usa.
static func nivel_del_agua(con_niveles: bool) -> int:
	return int(Configuracion.graficos.get("agua", 1)) if con_niveles else 0


func construir_la_lamina(ceder: Callable = Callable()) -> void:
	if lamina != null:
		lamina.queue_free()
		lamina = null
	var res := terreno.resolution
	if terreno._river_map.size() < res * res or terreno._height_map.size() < res * res:
		return
	var paso_x := float(terreno.terrain_size.x) / float(res - 1)
	var paso_z := float(terreno.terrain_size.y) / float(res - 1)
	# Un pelo por encima: la lámina y la superficie del relieve son la misma cota.
	var encima := 0.03 / maxf(terreno.meters_per_unit, 0.0001) * terreno.vertical_exaggeration
	var sube := AguaDelCauce.LAMINA_SUBE_M / maxf(terreno.meters_per_unit, 0.0001)
	var tope := sube * terreno.vertical_exaggeration
	var malla_de_la_lamina: ArrayMesh = await tejer_la_lamina(terreno._height_map,
		terreno._river_map, terreno._flow_map, res, paso_x, paso_z, encima, tope, ceder)
	if malla_de_la_lamina == null:
		return
	lamina = MeshInstance3D.new()
	lamina.name = "LaminaDelRio"
	lamina.mesh = malla_de_la_lamina
	lamina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamina.material_override = material_del_agua(
		terreno.meters_per_unit / maxf(terreno.vertical_exaggeration, 0.0001))
	terreno.add_child(lamina)
	print("Lamina del rio: %d vertices" % malla_de_la_lamina.surface_get_array_len(0))
	aplicar_la_lamina()


## TEJE LA LÁMINA DE AGUA de una rejilla cualquiera, y por eso es estática.
##
## La usan el recuadro jugable y **las ocho casillas de alrededor**. Estaba pegada al
## `TerrainGenerator` del recuadro —leía sus arrays, su resolución y su tamaño— y por eso el
## contorno no podía tener lámina: al subir el ajuste «Agua» a Alto, el río del recuadro
## pasaba a dibujarse con esta malla y el del contorno se quedaba con el agua pintada en el
## suelo, mucho más apagada. Resultado, medido con un A/B de la misma vista el 2026-09-19:
## con el agua en bajo el río cruzaba la raya y seguía; con el agua en alto **se cortaba en
## una línea recta justo en el borde**. Ver GRAFICOS §3.
##
## Devuelve `null` si en esa rejilla no hay ni un cuadro con agua, que es lo normal en una
## casilla de monte sin cauces.
static func tejer_la_lamina(alturas: PackedFloat32Array, rios: PackedFloat32Array,
		flujos: PackedVector2Array, res: int, paso_x: float, paso_z: float,
		encima: float, tope: float, ceder: Callable = Callable()) -> ArrayMesh:
	if res < 2 or alturas.size() < res * res or rios.size() < res * res:
		return null
	var cual := PackedInt32Array()
	cual.resize(res * res)
	cual.fill(-1)
	var vertices := PackedVector3Array()
	var colores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for z in range(res - 1):
		if ceder.is_valid() and z % 64 == 0:
			await ceder.call()
		for x in range(res - 1):
			var e0 := z * res + x
			if (rios[e0] <= AguaDelCauce.LAMINA_QUE_SE_DIBUJA
					and rios[e0 + 1] <= AguaDelCauce.LAMINA_QUE_SE_DIBUJA
					and rios[e0 + res] <= AguaDelCauce.LAMINA_QUE_SE_DIBUJA
					and rios[e0 + res + 1] <= AguaDelCauce.LAMINA_QUE_SE_DIBUJA):
				continue
			var esquinas: Array[int] = [e0, e0 + 1, e0 + res, e0 + res + 1]
			for e: int in esquinas:
				if cual[e] < 0:
					cual[e] = vertices.size()
					var ex := e % res
					var ez := e / res
					var cota := AguaDelCauce.cota_del_agua(alturas, rios, res, ex, ez, tope)
					vertices.append(Vector3(float(ex) * paso_x, cota + encima,
						float(ez) * paso_z))
					colores.append(color_del_agua(rios, flujos, res, ex, ez))
					uvs.append(uv_del_agua(alturas, rios, flujos, res, ex, ez, paso_x)
						if rios[e] >= AguaDelCauce.LINEA_DEL_AGUA else Vector2.ZERO)
			# La misma diagonal que el relieve de debajo, o se cruzarían dentro del cuadro.
			if diagonal_principal(alturas, res, x, z):
				indices.append_array([cual[esquinas[0]], cual[esquinas[1]], cual[esquinas[3]],
					cual[esquinas[0]], cual[esquinas[3]], cual[esquinas[2]]])
			else:
				indices.append_array([cual[esquinas[0]], cual[esquinas[1]], cual[esquinas[2]],
					cual[esquinas[1]], cual[esquinas[3]], cual[esquinas[2]]])
	if indices.is_empty():
		return null
	var normales := PackedVector3Array()
	normales.resize(vertices.size())
	normales.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = colores
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla


## El material del agua de los cauces. Estático por lo mismo que [tejer_la_lamina]: lo
## comparten el recuadro y el contorno, y dos copias que se separen serían dos ríos
## distintos a los dos lados de la raya.
static func material_del_agua(metros_por_unidad: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/agua_rio.gdshader") as Shader
	var texturas := ProceduralTextureGenerator.get_water_textures()
	if texturas.has("water_normal"):
		material.set_shader_parameter("water_normal_tex", texturas["water_normal"])
	if texturas.has("water_foam"):
		material.set_shader_parameter("water_foam_tex", texturas["water_foam"])
	material.set_shader_parameter("caida_de_rapido", AguaDelCauce.CAIDA_DE_RAPIDO)
	material.set_shader_parameter("veces_para_romper", AguaDelCauce.VECES_PARA_ROMPER_ENTERA)
	material.set_shader_parameter("linea_del_agua", AguaDelCauce.LINEA_DEL_AGUA)
	material.set_shader_parameter("metros_por_unidad", metros_por_unidad)
	# Ver [DEBAJO_DE_LA_NIEBLA]: el agua va antes que la niebla, siempre.
	material.render_priority = DEBAJO_DE_LA_NIEBLA
	return material


## El color de un vértice de lámina: la corriente en rg, el agua quieta en b y la lámina
## en a. Es lo que lee el shader del agua y también el del terreno.
static func color_del_agua(rios: PackedFloat32Array, flujos: PackedVector2Array, res: int,
		x: int, z: int) -> Color:
	var idx := z * res + x
	var flujo: Vector2 = flujos[idx] if idx < flujos.size() else Vector2.ZERO
	var mojado: float = rios[idx] if idx < rios.size() else 0.0
	if mojado > 0.02 and rios.size() >= res * res and flujos.size() >= res * res:
		flujo = AguaDelCauce.corriente_suave(flujos, rios, res, x, z)
	return Color(flujo.x * 0.5 + 0.5, flujo.y * 0.5 + 0.5,
		1.0 if (mojado > 0.01 and flujo.length_squared() < 0.01) else 0.0, mojado)


## La caída del rápido y la orilla de una celda, que van en el UV de la lámina.
static func uv_del_agua(alturas: PackedFloat32Array, rios: PackedFloat32Array,
		flujos: PackedVector2Array, res: int, x: int, z: int, paso: float) -> Vector2:
	if rios.size() < res * res:
		return Vector2.ZERO
	return Vector2(AguaDelCauce.caida_suave(alturas, rios, flujos, res, x, z, paso),
		AguaDelCauce.orilla(rios, res, x, z))


## Por qué diagonal se parte el cuadro de la rejilla que empieza en (`x`, `z`): `true`, de
## arriba-izquierda a abajo-derecha; `false`, de arriba-derecha a abajo-izquierda, que era
## la única hasta el 2026-09-16.
##
## **Por la diagonal a lo largo de la cual el relieve está más recto.** Partido siempre
## igual, un fondo de valle o un pie de talud que corre en diagonal a la rejilla quedaba
## atravesado por la arista de cada cuadro: un triángulo tumbado y el otro de pie, y la
## orilla del río salía en DIENTES DE SIERRA (captura en falso color del remanso,
## 2026-09-16; el relieve medido sube liso, 4-5 m por celda). Se compara la segunda
## diferencia de alturas a lo largo de cada diagonal, con la celda de más allá de cada
## punta; en un plano empatan y se queda la de siempre.
##
## Sólo cambia el dibujo: la partida mide la cota con [TerrainGenerator.get_height_at],
## bilineal, y la colisión es un [HeightMapShape3D].
static func diagonal_principal(alturas: PackedFloat32Array, res: int, x: int, z: int) -> bool:
	var tl := _cota(alturas, res, x, z)
	var tr := _cota(alturas, res, x + 1, z)
	var bl := _cota(alturas, res, x, z + 1)
	var br := _cota(alturas, res, x + 1, z + 1)
	var curva_principal := absf(_cota(alturas, res, x - 1, z - 1) - 2.0 * tl + br) 		+ absf(tl - 2.0 * br + _cota(alturas, res, x + 2, z + 2))
	var curva_otra := absf(_cota(alturas, res, x + 2, z - 1) - 2.0 * tr + bl) 		+ absf(tr - 2.0 * bl + _cota(alturas, res, x - 1, z + 2))
	return curva_principal < curva_otra


static func _cota(alturas: PackedFloat32Array, res: int, x: int, z: int) -> float:
	var i := clampi(z, 0, res - 1) * res + clampi(x, 0, res - 1)
	return alturas[i] if i < alturas.size() else 0.0


## Los dos triángulos de un cuadro en `indices` desde `i`, con el mismo giro por las dos
## diagonales.
static func _poner_el_cuadro(indices: PackedInt32Array, i: int, tl: int, tr: int, bl: int,
		br: int, principal: bool) -> void:
	if principal:
		indices[i] = tl
		indices[i + 1] = tr
		indices[i + 2] = br
		indices[i + 3] = tl
		indices[i + 4] = br
		indices[i + 5] = bl
	else:
		indices[i] = tl
		indices[i + 1] = tr
		indices[i + 2] = bl
		indices[i + 3] = tr
		indices[i + 4] = br
		indices[i + 5] = bl


## Enciende la lámina según el ajuste «Agua» —desde Alto— y le da su nivel; y al terreno,
## cuánto hunde el lecho: nada si no hay lámina encima. En caliente.
func aplicar_la_lamina() -> void:
	var nivel := nivel_del_agua(terreno.agua_con_niveles)
	if lamina != null:
		lamina.visible = nivel >= LAMINA_DESDE
		(lamina.material_override as ShaderMaterial).set_shader_parameter("nivel_de_agua", nivel)
	var material_del_terreno: ShaderMaterial = terreno._material_manager.get_material() \
		if terreno._material_manager != null else null
	if material_del_terreno != null:
		var hondo := AguaDelCauce.LECHO_M / maxf(terreno.meters_per_unit, 0.0001) * terreno.vertical_exaggeration
		material_del_terreno.set_shader_parameter("lecho_hondo",
			hondo if lamina != null and nivel >= LAMINA_DESDE else 0.0)


## Dónde rompe el agua en una celda: x la caída del cauce, y la orilla. Ver [AguaDelCauce].
func _agua_de_la_celda(x: int, z: int, paso: float) -> Vector2:
	return uv_del_agua(terreno._height_map, terreno._river_map, terreno._flow_map,
		terreno.resolution, x, z, paso)


## Lo mismo para un punto suelto, en la celda más cercana: lo usan los parches cosidos.
func _agua_del_punto(p: Vector3) -> Vector2:
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
	return _agua_de_la_celda(clampi(int(round(p.x / step_x)), 0, terreno.resolution - 1),
		clampi(int(round(p.z / step_z)), 0, terreno.resolution - 1), step_x)


## Y el color de vértice, que es como viaja la hidrografía al shader.
func _color_del_punto(p: Vector3) -> Color:
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
	return color_del_agua(terreno._river_map, terreno._flow_map, terreno.resolution,
		clampi(int(round(p.x / step_x)), 0, terreno.resolution - 1),
		clampi(int(round(p.z / step_z)), 0, terreno.resolution - 1))


## Las simas: donde la rejilla se ha quitado —ver [_en_el_ruedo_de_una_sima]— se
## cose un embudo circular con su pozo.
##
## Va aparte de la rejilla porque el relieve tiene un punto cada cinco metros y
## un agujero de dos no le cabe: sale cuadrado y del tamaño de la rejilla, que es
## lo que se vio en captura el 2026-09-13. Esto es terreno, no un objeto: el
## embudo lleva el mismo material que el resto del mapa y llega al borde con la
## cota que tiene el relieve allí, así que no se ve dónde acaba uno y empieza el
## otro.
func _construir_simas() -> void:
	var simas := terreno.simas()
	if simas.is_empty():
		return
	var paso := float(terreno.terrain_size.x) / float(maxi(terreno.resolution - 1, 1))
	var madre := Node3D.new()
	madre.name = "Simas"
	terreno._terrain_mesh.add_child(madre)

	for sima: Dictionary in simas:
		var centro: Vector3 = sima["position"]
		var boca := float(sima["boca"])
		var ruedo := float(sima["ruedo"])
		var hondo := float(sima["hondo"])
		var borde := terreno.get_height_at(centro)
		# El labio: lo poco que cae el embudo antes del pozo. Medio metro, no más:
		# cuanto más hunde, más se aparta de la cota que tiene el relieve
		# alrededor y más se le nota al shader —salía un cerco más oscuro de
		# veinte metros alrededor del agujero—.
		var labio := 0.5

		var anillos := 7
		var lados := 28
		# LA BOCA NO ES UN CÍRCULO. Un agujero perfecto canta a geometría —el
		# usuario, el 2026-09-13—, así que el radio se mueve con el ángulo. El
		# ruido va por semilla de la posición: la misma cueva sale igual siempre.
		var mordido := FastNoiseLite.new()
		mordido.seed = hash([int(centro.x), int(centro.z)])
		mordido.frequency = 0.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var puntos: Array[Vector3] = []
		for j in range(anillos + 1):
			var t := float(j) / float(anillos)
			var radio := lerpf(boca, ruedo + paso, t)
			for i in range(lados + 1):
				var angulo := TAU * float(i) / float(lados)
				# Mordido sólo cerca de la boca: en el borde de fuera el parche
				# tiene que cerrar contra la rejilla, y ahí no se toca.
				var mordida := 1.0 + MORDIDA_DE_LA_BOCA * (1.0 - t) \
					* mordido.get_noise_2d(cos(angulo) * 4.0, sin(angulo) * 4.0)
				var p := Vector3(centro.x + cos(angulo) * radio * mordida, 0.0,
					centro.z + sin(angulo) * radio * mordida)
				# Del labio del pozo a la cota del relieve, y LA CAÍDA VA PEGADA
				# AL AGUJERO: repartida por todo el parche, el terreno quedaba
				# hundido en varios metros a la redonda y el shader lo pintaba de
				# otra capa —se veía un cerco distinto alrededor de la boca—.
				p.y = lerpf(borde - labio, terreno.get_height_at(p),
					smoothstep(0.0, 0.25, t))
				if j == anillos:
					# El último anillo monta sobre la rejilla que queda: un dedo
					# por debajo, para que no peleen las dos superficies.
					p.y -= 0.05
				puntos.append(p)
		var fila := lados + 1
		for j in range(anillos):
			for i in range(lados):
				var a := j * fila + i
				var b := a + 1
				var d := a + fila
				var e := d + 1
				for tri: Array in [[a, d, b], [b, d, e]]:
					for k: int in tri:
						st.set_uv(_agua_del_punto(puntos[k]))
						st.set_uv2(_uv2_del_punto(puntos[k]))
						st.set_color(_color_del_punto(puntos[k]))
						# LA MISMA NORMAL QUE LA REJILLA, sacada del mapa de
						# alturas y no de la geometría del parche: el shader
						# mezcla sus capas por la normal, y con la geométrica el
						# parche salía de otro color y se veía un cerco
						# alrededor del agujero.
						st.set_normal(_normal_del_punto(puntos[k]))
						# Y LA TANGENTE, también como la rejilla: a lo largo de
						# +X y con la bitangente hacia +Z. Calculada por UV salía
						# girada, y con ella el mapa de normales pintaba el
						# parche con otra luz que el terreno de al lado.
						st.set_tangent(_tangente_del_punto(puntos[k]))
						st.add_vertex(puntos[k])

		var embudo := MeshInstance3D.new()
		embudo.name = "Embudo"
		embudo.mesh = st.commit()
		# El mismo material que el resto del terreno: esto ES el terreno.
		embudo.material_override = terreno._terrain_mesh.material_override
		# SIN PROYECTAR SOMBRA. El parche está casi a la misma cota que la
		# rejilla que sustituye, así que se sombreaba a sí mismo y dejaba un
		# cerco más oscuro de veinte metros alrededor del agujero.
		embudo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		madre.add_child(embudo)

		# EL POZO, con forma de embudo de gravedad: la pared cae cada vez más
		# rápido según se acerca al eje —`hondo = K · ln(boca / radio)`—, que es
		# la curva que pidió el usuario el 2026-09-13, «como la representación de
		# la gravedad sobre un plano», y no un tubo recto.
		#
		# Y con la ROCA DEL PROPIO TERRENO: el mismo material que el resto del
		# mapa, que en pared vertical ya pinta roca. La oscuridad la pone encima
		# una capa aparte que se va cerrando con la hondura —ver abajo—, para que
		# la cueva no pase de suelo a negro en el mismo borde.
		var arriba := borde - labio
		var garganta := boca * ESTRECHO_DEL_POZO
		var constante := hondo / log(1.0 / ESTRECHO_DEL_POZO)
		var caladas: Array[float] = []
		var radios: Array[float] = []
		var anillos_pozo := 12
		for j in range(anillos_pozo + 1):
			var r := boca * pow(ESTRECHO_DEL_POZO, float(j) / float(anillos_pozo))
			radios.append(r)
			caladas.append(constante * log(boca / r))

		var pared := SurfaceTool.new()
		pared.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sombra := SurfaceTool.new()
		sombra.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(anillos_pozo):
			var y0 := arriba - caladas[j]
			var y1 := arriba - caladas[j + 1]
			var r0: float = radios[j]
			var r1: float = radios[j + 1]
			# La oscuridad se cierra en los primeros metros: a seis ya no se ve
			# nada, que es lo que insinúa la hondura sin tapar la roca de arriba.
			var n0 := Color(0.0, 0.0, 0.0, clampf(caladas[j] / OSCURO_A_LOS, 0.0, 1.0))
			var n1 := Color(0.0, 0.0, 0.0, clampf(caladas[j + 1] / OSCURO_A_LOS, 0.0, 1.0))
			for i in range(lados):
				var a0 := TAU * float(i) / float(lados)
				var a1 := TAU * float(i + 1) / float(lados)
				# El mismo mordisco que la boca, y desdibujado al bajar: una
				# garganta no conserva la forma del brocal.
				var m0 := 1.0 + MORDIDA_DE_LA_BOCA * (1.0 - float(j) / float(anillos_pozo)) \
					* mordido.get_noise_2d(cos(a0) * 4.0, sin(a0) * 4.0)
				var m1 := 1.0 + MORDIDA_DE_LA_BOCA * (1.0 - float(j) / float(anillos_pozo)) \
					* mordido.get_noise_2d(cos(a1) * 4.0, sin(a1) * 4.0)
				var p0 := Vector3(centro.x + cos(a0) * r0 * m0, y0, centro.z + sin(a0) * r0 * m0)
				var p1 := Vector3(centro.x + cos(a1) * r0 * m1, y0, centro.z + sin(a1) * r0 * m1)
				var q0 := Vector3(centro.x + cos(a0) * r1 * m0, y1, centro.z + sin(a0) * r1 * m0)
				var q1 := Vector3(centro.x + cos(a1) * r1 * m1, y1, centro.z + sin(a1) * r1 * m1)
				# HACIA FUERA, para que el motor recorte la pared de acá y se vea
				# la del fondo: dibujando las dos, la de delante tapaba el
				# agujero y parecía una bola metida en el suelo.
				var eje := Vector3(centro.x, (y0 + y1) * 0.5, centro.z)
				var afuera := (p0 + q1) * 0.5 - eje
				for tri: Array in [[p0, q0, p1], [p1, q0, q1]]:
					_roca_del_pozo(pared, tri[0], tri[1], tri[2], afuera)
				_muro(sombra, p0, q0, p1, afuera, n0, n1, n0)
				_muro(sombra, p1, q0, q1, afuera, n0, n1, n1)
		var pozo := MeshInstance3D.new()
		pozo.name = "Pozo"
		pozo.mesh = pared.commit()
		# La roca del terreno: esto sigue siendo el mapa, no un objeto.
		pozo.material_override = terreno._terrain_mesh.material_override
		pozo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		madre.add_child(pozo)

		var negro := MeshInstance3D.new()
		negro.name = "Oscuridad"
		negro.mesh = sombra.commit()
		var tiniebla := StandardMaterial3D.new()
		tiniebla.vertex_color_use_as_albedo = true
		tiniebla.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tiniebla.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tiniebla.cull_mode = BaseMaterial3D.CULL_BACK
		negro.material_override = tiniebla
		negro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		madre.add_child(negro)


## Reconstruye lo que deja `_create_terrain_mesh()`, pero desde una cache ya
## valida en vez de recalcularlo: sin bucle de vertices, sin generate_lods.
func _create_terrain_mesh_from_cache(cache: TerrainGenerationCache,
		ceder: Callable = Callable()) -> void:
	terreno._terrain_mesh = MeshInstance3D.new()
	terreno._terrain_mesh.name = "TerrainMesh"
	if terreno.terrain_chunks <= 1:
		terreno._terrain_mesh.mesh = cache.single_mesh

	var tmat0 := Time.get_ticks_msec()
	terreno._apply_terrain_material()
	print("[TIMING]   material/texturas de terreno: %d ms" % (Time.get_ticks_msec() - tmat0))
	if ceder.is_valid():
		await ceder.call()

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

	if ceder.is_valid():
		await ceder.call()
	# El embudo de cada sima se rehace siempre: es geometría de un puñado de
	# triángulos y no merece guardarse.
	_construir_simas()
	if ceder.is_valid():
		await ceder.call()

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
		src = terreno.origen_de_la_cache
	return ruta_de_la_cache(src, terreno.sufijo_de_la_cache, terreno.resolution)


## Dónde se guarda la malla de un relieve. Aparte, para que quien monta el mapa sepa si la
## hay ANTES de tener el terreno: la pantalla de carga reparte la barra con eso.
static func ruta_de_la_cache(origen: String, sufijo: String, resolucion: int) -> String:
	if origen.is_empty():
		return ""
	return "%s/%s%s_mesh_r%d.res" % [origen.get_base_dir(), origen.get_file().get_basename(),
		sufijo, resolucion]


## Huella de las entalladuras actuales, para invalidar la cache si cambian
## -por ejemplo al fundar el mismo sitio en otra epoca, con otras cuevas
## excavadas en la malla.
func _carvings_hash() -> int:
	# Con la versión de las reglas que las colocan y la de las simas: lo pedido
	# no cambia si cambia dónde se considera buena una boca ni cuánta rejilla se
	# quita. Ver [Bocas.REGLAS] y [TerrainGenerator.SIMA_REGLAS].
	return hash([str(terreno.carvings), Bocas.REGLAS, TerrainGenerator.SIMA_REGLAS])


## Huella del relieve inventado: lo que se anade por debajo de lo que mide el
## MDT. Ver [TerrainGenerationCache.detail_hash] para por que va todo junto.
func _detail_hash() -> int:
	# La amplitud EFECTIVA, no la del inspector: depende del paso del dato, asi
	# que el mismo sitio con MDT del IGN y con terrarium no comparten malla.
	# Y EL SELLO DEL RELLENO DEL MAR DE HOY ([RellenoDelMarDeHoy]): un valle de costa es el
	# mismo fichero en todas las épocas y su relieve cambia con el mar. Sin esto, la malla
	# guardada de una época se reusaba tal cual en otra —visto el 2026-09-17 haciendo dos
	# capturas seguidas del sitio 36: salían idénticas—.
	return hash([terreno._effective_detail_amplitude(), terreno.detail_frequency, terreno.detail_octaves,
		terreno.detail_slope_gain, terreno.detail_slope_max, terreno.shelf_relief_m,
		terreno.heightmap.relleno_mar, terreno.heightmap.relleno_version])


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
##
## Con `ceder`, se guarda en un hilo y se espera cuadro a cuadro: la del mapa regional son
## 106 MB y guardarla de un tirón era un cuadro de 1 s detrás de la pantalla de carga.
func _save_generation_cache(single_mesh: ArrayMesh, chunk_meshes: Array[ArrayMesh],
		ceder: Callable = Callable()) -> void:
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
	cache.carvings_colocadas = terreno.carvings_colocadas.duplicate(true)
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
	var error := OK
	if ceder.is_valid():
		var hilo := Thread.new()
		hilo.start(ResourceSaver.save.bind(cache, path))
		while hilo.is_alive():
			await (Engine.get_main_loop() as SceneTree).process_frame
		error = hilo.wait_to_finish()
	else:
		error = ResourceSaver.save(cache, path)
	if error != OK:
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


## Si un punto cae en el ruedo de una sima, o sea que ahí la rejilla se quita.
static func _en_el_ruedo_de_una_sima(simas: Array[Dictionary], donde: Vector2) -> bool:
	for sima: Dictionary in simas:
		var centro: Vector3 = sima["position"]
		if donde.distance_to(Vector2(centro.x, centro.z)) < float(sima["ruedo"]):
			return true
	return false


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
func _split_into_chunks(arrays: Array, ceder: Callable = Callable()) -> Array[ArrayMesh]:
	# El ruedo de las simas, también aquí: cada trozo rehace sus propios índices.
	var simas := terreno.simas()
	var step_x := float(terreno.terrain_size.x) / float(terreno.resolution - 1)
	var step_z := float(terreno.terrain_size.y) / float(terreno.resolution - 1)
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
			if ceder.is_valid():
				await ceder.call()
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
					if _en_el_ruedo_de_una_sima(simas, Vector2(
							(float(x0 + x) + 0.5) * step_x,
							(float(z0 + z) + 0.5) * step_z)):
						continue
					var top_left := z * wide + x
					var top_right := top_left + 1
					var bottom_left := top_left + wide
					var bottom_right := bottom_left + 1
					var cuadro := (z0 + z) * (terreno.resolution - 1) + (x0 + x)
					var principal := _diagonales[cuadro] == 1 if cuadro < _diagonales.size() 						else diagonal_principal(terreno._height_map, terreno.resolution, x0 + x, z0 + z)
					_poner_el_cuadro(ci, i, top_left, top_right, bottom_left, bottom_right, principal)
					i += 6
			ci.resize(i)

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
