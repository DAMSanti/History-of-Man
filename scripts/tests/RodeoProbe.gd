extends SceneTree
## Rodeo real dividido por linea recta, estacion por estacion y sobre el MISMO
## conjunto de trayectos.
##
## Queja del jugador: «empezamos en primavera con el rio sin vadear y todos los
## que van a un paraje de la otra orilla dan el mismo rodeo largo hacia el oeste
## hasta un vado; cuando llega el verano y el rio si se vadea, siguen haciendo
## el mismo rodeo en vez de cruzar por delante». La prueba que pidio: si en
## verano el rodeo no baja, esta reproducido.
##
## ## Dos versiones anteriores de esta sonda midieron mal. Queda escrito.
##
## 1. Preguntaba `connected` sobre el punto CRUDO. Una celda de cuarenta metros
##    que toca el rio esta cerrada aunque el punto este seco, asi que decia
##    «ningun destino comunicado» en tres estaciones de cuatro.
## 2. Elegia los destinos con `Marcha.cruza_el_agua`, que contesta «¿hay agua
##    que HOY no se vadea de por medio?». En verano el rio se vadea, asi que la
##    respuesta cambia con la estacion y el conjunto medido no era el mismo.
##
## Ahora: los destinos se eligen UNA vez y sin mirar el agua, se mide contra el
## destino AMARRADO -que es adonde de verdad se va, ver [Marcha._firm_ground]-
## y se comparan solo los trayectos que existen en las dos estaciones.

const SITE_ID := 56

## Cada cuantos metros se cata la linea recta buscando agua. Tres, como
## [Marcha.CATA_DEL_PASO].
const CATA := 3.0

## La simulacion, para la autopsia. Se guarda porque `_comparar` no la recibe.
var _sim: Node = null


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var hasta := int(OS.get_environment("DIA")) if OS.has_environment("DIA") else 3
	var arranque := Time.get_ticks_msec()
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	sim.time_scale = 6.0
	var primero: int = sim.day
	var ultimo: int = sim.day
	while sim.day < primero + hasta:
		await process_frame
		if sim.day != ultimo:
			ultimo = sim.day
			print("SONDA: dia %d · %.0f s" % [sim.day,
				float(Time.get_ticks_msec() - arranque) / 1000.0])

	var casa: Vector3 = sim.home_position
	var tam: Vector2 = Vector2(sim._terrain.terrain_size)
	print("")
	print("abrigo en (%.0f, %.0f) · %d parajes · %d jornadas en %.0f s" % [
		casa.x, casa.z, sim.parajes.list.size(), hasta,
		float(Time.get_ticks_msec() - arranque) / 1000.0])

	# Los destinos: un abanico de puntos SECOS, elegidos una vez y sin mirar el
	# agua. Que haya rio de por medio o no lo dice el propio camino despues.
	var destinos: Array[Vector3] = []
	for i in range(72):
		var angulo := float(i) / 72.0 * TAU
		for radio: float in [300.0, 500.0, 800.0, 1200.0]:
			var punto: Vector3 = casa + Vector3(
				cos(angulo) * radio, 0.0, sin(angulo) * radio)
			if punto.x < 40.0 or punto.z < 40.0 \
				or punto.x > tam.x - 40.0 or punto.z > tam.y - 40.0:
				continue
			punto.y = sim._terrain.get_height_at(punto)
			if not Hydrography.can_cross(
					sim._terrain.crossing_difficulty_at(punto), false, false):
				continue
			destinos.append(punto)
	print("destinos secos en el abanico: %d" % destinos.size())

	# Y con agua de por medio o no, dicho de una forma que NO cambia con la
	# estacion: hay lamina de agua en la recta, se vadee hoy o no.
	var con_rio: Array[bool] = []
	var cuantos_con_rio := 0
	for destino: Vector3 in destinos:
		var mojado := _hay_lamina(sim, casa, destino)
		con_rio.append(mojado)
		if mojado:
			cuantos_con_rio += 1
	print("   de ellos, con lamina de agua en la recta: %d" % cuantos_con_rio)

	_sim = sim
	var por_estacion: Dictionary = {}
	for estacion: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		por_estacion[estacion] = await _medir(sim, casa, destinos, estacion)
		if estacion == Subsistence.Season.PRIMAVERA:
			por_estacion["rejilla_primavera"] = sim.marcha._navgrid()
		elif estacion == Subsistence.Season.VERANO:
			por_estacion["rejilla_verano"] = sim.marcha._navgrid()

	_comparar(casa, destinos, con_rio, por_estacion)
	_que_se_abre(por_estacion["rejilla_primavera"], por_estacion["rejilla_verano"])
	quit()


## QUE CELDAS ABRE EL VERANO, y sobre todo si abre AGUA HONDA.
##
## `TerrainGenerator.crossing_difficulty_with` multiplica el mapa de vados por
## el caudal SIN TOPE, y `Hydrography.can_cross` solo aplica la regla de «la mar
## abierta no la abre ninguna estacion» cuando se le pasa la estacion —cosa que
## [Navgrid] no hace—. Asi que un cauce de dificultad 1,0 sale 0,60 en verano,
## por debajo del tope de vadeo de 0,70. Si esta cuenta da celdas, en agosto se
## anda por el rio.
func _que_se_abre(primavera: Navgrid, verano: Navgrid) -> void:
	var terrain: TerrainGenerator = _sim._terrain
	var abiertas := 0
	var hondas := 0
	var hondas_ya := 0
	for celda in range(verano.cost.size()):
		var punto := verano.point_of(celda)
		var crudo := terrain.crossing_difficulty_at(punto)
		var abierta_v := verano.cost[celda] > Navgrid.BLOCKED
		var abierta_p := primavera.cost[celda] > Navgrid.BLOCKED
		if abierta_v and not abierta_p:
			abiertas += 1
			if crudo >= 1.0:
				hondas += 1
		if abierta_v and crudo >= 1.0:
			hondas_ya += 1
	print("")
	print("=== QUE ABRE EL VERANO ===")
	print("   celdas que abren en verano y no en primavera: %d" % abiertas)
	print("   de ellas, con agua HONDA (dificultad base >= 1,0): %d" % hondas)
	print("   celdas abiertas en verano con agua honda, en total: %d" % hondas_ya)
	print("   (el tope de vadeo es %.2f; 1,0 x caudal de verano %.2f = %.2f)" % [
		Hydrography.FORD_IMPASSABLE, verano.built_with_caudal,
		verano.built_with_caudal])


## Si entre dos puntos hay lamina de agua, se vadee hoy o no. Es la pregunta
## que NO depende de la estacion: `crossing_difficulty_at` es el mapa de vados
## sin caudal, y [Hydrography.ROZA_EL_AGUA] es el minimo por el que una celda
## cuenta como mojada.
func _hay_lamina(sim: Node, desde: Vector3, hasta: Vector3) -> bool:
	var largo := Traversal.en_llano(desde, hasta)
	var catas := maxi(int(ceil(largo / CATA)), 1)
	for i in range(catas + 1):
		var at := desde.lerp(hasta, float(i) / float(catas))
		if sim._terrain.crossing_difficulty_at(at) > Hydrography.ROZA_EL_AGUA:
			return true
	return false


## Mide una estacion entera. Devuelve, por destino, el rodeo y donde cruza.
func _medir(sim: Node, casa: Vector3, destinos: Array[Vector3],
		estacion: int) -> Array[Dictionary]:
	GameState.season = estacion
	var reloj := Time.get_ticks_msec()
	var grid: Navgrid = sim.marcha._navgrid()
	await process_frame

	var persona: Inhabitant = sim.people[0]
	var fuera: Array[Dictionary] = []
	for destino: Vector3 in destinos:
		# Lo que hace la partida antes de salir: el reparto pregunta si se llega
		# desde casa, y esa pregunta es la que rehace el arbol del abrigo.
		var admitido: bool = sim.marcha.alcanzable_desde_casa(destino)

		persona.position = casa
		persona.route = PackedVector3Array()
		persona.route_step = 0
		persona.target = Vector3.ZERO
		persona.unreachable = Vector3.ZERO
		sim._path_nodes_this_frame = 0
		sim._stranded_this_frame = 0
		sim.marcha._send_to(persona, destino)

		var dato := {"hay": false, "rodeo": 0.0, "cruce": -1.0,
			"donde": Vector3.ZERO, "arbol": false,
			"ruta": PackedVector3Array(), "admitido": admitido}
		if not persona.route.is_empty():
			var recta := Traversal.en_llano(casa, persona.target)
			if recta >= 1.0:
				var andado: float = sim.marcha.largo_de(casa, persona.route)
				dato["hay"] = true
				dato["rodeo"] = andado / recta
				dato["ruta"] = PackedVector3Array(persona.route)
				var punta := grid.nearest_open(persona.target)
				if punta >= 0:
					var por_arbol := Wayfinder.camino_por_el_arbol(grid,
						sim.marcha._arbol_desde_casa, punta, persona.target,
						false, sim.marcha._recortes_del_arbol)
					dato["arbol"] = not por_arbol.is_empty() and absf(
						sim.marcha.largo_de(casa, por_arbol) - andado) < 1.0
				# Por donde cruza el agua, si es que la cruza.
				var antes := casa
				for punto: Vector3 in persona.route:
					if _hay_lamina(sim, antes, punto):
						dato["cruce"] = Traversal.en_llano(casa, punto)
						dato["donde"] = punto
						break
					antes = punto
		fuera.append(dato)

	print("SONDA: %s medida en %.0f s (caudal %.2f · zonas %d)" % [
		Subsistence.season_name(estacion as Subsistence.Season),
		float(Time.get_ticks_msec() - reloj) / 1000.0,
		grid.built_with_caudal, grid.areas])
	return fuera


## Lo que le cuesta a la rejilla un camino ya trazado: es la suma que minimiza
## el A*, `coste de la celda x metros andados en ella` -ver [Wayfinder.find]-.
## Sirve para la unica pregunta que separa un fallo de busqueda de un fallo de
## modelo: ¿el camino largo es de verdad el MAS BARATO?
func _coste_de(grid: Navgrid, desde: Vector3, camino: PackedVector3Array) -> float:
	var total := 0.0
	var antes := desde
	for punto: Vector3 in camino:
		var largo := Traversal.en_llano(antes, punto)
		var pasos := maxi(int(ceil(largo / (Navgrid.CELL * 0.5))), 1)
		for i in range(pasos):
			var at := antes.lerp(punto, (float(i) + 0.5) / float(pasos))
			var celda := grid.cell_of(at)
			if celda < 0 or celda >= grid.cost.size():
				continue
			if grid.cost[celda] <= Navgrid.BLOCKED:
				return INF
			total += grid.cost[celda] * (largo / float(pasos))
		antes = punto
	return total


## La autopsia del peor caso: por que el camino de verano se va lejos a cruzar.
func _autopsia(sim: Node, casa: Vector3, destino: Vector3, p: Dictionary,
		v: Dictionary, por_estacion: Dictionary) -> void:
	var rej_p: Navgrid = por_estacion["rejilla_primavera"]
	var rej_v: Navgrid = por_estacion["rejilla_verano"]
	print("")
	print("=== AUTOPSIA DEL PEOR CASO ===")
	var cruce_p: Vector3 = p["donde"]
	if cruce_p != Vector3.ZERO:
		var celda := rej_v.cell_of(cruce_p)
		print("   el vado que usa PRIMAVERA, a %.0f m del abrigo, en (%.0f, %.0f):" % [
			float(p["cruce"]), cruce_p.x, cruce_p.z])
		print("      en la rejilla de primavera: coste %.2f · mascara %d" % [
			rej_p.cost[rej_p.cell_of(cruce_p)], rej_p.vado[rej_p.cell_of(cruce_p)]])
		print("      en la rejilla de VERANO:    coste %.2f · mascara %d%s" % [
			rej_v.cost[celda], rej_v.vado[celda],
			"  <-- CERRADO" if rej_v.cost[celda] <= Navgrid.BLOCKED else ""])
	var camino_p: PackedVector3Array = p["ruta"]
	var camino_v: PackedVector3Array = v["ruta"]
	print("   lo que cuesta cada camino EN LA REJILLA DE VERANO:")
	print("      el camino corto de primavera: %.0f" % _coste_de(rej_v, casa, camino_p))
	print("      el camino largo de verano:    %.0f" % _coste_de(rej_v, casa, camino_v))
	print("   si el corto cuesta MAS, el buscador acierta y el fallo es el modelo")
	print("   de coste; si cuesta MENOS, el fallo esta en la busqueda.")

	# Y DE QUE ESTA HECHO ESE COSTE. Deducirlo de la cifra no vale: la misma
	# celda cuesta casi lo mismo con caudal 1,25 que con 0,60, asi que el agua
	# no manda ahi. Se desglosa igual que [Navgrid._measure].
	if cruce_p != Vector3.ZERO:
		_desglose(rej_v, cruce_p, "el vado de primavera")
	var cruce_v: Vector3 = v["donde"]
	if cruce_v != Vector3.ZERO:
		_desglose(rej_v, cruce_v, "el vado de verano")
	_desglose(rej_v, casa + (destino - casa) * 0.5, "monte a medio camino")

	print("")
	print("   las celdas de cada camino, en la rejilla de verano:")
	for pareja: Array in [["corto", camino_p], ["largo", camino_v]]:
		var caro := 0.0
		var suma := 0.0
		var n := 0
		var vistas := {}
		var antes2 := casa
		for punto: Vector3 in pareja[1] as PackedVector3Array:
			var largo := Traversal.en_llano(antes2, punto)
			var pasos := maxi(int(ceil(largo / (Navgrid.CELL * 0.5))), 1)
			for i in range(pasos):
				var at := antes2.lerp(punto, (float(i) + 0.5) / float(pasos))
				var celda := rej_v.cell_of(at)
				if vistas.has(celda):
					continue
				vistas[celda] = true
				var c: float = rej_v.cost[celda]
				suma += c
				n += 1
				caro = maxf(caro, c)
			antes2 = punto
		print("      %-6s %d celdas · coste medio %.1f · la mas cara %.1f" % [
			pareja[0], n, suma / maxf(float(n), 1.0), caro])


## De que esta hecho el coste de una celda. Es [Navgrid._measure] dicho en voz
## alta: la misma cuenta, para poder decir cual de los factores manda.
func _desglose(grid: Navgrid, punto: Vector3, que: String) -> void:
	var terrain: TerrainGenerator = _sim._terrain
	var pendiente := terrain.get_slope_at(punto)
	var vado := terrain.crossing_difficulty_with(punto, grid.built_with_caudal)
	var suelo := Traversal.classify_ground(pendiente, vado,
		grid.built_with_encharque)
	var paso := Traversal.pace_both_ways(pendiente, suelo, 0.0)
	var celda := grid.cell_of(punto)
	print("      %-22s coste %.1f · pendiente %.2f · vado %.2f · suelo %d · paso %.3f" % [
		que, grid.cost[celda], pendiente, vado, suelo, paso])


func _comparar(casa: Vector3, destinos: Array[Vector3], con_rio: Array[bool],
		por_estacion: Dictionary) -> void:
	var primavera: Array[Dictionary] = por_estacion[Subsistence.Season.PRIMAVERA]
	var verano: Array[Dictionary] = por_estacion[Subsistence.Season.VERANO]

	for estacion: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		var datos: Array[Dictionary] = por_estacion[estacion]
		var hay := 0
		var suma := 0.0
		var malos := 0
		for dato: Dictionary in datos:
			if not bool(dato["hay"]):
				continue
			hay += 1
			suma += float(dato["rodeo"])
			if float(dato["rodeo"]) > 2.0:
				malos += 1
		print("")
		print("--- %s ---" % Subsistence.season_name(estacion as Subsistence.Season))
		print("   con camino: %d de %d · rodeo medio x%.2f · con rodeo > x2: %d" % [
			hay, datos.size(), suma / maxf(float(hay), 1.0), malos])
		# LA CONTRADICCION: el sitio pasa la regla del rodeo -que se mide sobre
		# el camino mas corto EN METROS- y luego se anda por el mas barato EN
		# ESFUERZO, que es otro y puede ser mucho mas largo. Ver
		# [Marcha.alcanzable_desde_casa] y [Marcha._rehacer_el_mapa_de_casa].
		var admitidos_largos := 0
		for dato: Dictionary in datos:
			if bool(dato["hay"]) and bool(dato["admitido"]) 				and float(dato["rodeo"]) > Marcha.RODEO_QUE_SE_ANDA:
				admitidos_largos += 1
		print("   admitidos por la regla del rodeo y andados por encima de x%.1f: %d" % [
			Marcha.RODEO_QUE_SE_ANDA, admitidos_largos])

	# Y LO QUE DE VERDAD SE PREGUNTA: los mismos trayectos, en las dos
	# estaciones. Comparar medias sobre conjuntos distintos no dice nada.
	print("")
	print("=== LOS MISMOS TRAYECTOS, PRIMAVERA CONTRA VERANO ===")
	var ambos := 0
	var sube := 0
	var baja := 0
	var igual := 0
	var suma_p := 0.0
	var suma_v := 0.0
	var solo_verano := 0
	var peor := 0.0
	var peor_i := -1
	for i in range(destinos.size()):
		var p: Dictionary = primavera[i]
		var v: Dictionary = verano[i]
		if not bool(p["hay"]):
			if bool(v["hay"]):
				solo_verano += 1
			continue
		if not bool(v["hay"]):
			continue
		ambos += 1
		suma_p += float(p["rodeo"])
		suma_v += float(v["rodeo"])
		var d := float(v["rodeo"]) - float(p["rodeo"])
		if d < -0.05:
			baja += 1
		elif d > 0.05:
			sube += 1
		else:
			igual += 1
		if float(p["rodeo"]) > peor:
			peor = float(p["rodeo"])
			peor_i = i
	print("   trayectos que existen en las dos: %d" % ambos)
	if ambos > 0:
		print("   rodeo medio · primavera x%.2f -> verano x%.2f" % [
			suma_p / ambos, suma_v / ambos])
		print("   baja en verano: %d · igual: %d · sube: %d" % [baja, igual, sube])
	print("   trayectos que SOLO existen en verano: %d" % solo_verano)

	if peor_i >= 0:
		var p: Dictionary = primavera[peor_i]
		var v: Dictionary = verano[peor_i]
		print("")
		print("   el peor rodeo de primavera, seguido al verano:")
		print("      destino (%.0f, %.0f) a %.0f m en recta%s" % [
			destinos[peor_i].x, destinos[peor_i].z,
			Traversal.en_llano(casa, destinos[peor_i]),
			" · con lamina de agua en medio" if con_rio[peor_i] else ""])
		for pareja: Array in [["primavera", p], ["verano", v]]:
			var d: Dictionary = pareja[1]
			var cruce: float = float(d["cruce"])
			print("      %-10s rodeo x%.2f · %s · %s" % [
				pareja[0], float(d["rodeo"]),
				("cruza el agua a %.0f m del abrigo" % cruce) if cruce >= 0.0
					else "no toca el agua",
				"del arbol" if bool(d["arbol"]) else "de una busqueda"])
		_autopsia(_sim, casa, destinos[peor_i], p, v, por_estacion)

	# Donde se cruza el agua, de media, en cada estacion. Es la queja dicha en
	# un numero: el rodeo al vado del oeste cruza LEJOS.
	print("")
	print("=== DONDE SE CRUZA EL AGUA ===")
	for estacion: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		var datos: Array[Dictionary] = por_estacion[estacion]
		var cruzan := 0
		var suma := 0.0
		for dato: Dictionary in datos:
			if not bool(dato["hay"]) or float(dato["cruce"]) < 0.0:
				continue
			cruzan += 1
			suma += float(dato["cruce"])
		print("   %-10s %d caminos cruzan · a %.0f m del abrigo de media" % [
			Subsistence.season_name(estacion as Subsistence.Season), cruzan,
			suma / maxf(float(cruzan), 1.0)])


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
		return null
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
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo
