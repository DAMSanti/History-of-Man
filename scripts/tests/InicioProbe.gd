extends SceneTree
## El momento inicial, en una escena real: ¿llega de verdad a la interfaz?
##
## Nace de docs/specs/QUE_FALTA_PARA_JUGARLO.md, tarea 5. El riesgo real no
## es el contenido del momento -eso ya lo prueba TestPartida.gd- sino el
## ORDEN de arranque en DemoMain: `sim.setup()` corre antes de que
## `ui.barra.watch_moments(sim)` conecte la señal, así que un `raise_moment`
## en el sitio equivocado se pierde sin avisar a nadie. Sólo una escena real
## -no una prueba unitaria con un `SettlementSim` suelto- puede demostrar que
## el orden es el correcto.

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan datos"); quit(); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID: site = s
	if site == null:
		print("sin emplazamiento"); quit(); return
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
	for i in range(90):
		await process_frame
	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var ui: GameUI = demo.ui if "ui" in demo else null
	if sim == null or ui == null:
		print("sin simulacion o interfaz"); quit(); return

	# Nada del jugador ha pasado todavia -ni un click-, y ya deberia haber
	# una tarjeta de momento en pantalla: la del arranque.
	var card: Control = ui.get("_moment_card")
	if card == null:
		print("FALLO: no hay ninguna tarjeta de momento en la primera jornada")
		quit(1); return

	var head := _find_label(card)
	if head == null:
		print("FALLO: la tarjeta no tiene ningun rotulo que leer")
		quit(1); return

	var esperado := "UN ABRIGO, UNA BANDA"
	if head.text != esperado:
		print("FALLO: la tarjeta que se ve dice '%s', se esperaba '%s'"
			% [head.text, esperado])
		quit(1); return

	print("OK: el momento inicial llega a la interfaz en la primera jornada,")
	print("    antes de cualquier accion del jugador. dia=%d" % [sim.day])
	quit(0)


## El primer `Label` que encuentre, en profundidad. La tarjeta la construye
## `BarraSuperior._build_moment_card`: el titular es el primer `Label` del
## `VBoxContainer` interior.
func _find_label(node: Node) -> Label:
	if node is Label:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child)
		if found != null:
			return found
	return null
