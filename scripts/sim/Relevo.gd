class_name Relevo
extends RefCounted
## Quién envejece, quién enferma, quién muere de vejez y quién nace.
##
## Sale de `SettlementSim` por lo mismo que [Percances] o [Hogar]: es un tema
## cerrado. Nace de docs/specs/QUE_SE_PUEDA_PERDER.md — hambre con
## consecuencia real, invierno que cuesta, nacimientos y muertes por vejez.
##
## La muerte por percance grave, en cambio, se queda en [Mishap]/[Percances]:
## es la misma tirada de siempre, no un motivo nuevo que viva aquí.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## A partir de qué edad se deja de ser `Age.NINO`. Coincide con el mínimo con
## el que `Inhabitant.create_band` siembra a los adultos de partida.
const CHILD_TO_ADULT_AGE := 16

## A partir de qué edad se pasa a `Age.ANCIANO`. Coincide con el mínimo con
## el que `create_band` siembra a los ancianos de partida.
const ADULT_TO_ELDER_AGE := 46


## Cumple años toda la banda. Se llama UNA vez por año de calendario, desde
## `SettlementSim._advance_local_season` en el giro a primavera -es el único
## sitio que ya sabe que ha pasado un año entero.
##
## Sólo cambia `age_years` y, si toca, `age_group`. NO resiembra `stats` ni
## `skill`: eso tendría sentido al crear la banda -donde nadie ha practicado
## nada todavía-, pero borraría de un plumazo la pericia y el físico que
## alguien ya se ha ganado jugando. `create_band` resiembra porque parte de
## cero; esto no.
func cumplir_anyos() -> void:
	for person: Inhabitant in sim.people:
		person.age_years += 1
		if person.age_group == Inhabitant.Age.NINO \
				and person.age_years >= CHILD_TO_ADULT_AGE:
			person.age_group = Inhabitant.Age.ADULTO
		elif person.age_group == Inhabitant.Age.ADULTO \
				and person.age_years >= ADULT_TO_ELDER_AGE:
			person.age_group = Inhabitant.Age.ANCIANO


## --- La vejez mata, sin que el jugador tenga nada que decidir --------------
##
## A diferencia de hambre, frío y percance, esto no depende de ninguna
## decisión: es un tercer motivo de muerte que corre solo. Se tira una vez
## por persona y por año, en el giro a primavera -junto a `cumplir_anyos`-,
## no jornada a jornada: envejecer es un suceso del calendario, no del reloj.
## Sin calibrar, como el resto.

## Edad a partir de la que empieza a haber riesgo de morir de vieja. Por
## debajo, cero: cumplir años de anciano no es, por sí solo, mortal.
const OLD_AGE_RISK_START := 60

## Edad a la que el riesgo satura cerca de su techo. Nadie llega a un 100%
## exacto -algunos ancianos viven mucho-, pero por encima de esto ya casi
## nadie sigue.
const OLD_AGE_RISK_MAX_AGE := 90

## Riesgo de morir este año, en los dos extremos de la curva.
const OLD_AGE_RISK_AT_START := 0.02
const OLD_AGE_RISK_AT_MAX := 0.35


## Probabilidad de morir de vieja ESTE año, dada la edad. Sube en línea recta
## entre los dos puntos de arriba -no hace falta más finura que ésa para algo
## que ni siquiera está calibrado todavía.
func _old_age_death_chance(age_years: int) -> float:
	if age_years < OLD_AGE_RISK_START:
		return 0.0
	var span := float(OLD_AGE_RISK_MAX_AGE - OLD_AGE_RISK_START)
	var t := clampf(float(age_years - OLD_AGE_RISK_START) / span, 0.0, 1.0)
	return lerpf(OLD_AGE_RISK_AT_START, OLD_AGE_RISK_AT_MAX, t)


## Se llama UNA vez por año, junto a `cumplir_anyos`.
func revisar_vejez() -> void:
	for person: Inhabitant in sim.people.duplicate():
		var riesgo := _old_age_death_chance(person.age_years)
		if riesgo <= 0.0:
			continue
		if sim._rng.randf() < riesgo:
			sim._person_dies(person,
				"%s murió de vieja, a los %d años."
					% [person.given_name, person.age_years])


## --- El frío mata, aparte del hambre ---------------------------------------
##
## `Inhabitant.cold` sube en `SettlementSim._tick_person` cuando se duerme en
## el abrigo sin hogar en invierno (ver [SettlementSim.HEARTH_COLD_RISE]).
## Esto es lo que pasa cuando se queda ahí demasiadas jornadas seguidas: se
## enferma, y si no se corta a tiempo, se muere. Todos los números son de
## BALANCEO y están sin calibrar -pendientes de playtest, igual que el resto
## de esta spec.

## A partir de qué `cold` se empieza a enfermar.
const COLD_SICK_THRESHOLD := 55.0

## Por debajo de qué `cold` se empieza a curar.
const COLD_RECOVER_THRESHOLD := 25.0

## Días enferma de frío que hacen falta para morir, por edad. Los niños y
## los ancianos aguantan menos: "empezar por los viejos y los críos, que es
## como fue" -ESTADO_DE_LA_SLICE.md §5.
const COLD_DEATH_DAYS_CHILD := 6
const COLD_DEATH_DAYS_ELDER := 6
const COLD_DEATH_DAYS_ADULT := 10


func _cold_death_days(person: Inhabitant) -> int:
	match person.age_group:
		Inhabitant.Age.NINO: return COLD_DEATH_DAYS_CHILD
		Inhabitant.Age.ANCIANO: return COLD_DEATH_DAYS_ELDER
		_: return COLD_DEATH_DAYS_ADULT


## Revisa el frío sostenido de cada persona. Se llama una vez al cerrar la
## jornada, desde `SettlementSim._end_of_day`.
##
## Se recorre una COPIA de `sim.people`: `_person_dies` quita a la persona de
## la lista de verdad a mitad de recorrido si le toca morir, y recorrer el
## array mientras se acorta salta a quien viene detrás.
func revisar_frio() -> void:
	for person: Inhabitant in sim.people.duplicate():
		if person.cold >= COLD_SICK_THRESHOLD:
			var estaba_sana := person.cold_sick_days == 0
			person.cold_sick_days += 1
			if estaba_sana:
				sim._note(Chronicle.Kind.PENURIA,
					"%s enferma de frío: el abrigo lleva demasiadas noches sin fuego."
						% person.given_name, 1)
		elif person.cold <= COLD_RECOVER_THRESHOLD:
			person.cold_sick_days = maxi(person.cold_sick_days - 1, 0)

		if person.cold_sick_days >= _cold_death_days(person):
			sim._person_dies(person,
				"%s murió de frío: demasiadas noches en un abrigo sin fuego."
					% person.given_name)


## --- El hambre mata, aparte del frío ----------------------------------------
##
## Mismo patrón que el frío, sobre `Inhabitant.hunger` -que ya sube sola cada
## hora, ver `SettlementSim.HAMBRE_POR_HORA`- en vez de sobre `cold`. Hoy el
## hambre baja el rendimiento y ahí se para; esto es el escalón siguiente:
## bajar rendimiento → enfermar → morir. Sin calibrar, como el resto.

## A partir de qué `hunger` se empieza a enfermar.
const HUNGER_SICK_THRESHOLD := 70.0

## Por debajo de qué `hunger` se empieza a curar.
const HUNGER_RECOVER_THRESHOLD := 30.0

## Días enferma de hambre que hacen falta para morir, por edad. Misma razón
## que en el frío: "empezar por los viejos y los críos".
const HUNGER_DEATH_DAYS_CHILD := 6
const HUNGER_DEATH_DAYS_ELDER := 6
const HUNGER_DEATH_DAYS_ADULT := 10


func _hunger_death_days(person: Inhabitant) -> int:
	match person.age_group:
		Inhabitant.Age.NINO: return HUNGER_DEATH_DAYS_CHILD
		Inhabitant.Age.ANCIANO: return HUNGER_DEATH_DAYS_ELDER
		_: return HUNGER_DEATH_DAYS_ADULT


## Revisa el hambre sostenida de cada persona. Se llama una vez al cerrar la
## jornada, desde `SettlementSim._end_of_day`, junto a `revisar_frio`.
func revisar_hambre() -> void:
	for person: Inhabitant in sim.people.duplicate():
		if person.hunger >= HUNGER_SICK_THRESHOLD:
			var estaba_sana := person.hunger_sick_days == 0
			person.hunger_sick_days += 1
			if estaba_sana:
				sim._note(Chronicle.Kind.PENURIA,
					"%s enferma de hambre: lleva demasiado tiempo sin comer lo suyo."
						% person.given_name, 1)
		elif person.hunger <= HUNGER_RECOVER_THRESHOLD:
			person.hunger_sick_days = maxi(person.hunger_sick_days - 1, 0)

		if person.hunger_sick_days >= _hunger_death_days(person):
			sim._person_dies(person,
				"%s murió de hambre: demasiado tiempo sin comer lo suyo."
					% person.given_name)


## --- Nacimientos: un parto por año bueno ------------------------------------
##
## "Año bueno" son las DOS condiciones a la vez -docs/specs/QUE_SE_PUEDA_PERDER.md,
## tarea 9-: la despensa cierra con margen Y no ha habido una racha larga de
## hambre severa en todo el año. Sin calibrar, como el resto.

## Días de reserva de comida que hacen falta al cerrar el año para que
## cuente como "año bueno".
const ANYO_BUENO_RESERVA_DIAS := 20.0

## Racha más larga de hambre severa que un año bueno todavía puede permitirse.
## Cero sería exigir un año perfecto; un margen pequeño es más realista.
const ANYO_BUENO_RACHA_MAXIMA := 3

## Edad máxima para que una mujer cuente como en edad fértil. Coincide con el
## límite que ya usa `Inhabitant.create_band` para decidir quién puede estar
## criando.
const EDAD_FERTIL_MAXIMA := 40


## Si el año que se acaba de cerrar fue "bueno". NO resetea nada: sólo mira.
func _fue_buen_anyo() -> bool:
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	var reserva_dias := sim.store.days_of_food(mouths)
	return reserva_dias >= ANYO_BUENO_RESERVA_DIAS \
		and sim.hambre_severa_peor_racha_del_anyo <= ANYO_BUENO_RACHA_MAXIMA


func _hay_madre() -> bool:
	for person: Inhabitant in sim.people:
		if person.sex == Inhabitant.Sex.MUJER \
				and person.age_group == Inhabitant.Age.ADULTO \
				and person.age_years <= EDAD_FERTIL_MAXIMA:
			return true
	return false


## Evalúa el año que se cierra y, si toca, hace nacer a alguien. Se llama
## UNA vez por año, desde `SettlementSim._advance_local_season` en el giro a
## primavera, justo después de `cumplir_anyos`.
##
## Resetea `hambre_severa_peor_racha_del_anyo` SIEMPRE, haya habido parto o
## no: la racha es del año que se cierra, y el que empieza arranca limpio.
## Un id que no tenga nadie vivo.
##
## No se lleva la cuenta aparte porque no hace falta y porque casi ningún sitio
## que crea `sim.people` a mano para una prueba se acordaría de mantenerla:
## basta con no repetir ninguno de los vivos. Estaba escrito dentro de
## [evaluar_nacimiento]; ahora lo pregunta también el trueque que trae gente, y
## una regla que se pregunta desde dos sitios va en uno.
func id_libre() -> int:
	var nuevo_id := 0
	for person: Inhabitant in sim.people:
		nuevo_id = maxi(nuevo_id, person.id + 1)
	return nuevo_id


func evaluar_nacimiento() -> void:
	var buen_anyo := _fue_buen_anyo()
	sim.hambre_severa_peor_racha_del_anyo = 0

	if not buen_anyo or not _hay_madre():
		return

	var nuevo := Inhabitant.create(id_libre(), sim.home_position, sim._rng)
	nuevo.age_group = Inhabitant.Age.NINO
	nuevo.age_years = 0
	# `create` sembró destreza y físico suponiendo un adulto. Se vuelve a
	# sembrar ahora que ya se sabe que es un recién nacido -mismo motivo que
	# `create_band` cuando corrige la edad de partida.
	nuevo.seed_skills(sim._rng)
	nuevo.seed_stats(sim._rng)
	nuevo.seed_traits(sim._rng)
	nuevo.position = sim.home_position
	sim.people.append(nuevo)

	sim._note(Chronicle.Kind.GENTE,
		"Nace %s. El año fue bueno." % nuevo.given_name, 2)
