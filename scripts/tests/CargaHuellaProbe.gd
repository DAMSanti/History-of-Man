extends SceneTree
## La partida que sale de cargar, con pantalla de carga y sin ella, es la misma.
## INTERFAZ §9.3: «lo que se carga es lo de hoy».
##
##   godot --headless --path . --script res://scripts/tests/CargaHuellaProbe.gd
##
## Funda el valle 56, guarda, y retoma lo guardado dos veces: una de un tirón —como antes
## de la pantalla— y otra con la pantalla abierta, repartida entre cuadros. De las dos
## toma la instantánea de la partida **en el instante en que el mapa queda montado**, antes
## de que el reloj dé un paso, y compara sus bytes.
##
## Una sonda y no una prueba: retomar es montar la escena entera, 20 s cada vez.

const SITE_ID := 56

var _sitios: SiteSet
var _huella := PackedByteArray()
var _dia := -1


func _init() -> void:
	Guardado.carpeta = "user://sondas/mapas_huella"
	DirAccess.make_dir_recursive_absolute(Guardado.carpeta)
	_sitios = load("res://data/sites/cantabria_sites.res")
	_preparar()
	node_added.connect(_al_llegar)

	change_scene_to_file(Expedition.LOCAL_SCENE)
	if not await _esperar_montado():
		print("no se fundó"); quit(1); return
	(current_scene as Node).call("_dejar_la_escena")
	Campamentos.vaciar()

	var sin := await _retomar(false)
	Campamentos.vaciar()
	var con := await _retomar(true)

	print("")
	print("=== LA PARTIDA CARGADA, CON Y SIN PANTALLA ===")
	print("  sin pantalla: %d bytes, jornada %d, huella %d" % [sin[0].size(), sin[1], hash(sin[0])])
	print("  con pantalla: %d bytes, jornada %d, huella %d" % [con[0].size(), con[1], hash(con[0])])
	print("  %s" % ("LA MISMA" if sin[0] == con[0] and sin[1] == con[1] else "DISTINTAS"))
	quit()


func _retomar(con_pantalla: bool) -> Array:
	_huella = PackedByteArray()
	var guardado := Guardado.leer(SITE_ID)
	if guardado.is_empty() or not Guardado.preparar_la_escena(guardado, _sitios):
		print("no hay partida guardada")
		return [PackedByteArray(), -1]
	Expedition.retomando = true
	if con_pantalla:
		Carga.abrir(self, "Retomando la partida")
	change_scene_to_file(Expedition.LOCAL_SCENE)
	await _esperar_montado()
	return [_huella, _dia]


## La escena del mapa, al entrar en el árbol: se escucha su `se_monto` para tomar la
## instantánea en ese mismo instante, antes que cualquier `_process`.
func _al_llegar(nodo: Node) -> void:
	if nodo.get_parent() != root or nodo.get_script() == null \
			or (nodo.get_script() as Script).resource_path != "res://scripts/DemoMain.gd":
		return
	nodo.connect("se_monto", func() -> void:
		var sim: SettlementSim = nodo.get("sim")
		_huella = Instantanea.tomar(sim, nodo.get("herds")).bytes()
		_dia = sim.day)


func _esperar_montado() -> bool:
	for _i in range(20000):
		await process_frame
		if current_scene != null and bool(current_scene.get("montado")):
			return true
	return false


func _preparar() -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var site: Site = null
	for s: Site in _sitios.sites:
		if s.id == SITE_ID:
			site = s
	GameState.begin(_sitios)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))
