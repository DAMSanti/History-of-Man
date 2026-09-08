class_name Percances
extends RefCounted
## Lo que sale mal ahi fuera: caidas, torceduras y sustos con la pieza.
##
## Sale de `SettlementSim` por lo mismo que [Caceria], [Cumbres] o [Trampas]:
## es un tema cerrado. Un percance no produce nada, no se reparte y no se
## acarrea; solo decide que a alguien le toque, cuanto le dure y si le ofrece
## al jugador la eleccion de aguantar o volverse.
##
## Se quedan en el simulador y se piden con `sim.`: [SettlementSim.CUIDADO_DAYS],
## [SettlementSim.VIVAC_RIESGO], [SettlementSim.PERCANCE_AGUANTAR] y
## `_care_given`. No es descuido: las tres primeras se leen tambien desde el
## hogar y el vivac, y la cuarta la escribe quien cuida en el abrigo. Traerlas
## aqui obligaria al camino contrario, que es peor.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Lo que puede salir mal ahi fuera, una vez por jornada y por explorador.
##
## Solo le pasa a quien esta LEJOS: el riesgo es el precio de haber mandado la
## partida a mirar, no un impuesto por existir. Y solo a la exploracion: el
## que va al avellanar de al lado no se pierde.
func _check_mishaps() -> void:
	if sim._terrain == null:
		return

	# Lo que ha dado hoy quien cuidaba adelanta la convalecencia del PEOR
	# herido, que es a quien se atiende primero. Ver `_tend_the_hurt`.
	var nursed: Inhabitant = null
	if sim._care_given >= 1.0:
		for person: Inhabitant in sim.people:
			if person.hurt_days <= 0:
				continue
			if nursed == null or person.hurt_days > nursed.hurt_days:
				nursed = person
	sim._care_given = 0.0

	for person: Inhabitant in sim.people:
		if person.hurt_days > 0:
			var gained := SettlementSim.CUIDADO_DAYS if person == nursed else 0
			person.hurt_days = maxi(person.hurt_days - 1 - gained, 0)
			if person.hurt_days == 0:
				sim._note(Chronicle.Kind.GENTE,
					"%s vuelve a andar bien." % person.given_name, 0)

		if person.job != Profession.Job.EXPLORACION:
			continue
		var away := Vector2(person.position.x - sim.home_position.x,
			person.position.z - sim.home_position.z).length()
		if away < 300.0:
			continue

		var ground := Traversal.classify_ground(
			sim._terrain.get_slope_at(person.position),
			sim._terrain.crossing_difficulty_at(person.position))
		var risk := Mishap.chance(ground, person.fatigue, away) 			* sim.weather.risk_factor()
		# Dormir mal a la intemperie no es sólo cansancio: es la noche de la
		# que se vuelve con un tobillo o no se vuelve con la carga. Ver
		# `_bivouac`.
		risk *= pow(SettlementSim.VIVAC_RIESGO, float(person.bivouac_lack))
		person.bivouac_lack = 0
		if sim._rng.randf() > risk:
			continue

		_apply_mishap(person, ground, away)


func _apply_mishap(person: Inhabitant, ground: Traversal.Ground,
		away: float) -> void:
	var kind := Mishap.roll(sim._rng, ground)
	var where := sim.parajes.place_name(person.position, sim.home_position)

	if Mishap.is_good(kind):
		# A veces sale bien: se tropieza con algo que no buscaba
		var found := Materia.Kind.PIEDRA
		if sim._rng.randf() < 0.4:
			found = Materia.Kind.ASTA
		elif sim._rng.randf() < 0.3:
			found = Materia.Kind.OCRE
		person.add_load(found, 1.0)
		sim._note(Chronicle.Kind.HALLAZGO,
			Mishap.tell(kind, person.given_name, where), 1)
		return

	person.hurt_days = maxi(person.hurt_days, Mishap.hurt_days(kind))

	if Mishap.drops_load(kind):
		person.load.clear()
		person.carrying = 0.0

	if Mishap.turns_back(kind):
		sim.marcha._send_to(person, sim.home_position)
		person.state = Inhabitant.State.VOLVIENDO
		# Un percance cancela la orden: insistir en mandarlos al mismo sitio
		# despues de que se hayan tenido que volver es el jugador quien lo
		# decide, no la maquina
		if sim.has_scout_order:
			sim.has_scout_order = false

	sim._note(Chronicle.Kind.PENURIA,
		Mishap.tell(kind, person.given_name, where),
		2 if Mishap.hurt_days(kind) > 0 else 1)

	# El accidente no se elige; la reacción sí, y es la que hace que perder a
	# alguien concreto pese. Sólo cuando queda margen: una caída ya obliga a dar
	# media vuelta, así que ahí no hay nada que decidir.
	if Mishap.hurt_days(kind) > 0 and not Mishap.turns_back(kind):
		_offer_mishap_choice(person, kind, where)


## Qué se hace con quien se ha roto algo lejos de casa. Ver [Moment].
func _offer_mishap_choice(person: Inhabitant, kind: Mishap.Kind,
		where: String) -> void:
	var moment := Moment.new()
	moment.kind = Moment.Kind.PERCANCE
	moment.who = person
	moment.where = person.position
	moment.has_place = true
	moment.title = "%s, %d años" % [person.given_name, person.age_years]
	moment.text = Mishap.tell(kind, person.given_name, where) 		+ " Está a %d m del abrigo." % int(
			person.position.distance_to(sim.home_position))
	moment.options = [
		{
			"label": "Que vuelva ya",
			"hint": "Se acaba su salida y pierde lo que fuera a traer, pero se "
				+ "cura como debe.",
			"on_pick": func() -> void:
				sim.marcha._send_to(person, sim.home_position)
				person.state = Inhabitant.State.VOLVIENDO,
		},
		{
			"label": "Que aguante y siga",
			"hint": "Termina lo que fue a hacer. Andar con eso roto lo deja "
				+ "tocado bastantes más días.",
			"on_pick": func() -> void:
				person.hurt_days = int(round(
					float(person.hurt_days) * SettlementSim.PERCANCE_AGUANTAR))
				sim._note(Chronicle.Kind.PENURIA,
					"%s aprieta los dientes y sigue." % person.given_name, 1),
		},
	]
	sim.raise_moment(moment)


## Lo que puede salir mal EN EL TAJO de caza, aparte de volver sin pieza:
## «riesgo» en [Fauna] no es un adorno -un uro no es un conejo-, y hasta
## ahora `Hunting.risk_at` se calculaba y no se usaba en ningun sitio: la
## banda podia mandar a un solo cazador contra un uro sin que le pasara
## nunca nada. Una vez al dia y por fraccion de jornada, no en cada tick de
## `_harvest`, o la probabilidad compuesta desmentiria el numero.
##
## La cuadrilla tambien reparte el peligro, no solo el trabajo: cuatro
## batidores no corren cada uno el riesgo entero del que va solo, que es
## justo la otra cara de [Hunting.crew_factor] -ir en cuadrilla no es solo
## mas pieza, es tambien mas seguro-.
func _check_hunting_risk(person: Inhabitant, speciality: Profession.Speciality,
		fraction: float) -> void:
	if speciality != Profession.Speciality.CAZA_MENOR \
			and speciality != Profession.Speciality.CAZA_MAYOR:
		return

	var risk := Hunting.risk_at(speciality, person.work_centre,
		GameState.season as Subsistence.Season, sim.taller.hunters_in(speciality), sim.toolkit)
	if risk <= 0.0:
		return
	risk *= fraction
	if sim._rng.randf() > risk:
		return

	var porte := Hunting.porte_of(speciality)
	var species := Fauna.huntable_at(person.work_centre,
		GameState.season as Subsistence.Season, porte as Fauna.Porte, sim.toolkit)
	var name := Fauna.species_name(species[sim._rng.randi() % species.size()]) \
		if not species.is_empty() else "la pieza"

	_hunting_mishap(person, speciality, name)


## El riesgo del LANCE, que sale de la pieza que se tiene delante.
##
## Va aparte de [_check_hunting_risk] y no es duplicar: aquélla contesta «qué
## puede pasarte en una jornada de caza en este coto», que es una media de lo
## que anda por ahí, y ésta contesta «qué puede pasarte al tirarle A ESTE
## BICHO». Cuando hay una cacería de verdad delante, la media sobra: lo que
## cornea es el uro que tienes a quince metros, no el promedio del monte.
##
## La cuadrilla reparte el peligro igual que en la otra, y por lo mismo: cuatro
## batidores no corren cada uno el riesgo entero del que va solo.
func _check_quarry_risk(person: Inhabitant, hunt: Hunt) -> void:
	var risk := Fauna.risk_of(hunt.species) / float(maxi(hunt.crew.size(), 1))
	risk *= Caceria.LANCE_RIESGO
	if risk <= 0.0 or sim._rng.randf() > risk:
		return
	_hunting_mishap(person,
		person.current_speciality as Profession.Speciality,
		Fauna.species_name(hunt.species))


## Lo que le pasa a quien sale mal parado de una caza. Lo comparten los dos
## caminos de arriba para que la consecuencia sea la misma venga de donde venga.
func _hunting_mishap(person: Inhabitant, speciality: Profession.Speciality,
		name: String) -> void:
	var hurt := Mishap.FALL_DAYS if speciality == Profession.Speciality.CAZA_MAYOR \
		else Mishap.SPRAIN_DAYS
	person.hurt_days = maxi(person.hurt_days, hurt)
	var where := sim.parajes.place_name(person.position, sim.home_position)
	sim._note(Chronicle.Kind.PENURIA,
		"%s salió mal parado%s cazando %s %s. Va a andar mal unos días." % [
			person.given_name,
			"a" if person.sex == Inhabitant.Sex.MUJER else "",
			name.to_lower(), where],
		2)
