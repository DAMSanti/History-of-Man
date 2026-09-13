extends SceneTree
## Un año entero de partida, estacion a estacion.
##
## Es la pregunta que ninguna prueba contesta: ¿se puede JUGAR esto? Las
## pruebas dicen que cada pieza funciona y las sondas miden un oficio cada una;
## esto deja correr la banda un año con el reparto por defecto y apunta lo que
## de verdad decide la partida.
##
## Por cada estacion: cuanta gente, cuanto se come, cuanto entra de cada cosa,
## que se pudre, que se aprende, quien se hace daño y en que se va el dia.
##
##   DIAS=180      cuantas jornadas seguir
##   BANDA=4,3,2   fuerza el reparto (recolectores,cazadores,pescadores) en
##                 vez del que decide `assign_default_jobs()` -mismo formato
##                 que `BandaProbe.gd`. Sin esto, el reparto por defecto
##                 puede no poner a nadie en Ribera y la tabla de abajo sale
##                 vacia sin decir nada sobre si la pesca se agota o no. Ver
##                 docs/specs/SECADERO_Y_RIO.md.

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

	# La partida arranca sin repartir -la primera decision es del jugador-, asi
	# que la sonda reparte por defecto para poder medir un año de banda viva.
	# Salvo que se pida BANDA=r,c,p: un reparto forzado, para medir un
	# escenario concreto en vez de lo que decida el juego -ver SECADERO_Y_RIO.md.
	if OS.get_environment("BANDA").is_empty():
		sim.assign_default_jobs()
	else:
		var partes := OS.get_environment("BANDA").split(",")
		var reparto := [4, 3, 2]
		for i in range(mini(partes.size(), 3)):
			reparto[i] = int(partes[i])
		_repartir(sim, reparto)
	# x5, no x20: tope acordado entre las sondas de esta corrida compartida
	# (ver docs/specs/LO_MISMO_MAS_DEPRISA.md) tras los cambios de rendimiento
	# de hoy -no es que 20 fallara, es no salirse del mismo baremo que usan
	# las demás sondas de la partida.
	sim.time_scale = 5.0

	# Un [Moment] con opciones para el reloj -es el punto- y nadie lo
	# resuelve nunca en una sonda sin jugador delante: sin esto, la primera
	# berrea o el primer percance con margen dejan `time_scale` en 0 para
	# siempre y la sonda se queda colgada sin decir nada. Se toma la opción
	# que menos toca el reparto por defecto que esta sonda quiere medir: en
	# la berrea, seguir como hasta ahora; en un percance, volver ya.
	#
	# Se resuelve por `BarraSuperior.elegir()` -viendo qué hay REALMENTE en
	# pantalla (`momento_en_pantalla()`), no llamando a `on_pick` a pelo
	# desde `moment_raised`-: llamar a `on_pick` sin pasar por `elegir()`
	# ejecuta la elección pero nunca hace avanzar la cola ni devuelve
	# `time_scale`, y ESE es el motivo real por el que esta sonda se quedaba
	# colgada para siempre en cuanto tocaba la primera decisión del año -no
	# era lentitud de fotogramas, era el reloj parado sin que nadie lo
	# reanudara-. Revisar cada fotograma y no sólo al raise: puede haber más
	# de una decisión en cola.
	# JUGADOR=razonable: en vez de no comprometerse nunca, juega. Hace falta
	# para medir el cierre de la fase (EPOCA_01 §10.1, tanda 2): con la opción 0
	# siempre, NUNCA se manda una expedición, nunca hay puntos nuevos y la fase
	# no se puede cerrar. La política es fija y está escrita aquí, para que la
	# cifra que salga se pueda leer: manda la expedición, sube en verano, se
	# vuelca en la berrea, trata siendo justo, y raciona el fuego sólo si la
	# leña no llega a todo el invierno.
	var razonable := OS.get_environment("JUGADOR") == "razonable"
	# Las decisiones que de verdad cuestan, por año y por tipo. Un diccionario y
	# no enteros sueltos: la lambda captura las variables locales POR VALOR.
	var decisiones: Dictionary = {}   # año -> {tipo: n}
	var _indice_razonable := func(m: Moment) -> int:
		var elegido := 0
		match m.kind:
			Moment.Kind.EXPEDICION, Moment.Kind.ASCENSO, Moment.Kind.BERREA, \
			Moment.Kind.TRUEQUE:
				elegido = 1
			Moment.Kind.INVIERNO:
				var hace_falta := SettlementSim.HEARTH_WOOD_PER_DAY \
					* SettlementSim.HEARTH_WINTER_FACTOR * float(Subsistence.DAYS_PER_SEASON)
				elegido = 1 if sim.store.amount(Materia.Kind.LENA) < hace_falta else 0
		return mini(elegido, m.options.size() - 1)
	var _elige := func(actual: Moment) -> int:
		if actual.la_eleccion_importa():
			var del_anyo: Dictionary = decisiones.get(GameState.year, {})
			var tipo: String = Moment.Kind.keys()[actual.kind]
			del_anyo[tipo] = int(del_anyo.get(tipo, 0)) + 1
			decisiones[GameState.year] = del_anyo
		# Sin JUGADOR, la opción 0: la que no compromete (SPECS §4.6).
		return (_indice_razonable.call(actual) as int) if razonable else 0
	# Y los avisos se cierran, que hasta el 2026-09-13 no: el primero de la
	# partida tapaba la cola y no se contestaba ninguna decisión en todo el año.
	# Ver [BarraSuperior.contestar_todo].
	var _resolver_decisiones := func() -> void:
		ui.barra.contestar_todo(_elige)

	var dias := 180
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	# Los Paraje de RIBERA que de verdad se han trabajado, por estacion.
	# CADA FOTOGRAMA y no una vez al dia: la primera version muestreaba en el
	# cambio de jornada -medianoche-, que es justo cuando nadie esta
	# TRABAJANDO -esta durmiendo o de camino-, y daba CERO parajes en una
	# corrida con miles de raciones de pescado entrando. El estado hay que
	# pillarlo mientras dura, no una vez al dia.
	var parajes_ribera_estacion: Dictionary = {}   # estacion -> {"x_z": true}
	var _rastrear_ribera := func() -> void:
		var est_ahora := Subsistence.season_name(GameState.season)
		if not parajes_ribera_estacion.has(est_ahora):
			parajes_ribera_estacion[est_ahora] = {}
		var claves: Dictionary = parajes_ribera_estacion[est_ahora]
		for persona: Inhabitant in sim.people:
			if persona.job != Profession.Job.RIBERA \
					or persona.state != Inhabitant.State.TRABAJANDO:
				continue
			var paraje: Paraje = sim._paraje_at(persona.position)
			if paraje != null:
				claves["%d_%d" % [paraje.cell_x, paraje.cell_z]] = true

	# Para docs/specs/SECADERO_Y_RIO.md §2, segunda vuelta: la caída de
	# primavera a verano (91,5 % medido, mismos parajes) no se explica solo
	# con `seasonal_factor`. La sospecha es que Ribera pasa el tiempo
	# RECONOCIENDO (tanteando) en vez de TRABAJANDO, que es justo lo que
	# `SinSitioProbe.gd` medía antes de `e4aece7` para otros oficios. Se
	# apunta EN QUÉ ESTADO está cada pescador cada fotograma -no una vez al
	# día, mismo motivo que `_rastrear_ribera`- y si `Barbecho.sin_sitio`
	# para PESCA está activo ese instante, para saber si Barbecho detecta
	# bien el problema y es Tanteo el que no resuelve, o si ni siquiera se
	# dispara.
	var estados_ribera_estacion: Dictionary = {}   # estacion -> {state_name: frames}
	var sin_sitio_pesca_estacion: Dictionary = {}  # estacion -> {"si": n, "total": n}
	var _rastrear_estados_ribera := func() -> void:
		var est_ahora := Subsistence.season_name(GameState.season)
		if not estados_ribera_estacion.has(est_ahora):
			estados_ribera_estacion[est_ahora] = {}
		var ee: Dictionary = estados_ribera_estacion[est_ahora]
		var hay_ribera := false
		for persona: Inhabitant in sim.people:
			if persona.job != Profession.Job.RIBERA:
				continue
			hay_ribera = true
			var nombre_estado: String = Inhabitant.State.keys()[persona.state]
			ee[nombre_estado] = int(ee.get(nombre_estado, 0)) + 1
		if not hay_ribera:
			return
		if not sin_sitio_pesca_estacion.has(est_ahora):
			sin_sitio_pesca_estacion[est_ahora] = {"si": 0, "total": 0}
		var ss: Dictionary = sin_sitio_pesca_estacion[est_ahora]
		ss["total"] = int(ss["total"]) + 1
		if sim.barbecho.sin_sitio(Subsistence.Activity.PESCA):
			ss["si"] = int(ss["si"]) + 1

	print("")
	print("=== UN AÑO DE PARTIDA (%d jornadas) ===" % dias)
	print("%-6s %-11s %5s %7s %7s %7s %6s %6s %7s  %s" % [
		"dia", "estacion", "gente", "despensa", "leña", "dias", "hambre", "cansa",
		"heridos", "tecnicas"])

	var primero: int = sim.day
	var ultimo: int = -1
	var pudrido := 0.0
	var por_estacion: Dictionary = {}
	## Oficio -> jornadas-persona trabajadas. Contar quien lo tiene AL FINAL
	## reparte el año entre los que quedan y da cifras sin sentido cuando la
	## banda acaba ociosa.
	var jornadas: Dictionary = {}
	# `produced_days` es una ventana rodante de 30 dias
	# ([SettlementSim.CONSUMO_DIAS]), no el libro del año: sumarla al final da
	# el ultimo mes creyendo que es la partida entera. Por eso se apunta cada
	# jornada al cerrarse, que es cuando `_roll_production` la ha metido ahi.
	var total: Dictionary = {}
	# Lo mismo que `total`/`jornadas` pero por ESTACION, no sólo el año
	# entero: hace falta para "raciones de ribera por persona-pescador y
	# día", que un agregado anual no puede contestar -pide una sonda aparte
	# según SECADERO_Y_RIO.md, y esto es esa sonda aparte, dentro de la
	# misma corrida en vez de una escena nueva.
	var total_estacion: Dictionary = {}       # estacion -> {Materia.Kind: float}
	var jornadas_estacion: Dictionary = {}    # estacion -> {oficio: int}
	# EL VIGÍA: Godot no suelta la salida hasta que termina, y esto son horas.
	# Con VIGIA=fichero, una línea por estación con `flush`, para poder mirar
	# cómo va sin matarlo.
	var vigia: FileAccess = null
	if not OS.get_environment("VIGIA").is_empty():
		vigia = FileAccess.open(OS.get_environment("VIGIA"), FileAccess.WRITE)
	var ultima_estacion := {"v": -1}
	while sim.day < primero + dias:
		if vigia != null and int(GameState.season) != int(ultima_estacion["v"]):
			ultima_estacion["v"] = int(GameState.season)
			vigia.store_line("dia %d · %s año %d · vivos %d · expediciones %d · descubiertos %d · tratos %d/%d · desenlace %d" % [
				sim.day, Subsistence.season_name(GameState.season), GameState.year,
				sim.people.size(), sim.expedicion.vueltas, sim.expedicion.descubiertos,
				sim.intercambio.consumados, sim.intercambio.intentados, sim.desenlace])
			vigia.flush()
		# SI LA PARTIDA SE ACABO, AQUI SE ACABA LA SONDA.
		#
		# `_process` no avanza nada sin banda, asi que `sim.day` se queda
		# clavado y este `while` gira en fotogramas vacios para siempre: un
		# nucleo entero, ni una linea de log, y hay que matarlo a mano. Eso
		# era el 🔴 «el cuelgue de la hambruna total» -diecisiete minutos
		# medidos-, y no era un bucle del juego: era esta espera. Ver
		# `SettlementSim.partida_terminada` y `CuelgueProbe`.
		if sim.partida_terminada():
			print("
LA PARTIDA TERMINO EN LA JORNADA %d (desenlace %d, vivos %d)."
				% [sim.day, sim.desenlace, sim.people.size()])
			print("Lo que sigue mide hasta ahi, no hasta la jornada %d pedida."
				% [primero + dias - 1])
			break
		await process_frame
		_resolver_decisiones.call()
		_rastrear_ribera.call()
		_rastrear_estados_ribera.call()
		if sim.day == ultimo:
			continue
		ultimo = sim.day
		var est := Subsistence.season_name(GameState.season)
		pudrido += sim.spoiled_rations_today
		if sim.taller.produced_days.size() > 0:
			var ayer: Dictionary = sim.taller.produced_days.back()
			if not total_estacion.has(est):
				total_estacion[est] = {}
			var te: Dictionary = total_estacion[est]
			for k: int in ayer:
				total[k] = float(total.get(k, 0.0)) + float(ayer[k])
				te[k] = float(te.get(k, 0.0)) + float(ayer[k])
		if not jornadas_estacion.has(est):
			jornadas_estacion[est] = {}
		var je: Dictionary = jornadas_estacion[est]
		for quien2: Inhabitant in sim.people:
			var oficio2 := Profession.job_name(quien2.job as Profession.Job)
			jornadas[oficio2] = int(jornadas.get(oficio2, 0)) + 1
			je[oficio2] = int(je.get(oficio2, 0)) + 1
		por_estacion[est] = float(por_estacion.get(est, 0.0)) + sim.spoiled_rations_today
		if (sim.day - primero) % 15 != 0:
			continue
		var hambre := 0.0
		var cansa := 0.0
		var heridos := 0
		var comen := 0.0
		for p: Inhabitant in sim.people:
			hambre += p.hunger
			cansa += p.fatigue
			comen += p.daily_food()
			if p.hurt_days > 0:
				heridos += 1
		var n := maxf(float(sim.people.size()), 1.0)
		var per := 0.0
		var efi := 0.0
		var cuantos := 0
		for p3: Inhabitant in sim.people:
			if p3.job != Profession.Job.RECOLECCION:
				continue
			per += p3.skill_in(p3.current_task())
			efi += p3.effectiveness()
			cuantos += 1
		if cuantos > 0:
			print("        pericia media del recolector %.3f · efectividad %.3f" % [
				per / float(cuantos), efi / float(cuantos)])
		print("%-6d %-11s %5d %7.0f %7.0f %7.1f %6.0f %6.0f %7d  %d" % [
			sim.day, est, sim.people.size(), sim.store.food_rations(),
			sim.store.amount(Materia.Kind.LENA),
			sim.store.food_rations() / maxf(comen, 0.01),
			hambre / n, cansa / n, heridos, sim.techs.known.size()])

	# Lo que decide la calibracion: raciones por PERSONA Y DIA de cada oficio,
	# contra las 2,0 que come una persona. Un oficio que no llega a 2 no se
	# mantiene a si mismo; uno que pasa de 6 hace irrelevantes a los demas.
	print("")
	print("--- POR QUE CADA CUAL HACE LO QUE HACE ---")
	print("   tajos montados:")
	for act: int in sim.work_sites:
		print("      %-16s a %5.0f m del abrigo" % [
			Subsistence.activity_name(act as Subsistence.Activity),
			sim.home_position.distance_to(sim.work_sites[act])])
	for act: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		if not sim.work_sites.has(act):
			print("      %-16s SIN TAJO" % Subsistence.activity_name(
				act as Subsistence.Activity))
	print("   por que se bloquea cada tarea (para el primero que pueda):")
	for job: int in Profession.Job.values():
		if job == Profession.Job.OCIOSO:
			continue
		for tarea: int in Profession.tasks_of(job as Profession.Job):
			for quien: Inhabitant in sim.people:
				if not Profession.can_do(job as Profession.Job, quien):
					continue
				var motivo: String = sim.task_blocked_by(quien, tarea)
				print("      %-26s %s" % [
					Profession.task_name(tarea),
					motivo if not motivo.is_empty() else "se puede"])
				break

	print("")
	print("--- LO QUE RINDE CADA OFICIO ---")
	var come := 0.0
	for p2: Inhabitant in sim.people:
		come += p2.daily_food()
	come /= maxf(float(sim.people.size()), 1.0)
	print("   una persona come %.2f raciones al dia" % come)
	var por_actividad: Dictionary = {}
	for k: int in total:
		# Las claves negativas son piezas de utillaje, no materiales: la
		# produccion lleva las dos en el mismo registro. Ver `logged_name`.
		if k < 0:
			continue
		var kk := k as Materia.Kind
		if not Materia.is_food(kk):
			continue
		var act := "otros"
		if kk in [Materia.Kind.CARNE, Materia.Kind.CARNE_SECA]:
			act = "Caza"
		elif kk in [Materia.Kind.PESCADO, Materia.Kind.PESCADO_SECO,
				Materia.Kind.MARISCO]:
			act = "Ribera"
		else:
			act = "Recolección"
		por_actividad[act] = float(por_actividad.get(act, 0.0)) \
			+ float(total[k]) * Materia.nutrition(kk)
	for oficio: String in ["Recolección", "Caza", "Ribera"]:
		var jp: int = int(jornadas.get(oficio, 0))
		var rac: float = float(por_actividad.get(oficio, 0.0))
		print("   %-14s %5d jornadas-persona · %7.0f raciones · %6.2f al dia cada uno" % [
			oficio, jp, rac, rac / maxf(float(jp), 1.0)])

	# Para docs/specs/SECADERO_Y_RIO.md §2: si el barbecho/tanteo evitan que
	# la pesca se quede clavada en un paraje agotado, tiene que verse AQUI,
	# estacion a estacion -un agregado del año entero no distingue "todo el
	# año a 1,79 raciones/dia" (el hallazgo de ESTADO_DE_LA_SLICE.md §5.6,
	# ribera esquilmada) de "verano alto, otoño bajo, invierno recuperado".
	print("")
	print("--- RIBERA POR ESTACION (para SECADERO_Y_RIO) ---")
	print("%-11s %10s %14s %10s %10s" % [
		"estacion", "raciones", "jornad-pers", "por dia", "parajes"])
	for est_nombre: String in total_estacion:
		var te2: Dictionary = total_estacion[est_nombre]
		var raciones_ribera := 0.0
		for k2: int in te2:
			if k2 < 0:
				continue
			var kk2 := k2 as Materia.Kind
			if kk2 in [Materia.Kind.PESCADO, Materia.Kind.PESCADO_SECO, Materia.Kind.MARISCO]:
				raciones_ribera += float(te2[k2]) * Materia.nutrition(kk2)
		var jp2: int = int((jornadas_estacion.get(est_nombre, {}) as Dictionary).get("Ribera", 0))
		var parajes_distintos: int = (parajes_ribera_estacion.get(est_nombre, {}) as Dictionary).size()
		print("%-11s %10.0f %14d %10.2f %10d" % [
			est_nombre, raciones_ribera, jp2, raciones_ribera / maxf(float(jp2), 1.0),
			parajes_distintos])

	print("")
	print("--- RIBERA: EN QUÉ SE VA EL DÍA, POR ESTACION (para SECADERO_Y_RIO) ---")
	print("%-11s %11s %11s %11s %11s %11s %14s" % [
		"estacion", "yendo", "buscando", "trabajando", "volviendo",
		"reconoc.", "sin_sitio(P)"])
	for est_nombre2: String in estados_ribera_estacion:
		var ee2: Dictionary = estados_ribera_estacion[est_nombre2]
		var total_frames := 0
		for c: int in ee2.values():
			total_frames += c
		var pct := func(nombre: String) -> float:
			return 100.0 * float(ee2.get(nombre, 0)) / maxf(float(total_frames), 1.0)
		var ss2: Dictionary = sin_sitio_pesca_estacion.get(est_nombre2, {"si": 0, "total": 0})
		var pct_sin_sitio := 100.0 * float(ss2.get("si", 0)) / maxf(float(ss2.get("total", 0)), 1.0)
		print("%-11s %10.1f%% %10.1f%% %10.1f%% %10.1f%% %10.1f%% %13.1f%%" % [
			est_nombre2, pct.call("YENDO"), pct.call("BUSCANDO"),
			pct.call("TRABAJANDO"), pct.call("VOLVIENDO"), pct.call("RECONOCIENDO"),
			pct_sin_sitio])

	print("")
	print("--- QUE HAY EN LA DESPENSA AL FINAL ---")
	var raciones: Array = []
	for k: int in Materia.Kind.values():
		var kk := k as Materia.Kind
		if not Materia.is_food(kk):
			continue
		var u: float = sim.store.amount(kk)
		if u <= 0.5:
			continue
		raciones.append([u * Materia.nutrition(kk), u, kk])
	raciones.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for fila: Array in raciones:
		print("   %-16s %8.0f raciones (%.0f %s · aguanta %d dias)" % [
			Materia.material_name(fila[2]), fila[0], fila[1],
			Materia.unit_name(fila[2]), Materia.shelf_life(fila[2])])

	print("")
	print("--- lo que ha entrado en el año, por material ---")
	var orden: Array[int] = []
	orden.assign(total.keys())
	orden.sort_custom(func(a: int, b: int) -> bool: return total[a] > total[b])
	for k: int in orden:
		if k < 0:
			continue
		var nombre := Materia.material_name(k as Materia.Kind)
		var rac := ""
		if Materia.is_food(k as Materia.Kind):
			rac = " = %.0f raciones" % (float(total[k]) * Materia.nutrition(k as Materia.Kind))
		print("   %-16s %8.1f %s%s" % [nombre, total[k],
			Materia.unit_name(k as Materia.Kind), rac])

	print("")
	print("se ha podrido en el año: %.1f raciones · por estacion %s" % [
		pudrido, str(por_estacion)])
	print("tecnicas sabidas al final: %d de %d" % [
		sim.techs.known.size(), TechTree.Tech.size()])
	var utillaje := 0
	for entrada: Dictionary in sim.toolkit.summary():
		utillaje += int(entrada.get("count", 0))
	print("piezas de utillaje: %d" % utillaje)
	print("atascos: %s" % str(sim.stuck_tally))
	print("cronica: %d entradas" % sim.chronicle.entries.size())
	var desenlace_nombre: String = SettlementSim.Desenlace.keys()[sim.desenlace]
	if sim.desenlace == SettlementSim.Desenlace.NINGUNO:
		print("desenlace: %s" % desenlace_nombre)
	else:
		print("desenlace: %s, en la jornada %d" % [desenlace_nombre, sim.desenlace_dia])

	print("")
	print("--- EL CIERRE DE LA FASE Y LAS DECISIONES (EPOCA_01 §10.1, tanda 2) ---")
	print("jugador: %s" % ("razonable" if razonable else "sin decidir (opcion 0)"))
	if sim.desenlace == SettlementSim.Desenlace.VICTORIA:
		print("SE CIERRA LA FASE en la jornada %d, año %d (%.2f años)" % [
			sim.desenlace_dia, GameState.year,
			float(sim.desenlace_dia) / float(4 * Subsistence.DAYS_PER_SEASON)])
	else:
		print("la fase NO se cierra. Falta: %s" % str(sim.partida.lo_que_falta_para_cerrar()))
	for anyo in decisiones.keys():
		var cuantas := 0
		for t in decisiones[anyo]:
			cuantas += int(decisiones[anyo][t])
		print("   decisiones que cuestan, año %d: %d · %s" % [anyo, cuantas, str(decisiones[anyo])])
	var e: Expedicion = sim.expedicion
	print("expediciones: mandada %s · vueltas %d · sitios descubiertos %d · jornadas-persona %d" % [
		str(e.mandada_alguna_vez), e.vueltas, e.descubiertos, e.jornadas_persona])
	if e.vueltas > 0:
		print("   por expedicion: %.1f sitios y %d jornadas-persona" % [
			float(e.descubiertos) / float(e.vueltas),
			e.jornadas_persona / maxi(e.vueltas, 1)])
	var ic: Intercambio = sim.intercambio
	print("trueque: intentados %d · consumados %d · tasa %.2f · gente conocida %d" % [
		ic.intentados, ic.consumados,
		float(ic.consumados) / maxf(float(ic.intentados), 1.0), sim.contacto.conocidos()])
	var de_frio := 0
	for entrada: Dictionary in sim.chronicle.entries:
		if String(entrada.get("text", "")).contains("murió de frío"):
			de_frio += 1
	print("muertes de frio en la cronica: %d" % de_frio)
	quit()


## Fuerza un reparto concreto (recolectores, cazadores, pescadores) en vez
## del que decida `assign_default_jobs()`. Calcado de `BandaProbe._repartir`
## -mismo criterio, no se reinventa-: el resto se manda mitad a talla y
## cordelería, mitad al hogar, para que la manufactura no se quede vacía.
func _repartir(sim: Node, reparto: Array) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: reparto[0],
		Profession.Job.CAZA: reparto[1],
		Profession.Job.RIBERA: reparto[2],
	}
	for person: Inhabitant in sim.people:
		for job: int in Profession.Job.values():
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 0)
	for job: int in pendiente:
		for person: Inhabitant in sim.people:
			if pendiente[job] <= 0:
				break
			if person.priorities.size() > 0:
				continue
			if not Profession.can_do(job as Profession.Job, person):
				continue
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 1)
			pendiente[job] -= 1
	var sobran := 0
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		sobran += 1
		if sobran % 2 == 0:
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				Profession.Speciality.TALLA), 1)
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				Profession.Speciality.CORDELERIA), 2)
		else:
			person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()
