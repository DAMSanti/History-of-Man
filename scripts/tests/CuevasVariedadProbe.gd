extends SceneTree
## ¿Explorar cuevas es una aventura o un trámite? Cincuenta cuevas, sin jugar
## jornadas.
##
## Frente 22 de EPOCA_01 §10.1, tanda 4, criterios de la sonda de variedad:
## - cada cueva presenta 2 o 3 situaciones, ninguna repite, dos seguidas no
##   empiezan igual, y aparecen al menos 25 situaciones distintas;
## - herida y muerte ocurren alguna vez, y no en todas;
## - de 90 cuevas, entre 20 y 40 salen pintables, y la de la banda siempre.
##
## Las decisiones se toman con un azar fijo, que es lo más parecido a un jugador
## que elige sin mirar. Sin escena: sólo la simulación y el repertorio.
##   godot --headless --path . --script res://scripts/tests/CuevasVariedadProbe.gd

const CUEVAS := 50


func _init() -> void:
	var elige := RandomNumberGenerator.new()
	elige.seed = 20260913

	var vistas: Dictionary = {}
	var aperturas_seguidas := 0
	var anterior := ""
	var fuera_de_rango := 0
	var repetidas := 0
	var heridas := 0
	var muertes := 0

	for cueva in range(CUEVAS):
		var sim := _sim()
		var citados: Array = []
		sim.moment_raised.connect(func(m: Moment) -> void:
			if m.kind == Moment.Kind.CUEVA:
				citados.append(m))
		sim.exploracion._ultima_apertura = anterior
		sim.exploracion.mandar(cueva)

		var visita_textos: Array = []
		var contestadas := 0
		while contestadas < citados.size():
			var momento: Moment = citados[contestadas]
			visita_textos.append(momento.text)
			contestadas += 1
			var cual := elige.randi() % momento.options.size()
			(momento.options[cual]["on_pick"] as Callable).call()

		# Qué situaciones salieron, por su texto.
		var ids: Array = []
		for texto: String in visita_textos:
			for id: String in Repertorio.SITUACIONES:
				if String((Repertorio.SITUACIONES[id] as Dictionary)["texto"]) == texto:
					ids.append(id)
					vistas[id] = true
		# La visita cuenta las de arranque que se sortearon; las ramas se suman.
		var sorteadas := Repertorio.visita_de(sim.game_seed, cueva, anterior)
		if sorteadas.size() < 2 or sorteadas.size() > 3:
			fuera_de_rango += 1
		var unicas: Dictionary = {}
		for id: String in ids:
			unicas[id] = true
		if unicas.size() < ids.size():
			repetidas += 1
		if not ids.is_empty() and String(ids[0]) == anterior:
			aperturas_seguidas += 1
		if not ids.is_empty():
			anterior = String(ids[0])

		# Quien entra es la del hogar, la de id 1. Contar si la banda queda vacía
		# no vale: hay dos personas, y así la sonda no vio ningún muerto.
		var exploradora: Inhabitant = null
		for p: Inhabitant in sim.people:
			if p.id == 1:
				exploradora = p
		if exploradora == null:
			muertes += 1
		elif exploradora.hurt_days > 0:
			heridas += 1

	var pintables := 0
	for cueva in range(90):
		if Exploracion.hay_zona_pintable(20260913, cueva):
			pintables += 1

	print("")
	print("cuevas %d · visitas fuera de 2-3: %d · con situación repetida: %d · "
		% [CUEVAS, fuera_de_rango, repetidas]
		+ "abren igual que la anterior: %d" % aperturas_seguidas)
	print("situaciones distintas vistas: %d de %d en el repertorio"
		% [vistas.size(), Repertorio.cuantas()])
	print("salen heridos: %d · no salen: %d · de %d" % [heridas, muertes, CUEVAS])
	print("pintables de 90: %d" % pintables)
	quit()


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.techs = TechTree.new()
	sim.toolkit = Toolkit.new()
	sim.game_seed = 20260913
	var person := Inhabitant.new()
	person.id = 1
	person.given_name = "Anda"
	person.age_group = Inhabitant.Age.ADULTO
	person.job = Profession.Job.HOGAR
	var otra := Inhabitant.new()
	otra.id = 2
	otra.given_name = "Beru"
	otra.age_group = Inhabitant.Age.ADULTO
	otra.job = Profession.Job.CAZA
	sim.people = [person, otra]
	sim.toolkit.add(Tool.make(Tool.Kind.LAMPARA, Tool.default_stuff(Tool.Kind.LAMPARA)))
	sim.store.add(Materia.Kind.GRASA, 5.0)
	return sim
