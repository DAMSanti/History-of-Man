extends SceneTree
## Un año entero cazando tirones: por hora, por día, y el desglose de cada uno
## grave EN EL MOMENTO en que ocurre.
##
## La queja: «hay tirones de varios segundos y se hacen más comunes según
## avanza la partida». `PicoProbe` caza el desglose pero solo mira unos pocos
## días; `CrecimientoProbe` sigue lo que se acumula pero tampoco dice CUÁNDO
## aprieta. Esto junta las dos preguntas sobre el año completo: cuánto tarda
## cada fotograma —por hora y por día— y en cuanto un tirón pasa de [GRAVE]
## milisegundos se vuelca su desglose ahí mismo, con el día y la hora, para
## poder cruzarlo después con lo que estaba creciendo entonces.
##
## Un año a VEL=20 tarda unas tres horas de reloj real (una jornada, algo más
## de un minuto). Lanzar con `tee` a un archivo y seguirlo con `tail -f` en
## vez de esperar sentado — y de una sonda en una, nunca en paralelo con otra
## medición: se estorban y falsean las cuentas.
##
##   VEL=20 DIAS=180 LIMITE=100 GRAVE=1000
##
##   VEL     time_scale de la partida
##   DIAS    jornadas a correr (180 = un año completo)
##   LIMITE  ms a partir de los cuales un fotograma cuenta como tirón
##   GRAVE   ms a partir de los cuales se vuelca el desglose EN EL MOMENTO
##           (1000 = un segundo; súbelo a 2000 para quedarte solo con los
##           «de varios segundos» de la queja original)
##   FIRMAS  fichero donde escribir la firma de cada jornada ([FirmaDiaria]),
##           para cotejar dos corridas con `Cotejo.gd`
##   CEPO    0 para apagar el cepo: con él apagado no hay tirones que contar,
##           pero sirve para comprobar que medir no cambia la partida
##   RESUMEN fichero CSV con el ranking de tramos, para `Cotejo.gd -- tramos`
##   INSTANTANEAS  carpeta donde dejar una instantánea cada CADA jornadas
##   CADA    cada cuántas jornadas se guarda una instantánea (15)
##   DESDE   fichero de instantánea del que arrancar, en vez de empezar una
##           partida nueva: ver [Instantanea]

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim

	# LA FIRMA DE CADA JORNADA, si se pide. Se toma en `day_passed`, DENTRO del
	# paso en que se cierra la jornada: mirar `sim.day` desde el bucle de abajo
	# la tomaría unos pasos después según lo cargada que esté la máquina. Ver
	# [FirmaDiaria].
	var firmas_ruta := OS.get_environment("FIRMAS")
	if not firmas_ruta.is_empty():
		_firmas = FileAccess.open(firmas_ruta, FileAccess.WRITE)
		if _firmas == null:
			print("no se puede escribir %s" % firmas_ruta)
			quit(1)
			return

	# LAS INSTANTÁNEAS, para poder medir una ventana de mitad del año sin
	# correr todo lo anterior. Ver [Instantanea] y la tarea 16 de la spec.
	_instantaneas = OS.get_environment("INSTANTANEAS")
	if not _instantaneas.is_empty():
		DirAccess.make_dir_recursive_absolute(_instantaneas)
		if not OS.get_environment("CADA").is_empty():
			_cada = maxi(int(OS.get_environment("CADA")), 1)

	if _firmas != null or not _instantaneas.is_empty():
		_demo = demo
		# AL FINAL DEL PASO, NO A MITAD. `day_passed` se emite dentro de
		# `_advance`, antes de que la gente y la fauna hagan lo suyo: una
		# instantánea tomada ahí es media partida a medio paso, y arrancar de
		# ella pierde esa mitad. Se apunta la jornada y se espera al cierre del
		# paso. Ver la tarea 17 de la spec.
		sim.day_passed.connect(func(dia: int) -> void: _dia_pendiente = dia)
		sim.paso_cerrado.connect(_cierra_el_paso)

	# ARRANCAR EN LA JORNADA N. La partida está todavía en pausa —`setup` deja
	# `time_scale` a cero— y NO se reparte: el reparto viene en la instantánea.
	var desde := OS.get_environment("DESDE")
	if desde.is_empty():
		sim.assign_default_jobs()
	else:
		var fichero := FileAccess.open(desde, FileAccess.READ)
		if fichero == null:
			print("no se puede leer %s" % desde)
			quit(1)
			return
		var foto := Instantanea.desde_bytes(fichero.get_buffer(fichero.get_length()))
		if foto == null:
			print("%s no es una instantánea de esta versión" % desde)
			quit(1)
			return
		var fallos := foto.volcar(sim, demo.herds, demo._caves)
		for aviso: String in foto.avisos:
			print("   aviso: %s" % aviso)
		if not fallos.is_empty():
			for fallo: String in fallos:
				print("   ERROR: %s" % fallo)
			print("la instantánea no cuadra con este código: se para")
			quit(1)
			return
		print("arrancando en la jornada %d, desde %s" % [sim.day, desde])

	var vel := 20.0
	if not OS.get_environment("VEL").is_empty():
		vel = float(OS.get_environment("VEL"))
	sim.time_scale = vel

	var dias := 180
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	var limite := 100.0
	if not OS.get_environment("LIMITE").is_empty():
		limite = float(OS.get_environment("LIMITE"))

	var grave := 1000.0
	if not OS.get_environment("GRAVE").is_empty():
		grave = float(OS.get_environment("GRAVE"))

	# LOS MOMENTOS, POR LA VÍA DEL JUGADOR -ver `BarraSuperior.elegir`-. Se
	# toma la opción que menos toca el reparto por defecto: en la berrea, seguir
	# como hasta ahora; en un percance, volver ya. Y los hallazgos se cierran.
	#
	# Se contestaba llamando a `on_pick` a pelo, y eso NO es lo que hace un
	# jugador: la tarjeta del arranque se quedaba abierta la corrida entera, todo
	# lo que venía después se apilaba detrás sin enseñarse, y la barra no paraba
	# el reloj nunca. Ver la tarea 1 de docs/specs/LO_MISMO_MAS_DEPRISA.md. La
	# del arranque se cierra la primera, como la cerraría quien juega.
	_barra = demo.ui.barra
	_contesta_los_momentos()
	sim.moment_raised.connect(func(_m: Moment) -> void: _contesta_los_momentos())

	# EL PANEL DE F3 SE QUEDA VIVO, y a propósito: quien mira la corrida tiene
	# que poder abrirlo y ver los mismos tirones que cuenta la sonda. Podían
	# los dos porque la bandeja de picos ya no la vacía quien lee —ver
	# [Cronometro.picos]—; antes se la quedaba el primero que pasara y la
	# sonda contaba 3 de cada 92. Ver la tarea 21 de
	# docs/specs/LO_MISMO_MAS_DEPRISA.md.

	Cronometro.limite_ms = limite
	Cronometro.activo = OS.get_environment("CEPO") != "0"
	Cronometro.reinicia()

	print("")
	print("=== UN AÑO CAZANDO TIRONES (%d jornadas, VEL=%.0f, LIMITE=%.0f ms, GRAVE=%.0f ms) ===" % [
		dias, vel, limite, grave])
	print("%-4s %-5s %6s %9s %6s" % ["dia", "hora", "fps", "peor ms", "tiron"])

	var primero: int = sim.day
	_primero = primero
	var dia_actual: int = sim.day
	var hora_actual := int(sim.hour)

	var h_frames := 0
	var h_suma_ms := 0.0
	var h_peor_ms := 0.0
	var h_tirones := 0

	var d_frames := 0
	var d_suma_ms := 0.0
	var d_peor_ms := 0.0
	var d_tirones := 0

	var todos: Array[Dictionary] = []
	var graves: Array[Dictionary] = []
	var t_frame_anterior := Time.get_ticks_usec()
	var apartado_antes := Cronometro.apartado_us

	while sim.day < primero + dias:
		await process_frame
		var ahora := Time.get_ticks_usec()
		# Lo que tardó la sonda en tomar la firma no es del fotograma del juego.
		var apartado := Cronometro.apartado_us - apartado_antes
		apartado_antes = Cronometro.apartado_us
		var delta_ms := float(ahora - t_frame_anterior - apartado) / 1000.0
		t_frame_anterior = ahora

		h_frames += 1; h_suma_ms += delta_ms; h_peor_ms = maxf(h_peor_ms, delta_ms)
		d_frames += 1; d_suma_ms += delta_ms; d_peor_ms = maxf(d_peor_ms, delta_ms)

		for pico: Dictionary in Cronometro.picos:
			pico["dia"] = sim.day
			pico["hora"] = sim.hour
			todos.append(pico)
			h_tirones += 1
			d_tirones += 1
			if float(pico["total"]) >= grave:
				graves.append(pico)
				print("")
				print("!!! TIRON GRAVE: %.0f ms · dia %d, %02d:%02d · %s" % [
					float(pico["total"]), sim.day, int(sim.hour),
					int(fmod(sim.hour, 1.0) * 60.0), String(pico.get("etiqueta", ""))])
				for tramo: Dictionary in (pico["desglose"] as Array):
					if float(tramo["ms"]) < 1.0:
						break
					print("      %7.1f ms  %-42s x%d" % [
						float(tramo["ms"]), String(tramo["tramo"]), int(tramo["veces"])])
		# No se vacía: la bandeja es del cuadro en curso y la limpia el cepo al
		# abrir el siguiente, para que el panel de F3 vea lo mismo que esto.

		if int(sim.hour) != hora_actual or sim.day != dia_actual:
			print("%-4d %02d:00 %6.1f %9.1f %6d" % [
				dia_actual, hora_actual,
				1000.0 / maxf(h_suma_ms / maxf(float(h_frames), 1.0), 0.001),
				h_peor_ms, h_tirones])
			h_frames = 0; h_suma_ms = 0.0; h_peor_ms = 0.0; h_tirones = 0
			hora_actual = int(sim.hour)

		if sim.day != dia_actual:
			print("--- dia %d cerrado (%s): fps medio %.1f · peor fotograma %.0f ms · %d tirones · %s ---" % [
				dia_actual,
				Subsistence.season_name(GameState.season as Subsistence.Season),
				1000.0 / maxf(d_suma_ms / maxf(float(d_frames), 1.0), 0.001),
				d_peor_ms, d_tirones, _crecimiento(sim)])
			d_frames = 0; d_suma_ms = 0.0; d_peor_ms = 0.0; d_tirones = 0
			dia_actual = sim.day

	Cronometro.activo = false
	if _firmas != null:
		print("")
		print("firmas escritas: %d jornadas · lo que tardó la sonda en tomarlas, fuera de la cuenta: %.0f ms" % [
			_firmas_escritas, float(Cronometro.apartado_us) / 1000.0])

	# LO QUE VE EL CEPO CONTRA LO QUE MIDE LA SONDA. Si no se parecen, el
	# recuento de tirones no vale: la sonda mide de `process_frame` a
	# `process_frame` y el cepo de `DemoMain._process` al siguiente.
	print("")
	print("cuadros del cepo: %d · media %.1f ms · peor %.0f ms · picos empujados %d" % [
		Cronometro.cuadros(), Cronometro.media_ms(), Cronometro.peor_ms(),
		Cronometro.empujados])

	# El objetivo de docs/specs/QUE_FALTA_PARA_JUGARLO.md, aprovechando que
	# esta corrida ya recorre el año entero: victoria/derrota y cuánto hay
	# pintado en la pared. `sim.desenlace`/`desenlace_dia` no dependen de
	# ninguna sonda -los pone `Partida` directamente en `SettlementSim`-, así
	# que basta con leerlos aquí; no hace falta otra corrida sólo para esto.
	print("")
	var desenlace_nombre: String = SettlementSim.Desenlace.keys()[sim.desenlace]
	if sim.desenlace == SettlementSim.Desenlace.NINGUNO:
		print("desenlace: %s (%d relatos pintados de %d para ganar)" % [
			desenlace_nombre, sim.paintings.size(), SettlementSim.CUEVA_PINTADA_MINIMO])
	else:
		print("desenlace: %s, en la jornada %d (%d relatos pintados)" % [
			desenlace_nombre, sim.desenlace_dia, sim.paintings.size()])

	# Y quién nació y quién murió, con la causa: lo pide
	# docs/specs/QUE_SE_PUEDA_PERDER.md para leer la población con su porqué y
	# no sólo con su número. La crónica ya dice la causa en cada entrada.
	print("")
	print("=== GENTE: nacimientos y muertes del año ===")
	var de_gente := 0
	if sim.chronicle != null:
		for entrada: Dictionary in sim.chronicle.entries:
			if int(entrada["kind"]) != Chronicle.Kind.GENTE:
				continue
			de_gente += 1
			print("   jornada %d: %s" % [int(entrada["day"]), String(entrada["text"])])
	print("   (%d entradas)" % de_gente)

	print("")
	print("=== RESUMEN DEL AÑO: %d tirones de mas de %.0f ms, %d graves (>= %.0f ms) ===" % [
		todos.size(), limite, graves.size(), grave])
	if todos.is_empty():
		quit()
		return

	# Donde se va el tiempo, sumando TODOS los tirones del año -no solo los
	# graves-, igual que hace PicoProbe pero sobre 180 dias en vez de 4.
	var suma: Dictionary = {}
	var veces: Dictionary = {}
	var total_tirones := 0.0
	for pico2: Dictionary in todos:
		total_tirones += float(pico2["total"])
		for tramo2: Dictionary in (pico2["desglose"] as Array):
			var nombre: String = tramo2["tramo"]
			# EL MOTOR lleva pegados los nodos, los objetos y los dibujos DE
			# ESE fotograma, así que cada tirón inventaría un tramo distinto y
			# el ranking lo contaría en trocitos. Se juntan todos.
			if nombre.begins_with("· EL MOTOR"):
				nombre = "· EL MOTOR (pintar, fisica)"
			suma[nombre] = float(suma.get(nombre, 0.0)) + float(tramo2["ms"])
			veces[nombre] = int(veces.get(nombre, 0)) + int(tramo2["veces"])
	print("")
	print("--- SUMANDO TODOS LOS TIRONES DEL AÑO (%.0f ms en total) ---" % total_tirones)
	var orden: Array[String] = []
	for nombre2: String in suma:
		orden.append(nombre2)
	orden.sort_custom(func(a: String, b: String) -> bool: return float(suma[a]) > float(suma[b]))
	for nombre3: String in orden:
		var ms: float = suma[nombre3]
		print("   %8.0f ms %3.0f %%  %-42s x%d" % [
			ms, 100.0 * ms / maxf(total_tirones, 0.001), nombre3, int(veces[nombre3])])

	# La pregunta central: ¿empeora con los días, o es ruido constante? Se
	# compara el primer cuarto del año contra el último.
	var corte: int = primero + dias / 4
	var corte_final: int = primero + dias - dias / 4
	var primero_n := 0
	var primero_suma := 0.0
	var ultimo_n := 0
	var ultimo_suma := 0.0
	for pico3: Dictionary in todos:
		var d: int = int(pico3["dia"])
		if d < corte:
			primero_n += 1; primero_suma += float(pico3["total"])
		elif d >= corte_final:
			ultimo_n += 1; ultimo_suma += float(pico3["total"])
	print("")
	print("--- ¿EMPEORA CON LOS DIAS? primer cuarto vs ultimo cuarto del año ---")
	print("   primer cuarto  (dia %4d-%4d): %4d tirones · %6.0f ms de media" % [
		primero, corte - 1, primero_n, primero_suma / maxf(float(primero_n), 1.0)])
	print("   ultimo cuarto  (dia %4d-%4d): %4d tirones · %6.0f ms de media" % [
		corte_final, primero + dias - 1, ultimo_n, ultimo_suma / maxf(float(ultimo_n), 1.0)])

	# Y EL RANKING A FICHERO, para compararlo con otra corrida sin mirar dos
	# listas a ojo: ver `Cotejo.gd -- tramos`.
	var resumen_ruta := OS.get_environment("RESUMEN")
	if not resumen_ruta.is_empty():
		var csv := FileAccess.open(resumen_ruta, FileAccess.WRITE)
		if csv == null:
			print("no se puede escribir %s" % resumen_ruta)
		else:
			csv.store_line("tramo;ms;veces;ms_por_llamada")
			for nombre4: String in orden:
				var ms2: float = suma[nombre4]
				var cuantas: int = int(veces[nombre4])
				csv.store_line("%s;%.3f;%d;%.6f" % [nombre4, ms2, cuantas,
					ms2 / maxf(float(cuantas), 1.0)])
			csv.store_line("# total_ms;%.0f" % total_tirones)
			csv.store_line("# tirones;%d" % todos.size())
			csv.store_line("# graves;%d" % graves.size())
			csv.store_line("# primer_cuarto;%d;%.0f" % [primero_n,
				primero_suma / maxf(float(primero_n), 1.0)])
			csv.store_line("# ultimo_cuarto;%d;%.0f" % [ultimo_n,
				ultimo_suma / maxf(float(ultimo_n), 1.0)])
			csv.close()
			print("")
			print("ranking escrito en %s" % resumen_ruta)

	if not graves.is_empty():
		print("")
		print("--- LOS %d GRAVES, EN ORDEN CRONOLOGICO ---" % graves.size())
		for pico4: Dictionary in graves:
			print("   dia %4d %02d:00  %6.0f ms  %s" % [
				int(pico4["dia"]), int(float(pico4["hora"])), float(pico4["total"]),
				String(pico4.get("etiqueta", ""))])
	quit()


## Los mismos montones que ya vigila `CrecimientoProbe`, en una línea, para
## poder cruzarlos con los tirones del mismo día sin abrir dos logs.
func _crecimiento(sim: Node) -> String:
	var salidas := 0
	for p: Inhabitant in sim.people:
		salidas += p.journeys.size()
	var cronica := 0
	if sim.chronicle != null and "entries" in sim.chronicle:
		cronica = (sim.chronicle.entries as Array).size()
	var cacerias: int = sim.caceria.hunts.size() if sim.caceria != null else 0
	var rutas := (sim.knowledge as BandKnowledge).veredas_recordadas()
	return "nodos %d · dibujos %d · salidas %d · cronica %d · cacerias %d · rutas-cache %d · RAM %d MB" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		salidas, cronica, cacerias, rutas,
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)]


var _barra: Object = null


## Contesta o cierra lo que haya en pantalla, y lo que salga detrás, como lo
## haría el jugador. La opción 0 es siempre la que no compromete: contrato de
## SPECS §4.6. El bucle vive en [BarraSuperior.contestar_todo], que es también
## quien impide contestar dos veces si un `on_pick` levanta otra tarjeta.
func _contesta_los_momentos() -> void:
	if _barra == null:
		return
	_barra.contestar_todo(func(_m: Moment) -> int: return 0)


var _firmas: FileAccess = null
var _firmas_escritas := 0
var _demo: Node = null
var _errores_avisados := false
var _instantaneas := ""
var _cada := 15
var _instantaneas_escritas := 0
var _primero := 0
var _dia_pendiente := -1


## Apunta la firma de la jornada que se acaba de cerrar, y guarda la partida si
## toca. Corre al CERRARSE EL PASO en que cambió la jornada, que es el único
## límite limpio. Fuera de la cuenta del cepo: ver [Cronometro.aparta].
func _cierra_el_paso(_dia_del_paso: int) -> void:
	if _dia_pendiente < 0:
		return
	var dia := _dia_pendiente
	_dia_pendiente = -1
	Cronometro.aparta()
	if _firmas != null:
		var huella := FirmaDiaria.de(_demo.sim, _demo.herds, _demo._caves)
		_firmas.store_line(huella.linea())
		_firmas.flush()
		_firmas_escritas += 1
		if not huella.errores.is_empty() and not _errores_avisados:
			_errores_avisados = true
			print("!!! la firma no ha podido guardarlo todo (%d): %s" % [
				huella.errores.size(), str(huella.errores.slice(0, 5))])
	if not _instantaneas.is_empty() and (dia - _primero) % _cada == 0:
		var salida := FileAccess.open("%s/dia_%04d.inst" % [_instantaneas, dia],
			FileAccess.WRITE)
		if salida != null:
			salida.store_buffer(Instantanea.tomar(_demo.sim, _demo.herds,
				_demo._caves).bytes())
			salida.close()
			_instantaneas_escritas += 1
	Cronometro.vuelve()


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
