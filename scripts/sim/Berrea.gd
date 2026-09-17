class_name Berrea
extends RefCounted
## El celo del ciervo: la decision del otoño y las semanas de caza que trae.
##
## Sale de `SettlementSim` en la segunda pasada (ARQUITECTURA §3.2): es un tema
## cerrado -empieza, se decide, dura y se acaba- y no se cruza con nada mas que
## con la caceria, a la que le cambia el rendimiento mientras dura.
##
## SLICE_PALEOLITICO §3 dice que el otoño decide si se sobrevive al invierno.
## Hasta la tanda 2 eso pasaba solo: cambiaba el multiplicador de rendimiento de
## la caza y el jugador se enteraba si iba a mirar la tabla. Aqui se le pone
## delante, con la reserva que lleva, y se le deja decidir en el momento.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## La decisión de la berrea, al empezar el otoño.
##
## SLICE_PALEOLITICO §3 dice que el otoño decide si se sobrevive al invierno.
## Hasta ahora eso pasaba solo: cambiaba el multiplicador de rendimiento de la
## caza y el jugador se enteraba si iba a mirar la tabla. Aquí se le pone
## delante, con la reserva que lleva, y se le deja decidir en el momento.
func _offer_rut_choice() -> void:
	var stock := sim.despensa.winter_stock()
	var moment := Moment.new()
	moment.kind = Moment.Kind.BERREA
	moment.title = "Empieza la berrea"
	moment.text = ("El ciervo baja y se junta: son las mejores semanas de caza "
		+ "del año, y las únicas que llenan la despensa de cara al invierno. "
		+ "Ahora mismo hay %d raciones de las %d que se comerán en invierno."
		) % [int(stock["have"]), int(stock["needed"])]
	var cazadores := _pueden_cazar()
	# «SEGUIR» VA PRIMERO, que es el contrato de SPECS §4.6: la opción 0 es la
	# que no compromete a nada. Estaba al revés, y por eso `TironAnualProbe`
	# tenía que contestar la berrea con la opción 1 como caso aparte.
	moment.options = [
		Moment.opcion("Seguir como hasta ahora",
			"El reparto de oficios no se toca.",
			func() -> void: pass),
		Moment.opcion("Volcarse en la berrea",
			("Los %d que pueden cazar pasan a caza mayor %d jornadas y dejan de "
				+ "recolectar y de hacer leña: son %d jornadas que no se recogen. "
				+ "Es la apuesta.") % [cazadores, DIAS_DE_BERREA,
					cazadores * DIAS_DE_BERREA],
			func() -> void: focus_on_rut(),
			{"jornadas": cazadores * DIAS_DE_BERREA}),
	]
	sim.raise_moment(moment)


## Cuánto dura volcarse en la berrea: un mes del calendario del juego.
##
## Es `Subsistence.DAYS_PER_MONTH` y no una cifra aparte: la spec dice «ese mes».
const DIAS_DE_BERREA := Subsistence.DAYS_PER_MONTH

## Cuántos pueden salir a la caza mayor.
func _pueden_cazar() -> int:
	var n := 0
	for person: Inhabitant in sim.people:
		if Profession.can_do(Profession.Job.CAZA, person):
			n += 1
	return n


## Vuelca la banda en la caza mayor. Es la mitad activa de la berrea.
##
## **Y AHORA CUESTA, que es lo que la spec pedía: «la berrea deja de ser
## gratis».** Antes ponía la caza mayor a prioridad 3, que en este reparto es
## la MENOS urgente —ver `Inhabitant.set_priority`, de 1 a 3—, así que quien
## tuviera recolección a 1 o a 2 seguía recolectando y volcarse no hacía casi
## nada. La pista de la opción ya prometía «se dejan de hacer otras cosas: es la
## apuesta», y el código no lo cumplía.
##
## Ahora, durante [DIAS_DE_BERREA]: la caza mayor a 1, y **la recolección
## entera apagada** para quien va —comida, leña y piedra, que son el oficio de
## recolección—. Al acabar se devuelven las prioridades de antes. Ver
## [_acabar_la_berrea].
func focus_on_rut() -> void:
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	var sent := 0
	sim.berrea_hasta_el_dia = sim.day + DIAS_DE_BERREA
	for person: Inhabitant in sim.people:
		if not Profession.can_do(Profession.Job.CAZA, person):
			continue
		if not sim._prioridades_antes_de_la_berrea.has(person.id):
			sim._prioridades_antes_de_la_berrea[person.id] = person.priorities.duplicate()
		for otra: int in person.priorities.keys():
			if Profession.task_job(otra) == Profession.Job.RECOLECCION:
				person.set_priority(otra, 0)
		person.set_priority(task, 1)
		sent += 1
	sim.apply_priorities()
	sim._note(Chronicle.Kind.TIERRA,
		("La banda se vuelca en la berrea: %d salen a la caza mayor y dejan la "
			+ "recolección %d jornadas.") % [sent, DIAS_DE_BERREA], 2)


## Se acaba la berrea y cada uno vuelve a lo suyo. Lo mira el cierre de jornada.
func _acabar_la_berrea() -> void:
	if sim.berrea_hasta_el_dia < 0 or sim.day < sim.berrea_hasta_el_dia:
		return
	for person: Inhabitant in sim.people:
		if sim._prioridades_antes_de_la_berrea.has(person.id):
			person.priorities = (sim._prioridades_antes_de_la_berrea[person.id] as Dictionary).duplicate()
	sim._prioridades_antes_de_la_berrea.clear()
	sim.berrea_hasta_el_dia = -1
	sim.apply_priorities()
	sim._note(Chronicle.Kind.TIERRA,
		"Acaba la berrea: cada uno vuelve a lo suyo.", 1)


## Lo que significa que entre cada estacion, dicho como se diria.
##
## No es adorno: cada frase avisa de lo que va a cambiar en los rendimientos,
## que es informacion que hoy solo esta en una tabla de multiplicadores.
func _season_line() -> String:
	match sim.estacion:
		Subsistence.Season.PRIMAVERA:
			return "Entra la primavera del año %d. Sube el rio y remonta el " \
				% sim.anyo + "pescado."
		Subsistence.Season.VERANO:
			return "Entra el verano. Los dias son largos y se puede ir lejos."
		Subsistence.Season.OTONO:
			return "Entra el otoño: la avellana y la bellota. Es AHORA cuando " \
				+ "se llena el abrigo o no se llena."
		_:
			return "Entra el invierno. El monte no da y se vive de lo guardado."
