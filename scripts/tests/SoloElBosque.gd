class_name SoloElBosque
extends RefCounted
## Lo común a las sondas de aros y huecos del bosque (GRAFICOS §7.1): el valle montado,
## **sólo el bosque pintado** sobre negro, y su máscara.
##
## Pintar sólo el bosque es lo que deja contar árbol por píxel: sobre el terreno, un
## pino oscuro y una ladera en sombra no se separan por color. El bosque se monta igual
## —lo decide la posición de la cámara, no lo que se ve—, así que la máscara dice lo que
## el jugador tendría delante.

const SITE_ID := 56
## Un píxel es árbol si algún canal pasa de esto. El fondo es negro y la luz de ambiente
## de la cámara no deja ningún árbol por debajo.
const UMBRAL := 0.03
## Las fotos a 1/4 para contar: basta para manchas del tamaño de una copa.
const REDUCE := 4


static func preparar_sitio(escalon: int) -> void:
	Configuracion.graficos["arboles"] = escalon
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))


static func buscar(nodo: Node, nombre: String) -> Node:
	if nodo.name == nombre:
		return nodo
	for hijo: Node in nodo.get_children():
		var hallado := buscar(hijo, nombre)
		if hallado != null:
			return hallado
	return null


## Esconde todo lo que no es el bosque —terreno, agua, personas, props, interfaz— y le
## pone a la cámara un entorno negro con luz de ambiente.
static func aislar(demo: Node, bosque: Node3D, camara: Camera3D) -> void:
	var camino: Array[Node] = []
	var nodo: Node = bosque
	while nodo != null and nodo != demo.get_parent():
		camino.append(nodo)
		nodo = nodo.get_parent()
	for ancestro: Node in camino:
		if ancestro == bosque:
			continue
		for hijo: Node in ancestro.get_children():
			if camino.has(hijo) or hijo == camara:
				continue
			if hijo is Node3D:
				(hijo as Node3D).visible = false
			elif hijo is CanvasLayer:
				(hijo as CanvasLayer).visible = false
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	camara.environment = env


## La máscara de árbol de la pantalla, reducida: 1 donde hay árbol.
static func mascara(raiz: Window) -> Dictionary:
	var imagen := raiz.get_texture().get_image()
	var w := imagen.get_width() / REDUCE
	var h := imagen.get_height() / REDUCE
	imagen.resize(w, h, Image.INTERPOLATE_NEAREST)
	var datos := imagen.get_data()
	var paso := 4 if imagen.get_format() == Image.FORMAT_RGBA8 else 3
	var salida := PackedByteArray()
	salida.resize(w * h)
	var umbral := int(UMBRAL * 255.0)
	for i in range(w * h):
		var o := i * paso
		if datos[o] > umbral or datos[o + 1] > umbral or datos[o + 2] > umbral:
			salida[i] = 1
	return {"w": w, "h": h, "m": salida}


## La máscara engordada `radio` píxeles en cuadro: 1 donde hay árbol a esa distancia.
static func dilatar(mascara_: PackedByteArray, w: int, h: int, radio: int) -> PackedByteArray:
	var filas := PackedByteArray()
	filas.resize(w * h)
	for y in range(h):
		for x in range(w):
			if mascara_[y * w + x] == 0:
				continue
			for dx in range(-radio, radio + 1):
				var xx := x + dx
				if xx >= 0 and xx < w:
					filas[y * w + xx] = 1
	var salida := PackedByteArray()
	salida.resize(w * h)
	for y in range(h):
		for x in range(w):
			if filas[y * w + x] == 0:
				continue
			for dy in range(-radio, radio + 1):
				var yy := y + dy
				if yy >= 0 and yy < h:
					salida[yy * w + x] = 1
	return salida


## Los píxeles de la mayor mancha de unos, contando vecinos en cruz.
static func mayor_mancha(m: PackedByteArray, w: int, h: int) -> int:
	var visto := PackedByteArray()
	visto.resize(w * h)
	var mayor := 0
	for inicio in range(w * h):
		if m[inicio] == 0 or visto[inicio] == 1:
			continue
		var pila: Array[int] = [inicio]
		visto[inicio] = 1
		var n := 0
		while not pila.is_empty():
			var i: int = pila.pop_back()
			n += 1
			var x := i % w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < w * h and m[j] == 1 and visto[j] == 0:
					visto[j] = 1
					pila.append(j)
		mayor = maxi(mayor, n)
	return mayor


## El bloque de 128 m con más árboles, lejos del borde: donde el bosque es seguido.
static func lo_mas_espeso(bosque: Forest) -> Vector3:
	var cuenta := {}
	for k in range(bosque._stands.size()):
		var por_bloque: Dictionary = bosque._stands[k]
		for bloque: Vector2i in por_bloque:
			cuenta[bloque] = int(cuenta.get(bloque, 0)) + (por_bloque[bloque] as Array).size()
	var mejor := Vector2i.ZERO
	var mas := -1
	for bloque: Vector2i in cuenta:
		var centro := (Vector2(bloque) + Vector2(0.5, 0.5)) * Forest.BLOCK_M
		if centro.x < 800.0 or centro.y < 800.0 or centro.x > 3300.0 or centro.y > 3300.0:
			continue
		if int(cuenta[bloque]) > mas:
			mas = int(cuenta[bloque])
			mejor = bloque
	return Vector3((float(mejor.x) + 0.5) * Forest.BLOCK_M, 0.0, (float(mejor.y) + 0.5) * Forest.BLOCK_M)


## EN VERANO, con la hoja entera. La partida abre al salir del invierno, con los caducos
## pelados, y de cerca un abedul pelado en 3D son cuatro ramas mientras su impostor sigue
## siendo una mancha: la primera medida vio «un 19 % de árbol» en el relevo que era eso.
## Un hueco se busca donde el árbol tiene que estar entero.
static func en_verano(bosque: Forest) -> void:
	GameState.season = Subsistence.Season.VERANO
	bosque.set_season(Subsistence.Season.VERANO, Subsistence.Season.VERANO, 1.0)


## Espera a que el bosque tenga montado todo lo que le toca alrededor de la cámara.
static func asentar(arbol: SceneTree, bosque: Forest) -> void:
	for _i in range(900):
		await arbol.process_frame
		if bosque._pending.is_empty():
			break
	for _i in range(4):
		await arbol.process_frame
