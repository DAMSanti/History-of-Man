extends SceneTree
## La puerta de la fase 1 de SISTEMAS §23: ¿cabe un campamento que no se mira?
##
## Monta N campamentos **sin vista** —ni cámara, ni bosque, ni alfileres—
## colgados de la raíz y llevados por el [RelojDeLaPartida], y contesta:
##
##   1. **Lo que no se mira es la misma partida.** Escribe la firma diaria del
##      primer campamento (sitio 56) para cotejarla con la de `TironAnualProbe`,
##      que es ese mismo campamento MIRADO, con la escena entera. Con N = 1
##      compara quitar la vista; con N = 2, además, tener otro campamento vivo.
##   2. **Lo que cuesta.** Montar cada campamento, la memoria tras cada uno, y
##      los milisegundos de reloj por jornada de juego y por fotograma.
##   3. **Que sobreviven al cambio de escena** (tarea 5): con dos o más, a la
##      tercera jornada se cambia a una escena vacía y se mira que siguen vivos
##      y avanzando.
##
## **EL ORDEN ES EL DE `TironAnualProbe` SOBRE `DemoMain`**, y no por gusto: la
## lección de §22 fue que dos instrumentos distintos juegan dos partidas. El
## primer campamento se monta entero en un solo fotograma —como `_ready`—, con
## la interfaz escuchando antes de `iniciar_partida`, para que la decisión del
## arranque lo pare antes de dar un paso; se esperan los mismos 120 fotogramas,
## se pone la velocidad y se contestan las decisiones por la barra.
##
## **Headless no mide la GPU**: con el renderizador de mentira las mallas no se
## suben a la tarjeta, así que la memoria que da es la del proceso. La de vídeo
## de N campamentos sin mirar queda por medir con ventana.
##
##   CAMPAMENTOS=2 DIAS=10 VEL=5 FIRMAS=<fichero> PARALELO=0|1 CEPO=0|1

const SITIOS := [56, 14, 33, 9000]

var _barra: BarraSuperior = null
var _dia_pendiente := -1


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var cuantos := 2
	if not OS.get_environment("CAMPAMENTOS").is_empty():
		cuantos = clampi(int(OS.get_environment("CAMPAMENTOS")), 1, SITIOS.size())
	var dias := 10
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var vel := 5.0
	if not OS.get_environment("VEL").is_empty():
		vel = float(OS.get_environment("VEL"))
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	await process_frame

	print("")
	print("=== %d CAMPAMENTOS SIN MIRAR, %d JORNADAS, VEL=%.0f, %s ===" % [cuantos, dias,
		vel, "EN SERIE" if OS.get_environment("PARALELO") == "0" else "EN PARALELO"])
	var memoria_al_empezar := OS.get_static_memory_usage() / 1048576.0

	# EL PRIMERO, ENTERO Y EN UN SOLO FOTOGRAMA, con la interfaz escuchando.
	var t0 := Time.get_ticks_msec()
	var primero := _montar(int(SITIOS[0]), comarca)
	if primero == null:
		quit(1)
		return
	var ui := GameUI.new()
	ui.name = "GameUI"
	ui.sim = primero.sim
	ui.knowledge = primero.knowledge
	ui.field = primero.field
	ui.tech = primero.tech
	ui.site = primero.sitio
	get_root().add_child(ui)
	_barra = ui.barra
	_barra.watch_moments(primero.sim)
	_empezar(primero)
	print("campamento %d (sitio %d): montado en %d ms, memoria %.0f MB"
		% [1, primero.sitio.id, Time.get_ticks_msec() - t0,
			OS.get_static_memory_usage() / 1048576.0 - memoria_al_empezar])

	# LOS DEMÁS, uno por fotograma. El primero está parado por su decisión de
	# arranque, así que montarlos no le hace dar ningún paso. Se montan dentro
	# del árbol, como la escena, y se sacan después.
	for k in range(1, cuantos):
		await process_frame
		var t := Time.get_ticks_msec()
		var otro := _montar(int(SITIOS[k]), comarca)
		if otro == null:
			continue
		_barra.watch_moments(otro.sim)
		_empezar(otro)
		print("campamento %d (sitio %d): montado en %d ms, memoria %.0f MB"
			% [k + 1, otro.sitio.id, Time.get_ticks_msec() - t,
				OS.get_static_memory_usage() / 1048576.0 - memoria_al_empezar])

	# NADIE LOS MIRA: fuera del árbol, en serie y en paralelo por igual —un solo
	# instrumento—. Ver [Campamentos.dejar_de_mirar].
	for campamento: Campamento in Campamentos.vivos:
		Campamentos.dejar_de_mirar(campamento)

	# Los mismos 120 fotogramas que espera `TironAnualProbe` tras cambiar a la
	# escena, y en el mismo orden después: la firma, el reparto, la velocidad,
	# contestar, y escuchar.
	for i in range(120):
		await process_frame

	# LA FIRMA SE TOMA AL CERRAR EL PASO, no en `day_passed`: tomada dentro del
	# paso es media partida a medio paso (SPECS §3.2). `TironAnualProbe` apunta la
	# jornada en `day_passed` y escribe en `paso_cerrado`, y aquí igual.
	var ruta := OS.get_environment("FIRMAS")
	# UNA FIRMA POR CAMPAMENTO: el primero en `FIRMAS` y el k-ésimo en
	# `FIRMAS.k`. Una carrera entre hilos puede estropear el segundo campamento y
	# dejar el primero intacto; firmando sólo uno no se vería.
	var firmas: Array[FileAccess] = []
	if not ruta.is_empty():
		for k in range(Campamentos.vivos.size()):
			firmas.append(FileAccess.open(ruta if k == 0 else "%s.%d" % [ruta, k + 1],
				FileAccess.WRITE))
	primero.sim.day_passed.connect(func(dia: int) -> void: _dia_pendiente = dia)
	Campamentos.reloj.paralelo = OS.get_environment("PARALELO") != "0"
	# EN LA BARRERA DEL RELOJ, y no en `paso_cerrado` de la simulación: en
	# paralelo `paso_cerrado` sale en otro hilo, y un solo instrumento para las
	# dos corridas es la lección de §22. Para cada campamento es el mismo
	# instante: entre su `paso_cerrado` y la barrera sólo dan su paso los demás,
	# que no le tocan nada.
	Campamentos.reloj.pasos_cerrados.connect(func() -> void:
		if _dia_pendiente < 0 or firmas.is_empty():
			return
		_dia_pendiente = -1
		for k in range(firmas.size()):
			var campamento: Campamento = Campamentos.vivos[k]
			firmas[k].store_line(FirmaDiaria.de(campamento.sim, campamento.herds,
				campamento.caves).linea())
			firmas[k].flush())

	# EL REPARTO DE LAS SONDAS. `TironAnualProbe` pone a trabajar a la banda con
	# `assign_default_jobs` —la partida de verdad arranca sin repartir, y una
	# banda parada no mide nada—. La primera versión de esta sonda no lo hacía y
	# se separaba en la jornada 2 con la leña a cero: era el instrumento, no el
	# campamento. A todos, el primero antes.
	for campamento: Campamento in Campamentos.vivos:
		campamento.sim.assign_default_jobs()
	primero.sim.time_scale = vel
	_contesta()
	for campamento: Campamento in Campamentos.vivos:
		campamento.sim.moment_raised.connect(func(_m: Moment) -> void: _contesta())

	# EL CEPO, si se pide (`CEPO=1`): dónde se va el tiempo del paso. Con el
	# límite a cero, cada fotograma deja su desglose en `Cronometro.picos` y se
	# suma aquí por tramo. Medir cuesta —el cepo se lleva un 20 %, SPECS §6.1—, así
	# que las cifras de coste de arriba sólo valen con él apagado.
	var con_cepo := OS.get_environment("CEPO") == "1"
	var gasto_por_tramo := {}
	var veces_por_tramo := {}
	if con_cepo:
		Cronometro.limite_ms = 0.0
		Cronometro.activo = true
		Cronometro.reinicia()

	var desde: int = primero.sim.day
	var dia := desde
	var t_dia := Time.get_ticks_msec()
	var cuadros := 0
	var suma_ms := 0.0
	var peor_ms := 0.0
	var t_cuadro := Time.get_ticks_usec()
	var por_jornada: Array[int] = []
	var escena_cambiada := false
	while primero.sim.day < desde + dias:
		await process_frame
		if con_cepo:
			Cronometro.abre_el_fotograma()
			for pico: Dictionary in Cronometro.picos:
				for parte: Dictionary in (pico["desglose"] as Array):
					var nombre := String(parte["tramo"])
					if nombre.begins_with("· EL MOTOR"):
						nombre = "· EL MOTOR (pintar, fisica)"
					gasto_por_tramo[nombre] = float(gasto_por_tramo.get(nombre, 0.0)) 						+ float(parte["ms"])
					veces_por_tramo[nombre] = int(veces_por_tramo.get(nombre, 0)) 						+ int(parte["veces"])
		var ahora := Time.get_ticks_usec()
		var ms := float(ahora - t_cuadro) / 1000.0
		t_cuadro = ahora
		cuadros += 1
		suma_ms += ms
		peor_ms = maxf(peor_ms, ms)
		if primero.sim.day != dia:
			por_jornada.append(Time.get_ticks_msec() - t_dia)
			t_dia = Time.get_ticks_msec()
			dia = primero.sim.day
			if cuantos > 1 and not escena_cambiada and dia >= desde + 2:
				escena_cambiada = true
				await _cambiar_de_escena()


	print("")
	print("=== LO QUE CUESTA ===")
	var total := 0
	for ms: int in por_jornada:
		total += ms
	print("campamentos: %d · jornadas: %d" % [Campamentos.vivos.size(), por_jornada.size()])
	print("ms de reloj por jornada de juego: media %.0f · por jornada %s"
		% [float(total) / maxf(float(por_jornada.size()), 1.0), str(por_jornada)])
	print("fotograma: medio %.1f ms · peor %.0f ms · %d cuadros"
		% [suma_ms / maxf(float(cuadros), 1.0), peor_ms, cuadros])
	print("memoria del proceso al final: %.0f MB (sobre %.0f al empezar)"
		% [OS.get_static_memory_usage() / 1048576.0, memoria_al_empezar])
	if con_cepo:
		Cronometro.activo = false
		print("")
		print("=== DÓNDE SE VA EL TIEMPO (cepo, %d jornadas) ===" % por_jornada.size())
		print("los de dentro van contados también en su raíz: no se suman entre sí")
		var nombres := gasto_por_tramo.keys()
		nombres.sort_custom(func(a, b) -> bool:
			return float(gasto_por_tramo[a]) > float(gasto_por_tramo[b]))
		for nombre: String in nombres.slice(0, 24):
			var ms_total := float(gasto_por_tramo[nombre])
			var n := int(veces_por_tramo.get(nombre, 0))
			print("  %9.0f ms  %7d veces  %8.3f ms/vez  %s" % [ms_total, n,
				ms_total / maxf(float(n), 1.0), nombre])

	var fechas: Array[String] = []
	for campamento: Campamento in Campamentos.vivos:
		fechas.append("%d %.2fh" % [campamento.sim.day, campamento.sim.hour])
	print("fecha de cada campamento al acabar: %s" % ", ".join(fechas))
	# `VOLCAR_ATASCOS=1`: los partes forenses de atascos de cada campamento, en
	# JSON, para ver qué dato cambia entre serie y paralelo (1b-6).
	var volcar := OS.get_environment("VOLCAR_ATASCOS")
	if not volcar.is_empty():
		for k in range(Campamentos.vivos.size()):
			var destino := FileAccess.open("%s.%d" % [volcar, k + 1], FileAccess.WRITE)
			for parte: Dictionary in (Campamentos.vivos[k] as Campamento).sim.stuck_reports:
				destino.store_line(JSON.stringify(parte, "", true, true))
			destino.close()

	# Fuera del árbol nadie los libera al salir: sin esto, doscientos avisos de
	# fugas tapan el registro.
	Campamentos.vaciar()
	quit()


## Monta un campamento sin vista con [Campamento.montar] y lo da de alta.
func _montar(id: int, comarca: SiteSet) -> Campamento:
	var sitio: Site = null
	for s: Site in comarca.sites:
		if s.id == id:
			sitio = s
	var campamento := Campamento.montar(self, sitio, GameState.population, GameState.food)
	if campamento == null:
		print("sin relieve horneado o sin ficha para el sitio %d: se salta" % id)
		return null
	Campamentos.alta(self, campamento)
	return campamento


## Lo que `DemoMain._levantar_interfaz` hace después de escuchar: empezar la
## partida, las cuevas de alrededor ya vistas, y los tajos.
func _empezar(campamento: Campamento) -> void:
	campamento.sim.iniciar_partida()
	campamento.mirar_las_cumbres()
	campamento.revisar_hallazgos()
	campamento.elegir_tajos(campamento.casa())


## Por la vía del jugador, como `TironAnualProbe`: ver [BarraSuperior.contestar_todo].
func _contesta() -> void:
	if _barra != null:
		_barra.contestar_todo(func(_m: Moment) -> int: return 0)


## A una escena vacía, y a mirar que los campamentos siguen ahí y andando.
func _cambiar_de_escena() -> void:
	var vacia := PackedScene.new()
	var raiz := Node.new()
	raiz.name = "EscenaVacia"
	vacia.pack(raiz)
	raiz.free()
	var antes: Array[int] = []
	for campamento: Campamento in Campamentos.vivos:
		antes.append(campamento.sim.day)
	change_scene_to_packed(vacia)
	for i in range(3):
		await process_frame
	var vivos := 0
	for k in range(Campamentos.vivos.size()):
		var campamento: Campamento = Campamentos.vivos[k]
		if is_instance_valid(campamento) and campamento.sim.day >= antes[k]:
			vivos += 1
	print("cambio de escena: %d de %d campamentos siguen vivos y andando (escena: %s)"
		% [vivos, Campamentos.vivos.size(),
			current_scene.name if current_scene != null else "ninguna"])
