class_name Hogar
extends RefCounted
## El fuego del abrigo y lo que se hace alrededor de el.
##
## Sale de `SettlementSim` como [Caceria] o [Reparto]: es un tema cerrado y
## ademas es EL SITIO, no una ruta. Aqui esta lo unico que se puede hacer de
## noche -ver `_can_work_at_night`-, lo que consume la lumbre, las obras del
## campamento, el secado y el ahumado, y quien cuida a los heridos.
##
## El oficio de Hogar no tiene especialidades a proposito: quien lo lleva hace
## todo lo de aqui. Ver `Profession.SPECIALITIES`.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Lo que se lleva el fuego en un día, y qué pasa si no lo hay.
##
## Dos cosas lo apagan y las dos son las que pide el diseño: que se acabe la
## leña y que no lo cuide nadie. La segunda no es un castigo arbitrario —un
## hogar sin nadie encima se apaga solo en una noche— y es lo que hace que el
## mínimo de gente en el hogar signifique algo: hasta ahora se podía dejar el
## oficio vacío y no pasaba nada.
##
## Y se cuenta: apagarse sin que quede rastro en la crónica sería un castigo
## invisible, que es la peor clase.
func _burn_hearth() -> void:
	var built: bool = sim.camp_built.get(CampProjects.Kind.HOGAR, false)
	var tended := sim._hearth_tended
	sim._hearth_tended = false
	if not built or not sim.hearth_lit:
		return

	if not tended:
		sim.hearth_lit = false
		sim.hearth_relight = 0.0
		sim._note(Chronicle.Kind.PENURIA,
			"Nadie se quedó al cuidado del sim.hogar y el fuego se apagó.", 2)
		return

	var wanted := SettlementSim.HEARTH_WOOD_PER_DAY
	if GameState.season == Subsistence.Season.INVIERNO:
		wanted *= SettlementSim.HEARTH_WINTER_FACTOR
	# Racionado se quema la mitad, que es lo que cuesta un fuego una noche sí y
	# otra no. Ver [racionado].
	if racionado:
		wanted *= 0.5
	if _hearth_keeper():
		wanted *= SettlementSim.YESQUERO_SAVING

	var burnt := sim.store.take(Materia.Kind.LENA, wanted)
	if burnt >= wanted - 0.001:
		return

	sim.hearth_lit = false
	sim.hearth_relight = 0.0
	sim._note(Chronicle.Kind.PENURIA,
		"Se acabó la leña y el sim.hogar se quedó frío.", 2)


## Si el fuego del invierno va racionado: una noche sí y otra no.
##
## Es la decisión fija del invierno —EPOCA_01 §10.1, frente 8—, y está hecha para
## que **cueste en las dos direcciones**, que es lo que la vuelve una decisión.
## El fuego de este juego es binario —encendido calienta, apagado deja el frío
## por grados de `SettlementSim.frio_por_hora`—, así que si racionar sólo
## gastara menos leña, siempre convendría. Racionado quiere decir **una noche
## con fuego y otra sin él**: se quema la mitad y la noche sin fuego se pasa el
## frío entero. No hay cifra de calor inventada: la mitad sale de «una sí y
## otra no».
var racionado := false


## Si el fuego calienta esta noche. Es lo que la cueva pregunta al dormir.
##
## Racionado, las noches impares no hay fuego aunque el hogar esté prendido.
func calienta_esta_noche() -> bool:
	if not sim.hearth_lit:
		return false
	return not (racionado and sim.day % 2 == 1)


## Propone la decisión del invierno. Lo llama [SettlementSim] al entrar el
## invierno. La primera opción es la que no compromete: SPECS §4.6.
func proponer_el_fuego() -> void:
	var moment := Moment.new()
	moment.kind = Moment.Kind.INVIERNO
	moment.title = "Llega el invierno: ¿cuánto fuego?"
	moment.text = ("Hay %.0f de leña en el abrigo. Con el fuego a manos llenas "
		+ "se quema toda la noche; racionado, dura el doble pero una noche de "
		+ "cada dos se duerme sin él.") % sim.store.amount(Materia.Kind.LENA)
	moment.options = [
		Moment.opcion("A manos llenas, como siempre",
			"Fuego cada noche. Gasta la leña de siempre.",
			func() -> void: racionado = false),
		Moment.opcion("Racionarlo",
			"Fuego una noche sí y otra no: la leña dura el doble y la otra "
				+ "noche se pasa frío.",
			func() -> void: _racionar(),
			{"riesgo": 0.5}),
	]
	sim.raise_moment(moment)


func _racionar() -> void:
	racionado = true
	sim._note(Chronicle.Kind.PENURIA,
		"Se raciona la leña: una noche con fuego y otra sin él.", 1)


## Se acaba el racionamiento con el invierno. Lo llama [SettlementSim].
func fin_del_invierno() -> void:
	racionado = false


## Si hoy hay alguien en el hogar, que es quien estira la leña.
##
## Era una ESPECIALIDAD -yesquero- y ya no: el hogar del Paleolitico lo hace
## todo, y quien lo atiende sabe prender, estirar la leña, ahumar y cuidar. Ver
## `Profession.SPECIALITIES`.
func _hearth_keeper() -> bool:
	return not _hearth_hands().is_empty()


## Quién está hoy al hogar. Es la lista y no la cuenta porque el secadero mira
## además lo que cada cual sabe: dos manos torpes no ahúman lo que dos buenas.
func _hearth_hands() -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.HOGAR:
			out.append(person)
	return out


## Quien trabaja SIN salir del abrigo: el hogar y el taller.
##
## Los dos hacen faena de verdad y ninguno tiene tajo en el monte, asi que no
## abren salida ni piden camino. Eso los dejaba fuera del estado TRABAJANDO y
## haciendo su jornada desde OCIOSO, o sea que la banda salia en pantalla
## parada media jornada cuando no lo estaba: medido en el sitio 56, ocho dias,
## el 39,6 % de las horas de luz figuraba como ocio y de ese ocio el 17,2 % era
## el hogar y el 16,0 % el taller, los dos trabajando.
func _works_at_camp(person: Inhabitant) -> bool:
	return person.job == Profession.Job.HOGAR \
		or person.job == Profession.Job.MANUFACTURA


## Si a esta persona le queda jornada, contando que ya ha anochecido.
##
## De noche solo se trabaja AL FUEGO Y EN CASA. Es la diferencia entre una
## banda y una cuadrilla de turnos: fuera no hay luz, y la que hay es la del
## hogar. Quien esta en el abrigo con el fuego encendido puede seguir tallando
## o curtiendo despues de que se ponga el sol; quien esta en el monte, no.
##
## Y a la hora de dormir se acaba para todos, tengan fuego o no: [HORA_DORMIR]
## no se negocia. Una banda que talla hasta la madrugada porque le sobra leña
## es un almacen con antorchas, no gente.
func _can_work_at_night(person: Inhabitant) -> bool:
	if sim.hour < SettlementSim.HORA_SALIDA or sim.hour >= SettlementSim.HORA_DORMIR:
		return false
	if sim.hour < SettlementSim.HORA_REGRESO:
		return true
	# Anochecido: hace falta estar en el abrigo y que el hogar arda.
	return sim.hearth_lit and sim._at_shelter(person)


## Lo que cansa una jornada de taller o de hogar, por hora.
##
## A CERO, que es exactamente lo que valia hasta ahora: en OCIOSO no se sumaba
## fatiga ninguna, asi que el tallador podia trabajar el ano entero sin
## cansarse. Se deja escrito y en su sitio para poder subirlo cuando toque
## ajustar -curtir pieles cansa, y no como andar diez kilometros-, pero
## subirlo AHORA seria cambiar el juego a la vez que se arregla el nombre, y
## entonces no se sabria cual de las dos cosas movio los numeros.
const CAMP_FATIGUE_RATE := 0.0


## La jornada de quien se queda en el abrigo.
##
## No bate el paraje -no hay paraje- ni se vuelve a casa al cansarse -ya esta
## en casa-, que son las dos cosas que hace el trabajo de monte y aqui no
## pintan. Lo demas es igual: se trabaja hasta la hora de recogerse, y de eso
## se encarga el bloque de `winding_down`.
func _camp_work(person: Inhabitant, hours: float) -> void:
	# Quieto. TRABAJANDO es uno de los estados que ANDAN -ver el bloque de
	# movimiento-, asi que sin esto el del taller se echaria a andar hacia el
	# ultimo destino que tuviera apuntado, que es el tajo del oficio anterior.
	person.target = person.position
	person.route = PackedVector3Array()
	person.route_step = 0
	if CAMP_FATIGUE_RATE > 0.0:
		person.fatigue = clampf(person.fatigue
			+ hours * CAMP_FATIGUE_RATE * person.fatigue_factor(), 0.0, 100.0)
	if person.job == Profession.Job.HOGAR:
		# El hogar levanta lo que este en cola y, si ya hay secadero, ahuma lo
		# que haya llegado fresco.
		_tend_camp(person, hours)
	else:
		# El taller no sale a picar piedra. En la tabla de oficios figura con
		# actividad MATERIA_PRIMA -es de donde saca lo que talla- y eso lo
		# mandaba cada manana a un cotarro al otro lado del valle: medido, un
		# tallador se pasaba el 79 % del dia andando y no salia una sola pieza.
		# La materia prima la traen los recolectores; el artesano trabaja sobre
		# lo que hay en el abrigo, y si no hay, se va a su siguiente oficio
		# -ver `_speciality_can_work`.
		sim.taller._craft(person, hours)


## Trabajo de quien esta en el hogar: no sale del campamento. Si hay un
## proyecto en cola lo saca adelante; si no, y ya hay secadero, ahuma lo que
## haya de carne fresca. Sin ninguna de las dos cosas, simplemente cuida del
## fuego y de quien no puede valerse solo, que es lo que ya hacia antes de
## que existiera nada de esto.
func _tend_camp(person: Inhabitant, hours: float) -> void:
	var fraction := hours / SettlementSim.HORAS_UTILES
	if fraction <= 0.0:
		return

	# El hogar no se le pide a nadie: es lo primero que levanta una banda al
	# llegar a un abrigo. Y hasta ahora no lo levantaba NUNCA, porque poner una
	# obra en cola sólo lo hacía el jugador desde el panel. Medido antes de
	# arreglarlo: cuarenta y cinco jornadas con ciento ochenta y cinco de leña
	# guardada y el abrigo todavía sin hogar, o sea la banda entera comiendo
	# crudo por un menú que nadie había abierto.
	if sim.camp_queue < 0 and not sim.camp_built.get(CampProjects.Kind.HOGAR, false):
		queue_project(CampProjects.Kind.HOGAR)

	if sim.camp_queue >= 0 and not sim.camp_built.get(sim.camp_queue, false):
		# El nombre se coge ANTES de trabajar: la jornada que termina la obra
		# vacía la cola -`_work_on_project` deja `camp_queue` en -1- y pedir
		# el nombre después reventaba con «Out of bounds get index '-1'»
		# justo al acabar el hogar, que es lo primero que levanta la banda.
		var doing := CampProjects.project_name(
			sim.camp_queue as CampProjects.Kind).to_lower()
		_work_on_project(person, fraction)
		person.log_deed(person.current_task(), "levantando %s" % doing, false)
		return

	# Prender otra vez es lo primero, por delante del secadero: sin brasas no se
	# ahuma nada, así que ponerse al secadero con el fuego apagado sería una
	# jornada tirada.
	if sim.camp_built.get(CampProjects.Kind.HOGAR, false) and not sim.hearth_lit:
		_relight_hearth(person, fraction)
		return

	sim._hearth_tended = sim._hearth_tended or sim.hearth_lit

	# Sin agua a mano -el abrigo no está junto al río de verdad, ver
	# [_home_by_water]-, llenar odres deja de ser gratis: hace falta una
	# salida real a la orilla más cercana. Va antes que curar y pintar
	# porque sin agua tampoco se hacen esas dos cosas.
	if _fetch_water(person):
		return

	# La pared, si el jugador ha mandado pintar algo. Va por delante de curar y
	# de ahumar porque es lo único de aquí que el jugador ha PEDIDO: lo demás
	# lo hace la banda sola. Ver `_paint_wall`.
	if sim.painting_queue != null:
		sim.pinturas._paint_wall(person, fraction)
		return

	# Y cuidar de quien no se vale. AHUMAR YA NO ESTA AQUI, y esa es la
	# diferencia: el secadero no es un trabajo, es un bastidor sobre las
	# brasas. Se cuelga la carne por la mañana y el humo hace el resto solo
	# mientras la persona atiende otra cosa. Lo que hace falta es que haya
	# fuego, bastidor y alguien al hogar; lo que NO hace falta es que ese
	# alguien se pase la jornada mirándolo. Ver `_smoke_the_larder`.
	if _someone_hurt():
		_tend_the_hurt(person, fraction)
		return

	var smoking: bool = (sim.hearth_lit
		and sim.camp_built.get(CampProjects.Kind.SECADERO, false)
		and _something_to_cure())
	if smoking:
		person.log_deed(person.current_task(),
			"al sim.hogar, con el secadero cargado", false)
		return

	person.log_deed(person.current_task(),
		"manteniendo el fuego" if sim.hearth_lit else "en el abrigo, sin fuego",
		false)


## Si hay algo fresco que merezca colgar del secadero.
func _something_to_cure() -> bool:
	for kind: int in CURADO:
		if sim.store.amount(kind as Materia.Kind) > 0.0:
			return true
	return false


## Si hay alguien a quien cuidar: heridos, o quien no se vale solo.
func _someone_hurt() -> bool:
	for person: Inhabitant in sim.people:
		if person.hurt_days > 0:
			return true
	return false


## Prender el hogar otra vez, que cuesta jornada y leña.
##
## Cuesta las dos cosas a propósito. Encender no es el problema —la banda sabe
## hacer fuego, ver SLICE_PALEOLITICO §1— y por eso no cuesta una tirada de
## suerte: lo que cuesta es la mañana de alguien y la leña que hay que reunir,
## que es exactamente lo que se pierde cuando se deja apagar.
func _relight_hearth(person: Inhabitant, fraction: float) -> void:
	person.log_deed(person.current_task(), "prendiendo el fuego", false)
	var pace := person.effectiveness() * SettlementSim.YESQUERO_BONUS
	sim.hearth_relight += fraction * pace
	if sim.hearth_relight < SettlementSim.HEARTH_RELIGHT_DAYS:
		return
	# No basta la leña de prenderlo: hace falta además con qué alimentarlo el
	# resto del día. Sin esta condición se entraba en un bucle de prenderlo por
	# la mañana y quedarse frío por la noche, gastando cada jornada la leña que
	# la banda acababa de traer y sin llegar nunca a tener fuego de verdad.
	if sim.store.amount(Materia.Kind.LENA) < SettlementSim.HEARTH_RELIGHT_WOOD + SettlementSim.HEARTH_WOOD_PER_DAY:
		return
	sim.store.take(Materia.Kind.LENA, SettlementSim.HEARTH_RELIGHT_WOOD)
	sim.hearth_relight = 0.0
	sim.hearth_lit = true
	sim._hearth_tended = true
	sim._note(Chronicle.Kind.OBRA,
		"%s volvió a prender el sim.hogar." % person.given_name, 1)


## Cuidar de quien no se vale solo. Adelanta la convalecencia de los heridos.
func _tend_the_hurt(person: Inhabitant, fraction: float) -> void:
	var worst: Inhabitant = null
	for other: Inhabitant in sim.people:
		if other.hurt_days <= 0:
			continue
		if worst == null or other.hurt_days > worst.hurt_days:
			worst = other
	if worst == null:
		person.log_deed(person.current_task(), "manteniendo el fuego", false)
		return
	person.log_deed(person.current_task(),
		"cuidando de %s" % worst.given_name, false)
	sim._care_given += fraction * person.effectiveness()


## Pone en cola una mejora del abrigo. Falla si ya esta hecha o si le falta la
## que necesita antes -el secadero sin hogar, por ejemplo-.
func queue_project(kind: CampProjects.Kind) -> bool:
	if sim.camp_built.get(kind, false):
		return false
	var needs := CampProjects.requires(kind)
	if needs >= 0 and not sim.camp_built.get(needs, false):
		return false
	sim.camp_queue = kind
	sim.camp_progress = 0.0
	sim._camp_paid = false
	return true


func _work_on_project(person: Inhabitant, fraction: float) -> void:
	if sim.camp_queue < 0:
		return
	var kind := sim.camp_queue as CampProjects.Kind

	# El material se paga una vez, al arrancar. Si no hay bastante, el
	# proyecto espera: no se descuenta a medias ni se avanza sin haberlo
	# pagado.
	if not sim._camp_paid:
		for material: int in CampProjects.materials(kind):
			var wanted: float = float(CampProjects.materials(kind)[material])
			if sim.store.amount(material as Materia.Kind) < wanted:
				return
		for material: int in CampProjects.materials(kind):
			sim.store.take(material as Materia.Kind,
				float(CampProjects.materials(kind)[material]))
		sim._camp_paid = true

	sim.camp_progress += fraction * person.effectiveness()
	if sim.camp_progress < CampProjects.labor_days(kind):
		return

	sim.camp_built[kind] = true
	# Se levanta el hogar y se prende de una vez: nadie delimita una fogata con
	# piedras para dejarla apagada.
	if kind == CampProjects.Kind.HOGAR:
		sim.hearth_lit = true
		sim._hearth_tended = true
	sim.camp_queue = -1
	sim.camp_progress = 0.0
	sim._camp_paid = false
	sim._note(Chronicle.Kind.OBRA,
		"Queda levantado el %s del abrigo, obra de %s."
			% [CampProjects.project_name(kind).to_lower(), person.given_name], 2)


## Cuanto ahuma un dia entero de trabajo al frente del secadero, a rendimiento
## perfecto. Una persona no seca una res al dia: es un goteo constante,
## limitado sobre todo por cuanta carne fresca vaya llegando de la caza.
## Raciones que ahuma una jornada entera de alguien en el hogar.
##
## Eran cuatro, y cuatro no es un secadero: es un pincho. Medido en el sitio
## 56 con tres personas en la pesca de orilla, la banda descargaba 53
## raciones de pescado al dia y el almacen se quedaba clavado en 124, porque
## el pescado fresco aguanta TRES DIAS y se pudria mas deprisa de lo que se
## podia curar. El jugador lo veia como «pescan pero no sube el pescado».
##
## Veinticuatro es lo que da de si un bastidor sobre el hogar con alguien
## atendiendolo la jornada entera: da para el remonte de un rio, que es
## justo lo que tiene que dar.
const DRY_PER_DAY := 24.0


## Lo que se cura y en que se convierte. La carne en cecina, el pescado en
## pescado seco: no es lo mismo y no se llama igual.
const CURADO := {
	Materia.Kind.PESCADO: Materia.Kind.PESCADO_SECO,
	Materia.Kind.CARNE: Materia.Kind.CARNE_SECA,
}


## Lo que ha salido del secadero hoy, material CURADO -> unidades. Para el
## parte de la jornada: sin esto, ahumar es un número que sube y otro que baja
## en el almacén y no se ve por ninguna parte.
var smoked_today: Dictionary = {}


## Ahuma lo que se pudre: carne y PESCADO.
##
## El secadero solo curaba carne, y el pescado —que aguanta tres dias, uno
## menos que la carne— se perdia entero. Ahumar el remonte del salmon es la
## razon de plantarse en el rio: no se pesca para comer hoy, se pesca para
## comer en enero. Se cura primero lo que antes se pudre, que es lo mismo que
## se come primero.
func _dry_meat(fraction: float, skill: float) -> void:
	var capacity := DRY_PER_DAY * fraction * skill
	if capacity <= 0.0:
		return

	var fresh: Array[int] = []
	for kind: int in CURADO:
		fresh.append(kind)
	fresh.sort_custom(func(a: int, b: int) -> bool:
		return Materia.shelf_life(a as Materia.Kind) 			< Materia.shelf_life(b as Materia.Kind))

	for kind: int in fresh:
		if capacity <= 0.0:
			break
		var raw := kind as Materia.Kind
		var dried := minf(capacity, sim.store.amount(raw))
		if dried <= 0.0:
			continue
		sim.store.take(raw, dried)
		sim.store.add(CURADO[raw] as Materia.Kind, dried)
		# Y AL LIBRO, que si no la cecina no existe para el almacén: se apuntaba
		# la carne fresca gastada -eso lo hace `take` solo- pero no la seca
		# producida, así que su «produce/mes» salía en cero por muchas tiras que
		# se colgaran. Ahumar es producir: el lavadero de bellota, que es la
		# misma clase de faena, ya lo apuntaba.
		sim.taller.note_production(CURADO[raw] as Materia.Kind, dried)
		var cured := int(CURADO[raw])
		smoked_today[cured] = float(smoked_today.get(cured, 0.0)) + dried
		capacity -= dried


## El secadero, una vez al día y sin gastarle la jornada a nadie.
##
## Es la petición literal —«será automático siempre que se tenga hogar
## encendido y ahumador y al menos un trabajador de hogar; no es un trabajo
## activo, pero sí se necesita supervisar»— y además es lo que es un secadero:
## un bastidor sobre las brasas. La carne se cuelga y el humo trabaja solo.
##
## Las tres condiciones son las tres, y cada una falla de una manera distinta:
## sin bastidor no hay dónde colgar, sin brasas no hay humo, y sin nadie al
## hogar el fuego se aviva mal, la carne se ahúma de un lado y se pierde. Esa
## tercera es la supervisión, y es la que hace que dejar el oficio de hogar
## vacío tenga un precio que se ve en la despensa.
##
## Cuánto se cura sale de CUÁNTOS supervisan y de lo que saben, no de cuántas
## horas le echan: el bastidor tiene el tamaño que tiene, y una segunda persona
## al hogar es una segunda tanda colgada, no la misma vigilada el doble.
func _smoke_the_larder() -> void:
	smoked_today.clear()
	if not sim.hearth_lit:
		return
	if not sim.camp_built.get(CampProjects.Kind.SECADERO, false):
		return

	var hands := _hearth_hands()
	if hands.is_empty():
		return

	var supervision := 0.0
	for person: Inhabitant in hands:
		supervision += person.effectiveness()
	_dry_meat(supervision, SettlementSim.AHUMADO_BONUS)


## Si el abrigo está de verdad junto al agua -no "hay un río en el valle",
## sino que se puede llenar un odre sin alejarse-. De eso depende que llenar
## odres (y beber en casa, ver [Despensa._drink_and_thirst]) sea gratis o
## una salida real. No todas las cuevas lo son: `Tajo._water_beside` mira el
## terreno de verdad, no lo asume.
func _home_by_water() -> bool:
	# Sin terreno que consultar -pruebas y montajes a medias, mismo patron
	# que `Taller.knows_tool` con el arbol de tecnicas- se asume que si, que
	# es el comportamiento de siempre: no penalizar un montaje que no viene
	# a probar esto.
	if sim._terrain == null:
		return true
	return sim.tajo._water_beside(sim.home_position)


## Cuántos odres se llenan por jornada y por persona de hogar, a rendimiento
## pleno -tanto en casa como en la orilla, ver [_arrive_at_water]-.
const ODRES_LLENADOS_POR_DIA := 4.0


## Llena odres vacíos EN CASA, una vez al día, sin que nadie salga.
##
## Sólo aplica si el abrigo está junto al agua de verdad -ver
## [_home_by_water]-; si no, llenar es una salida real y la lleva
## [_fetch_water] en vez de esto. Mismo patrón pasivo que
## [_smoke_the_larder]: capado por cuántos vigilan y cuánto saben, sin
## gastarle la jornada a nadie de forma explícita.
func _fill_waterskins() -> void:
	if not _home_by_water():
		return
	var vacios := float(sim.toolkit.count(Tool.Kind.ODRE)) \
		- sim.store.amount(Materia.Kind.AGUA)
	if vacios <= 0.0:
		return

	var hands := _hearth_hands()
	if hands.is_empty():
		return

	var supervision := 0.0
	for person: Inhabitant in hands:
		supervision += person.effectiveness()

	var llenados := minf(vacios, ODRES_LLENADOS_POR_DIA * supervision)
	if llenados <= 0.0:
		return
	sim.store.add(Materia.Kind.AGUA, llenados)


# --- ir a por agua de verdad, cuando el abrigo no está junto al río -------
#
# «Tanto beber del río como llenar los odres debe ser una salida y marcarse
# como tal, quizá haya cuevas que no estén pegadas al agua». Antes de esto,
# `_home_by_water() == false` no cambiaba nada: se seguía llenando gratis en
# el sitio. Ahora, sin agua a mano, alguien de HOGAR tiene que ir de verdad.

## Manda a alguien de HOGAR a la orilla más cercana si el abrigo no está
## junto al agua y hacen falta odres. Devuelve si se ha gastado la faena en
## esto -y `_tend_camp` no hace nada más este tick-.
##
## Es una salida real: `marcha._send_to` + `State.YENDO` es el mismo
## mecanismo que usa cualquier otro viaje del juego, así que cuenta como
## jornada de camino, deja rastro y cierra su `journey` al volver -ver
## [Inhabitant.end_journey], llamado desde [Despensa._deliver] igual que
## para cualquiera-. Nada de esto es nuevo: es no tratar a quien va a por
## agua de otra manera que a quien va a cualquier otro tajo.
func _fetch_water(person: Inhabitant) -> bool:
	if _home_by_water():
		return false
	var vacios := float(sim.toolkit.count(Tool.Kind.ODRE)) \
		- sim.store.amount(Materia.Kind.AGUA)
	if vacios <= 0.0:
		return false

	if person.journey.is_empty():
		person.begin_journey(Profession.job_name(person.job as Profession.Job),
			sim.day, sim.hour, sim.home_position)
	person.log_deed(person.current_task(), "de camino al agua", false)
	sim.marcha._send_to(person, sim.tajo._shore_near(sim.home_position))
	person.state = Inhabitant.State.YENDO
	return true


## Al llegar a la orilla -enganchado desde el `YENDO` general de
## `SettlementSim`, cuando quien llega es de HOGAR-. Llena lo que el
## acarreo de uno dé de sí y vuelve; `_deliver` cierra la salida al entrar
## por la boca del abrigo, igual que con cualquier otro viaje.
func _arrive_at_water(person: Inhabitant) -> void:
	var vacios := float(sim.toolkit.count(Tool.Kind.ODRE)) \
		- sim.store.amount(Materia.Kind.AGUA)
	var llenados := minf(vacios, ODRES_LLENADOS_POR_DIA * person.effectiveness())
	if llenados > 0.0:
		sim.store.add(Materia.Kind.AGUA, llenados)
	person.log_deed(person.current_task(), "llenando odres en la orilla", false)
	sim.marcha._send_to(person, sim.home_position)
	person.state = Inhabitant.State.VOLVIENDO



# --------------------------------------------------- el desamargado -----

## Cuántas jornadas tiene que estar la bellota en el agua.
##
## Tres. Es lo que tarda el agua corriente en llevarse el tanino de una bellota
## partida, y es lo que convierte el otoño en una decisión: recoger es fácil,
## hacerla comestible cuesta. La cifra queda abierta a playtest.
const REMOJO_JORNADAS := 3.0

## Cuántos puñados caben en un lavadero.
##
## Es el CUELLO DE BOTELLA, y es lo único que impide que el otoño sea «recoge y
## ya»: en un otoño bueno sobra bellota sin tratar. Un cesto lastrado en el
## remanso son treinta puñados; querer más es levantar otro lavadero.
const CABE_EN_EL_CESTO := 30.0

## Cuánto merma al lavarse. La bellota suelta el tanino y algo de sustancia con
## él, y además se parte: de diez puñados puestos salen nueve.
const MERMA := 0.9

## Lo que hay a remojo ahora mismo, en puñados, y desde cuándo.
var a_remojo: float = 0.0
var remojo_dias: float = 0.0

## Lo que salió del lavadero hoy. Para que la crónica y las sondas lo vean.
var lavado_hoy: float = 0.0


## La bellota puesta a lavar. La corriente trabaja sola: esto sólo mira si ya
## está, y si hay sitio, mete más.
##
## Va con el hogar porque es quien atiende lo que hay puesto —igual que
## [_smoke_the_larder]—, pero NO pide fuego: es agua corriente. Por eso el
## lavadero es la única obra que se puede levantar sin haber encendido nada.
func _lavar_bellota() -> void:
	lavado_hoy = 0.0
	if not sim.camp_built.get(CampProjects.Kind.LAVADERO, false):
		return

	# Primero se saca lo que ya está: el cesto tiene que quedar libre para
	# volver a llenarlo el mismo día, que es como se hace en un otoño.
	if a_remojo > 0.0:
		remojo_dias += 1.0
		if remojo_dias >= REMOJO_JORNADAS:
			lavado_hoy = a_remojo * MERMA
			# La cascarilla y la cupula, que es lo que la bellota suelta al
			# lavarse, van al monton igual que la concha. Ver [Desechos].
			sim.desechos.tirar_litros(Materia.Kind.BELLOTA,
				(a_remojo - lavado_hoy) * Materia.litres_per_unit(
					Materia.Kind.BELLOTA))
			sim.store.add(Materia.Kind.BELLOTA_DULCE, lavado_hoy)
			sim.taller.note_production(Materia.Kind.BELLOTA_DULCE, lavado_hoy)
			a_remojo = 0.0
			remojo_dias = 0.0

	if a_remojo > 0.0:
		return
	var cruda := sim.store.amount(Materia.Kind.BELLOTA)
	if cruda <= 0.0:
		return
	var mete := minf(cruda, CABE_EN_EL_CESTO)
	sim.store.take(Materia.Kind.BELLOTA, mete)
	a_remojo = mete
	remojo_dias = 0.0


## Cuánta bellota cruda hay esperando turno de lavadero.
##
## Es la cifra que enseña el cuello de botella: si crece y crece, el otoño está
## trayendo más de lo que se puede tratar y hace falta otro lavadero.
func bellota_en_cola() -> float:
	return sim.store.amount(Materia.Kind.BELLOTA)
