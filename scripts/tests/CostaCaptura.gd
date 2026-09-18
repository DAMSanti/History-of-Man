extends SceneTree
## Dónde poner los cuatro abrigos de la costa de la época, y cómo se ven.
##
## EPOCA_01 §10.2, tarea 6. La spec dice que el sitio exacto **lo confirma el usuario**
## sobre una captura, así que esto propone y enseña; no escribe nada.
##
## Para cada uno de los cuatro ríos —Nansa, Saja-Besaya, Pas y Asón— busca su
## desembocadura con el mar a −120 m —el final del tramo de la plataforma que hornea
## `HornearRios`— y, alrededor, el mejor resalte para un abrigo: alto sobre el mar pero
## no en lo alto de un monte, cerca del agua y con el río a mano.
##
##   godot --path . --script res://scripts/tests/CostaCaptura.gd
##
## `SIN_VENTANA=1` sólo propone y no captura.

const RELIEVE := "res://data/dem/cantabria_region.res"
const MAR := -120.0

## Las cuatro desembocaduras de hoy, para saber qué tramo de la plataforma es el de cada
## río. Son las bocas de sus rías, a ojo sobre el mapa.
const RIOS := [
	{"nombre": "Nansa", "lon": -4.399, "lat": 43.394},
	{"nombre": "Saja-Besaya", "lon": -4.045, "lat": 43.435},
	{"nombre": "Pas", "lon": -3.9816, "lat": 43.4417},
	{"nombre": "Asón", "lon": -3.463, "lat": 43.435},
]

## Cuánto se busca alrededor de la desembocadura de la época, en metros.
## *(Eran 4 000 m hasta el 2026-09-17: con la plataforma nueva el mejor resalte del Nansa
## salía a más de dos kilómetros de su boca, y el valle del abrigo, de 4,5 km de lado, se
## quedaba sin río —`TestCosta`—. Con 1 800 la boca cabe siempre en el valle.)*
const ALREDEDOR_M := 1800.0

## Entre qué cotas sobre el mar de la época puede estar un abrigo: bastante para no
## inundarse, poco para no ser un risco.
const SOBRE_EL_MAR_M := Vector2(12.0, 70.0)

## A cuánto del mar como mucho: la spec pide el abrigo a menos de 1 km.
const DEL_MAR_M := 1000.0

## Dos abrigos no pueden caer más cerca que esto, en metros. Hace falta porque **el Pas
## y el Saja-Besaya desembocan juntos** con el mar a −120 m —sus cauces confluyen en la
## plataforma— y los dos proponían el mismo resalte (2026-09-16).
const ENTRE_ABRIGOS_M := 3000.0


func _init() -> void:
	var datos: HeightmapData = load(RELIEVE)
	var rios := RiosDeLaRegion.cargar()
	if datos == null or rios.de_la_plataforma.is_empty():
		print("MAL: falta el relieve regional o los ríos horneados (HornearRios)")
		quit(1)
		return
	var plataforma := RelieveDeLaPlataforma.para(datos, MAR, rios.de_la_plataforma)

	var propuestas: Array[Dictionary] = []
	for rio: Dictionary in RIOS:
		var tramo := _tramo_de(rios.de_la_plataforma, float(rio["lon"]), float(rio["lat"]))
		if tramo.is_empty():
			print("%s: sin tramo de plataforma" % rio["nombre"])
			continue
		var puntos: PackedVector2Array = tramo["points"]
		var boca := puntos[puntos.size() - 1]
		var sitio := _resalte_junto_a(datos, plataforma, boca, propuestas)
		if sitio.is_empty():
			print("%s: sin resalte alrededor de la desembocadura" % rio["nombre"])
			continue
		sitio["rio"] = rio["nombre"]
		sitio["boca_lon"] = boca.x
		sitio["boca_lat"] = boca.y
		sitio["km_de_plataforma"] = _km(puntos)
		sitio["tramo"] = "%s, que empieza a %.1f km" % [tramo.get("name", "sin nombre"),
			_metros(puntos[0], Vector2(float(rio["lon"]), float(rio["lat"]))) / 1000.0]
		propuestas.append(sitio)

	print("")
	print("=== LOS CUATRO ABRIGOS DE LA COSTA, PROPUESTOS ===")
	for sitio: Dictionary in propuestas:
		print("%s: %.4f N %.4f E · cota %.0f m (%.0f sobre el mar) · a %.0f m del mar · "
			% [sitio["rio"], sitio["lat"], sitio["lon"], sitio["cota"],
				sitio["cota"] - MAR, sitio["del_mar_m"]]
			+ "resalte de %.0f m · el río cruza %.0f km de plataforma · tramo: %s"
			% [sitio["resalte"], sitio["km_de_plataforma"], sitio["tramo"]])

	if OS.get_environment("SIN_VENTANA") == "1" or propuestas.is_empty():
		quit()
		return
	await _capturar(propuestas)
	quit()


## El tramo de plataforma que sale de esta desembocadura de hoy.
func _tramo_de(cauces: Array, lon: float, lat: float) -> Dictionary:
	var mejor: Dictionary = {}
	var mas_cerca := 15000.0
	for cauce: Dictionary in cauces:
		var puntos: PackedVector2Array = cauce["points"]
		if puntos.is_empty():
			continue
		var lejos := _metros(puntos[0], Vector2(lon, lat))
		if lejos < mas_cerca:
			mas_cerca = lejos
			mejor = cauce
	return mejor


## El mejor sitio para un abrigo alrededor de una desembocadura.
##
## Se busca en la rejilla regional —111 m por muestra—, que para elegir el punto sobra:
## el cantil de verdad lo talla después el valle del sitio.
func _resalte_junto_a(datos: HeightmapData, plataforma: RelieveDeLaPlataforma,
		boca: Vector2, ya_puestos: Array[Dictionary]) -> Dictionary:
	var paso := datos.meters_per_sample
	var radio := int(ALREDEDOR_M / paso)
	var x0 := roundi(datos.u_for_lon(boca.x) * float(datos.width - 1))
	var z0 := roundi(datos.v_for_lat(boca.y) * float(datos.height - 1))
	var mejor: Dictionary = {}
	var mejor_nota := -INF
	for dz in range(-radio, radio + 1):
		for dx in range(-radio, radio + 1):
			var x := x0 + dx
			var z := z0 + dz
			if x < 1 or z < 1 or x >= datos.width - 1 or z >= datos.height - 1:
				continue
			var lon := lerpf(datos.lon_west, datos.lon_east, float(x) / float(datos.width - 1))
			var lat := datos.lat_for_v(float(z) / float(datos.height - 1))
			var cota := plataforma.cota_en(lon, lat)
			var sobre := cota - MAR
			if sobre < SOBRE_EL_MAR_M.x or sobre > SOBRE_EL_MAR_M.y:
				continue
			var del_mar := _del_mar(datos, plataforma, x, z)
			if del_mar > DEL_MAR_M:
				continue
			var pegado := false
			for otro: Dictionary in ya_puestos:
				if _metros(Vector2(float(otro["lon"]), float(otro["lat"])),
						Vector2(lon, lat)) < ENTRE_ABRIGOS_M:
					pegado = true
					break
			if pegado:
				continue
			# El resalte: cuánto sobresale de lo que tiene a medio kilómetro.
			var vecinos := 0.0
			var cuantos := 0
			var salto := maxi(int(500.0 / paso), 1)
			for lado: Vector2i in [Vector2i(salto, 0), Vector2i(-salto, 0),
					Vector2i(0, salto), Vector2i(0, -salto)]:
				var nx := clampi(x + lado.x, 0, datos.width - 1)
				var nz := clampi(z + lado.y, 0, datos.height - 1)
				vecinos += plataforma.cota_en(
					lerpf(datos.lon_west, datos.lon_east, float(nx) / float(datos.width - 1)),
					datos.lat_for_v(float(nz) / float(datos.height - 1)))
				cuantos += 1
			var resalte := cota - vecinos / maxf(float(cuantos), 1.0)
			var nota := resalte * 2.0 + (DEL_MAR_M - del_mar) / 200.0
			if nota > mejor_nota:
				mejor_nota = nota
				mejor = {"lon": lon, "lat": lat, "cota": cota, "resalte": resalte,
					"del_mar_m": del_mar}
	return mejor


## A qué distancia está el mar de la época, mirando alrededor.
func _del_mar(datos: HeightmapData, plataforma: RelieveDeLaPlataforma, x: int,
		z: int) -> float:
	var paso := datos.meters_per_sample
	var radio := int(DEL_MAR_M / paso) + 1
	var cerca := INF
	for dz in range(-radio, radio + 1):
		for dx in range(-radio, radio + 1):
			var nx := x + dx
			var nz := z + dz
			if nx < 0 or nz < 0 or nx >= datos.width or nz >= datos.height:
				continue
			# EL MAR CON SUS RÍAS, no el de los datos a secas: desde el 2026-09-17 las vaguadas
			# que llegan al mar se inundan (GRAFICOS §3), y una desembocadura al fondo de una
			# ría quedaba a más de un kilómetro del mar de antes. Salía el Asón «sin resalte».
			var lon := lerpf(datos.lon_west, datos.lon_east, float(nx) / float(datos.width - 1))
			var lat := datos.lat_for_v(float(nz) / float(datos.height - 1))
			if plataforma.cota_en(lon, lat) > MAR:
				continue
			cerca = minf(cerca, sqrt(float(dx * dx + dz * dz)) * paso)
	return cerca


func _capturar(propuestas: Array[Dictionary]) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Guardado.carpeta = "user://sondas/mapas"
	GameState.started = false
	GameState.niebla = null
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().size = Vector2i(1920, 1080)
	GameState.begin(load("res://data/sites/cantabria_sites.res") as SiteSet)
	change_scene_to_file("res://scenes/region_map.tscn")
	var mapa: Node = null
	for i in range(3000):
		await process_frame
		mapa = current_scene
		if mapa != null and mapa.get("terrain") != null and i > 240 \
				and not (mapa.terrain as TerrainGenerator).generando_la_malla:
			break
	if mapa == null or mapa.get("terrain") == null:
		print("MAL: sin mapa regional")
		return
	# Sin niebla ni nubes: lo que se mira es la costa de la época.
	var terreno: TerrainGenerator = mapa.terrain

	for sitio: Dictionary in propuestas:
		mapa.camera.set_target(terreno.geo_to_world(float(sitio["lon"]), float(sitio["lat"])))
		mapa.camera.set_distance(float(maxi(terreno.terrain_size.x,
			terreno.terrain_size.y)) * 0.02)
		for i in range(60):
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot != null:
			var nombre := "user://costa_%s.png" % String(sitio["rio"]).to_lower().replace("-", "_")
			shot.save_png(nombre)
			print("captura en %s" % ProjectSettings.globalize_path(nombre))

	# Y una general de la costa de la época, con los cuatro dentro.
	mapa.camera.set_target(terreno.geo_to_world(-3.9, 43.55))
	mapa.camera.set_distance(float(maxi(terreno.terrain_size.x,
		terreno.terrain_size.y)) * 0.28)
	for i in range(60):
		await process_frame
	var general := get_root().get_texture().get_image()
	if general != null:
		general.save_png("user://costa_los_cuatro.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://costa_los_cuatro.png"))


func _km(puntos: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(1, puntos.size()):
		total += _metros(puntos[k - 1], puntos[k])
	return total / 1000.0


func _metros(a: Vector2, b: Vector2) -> float:
	var dy := (b.y - a.y) * 111320.0
	var dx := (b.x - a.x) * 111320.0 * cos(deg_to_rad(a.y))
	return sqrt(dx * dx + dy * dy)
