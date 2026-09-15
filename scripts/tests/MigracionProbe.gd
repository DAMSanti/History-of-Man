extends SceneTree
## Migrar de verdad, con escenas: SISTEMAS §23, tareas 9, 12 y 14.
##
## Las reglas están en la suite (`TestViaje`, `TestGuardado`, `TestReloj`), pero
## lo que no cabe en ella es lo que necesita escena y árbol: fundar al llegar
## —monta relieve—, que la escena adopte un campamento vivo en vez de montar
## otro, que al salir al mapa regional la partida siga, la visita con el reloj
## corriendo y retomar varios campamentos desde disco.
##
## Recorre, en este orden:
##
##   1. se entra en el sitio 56 y se empieza la partida: un campamento, y el reloj;
##   2. se manda a dos personas al sitio 14 y se sale al mapa regional;
##   3. en el regional la partida sigue: el grupo llega y **funda**;
##   4. se entra en el 14: la escena **adopta** el campamento fundado;
##   5. se salta al 56 desde la lista, sin pasar por el regional;
##   6. se visita el 33: la fecha de la visita es la de todos, y avanza;
##   7. se guarda, se tira todo y se retoma: vuelven los dos campamentos.
##
## Guarda en su propia carpeta, nunca en la del jugador. Unos minutos: lo que
## tarde en pasar el viaje, que entre 56 y 14 es de una jornada.
##
##   godot --headless --path . --script res://scripts/tests/MigracionProbe.gd

const ORIGEN := 56
const DESTINO := 14
const VISITA := 33
const CARPETA := "user://sondas/migracion/mapas"

var _fallos: Array[String] = []
var _sitios: SiteSet


func _initialize() -> void:
	Guardado.carpeta = CARPETA
	Guardado.borrar()
	_sitios = load(MenuPrincipal.SITIOS) as SiteSet

	print("")
	print("=== MIGRAR, CON ESCENAS ===")
	# 1. Entrar y empezar.
	_traspaso(ORIGEN, false)
	var demo := await _escena_local()
	if demo == null:
		_acabar()
		return
	demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	_comprueba(Campamentos.vivos.size() == 1, "empezar da de alta un campamento",
		"hay %d campamentos" % Campamentos.vivos.size())
	var origen: Campamento = demo.campamento
	demo.sim.time_scale = 5.0
	await _hasta(func() -> bool: return Campamentos.reloj.dia >= 2, demo)

	# 2. Mandar y salir.
	var grupo: Array = []
	for persona: Inhabitant in origen.sim.people:
		if persona.age_group == Inhabitant.Age.ADULTO and persona.hurt_days == 0 \
				and not persona.esta_de_expedicion(origen.sim.day) and grupo.size() < 2:
			grupo.append(persona)
	var viaje := Campamentos.mandar(origen, grupo, _sitio(DESTINO))
	_comprueba(viaje != null, "sale el grupo", Viaje.ultimo_motivo)
	if viaje == null:
		_acabar()
		return
	print("   el viaje sale el día %d y llega el %d" % [viaje.sale_el_dia, viaje.llega_el_dia])
	var gente_origen := origen.sim.people.size()
	demo._return_to_region()
	await _frames(30)
	_comprueba(not origen.is_inside_tree(), "al salir, el campamento deja la escena", "")
	_comprueba(Campamentos.vivos.has(origen), "pero no la partida", "")

	# 3. En el regional la partida sigue, y el grupo funda.
	var dia_al_salir := Campamentos.reloj.dia
	await _hasta(func() -> bool: return Campamentos.de_sitio(DESTINO) != null, null, 6000)
	var fundado := Campamentos.de_sitio(DESTINO)
	_comprueba(Campamentos.reloj.dia > dia_al_salir, "en el mapa regional la fecha avanza",
		"sigue en el día %d" % Campamentos.reloj.dia)
	_comprueba(fundado != null and fundado.sim.people.size() == 2,
		"al llegar, funda con los dos", "fundado: %s" % str(fundado))
	if fundado == null:
		_acabar()
		return
	_comprueba(fundado.sim.day == Campamentos.reloj.dia, "en la jornada de la partida",
		"%d frente a %d" % [fundado.sim.day, Campamentos.reloj.dia])
	_comprueba(origen.sim.people.size() == gente_origen, "y el origen no ha recuperado a nadie", "")

	# 4. Entrar en el fundado: se adopta.
	Campamentos.traspaso_de(fundado)
	change_scene_to_file(Expedition.LOCAL_SCENE)
	demo = await _escena_local()
	if demo == null:
		_acabar()
		return
	_comprueba(demo.campamento == fundado and demo._adoptado,
		"la escena adopta el campamento vivo, no monta otro", "")
	_comprueba(Campamentos.vivos.size() == 2, "y sigue habiendo dos",
		"hay %d" % Campamentos.vivos.size())
	_comprueba(fundado.sim.se_mira and fundado.is_inside_tree(), "que ahora se mira", "")

	# 5. Saltar al origen desde la lista.
	demo.ui.ir_al_campamento.emit(origen)
	demo = await _escena_local()
	if demo == null:
		_acabar()
		return
	_comprueba(demo.campamento == origen, "el salto directo lleva al otro campamento", "")
	_comprueba(not fundado.is_inside_tree(), "y el de antes sale de la escena", "")

	# 6. La visita, con el reloj.
	demo._return_to_region()
	await _frames(30)
	_traspaso(VISITA, true)
	demo = await _escena_local()
	if demo == null:
		_acabar()
		return
	demo.sim.time_scale = 5.0
	var dia_visita := Campamentos.reloj.dia
	await _hasta(func() -> bool: return Campamentos.reloj.dia > dia_visita, demo, 6000)
	_comprueba(demo.sim.day == Campamentos.reloj.dia, "la visita va en la fecha de todos",
		"%d frente a %d" % [demo.sim.day, Campamentos.reloj.dia])
	_comprueba(Campamentos.reloj.dia > dia_visita, "y el reloj corre mientras se visita", "")
	demo._return_to_region()
	await _frames(30)
	_comprueba(Campamentos.reloj.campamentos.size() == 2,
		"al irse, la visita suelta el reloj", "el reloj lleva %d simulaciones"
		% Campamentos.reloj.campamentos.size())

	# 7. Guardar, tirar y retomar.
	Campamentos.traspaso_de(origen)
	change_scene_to_file(Expedition.LOCAL_SCENE)
	demo = await _escena_local()
	if demo == null:
		_acabar()
		return
	var dias := {ORIGEN: origen.sim.day, DESTINO: fundado.sim.day}
	var gente := {ORIGEN: origen.sim.people.size(), DESTINO: fundado.sim.people.size()}
	demo.sim.time_scale = 0.0
	await _frames(3)
	demo._return_to_region()
	await _frames(30)
	Campamentos.vaciar()
	await _frames(3)
	_comprueba(FileAccess.file_exists(CARPETA.path_join(Guardado.PARTIDA)),
		"guardar escribe la cabecera de la partida", "")
	if not Guardado.preparar_la_escena(Guardado.leer(ORIGEN), _sitios):
		_mal("no se puede preparar la escena desde lo guardado")
		_acabar()
		return
	Expedition.retomando = true
	change_scene_to_file(Expedition.LOCAL_SCENE)
	demo = await _escena_local()
	if demo == null:
		_acabar()
		return
	_comprueba(Campamentos.vivos.size() == 2, "al retomar vuelven los dos campamentos",
		"hay %d" % Campamentos.vivos.size())
	var retomado := Campamentos.de_sitio(DESTINO)
	if retomado != null:
		_comprueba(retomado.sim.people.size() == int(gente[DESTINO]),
			"con su gente", "%d frente a %d" % [retomado.sim.people.size(), gente[DESTINO]])
		_comprueba(retomado.sim.day == int(dias[DESTINO]), "en su jornada",
			"%d frente a %d" % [retomado.sim.day, dias[DESTINO]])
		_comprueba(not retomado.is_inside_tree(), "sin mirarlo", "")
	_comprueba(demo.sim.people.size() == int(gente[ORIGEN]), "y el de la escena, con la suya", "")
	_acabar()


func _traspaso(id: int, de_visita: bool) -> void:
	var sitio := _sitio(id)
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % id)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.visita = de_visita
	Expedition.retomando = false
	Expedition.site = sitio
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % id
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = GameState.era
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(sitio.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(sitio.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file(Expedition.LOCAL_SCENE)


## Espera a la escena local nueva, con su simulación y su interfaz.
func _escena_local() -> Node:
	var antes := current_scene
	for i in range(600):
		await process_frame
		var escena := current_scene
		if escena != null and escena != antes and "sim" in escena \
				and escena.get("sim") != null and escena.get("ui") != null:
			await _frames(5)
			return escena
	_mal("la escena local no llega a montarse")
	return null


## Espera hasta que se cumpla algo, contestando lo que salga por el camino: en la
## escena, por la barra; sin escena, lo que se quedó sin ver, y devolviendo la
## velocidad que la decisión paró.
func _hasta(condicion: Callable, demo: Node, tope: int = 20000) -> void:
	for i in range(tope):
		if condicion.call():
			return
		if demo != null and is_instance_valid(demo):
			demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
			if demo.sim.time_scale <= 0.0:
				demo.sim.time_scale = 5.0
		else:
			for moment: Moment in Campamentos.sin_ver:
				if moment.is_decision():
					(moment.options[0]["on_pick"] as Callable).call()
			Campamentos.sin_ver.clear()
			if Campamentos.reloj != null and Campamentos.reloj.time_scale <= 0.0:
				Campamentos.reloj.time_scale = 5.0
		await process_frame
	_mal("se acabó la espera sin que se cumpliera la condición")


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _sitio(id: int) -> Site:
	for s: Site in _sitios.sites:
		if s.id == id:
			return s
	return null


func _comprueba(bien: bool, que: String, porque: String) -> void:
	if bien:
		print("   ok · %s" % que)
	else:
		_mal("%s: %s" % [que, porque])


func _mal(linea: String) -> void:
	_fallos.append(linea)
	print("   MAL · %s" % linea)


func _acabar() -> void:
	print("")
	if _fallos.is_empty():
		print("=== TODO BIEN ===")
	else:
		print("=== %d COSAS MAL ===" % _fallos.size())
		for linea: String in _fallos:
			print("   %s" % linea)
	Campamentos.vaciar()
	Guardado.borrar()
	quit(0 if _fallos.is_empty() else 1)
