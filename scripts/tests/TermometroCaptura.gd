extends SceneTree
## La barra superior con los grados, para poder mirarla.
##
## Es como INTERFAZ.md §4 manda comprobar una lectura: mirándola. **Necesita
## ventana**: con `--headless`, `get_texture().get_image()` devuelve null, así
## que esto no se corre sin pantalla.
##
## ## Dos capturas y no cuatro, y hay que decir por qué
##
## INTERFAZ §4 pedía cuatro —mediodía de verano y noche de invierno, en la
## cueva y en el roquedo—. La barra enseña los grados **del abrigo**, que es
## donde está la banda cuando el frío importa, así que el par cueva/roquedo no
## se puede enseñar moviendo la cámara: no depende de dónde mires. Esa mitad la
## cubre `TestTermometro.test_entre_la_cueva_y_el_roquedo_hay_la_diferencia_que_toca`,
## que comprueba los 1,82 grados de los 280 m de desnivel.
##
## Lo que sí se ve aquí, que es lo que no se podía ver de ninguna otra manera:
## que en pantalla ponga grados, y que el verano y el invierno no se parezcan.

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar la escena")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0

	await _retratar(demo, sim, Subsistence.Season.VERANO, 15.0, "verano_tarde")
	await _retratar(demo, sim, Subsistence.Season.INVIERNO, 3.0, "invierno_noche")

	# Y UNA TERCERA CON ABRIGO PUESTO, porque la banda empieza sin ninguno y
	# con cero vestidos el rótulo sólo puede decir «sin abrigo»: la mitad que
	# INTERFAZ §4 pide —quién va vestido y con cuánto desgaste— no se vería.
	# Se cosen unos cuantos y se gasta uno más que los otros, que es el caso
	# que importa: el aviso tiene que hablar de LA PEOR, no de la media.
	for i in range(8):
		sim.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL, 0.6)
	var gastada := sim.toolkit.pick(Tool.Kind.VESTIDO)
	if gastada != null:
		gastada.wear(gastada.durability() * 0.72)
	await _retratar(demo, sim, Subsistence.Season.INVIERNO, 3.0, "invierno_abrigo")
	quit()


func _retratar(demo: Node, sim: SettlementSim, estacion: Subsistence.Season,
		hora: float, nombre: String) -> void:
	GameState.season = estacion
	sim.hour = hora
	# El rótulo sólo se reescribe cuando cambia el minuto, así que se le fuerza
	# la mano: ver [BarraSuperior._update_clock].
	demo.ui._clock_minute = -1
	demo.ui.barra._update_clock()
	for i in range(8):
		await process_frame

	var cota := 0.0
	if sim.terrain() != null:
		cota = sim.terrain().get_height_at(sim.home_position)
	print("%s · %s a las %.0f:00 · abrigo a %.0f m · %.1f °C · barra: «%s»" % [
		nombre, Subsistence.season_name(estacion), hora, cota,
		Termometro.grados(estacion, hora, cota),
		demo.ui._temp_label.text if demo.ui._temp_label != null else "(sin rótulo)"])

	var foto := get_root().get_texture().get_image()
	if foto == null:
		print("   LA IMAGEN SALE NULA: esto necesita ventana, no --headless")
		return
	# Sólo la banda de arriba, que es lo que se juzga.
	var alto := mini(64, foto.get_height())
	foto.save_png("user://termometro_%s.png" % nombre)
	var tira := foto.get_region(Rect2i(0, 0, foto.get_width(), alto))
	tira.save_png("user://barra_%s.png" % nombre)
	print("   user://barra_%s.png" % nombre)


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
