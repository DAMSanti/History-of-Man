extends SceneTree
## Tres quejas del usuario del 2026-09-14, contestadas en UNA corrida sobre una
## copia de su partida —nunca leída en su sitio—:
##
##   1. «No está pasando las noches rápido cuando todos se van a dormir.» Cada
##      hora de juego: cuánto reloj real ha costado, si `nadie_trabaja()` dejaba
##      acelerar, y quién lo impedía.
##   2. «Las cimas se quedan explorando en lugar de subir, coronar y terminar.»
##      Cada cambio de estado de quien sube, con su distancia a la cumbre más
##      cercana.
##   3. «No se están construyendo pasarelas.» Si se sabe la técnica, cuántas
##      veredas hay, cuál es el mejor cruce y por qué no vale.
##
##   COPIA=<ruta .sav> DIAS=2 VEL=5 godot --headless --path . --script res://scripts/tests/NocheCimaPasarelaProbe.gd

const SITE_ID := 56


func _init() -> void:
	Guardado.carpeta = "user://sondas/mapas"
	var copia := OS.get_environment("COPIA")
	if copia.is_empty():
		print("COPIA=<ruta de un .sav>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Guardado.carpeta))
	DirAccess.copy_absolute(copia, ProjectSettings.globalize_path(Guardado.ruta_de(SITE_ID)))
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	if not Guardado.preparar_la_escena(Guardado.leer(SITE_ID), sitios):
		print("la copia no se puede preparar")
		quit(1)
		return
	Expedition.retomando = true
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(200):
		await process_frame
	var demo := current_scene
	var sim: SettlementSim = demo.sim
	print("retomada: jornada %d, %.1f h, %d personas" % [sim.day, sim.hour, sim.people.size()])
	_pasarelas(sim)

	var dias := int(OS.get_environment("DIAS")) if OS.get_environment("DIAS").is_valid_int() else 2
	var hasta := sim.day + dias
	# VEL=1|3|5: la noche tiene que pasar igual de deprisa a cualquier velocidad.
	sim.time_scale = float(OS.get_environment("VEL")) if OS.get_environment("VEL").is_valid_float() else 5.0
	var hora := int(sim.hour)
	var reloj := Time.get_ticks_msec()
	var libres := 0
	var cuadros := 0
	var frenos := {}
	var estados := {}
	while sim.day < hasta:
		await process_frame
		demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
		cuadros += 1
		if sim.nadie_trabaja():
			libres += 1
		else:
			for person: Inhabitant in sim.people:
				match person.state:
					Inhabitant.State.TRABAJANDO, Inhabitant.State.BUSCANDO, \
							Inhabitant.State.RECONOCIENDO:
						var clave := "%s/%s/%s" % [Inhabitant.State.keys()[person.state],
							Profession.Job.keys()[person.job],
							Profession.Speciality.keys()[person.current_speciality]]
						frenos[clave] = int(frenos.get(clave, 0)) + 1
		_seguir_a_los_que_suben(sim, estados)
		if int(sim.hour) != hora:
			var ahora := Time.get_ticks_msec()
			print("hora %02d · %5d ms de reloj · acelera en %3d de %3d cuadros · frenan: %s" % [
				hora, ahora - reloj, libres, cuadros, _top(frenos)])
			hora = int(sim.hour)
			reloj = ahora
			libres = 0
			cuadros = 0
			frenos.clear()
	_pasarelas(sim)
	Guardado.borrar(SITE_ID)
	quit()


func _top(frenos: Dictionary) -> String:
	var claves := frenos.keys()
	claves.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(frenos[a]) > int(frenos[b]))
	var partes: Array[String] = []
	for i in range(mini(3, claves.size())):
		partes.append("%s×%d" % [claves[i], int(frenos[claves[i]])])
	return ", ".join(partes) if not partes.is_empty() else "-"


func _seguir_a_los_que_suben(sim: SettlementSim, estados: Dictionary) -> void:
	for person: Inhabitant in sim.people:
		if person.current_speciality != Profession.Speciality.ASCENSION:
			continue
		var estado: int = person.state
		if int(estados.get(person, -1)) == estado:
			continue
		estados[person] = estado
		var cerca := INF
		for peak: Dictionary in sim.cumbres.peaks():
			var pos: Vector3 = peak["pos"]
			cerca = minf(cerca, Vector2(person.position.x - pos.x,
				person.position.z - pos.z).length())
		var al_objetivo := Vector2(person.position.x - person.target.x,
			person.position.z - person.target.z).length()
		print("   CIMA · día %d %.1f h · %s → %s · a %.0f m de la cumbre más cercana · a %.0f m de su destino · coronadas %d" % [
			sim.day, sim.hour, person.given_name, Inhabitant.State.keys()[estado],
			cerca, al_objetivo, sim.cumbres.ascents])


func _pasarelas(sim: SettlementSim) -> void:
	var sabe := sim.techs != null and sim.techs.has(TechTree.Tech.PASARELA)
	print("PASARELAS · técnica %s · levantadas %d · obra %d celdas, %.1f jornadas · veredas %d" % [
		"sabida" if sabe else "NO sabida", sim.pasarelas.puentes.size(),
		sim.pasarelas.obra.size(), sim.pasarelas.jornadas_puestas,
		sim.knowledge.veredas.size() if sim.knowledge != null else -1])
	if sim.knowledge == null:
		return
	var mejores: Array = []
	for clave: Variant in sim.knowledge.veredas:
		var vereda: Vereda = sim.knowledge.veredas[clave]
		if vereda == null or vereda.hitos.size() < 2:
			continue
		var andado := 0.0
		for i in range(1, vereda.hitos.size()):
			andado += vereda.hitos[i].distance_to(vereda.hitos[i - 1])
		var recto := vereda.hitos[0].distance_to(vereda.hitos[vereda.hitos.size() - 1])
		var mojadas := sim.pasarelas._agua_en_la_recta(vereda.hitos[0],
			vereda.hitos[vereda.hitos.size() - 1])
		mejores.append([andado - recto, mojadas.size()])
	mejores.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var trozos: Array[String] = []
	for i in range(mini(8, mejores.size())):
		trozos.append("rodeo %.0f m / %d celdas de agua" % [float(mejores[i][0]), int(mejores[i][1])])
	print("   las veredas que más rodean: %s" % "; ".join(trozos))
	print("   celda de la rejilla %.0f m · tope %d celdas" % [Navgrid.CELL, Pasarelas.CELDAS_DE_ANCHO])
