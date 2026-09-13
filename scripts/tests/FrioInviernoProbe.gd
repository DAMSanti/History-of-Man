extends SceneTree
## Un invierno entero, con ropa o sin ella. M2 de la tanda 2 del Paleolítico.
##
## El criterio del frente 7 —EPOCA_01 §10.1— es: «dos corridas con la misma
## semilla, una en la que la banda hace ropa y otra en la que no. En la que no,
## alguien enferma o muere de frío; en la que sí, menos o ninguno. Si nadie
## enferma de frío, la necesidad no existe y el frente no está hecho».
##
## **Construye el estado en vez de simular hasta él** —ARQUITECTURA §5.1—: pone
## la partida en el último día de otoño y corre el invierno. Llegar hasta ahí
## simulando cuesta tres estaciones y no comprueba nada más.
##
## **Y LA DESPENSA Y EL AGUA SE MANTIENEN LLENAS**, decidido el 2026-09-13 tras
## la primera pasada. En ella se construyó sólo el calendario: la despensa era
## la del primer día de primavera, la banda entera **murió de hambre** en 18 y
## 22 jornadas de invierno, con y sin ropa, y **nadie llegó a enfermar de frío**
## porque los muertos no enferman. El hambre tapaba la pregunta. Aquí se
## neutraliza: lo que se mide es el frío y nada más. Se rellena CADA DÍA y no
## una vez, porque la despensa tiene tope por cestos y odres y parte se pudre.
## Es un control de la prueba, no una cifra de balance.
##
##   ROPA=si|no     con un vestido por cabeza, o sin ninguno en todo el invierno
##   VIGIA=fichero  una línea cada diez jornadas, con flush

const SITE_ID := 56


func _init() -> void:
	var con_ropa := OS.get_environment("ROPA") != "no"
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar la escena")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	var ui: GameUI = demo.ui
	sim.assign_default_jobs()

	# EL ÚLTIMO DÍA DE OTOÑO: la jornada siguiente entra el invierno.
	GameState.season = Subsistence.Season.OTONO
	sim.season_day = Subsistence.DAYS_PER_SEASON - 1
	sim.temporada.asentar(Subsistence.Season.OTONO)

	_la_ropa(sim, con_ropa)
	_llenar_la_despensa(sim)
	var ultimo_dia_lleno := {"v": sim.day}

	var vigia: FileAccess = null
	if not OS.get_environment("VIGIA").is_empty():
		vigia = FileAccess.open(OS.get_environment("VIGIA"), FileAccess.WRITE)

	var enfermaron := {}
	var inicio := sim.day
	var entro_el_invierno := false
	sim.time_scale = 5.0
	while true:
		await process_frame
		# Las decisiones, por la vía del jugador y con la opción que no
		# compromete: el fuego a manos llenas, que es lo que se quiere medir.
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
		# Sin ropa quiere decir sin ropa TODO el invierno: si la peletería cose
		# un vestido por el camino, se retira. Si no, el brazo «sin ropa» deja
		# de serlo a mitad.
		if not con_ropa:
			_la_ropa(sim, false)
		if sim.day != int(ultimo_dia_lleno["v"]):
			ultimo_dia_lleno["v"] = sim.day
			_llenar_la_despensa(sim)
		for p: Inhabitant in sim.people:
			if p.cold_sick_days > 0:
				enfermaron[p.id] = p.given_name
		if GameState.season == Subsistence.Season.INVIERNO:
			entro_el_invierno = true
		if entro_el_invierno and GameState.season != Subsistence.Season.INVIERNO:
			break
		if sim.partida_terminada():
			break
		if vigia != null and (sim.day - inicio) % 10 == 0 and sim.hour < 0.3:
			vigia.store_line("dia %d · %s · vivos %d · enfermos de frio hasta ahora %d" % [
				sim.day, Subsistence.season_name(GameState.season),
				sim.people.size(), enfermaron.size()])
			vigia.flush()

	var de_frio := 0
	var muertes: Array[String] = []
	for entrada: Dictionary in sim.chronicle.entries:
		var texto := String(entrada.get("text", ""))
		if texto.contains("murió de frío"):
			de_frio += 1
		# De qué muere cada uno, para que si vuelve a morir alguien se sepa si
		# es el frío o es otra cosa tapándolo, como en la primera pasada.
		if texto.contains("murió") or texto.contains("muere"):
			muertes.append(texto)
	var frio_medio := 0.0
	for p: Inhabitant in sim.people:
		frio_medio += p.cold
	frio_medio /= maxf(float(sim.people.size()), 1.0)
	print("M2 ROPA=%s · jornadas %d · vivos al acabar %d · enfermaron de frio %d · murieron de frio %d · frio medio final %.1f" % [
		"si" if con_ropa else "no", sim.day - inicio, sim.people.size(),
		enfermaron.size(), de_frio, frio_medio])
	print("   quienes enfermaron: %s" % str(enfermaron.values()))
	print("   de qué murió cada uno: %s" % str(muertes))
	quit()


## Deja la despensa con comida de sobra para todo el invierno, y los odres llenos.
##
## El doble de lo que come la banda en una estación: no es una cifra de balance,
## es «que el hambre no cuente». Carne seca porque no se pudre.
static func _llenar_la_despensa(sim: SettlementSim) -> void:
	var hace_falta := float(sim.despensa.winter_stock()["needed"]) * 2.0
	var hay := sim.store.food_rations()
	if hay < hace_falta:
		var nutre := maxf(Materia.nutrition(Materia.Kind.CARNE_SECA), 0.001)
		sim.store.add(Materia.Kind.CARNE_SECA, (hace_falta - hay) / nutre)
	sim.store.add(Materia.Kind.AGUA, 100.0)


## Un vestido por cabeza, o ninguno.
static func _la_ropa(sim: SettlementSim, con_ropa: bool) -> void:
	var tiene := sim.toolkit.count(Tool.Kind.VESTIDO)
	if con_ropa:
		for i in range(maxi(sim.people.size() - tiene, 0)):
			sim.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL, 0.6)
	else:
		while sim.toolkit.detach(Tool.Kind.VESTIDO) != null:
			pass


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
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
		return null
	return demo
