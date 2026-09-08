class_name Despensa
extends RefCounted
## Comer, beber y salir avituallado.
##
## Sale de `SettlementSim` como [Caceria] o [Taller]. Junta las tres formas de
## que la comida llegue a una persona: la que se come EN EL ABRIGO al desayuno
## y a la cena, la que se saca del almacen para llevarsela, y la que se come
## fuera de lo que se lleva encima.
##
## Y con ellas va el VIVAC, que es lo que decide si se vuelve a dormir a casa:
## irse varios dias solo se puede si hay de comer que cargar, y solo COMPENSA
## si lo que se va a traer da para mas de lo que se come mientras.
##
## La racion es la unidad de todo esto: [Materia.KCAL_RACION] calorias, media
## jornada de una persona. Ver el encabezado de [Materia.CATALOGUE].
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Cuantos dias de mas pide una distancia, por encima del suelo de
## siempre. Grosero a proposito: no sabe de rios ni de cuestas por el
## camino real, solo dice "esto esta lejos, para esto no basta con lo de
## siempre".
func _travel_days_for(distance_m: float) -> float:
	if distance_m <= 0.0:
		return 0.0
	return floor((distance_m / 1000.0) / SettlementSim.KM_PER_EXTRA_DAY)


## Cuantos dias de comida le tocan a esta persona, segun su destreza y lo
## lejos que va.
##
## En LA SUYA: expedicion y ascension no comparten cuenta, cada una avanza
## con su propio ritmo -alguien puede ser un buen escalador y un mal
## logistico de expedicion larga, o al reves.
##
## `distance_m` es la distancia real al destino de esta salida. Antes se
## cargaban siempre los mismos `expedition_days` sin mirar adonde se iba,
## asi que una ascension a la loma de al lado y una expedicion a dos
## valles cargaban exactamente lo mismo: de sobra para la primera, corto
## para la segunda. Sin distancia -pruebas, o destino aun sin calcular- se
## queda en el suelo de siempre.
func _expedition_days_for(person: Inhabitant, distance_m: float = -1.0) -> float:
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		person.current_speciality as Profession.Speciality)
	var factor := lerpf(SettlementSim.EXPEDITION_SKILL_DAYS_RANGE.x, SettlementSim.EXPEDITION_SKILL_DAYS_RANGE.y,
		person.skill_in(task))
	var base_days := float(sim.expedition_days)
	if distance_m > 0.0:
		base_days = maxf(base_days, _travel_days_for(distance_m) + SettlementSim.SAFETY_MARGIN_DAYS)
	return base_days * factor


## Avitualla una expedicion o ascension. Devuelve si pudo salir.
##
## Es lo que hace que explorar lejos deje de ser gratis: cada salida se
## lleva comida del almacen, y en un mal invierno eso es comida que no esta.
## La batida no pasa por aqui -no acampa, vuelve a diario- ver el bloque
## nocturno de `_tick_person`.
##
## `distance_m` es la distancia al destino de HOY. Si no llega a acampar
## -un pico cercano, un frente a un paso del abrigo- no hace falta cargar
## nada: se come en casa como cualquier otro y se vuelve esa misma tarde.
## Cargar racion aqui era pedirle un peaje a quien ni siquiera duerme fuera.
func _provision(person: Inhabitant, distance_m: float = -1.0) -> bool:
	if distance_m >= 0.0 and distance_m <= sim.arrive_radius * 4.0:
		return true

	# Lo que ya lleve cuenta
	var carried := 0.0
	for kind: int in person.load.keys():
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			carried += float(person.load[kind]) * Materia.nutrition(k)

	var days := _expedition_days_for(person, distance_m)
	var needed := person.daily_food() * days - carried
	if needed <= 0.0:
		return true

	# Se prefiere lo que menos pesa por racion y mas aguanta: para llevar
	# encima varios dias, la carne seca y el fruto son lo unico razonable
	for kind: int in [Materia.Kind.CARNE_SECA, Materia.Kind.PESCADO_SECO,
			Materia.Kind.FRUTO_SECO, Materia.Kind.GRASA]:
		if needed <= 0.0:
			break
		var k := kind as Materia.Kind
		var units := sim.store.take(k, needed / maxf(Materia.nutrition(k), 0.001))
		if units > 0.0:
			person.add_load(k, units)
			person.note_from_store(k, units)
			needed -= units * Materia.nutrition(k)

	# Sin nada de eso -o sin bastante-, se carga lo que HAYA, fresco o no.
	# Antes, si el almacen se quedaba sin las tres cosas concretas de
	# arriba, la expedicion simplemente NO SALIA, sin una nota ni un
	# aviso: una banda que agotaba su carne seca dejaba de explorar EL
	# RESTO DE LA PARTIDA sin que nadie supiera por que, aunque el
	# almacen siguiera lleno de pescado, mariscos o fruto fresco.
	# Cualquier banda de verdad sale con lo que tenga antes que quedarse
	# en el abrigo por no tener precisamente la mejor racion de viaje.
	if needed > 0.0:
		for kind: int in Materia.Kind.values():
			if needed <= 0.0:
				break
			var k := kind as Materia.Kind
			if not Materia.is_food(k):
				continue
			var units := sim.store.take(k, needed / maxf(Materia.nutrition(k), 0.001))
			if units > 0.0:
				person.add_load(k, units)
				person.note_from_store(k, units)
				needed -= units * Materia.nutrition(k)

	_pack_bivouac(person, days)

	# Con menos de un dia de comida no se sale
	return needed <= person.daily_food() * (days - 1.0)


## Carga la tienda y la hoguera de las noches que se van a pasar fuera.
##
## No impide salir si falta: una banda sale con lo que tiene, igual que con la
## comida. Lo que hace la falta es cara: se paga esa noche, en riesgo de
## percance. Ver `_bivouac`.
func _pack_bivouac(person: Inhabitant, days: float) -> void:
	var nights := maxf(ceil(days), 1.0) + SettlementSim.VIVAC_MARGEN_NOCHES
	var piel := SettlementSim.VIVAC_PIEL - float(person.load.get(Materia.Kind.PIEL, 0.0))
	if piel > 0.0:
		var got := sim.store.take(Materia.Kind.PIEL, piel)
		person.add_load(Materia.Kind.PIEL, got)
		person.note_from_store(Materia.Kind.PIEL, got)
	var lena := SettlementSim.VIVAC_LENA * nights - float(person.load.get(Materia.Kind.LENA, 0.0))
	if lena > 0.0:
		var got_wood := sim.store.take(Materia.Kind.LENA, lena)
		person.add_load(Materia.Kind.LENA, got_wood)
		person.note_from_store(Materia.Kind.LENA, got_wood)


## Lo que cuesta pasar la noche fuera del abrigo.
##
## Se cobra UNA vez por noche —de ahí `bivouac_day`— y no en cada tick, que es
## como se cobraría sesenta veces por segundo. La piel no se gasta: hay que
## tenerla, y vuelve al abrigo con quien la llevó. La leña arde.
func _bivouac(person: Inhabitant) -> void:
	if person.bivouac_day == sim.day:
		return
	person.bivouac_day = sim.day
	person.bivouac_lack = 0
	person.bivouac_tent = float(person.load.get(Materia.Kind.PIEL, 0.0)) 		>= SettlementSim.VIVAC_PIEL
	if not person.bivouac_tent:
		person.bivouac_lack += 1
	# La leña que se quema es la hoguera, y ahora se ve arder: ver
	# [BivouacFires]. Sin fuego se sigue durmiendo, pero a oscuras y con el
	# riesgo que eso trae.
	person.bivouac_fire = person.take_load(
		Materia.Kind.LENA, SettlementSim.VIVAC_LENA) >= SettlementSim.VIVAC_LENA
	if not person.bivouac_fire:
		person.bivouac_lack += 1

	# Y ARMARLO, que no es tener el material. Montar una tienda de pieles con
	# viento, prender con leña húmeda y dejarlo de forma que aguante la noche es
	# saber del HOGAR: es el mismo oficio que mantiene el fuego del abrigo, y
	# por eso es su saber el que decide, no el de explorar.
	#
	# Quien no lo sabe hacer duerme peor aunque lleve todo lo que hace falta, y
	# eso se paga a la mañana siguiente: se levanta mas cansado y la jornada le
	# cunde menos. Es lo que hace que poner a alguien en el sim.hogar valga tambien
	# para quien sale de expedicion.
	# Va APARTE de `bivouac_lack`, que cuenta lo que FALTA: llevar la piel y la
	# leña y no saber armarlo son dos cosas distintas y se leen distinto en la
	# cronica -«sin tienda» no es «mal armado»-.
	person.bivouac_botched = not _camps_well(person)
	if person.bivouac_botched:
		person.log_deed(person.current_task(),
			"pasó la noche mal armado", false)

	if person.bivouac_lack <= 0:
		return
	var falta := "sin tienda ni hoguera"
	if person.bivouac_lack == 1:
		falta = "sin hoguera" if person.bivouac_tent else "sin tienda"
	sim._note(Chronicle.Kind.PENURIA,
		"%s pasa la noche %s en %s." % [person.given_name, falta,
			sim.parajes.place_name(person.position, sim.home_position)], 1)


## Cuanto pesa el saber del sim.hogar en armar un vivac.
##
## De cero a uno: con el sim.hogar sin practicar se falla casi siempre, y con el
## oficio hecho no se falla nunca. La suerte que queda es la noche -llueve, o
## no-, y por eso no es un si o no seco.
##
## Pendiente de playtest: lo decidido es que el sim.hogar sirva para esto, no
## cuanto.
const VIVAC_BASE := 0.35


## Si esta persona sabe armar el campamento de una noche.
func _camps_well(person: Inhabitant) -> bool:
	var task := Profession.task_id(Profession.Job.HOGAR)
	var know := clampf(VIVAC_BASE + person.skill_in(task), 0.0, 1.0)
	return sim._rng.randf() < know


## Cuanto del dia util puede costar el ir y venir antes de que no compense
## volver a dormir a casa.
##
## MEDIDO, y es de las cifras que mas cambian el juego. Con
## `scripts/tests/JornadaCazadorProbe.gd`, doce jornadas y cinco cazadores de
## caza mayor con azagaya, el dia de un cazador se repartia asi:
##
##   durmiendo          45,2 %
##   de camino          23,4 %
##   volviendo          22,5 %
##   ocioso              4,7 %
##   buscando            3,2 %
##   TRABAJANDO          0,8 %   <- rastreo, acecho y lance, todo junto
##
## Y en esos ratos de trabajo tenia pieza al alcance el CIEN por cien de las
## veces. O sea que la caza no fallaba por falta de caza, ni por punteria, ni
## por fuelle: el cazador no llegaba a cazar. Se le iba el dia andando a un
## coto a kilometro y medio -[CAZA_LEJOS_M]- y volviendo de el.
##
## Media jornada util. Pendiente de playtest: lo decidido es que a partir de
## cierto punto se duerma donde se caza en vez de hacer el camino dos veces al
## dia, no donde esta ese punto.
const VUELTA_QUE_NO_COMPENSA := 0.5


## Si esta persona pasa la noche FUERA en vez de volver al abrigo.
##
## Lo hacia solo el explorador. Ahora tambien EL CAZADOR DE PIEZA GRANDE, y esa
## es la diferencia entre una caza de jornada y una caza de verdad: una pieza
## grande no se cobra entre el desayuno y la cena. Se sale con provisiones, se
## duerme al raso y se vuelve con ella o sin ella.
##
## Las tres condiciones son las mismas para todos: hay que estar LEJOS -si no
## se duerme en casa, que se duerme mejor-, hay que poder con la noche, y hay
## que llevar de comer. Lo de comer lo mira quien llama; aqui va el resto.
func _camps_out(person: Inhabitant, mid_survey: bool) -> bool:
	if person.position.distance_to(sim.home_position) <= sim.arrive_radius * 4.0:
		return false
	if person.job == Profession.Job.EXPLORACION:
		return person.current_speciality != Profession.Speciality.BATIDA \
			and (person.fatigue < 70.0 or mid_survey)
	if person.job == Profession.Job.CAZA:
		if person.fatigue >= 70.0:
			return false
		# Con la pieza levantada no se vuelve: eso no se discute.
		if sim.caceria.hunt_of(person) != null:
			return true
		# Y sin ella tampoco, si el coto esta tan lejos que el camino se come el
		# dia. Antes se volvia siempre, y el rastreo -que es la mayor parte del
		# oficio- no llegaba a empezar nunca. Ver [VUELTA_QUE_NO_COMPENSA].
		if person.current_speciality != Profession.Speciality.CAZA_MAYOR:
			return false
		if not _worth_sleeping_out(person):
			return false
		var round_trip := sim.marcha.hours_to_walk(
			person.position.distance_to(sim.home_position) * SettlementSim.RODEO_DE_VUELTA) * 2.0
		return round_trip >= SettlementSim.HORAS_UTILES * VUELTA_QUE_NO_COMPENSA
	return false


## Si a esta persona le compensa quedarse a dormir en el monte a por pieza
## grande, en vez de volverse y hacer caza menor cerca de casa.
##
## La gente NO ES TONTA: sabe con lo que sale. Un cazador con las manos vacias
## no se va cinco jornadas detras de un uro -no lo va a matar, y mientras tanto
## no come-; con azagayas en el abrigo y tres personas al lado, la cuenta
## cambia y entonces si.
##
## Se pide de verdad, no se aproxima: `Caceria.raciones_esperadas` mira las
## raciones que tiene la pieza -[Fauna] manda-, lo que se cobra de lo que se
## levanta, y las horas de rastreo, que ya llevan dentro LA PERICIA, el filo
## que hay y la cuadrilla que hay. Los tres mandos que se pedian estan ahi
## dentro sin tener que ponerlos aparte.
##
## Y el liston es el que se puede defender solo: que traiga al menos lo que
## come mientras esta fuera. Por debajo de eso, irse es perder comida.
func _worth_sleeping_out(person: Inhabitant) -> bool:
	var big := sim.caceria.raciones_esperadas(person, Profession.Speciality.CAZA_MAYOR)
	if big < person.daily_food():
		return false
	# Y ademas tiene que ganarle a quedarse cerca haciendo caza menor, que es
	# la alternativa de verdad y no «no hacer nada».
	return big >= sim.caceria.raciones_esperadas(person,
		Profession.Speciality.CAZA_MENOR)


## Come de lo que lleva en la mochila, estando fuera.
func _eat_from_pack(person: Inhabitant, hours: float) -> void:
	var wanted := person.daily_food() * (hours / 24.0)
	for kind: int in person.load.keys().duplicate():
		if wanted <= 0.0:
			break
		var k := kind as Materia.Kind
		if not Materia.is_food(k):
			continue
		var have: float = person.load[k]
		var units := minf(have, wanted / maxf(Materia.nutrition(k), 0.001))
		person.load[k] = have - units
		if person.load[k] <= 0.0001:
			person.load.erase(k)
		# Lo comido sale de lo que se sacó del almacén: si no se descontara
		# aquí, al volver se le restaría a la producción una comida que ya no
		# lleva encima.
		person.carried_out[k] = maxf(
			float(person.carried_out.get(k, 0.0)) - units, 0.0)
		wanted -= units * Materia.nutrition(k)
		person.hunger = maxf(person.hunger - units * Materia.nutrition(k) * (3.4 * 24.0), 0.0)


## Cuanta comida le queda encima a una persona, en raciones.
func pack_rations(person: Inhabitant) -> float:
	var total := 0.0
	for kind: int in person.load.keys():
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			total += float(person.load[kind]) * Materia.nutrition(k)
	return total


## A partir de que distancia del abrigo cuenta como "lejos": el borde del
## mapa local, donde la exploracion empieza a asomarse a la comarca.
const REGIONAL_DISTANCE := 2600.0

## Cuanta gente hace falta dedicada a la expedicion antes de dejar que
## alguien se aventure mas alla de [REGIONAL_DISTANCE].
##
## La peticion explicita: "las exploraciones mas lejanas o regionales
## requieren grupos relativamente numerosos". Todavia no hay partidas que
## caminen juntas en formacion -cada explorador sigue su propio paso y su
## propio destino-, asi que esto se aplica como una condicion de PARTIDA:
## mientras la banda no tenga suficiente gente puesta en ello, nadie sale
## solo a explorar el borde del mapa. Con mas manos dedicadas a la vez, sí.
const MIN_GROUP_FOR_REGIONAL := 3


## Cuanta gente de la banda esta puesta en expedicion ahora mismo.
func _expedition_party_size() -> int:
	var n := 0
	for p: Inhabitant in sim.people:
		if p.job == Profession.Job.EXPLORACION \
				and p.current_speciality == Profession.Speciality.EXPEDICION:
			n += 1
	return n


## Cómo va la reserva de cara al invierno.
##
## Es la cuenta central de la época —SLICE_PALEOLITICO §3: el otoño decide si
## sobrevives al invierno— y hasta ahora sólo existía repartida entre el almacén
## y la cabeza del jugador. Devuelve raciones guardadas, las que hacen falta
## para pasar el invierno entero, y la fracción entre las dos.
func winter_stock() -> Dictionary:
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	var needed := mouths * float(Subsistence.DAYS_PER_SEASON)
	var have := sim.store.food_rations()
	return {
		"have": have, "needed": needed,
		"share": have / maxf(needed, 0.001),
	}


## Cuantos odres LLENOS cuelgan del abrigo ahora mismo.
##
## El almacen no guarda agua a granel: guarda odres llenos, y por eso
## `Materia.Kind.AGUA` se mide en «odre» y pesa lo que pesa uno. La cifra no se
## lleva a mano -eso serian dos verdades sobre lo mismo- sino que se deriva de
## los odres que ha hecho el taller menos los que hay fuera con alguien.
##
## Y estan llenos porque el abrigo se funda junto al agua: colgar un odre en la
## boca de la cueva es tenerlo lleno. El que se vacia es el que sale.
func _sync_waterskins() -> void:
	if sim.store == null or sim.toolkit == null:
		return
	var out := 0
	for person: Inhabitant in sim.people:
		if person.has_waterskin:
			out += 1
	var at_home := maxf(float(sim.toolkit.count(Tool.Kind.ODRE) - out), 0.0)
	var now := sim.store.amount(Materia.Kind.AGUA)
	if absf(now - at_home) < 0.01:
		return
	if now > at_home:
		sim.store.take(Materia.Kind.AGUA, now - at_home)
	else:
		sim.store.add(Materia.Kind.AGUA, at_home - now)


## Reparte cesto y odre entre los que salen, de lo que hay HECHO.
##
## Uno por cabeza y hasta donde llegue el taller: dos personas no comparten un
## odre. Antes se preguntaba si en el almacen quedaba piel o fibra en bruto,
## con lo que la banda entera salia siempre con los dos recipientes desde el
## primer dia -medido en el sitio 56: cero odres tallados y aun asi todo el
## mundo con odre- y el taller no servia para nada en este frente.
func _hand_out_containers(person: Inhabitant) -> void:
	person.has_basket = _take_container(person, Tool.Kind.CESTO)
	person.has_waterskin = _take_container(person, Tool.Kind.ODRE)
	# Se sale de casa con el odre lleno; sin odre, con lo que se lleva bebido.
	person.water_left = SettlementSim.SED_HORAS_CON_ODRE if person.has_waterskin \
		else SettlementSim.SED_HORAS_SIN_ODRE
	_sync_waterskins()


## Si queda una pieza de este tipo libre para esta persona.
func _take_container(person: Inhabitant, kind: Tool.Kind) -> bool:
	var made := sim.toolkit.count(kind)
	if made <= 0:
		return false
	var taken := 0
	for other: Inhabitant in sim.people:
		if other == person:
			continue
		var carries := other.has_basket if kind == Tool.Kind.CESTO \
			else other.has_waterskin
		if carries:
			taken += 1
	return taken < made


## El agua del dia: se bebe donde la hay y se gasta donde no.
##
## Es la regla que faltaba para que una banda no pueda plantarse una jornada
## entera en un canchal seco. Beber es gratis y no cuesta tiempo mientras se
## este JUNTO al agua -o en el abrigo, que se funda al lado de ella-; lo que
## cuesta es el viaje cuando se acaba a media tarde en mitad del monte.
func _drink_and_thirst(person: Inhabitant, hours: float) -> void:
	if sim.tajo._water_beside(person.position) or sim._at_shelter(person):
		person.water_left = SettlementSim.SED_HORAS_CON_ODRE if person.has_waterskin \
			else SettlementSim.SED_HORAS_SIN_ODRE
		return
	# Durmiendo no se bebe, pero tampoco se suda: la noche no cuenta.
	if person.state == Inhabitant.State.DURMIENDO:
		return
	person.water_left = maxf(person.water_left - hours, 0.0)
	if person.water_left > 0.0:
		return
	# Sin agua se deja el sim.tajo. No se sigue trabajando sediento, que es
	# exactamente lo que se venia haciendo.
	if person.state != Inhabitant.State.TRABAJANDO \
			and person.state != Inhabitant.State.BUSCANDO:
		return
	# Al charco mas cercano si lo hay, y si no, al abrigo, que se funda junto
	# al agua. `_shore_near` solo mira setenta metros y devuelve el MISMO punto
	# cuando no encuentra nada: tomando eso por un destino, la persona se
	# quedaba plantada trabajando seca, que es justo lo que se venia a impedir.
	var water := sim.tajo._shore_near(person.position)
	if not sim.tajo._water_beside(water):
		water = sim.home_position
	sim.marcha._send_to(person, water)
	person.state = Inhabitant.State.YENDO
	person.log_deed(person.current_task(), "a por agua", false)


## Descarga lo que trae en el almacen.
func _deliver(person: Inhabitant) -> void:
	# Volver al abrigo cierra la salida. Sin esto, una salida que se
	# interrumpe -porque se acaba la comida, porque se le cambia el oficio, o
	# porque no habia por donde llegar- se queda abierta para siempre y sigue
	# sumando kilometros de otros dias.
	if not person.journey.is_empty():
		# El sitio se nombra por LO MAS LEJOS que llego, no por su destino: al
		# volver, el destino ya es el propio abrigo, y salia «en del abrigo, a
		# 0 m», que no es una frase.
		var reached := float(person.journey["farthest"])
		var where := "el entorno del abrigo" if reached < sim.arrive_radius * 3.0 			else sim.parajes.place_name(
				person.journey["far_point"] as Vector3, sim.home_position)
		person.end_journey(sim.day, where, sim._brought_text(person))

	var rejected := 0.0
	for kind: int in person.load.keys():
		var units: float = person.load[kind]
		if units <= 0.0:
			continue
		sim.store.add(kind as Materia.Kind, units)
		# Lo que se llevó de casa y vuelve sin gastar NO es producción: es la
		# misma comida y la misma piel dando un paseo. Ver `carried_out`.
		var gathered := units - person.brought_from_store(kind as Materia.Kind)
		sim.taller.note_production(kind as Materia.Kind, maxf(gathered, 0.0))
		rejected += sim.store.overflow
	person.load.clear()
	person.carried_out.clear()
	person.carrying = 0.0
	# Y el cesto y el odre vuelven al abrigo con quien los llevaba. Se cogen
	# AL SALIR -ver `_hand_out_containers`-, asi que quedarselos puestos en
	# casa es quitarselos a quien sale manana: con dos cestos hechos y quince
	# personas, los dos primeros que los cogieron no los soltaban nunca.
	person.has_basket = false
	person.has_waterskin = false
	# El odre vuelve al abrigo, y vuelve LLENO: se rellena en el rio de la
	# puerta. Ver `_sync_waterskins`.
	_sync_waterskins()
	if rejected > 0.01:
		sim.storage_full.emit(rejected)

	# Y se cuenta lo que se trae. Al llegar y no antes: una cacería se cuenta
	# en el abrigo, con la banda delante, y ésa es la mitad de lo que la hace
	# un relato en vez de una entrada de almacén.
	if person.pending_tale != null:
		var tale := person.pending_tale
		person.pending_tale = null
		sim.tell_tale(tale)


## Un rato de comida: se come del almacen y baja el hambre.
##
## Sale del bloque de estados para poder llamarla TAMBIEN de noche. La cena es
## a las nueve -ver [HORA_CENA]- y a esa hora el reparto noche/dia ya ha
## mandado a todo el mundo a dormir, asi que el estado COMIENDO no llegaba a
## procesarse nunca y la cena era una comida que empezaba y no terminaba.
func _eat_meal(person: Inhabitant, hours: float) -> void:
	# La barra de hambre ES la jornada: de 0 a 100 va lo que come una persona en
	# un dia. Asi una RACION -media jornada, ver [Materia.KCAL_RACION]- quita
	# exactamente cincuenta, y las dos comidas del dia suman cien.
	#
	# Antes eran dos numeros sueltos —hambre por hora y hambre por racion— y no
	# cuadraban: la banda consumia un 50% mas de lo que decia `daily_food()`.
	var bite := _eat_from_store(hours * 3.0)
	# Cocinar no anade comida: hace que la que hay cunda mas. La carne y la
	# raiz al fuego se digieren mejor y dan mas calorias aprovechables por la
	# misma racion -es la tesis de Wrangham sobre el fuego en la dieta humana-,
	# asi que el sim.hogar no toca el almacen, toca cuanto quita el hambre.
	# Encendido, no construido: un sim.hogar apagado es un corro de piedras, y
	# sobre un corro de piedras no se cocina.
	var cooked := 1.15 if sim.hearth_lit else 1.0
	person.hunger = maxf(person.hunger - bite * cooked * SettlementSim.HAMBRE_POR_RACION, 0.0)
	if person.hunger < SettlementSim.COMIDA_SUFICIENTE or bite <= 0.0:
		person.state = Inhabitant.State.OCIOSO


## Come del almacen, empezando por lo que antes se echa a perder.
##
## El orden importa: comerse primero la carne fresca y dejar el fruto seco para
## el final es lo que de verdad hacia una banda, y ademas es lo optimo.
func _eat_from_store(rations: float) -> float:
	# TODO lo que alimenta, y no una lista escrita a mano.
	#
	# Era una lista de seis -pescado, marisco, carne, grasa, carne seca y
	# fruto seco- mientras `Storehouse.food_rations` contaba las doce cosas
	# que alimentan. O sea que la raiz, la baya, la bellota, la seta, el
	# huevo, la miel y el caracol entraban en la cuenta de la sim.despensa y no
	# se comian NUNCA. Medido en el sitio 56: dia 23, cuarenta y siete
	# raciones en el abrigo, los quince con el hambre a 100 y la cifra
	# clavada quince dias seguidos. En primavera lo que se recoge es raiz, y
	# la banda se moria de hambre al lado de ella.
	#
	# El orden es por lo que antes se pudre: se come primero lo que no
	# aguanta, que es lo que haria cualquiera y ademas evita tirarlo.
	var order: Array[int] = []
	for kind: int in Materia.Kind.values():
		if Materia.is_food(kind as Materia.Kind):
			order.append(kind)
	order.sort_custom(func(a: int, b: int) -> bool:
		return Materia.shelf_life(a as Materia.Kind) 			< Materia.shelf_life(b as Materia.Kind))

	var eaten := 0.0
	for kind: int in order:
		if eaten >= rations:
			break
		var k := kind as Materia.Kind
		var needed := (rations - eaten) / maxf(Materia.nutrition(k), 0.001)
		var taken := sim.store.take(k, needed)
		eaten += taken * Materia.nutrition(k)
		# Lo que se come deja lo que no se come, y eso NO desaparece: va al
		# monton. Ver [Desechos]; es de donde sale el conchero.
		sim.desechos.tirar(k, taken * Materia.nutrition(k))
	return eaten


## Redacta el parte del día y lo anota. Se llama justo después de `store.age`,
## que es quien acaba de tirar lo que aquí se cuenta.
func _report_spoilage() -> void:
	sim.spoiled_today = sim.store.spoiled.duplicate()
	sim.spoiled_rations_today = 0.0
	if sim.spoiled_today.is_empty():
		return

	var parts: Array[String] = []
	for kind: int in sim.spoiled_today:
		var k := kind as Materia.Kind
		var units := float(sim.spoiled_today[kind])
		if units < 0.05:
			continue
		if Materia.is_food(k):
			sim.spoiled_rations_today += units * Materia.nutrition(k)
		parts.append("%.1f de %s" % [units, Materia.material_name(k).to_lower()])
	if parts.is_empty():
		return

	# Y por qué. Un parte que sólo dice cuánto se ha perdido deja al jugador
	# sin nada que hacer con el dato; lo que lo convierte en una decisión es
	# saber qué le falta para que no vuelva a pasar.
	var why := ""
	if sim.spoiled_rations_today > 0.0:
		if not sim.camp_built.get(CampProjects.Kind.SECADERO, false):
			why = " Sin secadero no hay forma de guardarlo."
		elif not sim.hearth_lit:
			why = " El secadero está frío: sin brasas no se ahúma."
		elif sim.hogar._hearth_hands().is_empty():
			why = " El secadero está cargado y no hay nadie al sim.hogar."

	var weight := 1 if sim.spoiled_rations_today >= SettlementSim.MERMA_QUE_DUELE else 0
	sim._note(Chronicle.Kind.PENURIA,
		"Se echó a perder %s.%s" % [sim._join_and(parts), why], weight)


func hungry_count(threshold: float = 60.0) -> int:
	var total := 0
	for person: Inhabitant in sim.people:
		if person.hunger >= threshold:
			total += 1
	return total


## Si la sim.despensa ha llegado al tope que puso el jugador.
func food_is_capped() -> bool:
	if sim.food_cap <= 0.0:
		sim._larder_full = false
		return false
	var have := sim.store.food_rations()
	if sim._larder_full:
		if have < sim.food_cap * SettlementSim.REANUDAR_COMIDA:
			sim._larder_full = false
	elif have >= sim.food_cap:
		sim._larder_full = true
	return sim._larder_full


## Si este oficio existe para traer comida.
##
## La manufactura gasta materia prima y el sim.hogar no sale del campamento: el
## tope no les toca. La exploracion tampoco, que no trae comida sino mapa.
func _feeds_the_band(job: Profession.Job) -> bool:
	# SOLO LA RECOLECCION, y es una correccion importante.
	#
	# El tope existe para cortar el circulo vicioso de las salidas a por
	# comida -llegar al maximo, comer, bajar, volver a salir- y ese circulo es
	# de la recoleccion: lo que trae aguanta un año en la cueva y se apila.
	#
	# Cortar tambien la caza y la ribera hacia algo que no queria nadie: con la
	# despensa llena de avellana los cazadores se quedaban en el abrigo, y como
	# la recoleccion la llena antes que nada, la caza no llegaba a jugar NUNCA.
	# Medido: 209 salidas de caza, 193 vacias y CERO carne entregada.
	#
	# Y ademas no hace falta cortarlas: la carne fresca aguanta cuatro dias y
	# el pescado tres, asi que se limitan solas. Es justamente por eso por lo
	# que secar y ahumar importa, que es la mecanica de la epoca.
	return job == Profession.Job.RECOLECCION


## Cuantos dias de comida da el tope puesto, para poder decirselo al jugador
## en dias y no en raciones -que no significan nada solas-.
func food_cap_days() -> float:
	if sim.food_cap <= 0.0:
		return 0.0
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	return sim.food_cap / maxf(mouths, 0.001)


