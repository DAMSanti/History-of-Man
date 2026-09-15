extends SceneTree
## Treinta jornadas que contestan las dos preguntas que una prueba no puede.
##
## Tarea 13 del bloque de SISTEMAS §22. Una sola corrida con dos contadores,
## que es la regla de ARQUITECTURA §5.1: lo caro es arrancar la partida, no lo
## que se mida dentro.
##
##   Jornadas 1 a 10, SIN TOCAR NADA — se escribe la firma de cada jornada para
##   cotejarla con la de antes del trabajo (`Cotejo`). Contesta «nada cambia sin
##   tocar nada».
##
##   Jornadas 11 a 30, CON ENCARGOS Y PRIORIDADES — cada hora se apunta cuál es
##   la primera entrada hacedera de la cola de cada especialidad, y cuando el
##   utillaje sube en una pieza se mira si esa pieza estaba entre las apuntadas.
##   Contesta «lo que se ve es lo que se hace».
##
## La segunda no es tautológica aunque `_next_piece` lea la cola: lo que se
## compara es la pieza que **termina de verdad** contra la cabeza de cola de la
## hora anterior, con el progreso por persona, las roturas y la materia prima
## gastándose por en medio.
##
##   VEL=5 DIAS_LIMPIAS=10 DIAS_CON_COLA=20 FIRMAS=<fichero>

const SITE_ID := 56

var _barra: BarraSuperior = null
var _firmas: FileAccess = null

## Lo que podía hacerse, por especialidad, en la última hora mirada.
var _cabezas: Dictionary = {}

var _coinciden := 0
var _no_coinciden := 0
var _fuera_de_cola: Array[String] = []


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit(1)
		return
	var sim: Node = demo.sim

	var ruta := OS.get_environment("FIRMAS")
	if not ruta.is_empty():
		_firmas = FileAccess.open(ruta, FileAccess.WRITE)
	# La firma se toma en `day_passed`, DENTRO del paso que cierra la jornada,
	# igual que `TironAnualProbe`: mirarla desde el bucle la tomaría unos pasos
	# después según lo cargada que esté la máquina.
	sim.day_passed.connect(func(_d: int) -> void:
		if _firmas != null:
			_firmas.store_line(FirmaDiaria.de(sim, demo.herds, demo._caves).linea()))

	_barra = demo.ui.barra
	_contesta_los_momentos()
	sim.moment_raised.connect(func(_m: Moment) -> void: _contesta_los_momentos())

	var vel := 5.0
	if not OS.get_environment("VEL").is_empty():
		vel = float(OS.get_environment("VEL"))
	var limpias := 10
	if not OS.get_environment("DIAS_LIMPIAS").is_empty():
		limpias = int(OS.get_environment("DIAS_LIMPIAS"))
	var con_cola := 20
	if not OS.get_environment("DIAS_CON_COLA").is_empty():
		con_cola = int(OS.get_environment("DIAS_CON_COLA"))
	sim.time_scale = vel

	var primero: int = sim.day
	print("")
	print("=== %d JORNADAS SIN TOCAR NADA, Y %d CON LA COLA PUESTA (VEL=%.0f) ==="
		% [limpias, con_cola, vel])

	while sim.day < primero + limpias:
		await process_frame
	print("jornada %d: %d firmas escritas. A partir de aquí, encargos y prioridades."
		% [sim.day, limpias])

	# LO QUE PIDE EL JUGADOR. Un encargo de cada rama que se sabe hacer, una
	# especie en alta, un material en alta y otro en nunca: la cola deja de ser
	# la de por defecto y empieza a haber algo que vigilar.
	sim.taller.encargar_pieza(Tool.Kind.LASCA, 4)
	sim.taller.encargar_pieza(Tool.Kind.CESTO, 2)
	sim.fijar_prioridad_material(Materia.Kind.SILEX, Prioridades.Nivel.ALTA)
	sim.fijar_prioridad_material(Materia.Kind.CONCHA, Prioridades.Nivel.NUNCA)
	sim.fijar_prioridad_especie("ciervo", Prioridades.Nivel.ALTA)
	sim.fijar_prioridad_pieza(Tool.Kind.PUNZON, Prioridades.Nivel.BAJA)

	var tenia := _cuantas_hay(sim)
	var hora_mirada := -1
	while sim.day < primero + limpias + con_cola:
		await process_frame
		if int(sim.hour) == hora_mirada:
			continue
		hora_mirada = int(sim.hour)
		# Lo que subió desde la última mirada, contra lo que se podía hacer
		# entonces.
		var hay := _cuantas_hay(sim)
		for kind: int in hay:
			if int(hay[kind]) <= int(tenia.get(kind, 0)):
				continue
			if _estaba_en_cabeza(kind):
				_coinciden += 1
			else:
				_no_coinciden += 1
				if _fuera_de_cola.size() < 12:
					_fuera_de_cola.append("dia %d %02d:00 · %s" % [sim.day,
						hora_mirada, Tool.kind_name(kind as Tool.Kind)])
		tenia = hay
		_apunta_las_cabezas(sim)

	if _firmas != null:
		_firmas.close()

	print("")
	print("=== LO QUE SE VE ES LO QUE SE HACE ===")
	print("piezas terminadas que estaban a la cabeza de su cola: %d" % _coinciden)
	print("piezas terminadas que NO estaban:                     %d" % _no_coinciden)
	for linea: String in _fuera_de_cola:
		print("   %s" % linea)
	print("")
	print("encargos que quedan sin cumplir: %s" % str(sim.taller.encargos))
	quit(0 if _no_coinciden == 0 else 1)


## Cuántas piezas hay de cada tipo, ahora mismo.
func _cuantas_hay(sim: Node) -> Dictionary:
	var hay := {}
	for kind: int in Tool.Kind.values():
		hay[kind] = sim.toolkit.count(kind as Tool.Kind)
	return hay


## La primera entrada hacedera de cada especialidad, que es lo que un artesano
## de esa rama se pondría a hacer.
func _apunta_las_cabezas(sim: Node) -> void:
	_cabezas.clear()
	for speciality_key: int in SettlementSim.SPECIALITY_MAKES:
		var cabeza: int = sim.taller._next_piece(
			speciality_key as Profession.Speciality)
		if cabeza >= 0:
			_cabezas[speciality_key] = cabeza


func _estaba_en_cabeza(kind: int) -> bool:
	for speciality_key: int in _cabezas:
		if int(_cabezas[speciality_key]) == kind:
			return true
	# La primera hora de la ventana todavía no tiene nada apuntado: no se
	# cuenta como discrepancia porque no hay con qué comparar.
	return _cabezas.is_empty()


## Las decisiones, por la vía del jugador. Ver [BarraSuperior.contestar_todo] y
## SPECS §4.6: un aviso sin cerrar tapa la cola entera.
func _contesta_los_momentos() -> void:
	if _barra != null:
		_barra.contestar_todo(func(_m: Moment) -> int: return 0)


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
