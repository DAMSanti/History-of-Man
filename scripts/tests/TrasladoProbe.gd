extends SceneTree
## ¿La banda se muda de verdad? En la escena del juego, sin tocar posiciones: se
## manda trasladar a otra cueva a la que se llega y se deja correr el reloj hasta
## que se asienta.
##
## Cuenta cuántas horas de partida tarda, cuántos llegan andando, y si la casa, la
## hoguera y los tajos acaban en la cueva nueva.
##   godot --headless --path . --script res://scripts/tests/TrasladoProbe.gd

const SITE_ID := 56
const MAR_PALEOLITICO := -120.0


func _init() -> void:
	# Una sonda no escribe en los mapas del jugador. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/mapas"
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
	Expedition.sea_level_m = MAR_PALEOLITICO
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.retomando = false
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(150):
		await process_frame

	var demo := current_scene
	var sim: SettlementSim = demo.sim
	var ui: GameUI = demo.ui
	var contesta := func(_m: Moment) -> int: return 0
	ui.barra.contestar_todo(contesta)
	sim.store.add(Materia.Kind.FRUTO_SECO, 40.0)
	sim.store.add(Materia.Kind.PIEDRA, 300.0)

	# La cueva de casa, y otra a la que se llegue: la más cercana que valga.
	var casa: CaveMouth = demo._cave_at(sim.home_position)
	var destino: CaveMouth = null
	var mejor := INF
	for cueva: CaveMouth in demo._caves:
		if cueva == casa:
			continue
		var puntos: Dictionary = demo._casa_de(cueva)
		var falta := sim.traslado.lo_que_falta(cueva.id, puntos["campa"])
		var lejos := cueva.boca().distance_to(sim.home_position)
		print("cueva %d a %.0f m: %s" % [cueva.id, lejos, "se puede" if falta.is_empty() else falta])
		if falta.is_empty() and lejos < mejor:
			mejor = lejos
			destino = cueva
	if destino == null:
		print("ninguna cueva a la que mudarse")
		quit(1)
		return

	var puntos: Dictionary = demo._casa_de(destino)
	var hoguera_antes: Vector3 = demo.hearth_fire.global_position
	var tajos_antes := sim.work_sites.duplicate()
	var hora_salida := float(sim.day) * 24.0 + sim.hour
	assert(sim.traslado.mandar(destino.id, puntos["boca"], puntos["dentro"], puntos["campa"]))
	print("sale la banda hacia la cueva %d, a %.0f m, con %d personas" % [
		destino.id, mejor, sim.people.size()])
	for p: Inhabitant in sim.people:
		print("  %s carga %.1f kg de %.1f" % [p.given_name, p.load_kg(), p.carry_limit_kg()])

	sim.time_scale = 5.0
	var cuadros := 0
	while sim.traslado.en_marcha() and cuadros < 20000:
		await process_frame
		ui.barra.contestar_todo(contesta)
		cuadros += 1
		if cuadros % 600 == 0:
			var llegados := 0
			for p: Inhabitant in sim.people:
				if sim.traslado.ha_llegado(p):
					llegados += 1
			print("  día %d %.1f h · han llegado %d de %d" % [sim.day, sim.hour,
				llegados, sim.people.size()])
	var horas := float(sim.day) * 24.0 + sim.hour - hora_salida

	print("")
	if sim.traslado.en_marcha():
		print("NO SE ASENTÓ en %d cuadros" % cuadros)
		quit(1)
		return
	var penuria := false
	for entrada: Dictionary in sim.chronicle.entries:
		if String(entrada["text"]).contains("no encuentra el camino"):
			penuria = true
	print("asentada en %.1f horas de partida · red de seguridad usada: %s" % [horas, penuria])
	print("casa en la cueva nueva: %s · cueva de la banda %d" % [
		sim.home_position.distance_to(puntos["boca"]) < 1.0, sim.exploracion.cueva_de_la_banda])
	print("hoguera movida %.0f m · tajos rehechos: %s" % [
		demo.hearth_fire.global_position.distance_to(hoguera_antes),
		str(sim.work_sites != tajos_antes)])
	print("lo que se quedó en la vieja: %s" % str(sim.traslado.dejado))
	print("almacén al llegar: fruto seco %.0f · piedra %.0f" % [
		sim.store.amount(Materia.Kind.FRUTO_SECO), sim.store.amount(Materia.Kind.PIEDRA)])
	quit()
