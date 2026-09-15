extends SceneTree
## Entrar de visita en un mapa que no es el de la banda.
##
## Decisión del usuario del 2026-09-14: «cuando voy al mapa regional y entro en
## otro mapa, no debe traer a mi banda, sólo cargar y mostrarme el mapa; lo que sí
## debe hacer es mantener la fecha». Comprueba lo que sólo se ve montando la
## escena de verdad: que no hay gente, que la fecha es la de la banda, que el
## reloj no se pone en marcha, y que al volver no queda estado del mapa visitado.
##
##   COPIA=<ruta del .sav de la banda, sitio 56> godot --headless --path . --script res://scripts/tests/VisitaProbe.gd

const BANDA := 56
const VISITA := 33


func _init() -> void:
	Guardado.carpeta = "user://sondas/mapas"
	Guardado.borrar()
	var copia := OS.get_environment("COPIA")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Guardado.carpeta))
	DirAccess.copy_absolute(copia, ProjectSettings.globalize_path(Guardado.ruta_de(BANDA)))
	var cabecera := Guardado.leer(BANDA)
	print("la banda: mapa %d, jornada %d · sitio_de_la_banda %d" % [BANDA,
		int(cabecera.get("jornada", -1)), Guardado.sitio_de_la_banda()])

	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % VISITA)
	var site: Site = null
	for s: Site in sitios.sites:
		if s.id == VISITA:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % VISITA
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	Expedition.visita = true
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(200):
		await process_frame
	var demo := current_scene
	var sim: SettlementSim = demo.sim
	demo.ui.barra._set_speed(5.0)
	var hora := sim.hour
	for i in range(60):
		await process_frame
	print("VISITA · gente %d · jornada %d · reloj %.1f · la hora se ha movido %.3f" % [
		sim.people.size(), sim.day, sim.time_scale, sim.hour - hora])
	demo._return_to_region()
	for i in range(30):
		await process_frame
	print("VUELTA · estado del mapa visitado: %s · la banda sigue en el %d" % [
		"HAY" if Guardado.hay_partida(VISITA) else "ninguno", Guardado.sitio_de_la_banda()])
	Guardado.borrar()
	quit()
