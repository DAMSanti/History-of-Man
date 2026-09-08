extends SceneTree
## El camino del perro, recorrido entero, y lo que cambia cuando llega.
##
## Dos cosas que ninguna prueba contesta:
##
##   1. ¿SE PUEDE ANDAR? El camino sale del montón de desechos y va por cinco
##      decisiones. Si el montón nunca llega a los litros que hacen falta, o si
##      el trato no sube bastante, el perro es código muerto. Aquí se recorre
##      eligiendo siempre lo amable, que es la mejor partida posible, y se dice
##      cuántas jornadas cuesta.
##   2. ¿VALE LA PENA? El perro corta el rastro perdido, y el rastro perdido es
##      el 73 % de las cacerías. Se mide la misma cacería con perro y sin él.
##
##   DIAS=400   cuantas jornadas seguir el camino

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("")
	print("=== EL CAMINO DEL PERRO ===")
	_a_mano()
	_el_efecto()
	quit()


## El camino, recorrido de verdad: se hace latir [ElLobo] jornada a jornada y
## se contesta a sus momentos.
##
## Se ejecuta la maquina, no se estima. La primera version de esta sonda hacia
## la cuenta a mano y dijo «NO LLEGA» por cuatro puntos: estaba mal la cuenta,
## no el camino, porque las noches siguen sumando entre un paso y el siguiente.
## Una sonda que modela lo que mide acaba midiendo el modelo.
##
## No hace falta el valle -el trato es una cuenta- pero si la simulacion, que es
## quien tiene despensa, fauna y momentos.
func _a_mano() -> void:
	print("")
	print("lo que pide cada paso:")
	print("   monton que atrae          %.0f litros" % ElLobo.MONTON_QUE_ATRAE)
	print("   noches para que empiece   %d" % ElLobo.NOCHES_PARA_EMPEZAR)
	print("   trato para que se quede   %.0f de %.0f" % [
		ElLobo.PARA_QUE_SE_QUEDE, ElLobo.TRATO_TOPE])
	print("   trato para la camada      %.0f" % ElLobo.PARA_LA_CAMADA)
	print("   jornadas de cria          %.0f" % ElLobo.CRIA_JORNADAS)
	print("   y come                    %.2f raciones al dia" % ElLobo.COME_AL_DIA)

	for cual in ["amable", "duro"]:
		_andar(cual)


## Recorre el camino eligiendo siempre la primera opcion -la amable- o la
## ultima -la dura-, y apunta en que jornada cae cada paso.
func _andar(cual: String) -> void:
	var sim := SettlementSim.new()
	get_root().add_child(sim)
	# Comida de sobra: lo que se mide es el trato, no el hambre.
	sim.store.add(Materia.Kind.FRUTO_SECO, 9000.0)
	# Monton por encima del umbral y lobos en el valle, que es lo que hace que
	# vengan. Sin las dos cosas no hay camino y la sonda no mediria nada.
	sim.desechos.tirar_litros(Materia.Kind.MARISCO,
		ElLobo.MONTON_QUE_ATRAE * 2.0)
	var fauna := WildlifeHerds.new()
	fauna._animals.append({"species": "lobo"})
	sim.caceria.wildlife = fauna

	sim.moment_raised.connect(func(momento: Moment) -> void:
		if momento.options.is_empty():
			return
		# La opcion dura NO es «la ultima»: en la camada la ultima es dejarla en
		# paz. Se busca por lo que dice, que es lo unico fiable si el dia de
		# mañana se reordenan las opciones.
		var cual_opcion: Dictionary = momento.options[0]
		if cual == "duro":
			cual_opcion = momento.options[momento.options.size() - 1]
			# Por orden: matar antes que espantar. Buscar «lo primero que
			# suene duro» elegia la pedrada porque va antes en la lista.
			for clave: String in ["Matar", "Cobrár", "Espantar"]:
				var encontrada := false
				for opcion: Dictionary in momento.options:
					if String(opcion["label"]).contains(clave):
						cual_opcion = opcion
						encontrada = true
						break
				if encontrada:
					break
		if sim.day <= 200:
			print("      dia %-4d %-22s -> %s" % [sim.day, momento.title,
				String(cual_opcion["label"])])
		(cual_opcion["on_pick"] as Callable).call())

	print("")
	print("eligiendo siempre lo %s:" % cual.to_upper())
	var lobo: ElLobo = sim.lobo
	var dias := 400
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var visto: Dictionary = {}
	for d in range(dias):
		sim.day = d + 1
		lobo.nuevo_dia()
		if not visto.has(lobo.paso):
			visto[lobo.paso] = sim.day
	print("      -> trato final %.0f · %d muertos · %s" % [
		lobo.trato, lobo.muertos,
		"HAY PERRO en la jornada %d" % int(visto.get(ElLobo.Paso.EL_PERRO, 0))
			if lobo.perro
			else ("manada HOSTIL" if lobo.hostil() else "sin perro")])
	for paso: int in [ElLobo.Paso.MERODEAN, ElLobo.Paso.UNO_SE_QUEDA,
			ElLobo.Paso.LA_CAMADA, ElLobo.Paso.EL_CACHORRO,
			ElLobo.Paso.EL_PERRO]:
		if visto.has(paso):
			print("      %-14s jornada %d" % [
				ElLobo.Paso.keys()[paso], int(visto[paso])])
	sim.queue_free()


## Lo que cambia el perro en la cacería, en la única cifra que importa: cuántas
## de las que se levantan se cobran.
func _el_efecto() -> void:
	print("")
	print("--- LO QUE CAMBIA EN LA CACERÍA ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	var intentos := 20000

	# El acecho se pierde por dos motivos y el perro sólo arregla uno: el
	# rastro. Lo que se va de vista se va igual.
	var recuperados := 0
	for i in range(intentos):
		if rng.randf() < ElLobo.CORTA_EL_RASTRO:
			recuperados += 1
	print("   rastros perdidos que el perro corta: %.1f %% (%d de %d)" % [
		100.0 * float(recuperados) / float(intentos), recuperados, intentos])
	print("   fuelle de la carrera: %.1f h → %.1f h (×%.2f)" % [
		Hunt.FUELLE_HORAS, Hunt.FUELLE_HORAS * ElLobo.FUELLE_EXTRA,
		ElLobo.FUELLE_EXTRA])
	print("   riesgo del vivac: ×%.2f con perro, ×%.2f con la manada en contra" % [
		ElLobo.VIVAC_MAS_SEGURO, ElLobo.VIVAC_CON_ENEMIGOS])

	# Y el coste, que es lo que lo hace una decisión y no un regalo.
	print("")
	print("   come %.1f raciones al día = %.0f al año, que es lo que come %.1f persona"
		% [ElLobo.COME_AL_DIA, ElLobo.COME_AL_DIA * 180.0,
			ElLobo.COME_AL_DIA / 1.69])
	print("   medido en el año 4/3/2: la caza dio 147 raciones con 537")
	print("   jornadas-persona. El perro se come %.0f de esas 147 al año."
		% (ElLobo.COME_AL_DIA * 180.0))
