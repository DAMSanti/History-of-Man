class_name Caceria
extends RefCounted
## La caceria vista: acecho, persecucion, lance y despiece.
##
## Sale de `SettlementSim` porque aquel fichero pasaba de nueve mil lineas y
## esto son seiscientas ochenta y cinco de un tema que no se cruza con ningun
## otro: nadie que venga a mirar como se reparte el trabajo o como se apaga el
## hogar necesita leer como se tira una azagaya.
##
## Guarda una referencia al simulador en vez de heredar de el: la caceria
## necesita el terreno, la fauna y el almacen, pero no ES un asentamiento.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement

# --- La cacería, vista -----------------------------------------------------
#
# «Toda caza que no sea sorpresiva quiero que se reproduzca en el juego, es
# decir quiero ver a los cazadores acechar, perseguir, cazar a su presa.»
#
# Lo que había era una tabla: el cazador se plantaba en su paraje, corrían las
# horas y aparecía carne en el zurrón. Los ciervos que [WildlifeHerds] pinta
# cruzando el valle no tenían nada que ver con eso —eran decorado— y la caza
# era aritmética. Aquí la pieza es UN ANIMAL DE LOS QUE HAY, con su sitio y su
# rumbo, y lo que llega al almacén sale de esa pieza.
#
# La trampa se queda como estaba, y no es un olvido: una trampa ES lo
# sorpresivo. Cae sola mientras la banda duerme y no hay acecho que mirar. Ver
# `sim.trampas._trapline`.
#
# **Y el reparto de tiempo no se ha inventado de cero.** Lo que gobierna
# cuántas piezas cobra una jornada sigue siendo [Hunting.pieces_per_day], que
# está medido; lo que hace la cacería visible es GASTAR esas horas donde se
# ven —rastreando, acechando, corriendo— en vez de hacerlas desaparecer en una
# multiplicación. Ver `_tracking_hours`.

## La fauna dibujada. La pone [DemoMain]; sin ella la caza se resuelve como
## antes, con la tabla de [Hunting], que es lo que hace que las pruebas
## headless y el rato anterior a montar el mundo sigan funcionando.
var wildlife: WildlifeHerds = null

## Las cacerías en marcha, y las piezas abiertas que quedan en el monte
## esperando a que alguien vuelva a por lo que no cupo.
var hunts: Array[Hunt] = []

## Cuántas cacerías se cierran hoy con pieza. Para la crónica y el relato.
var kills_today: Array[Hunt] = []

## Por qué se acaba cada cacería, contado. Es de mirar, no de jugar.
##
## Existe porque afinar la caza a ojo es adivinar: una cacería que se pierde y
## una que se cobra se ven igual desde fuera —no vuelve nadie con nada— y las
## causas son cuatro y piden arreglos distintos. Sin esta cuenta, la primera
## versión de la cacería estuvo dos sondeos dando cero piezas sin que se supiera
## si era que no llegaban a tiro, que fallaban el lance o que la pieza se les
## iba. Ver `CaceriaProbe`.
var hunt_endings: Dictionary = {}

## Lances fallados. NO es un final de caceria y por eso va aparte.
##
## Estuvo contado como final y la cuenta mentia de un modo que costo caro:
## fallar un lance devuelve a la persecucion mientras quede fuelle, asi que una
## sola caceria podia apuntar tres o cuatro «lance fallado» y seguir viva. Con
## eso, en una medida de doce jornadas salian «cuarenta y una caceria, treinta
## y ocho falladas», y lo que habia de verdad eran unas pocas piezas seguidas a
## conciencia, y se calibro sobre esa cifra.
var lances_fallados: int = 0

## Jornadas de la caceria mas larga que se haya abierto en la partida.
##
## Se guarda aqui y no en la lista de caceria porque la lista solo tiene las
## VIVAS: preguntandole a ella cuanto duro la mas larga sale cero en cuanto se
## cierran todas, que es lo que pasaba al medir.
var jornadas_mas_larga: int = 0


func _note_ending(why: String) -> void:
	hunt_endings[why] = int(hunt_endings.get(why, 0)) + 1

## A qué distancia se suma alguien a una cacería que ya está en marcha, en
## metros. Una cuadrilla de caza mayor no levanta cuatro ciervos: rodea uno.
const SE_SUMA_A_LA_BATIDA := 220.0

## Cuanto se espera antes de volver a mirar si hay pieza cerca, en horas.
##
## Un cuarto de hora de juego. Es el rato que se tarda en cambiar de ladera, y
## es lo que separa batir el monte de barrerlo con la vista sesenta veces por
## segundo.
const MIRAR_OTRA_VEZ := 0.25

## Fraccion de jornada a la que se cobra el riesgo de un lance.
##
## Un tercio: es lo que dura tener la pieza delante y decidir, contado sobre la
## jornada entera. Ver `Percances._check_hunting_risk`, que ya escala por eso mismo.
const LANCE_RIESGO := 0.33

## Lo despacio que se anda acechando, en tanto por uno del paso normal.
##
## Acechar no es ir hacia el animal, es ir hacia el animal sin que se entere, y
## eso se hace parando, agachándose y esperando. Es además lo que hace que el
## acecho SE VEA distinto de la marcha en pantalla, que es medio encargo.
##
## Estuvo en un tercio y era demasiado poco, por una razón que no es de gusto
## sino de aritmética: la pieza NO ESTÁ QUIETA. Un ciervo pasta a 6,5 unidades
## por segundo, y un cazador a un tercio de su paso se le acerca a menos de una
## unidad por segundo neta: los últimos noventa metros no se cierran nunca y el
## acecho se acaba por reloj. Medido con `CaceriaProbe`: cero piezas y la banda
## a cero raciones desde la jornada treinta y dos.
##
## Con 0,55 el cazador gana terreno a algo más del doble de lo que la pieza
## deriva, que es lo que hace que acercarse sea posible, y sigue viéndose medio
## paso más lento que quien vuelve a casa.
const PASO_DE_ACECHO := 0.55


## La cacería en la que anda esta persona, o null.
func hunt_of(person: Inhabitant) -> Hunt:
	for hunt: Hunt in hunts:
		if hunt.crew.has(person):
			return hunt
	return null


## Si anda tras una pieza ahora mismo.
func _is_hunting(person: Inhabitant) -> bool:
	return hunt_of(person) != null


## Lo que multiplica su paso, que sólo es distinto de uno acechando.
##
## Se pregunta por la cacería y no se fía de `person.hunt_pace` a secas: así el
## paso lento no se queda pegado a nadie. Quien terminó una cacería ayer anda
## hoy como todo el mundo aunque nadie se acordara de devolverle el número.
func _hunt_pace(person: Inhabitant) -> float:
	if not _is_hunting(person):
		return 1.0
	return clampf(person.hunt_pace, 0.1, 1.0)


## Las especies que ESTA persona puede cobrar aquí y hoy: de su porte para
## abajo y con lo que hay en el abrigo. Es la misma puerta que
## [Hunting.yields_at], no una parecida.
func _huntable_species(speciality: Profession.Speciality) -> Array:
	var porte := Hunting.porte_of(speciality)
	var out: Array = []
	for species: String in Fauna.SPECIES:
		if Fauna.porte_of(species) > porte:
			continue
		if not Fauna.huntable_with(species, sim.toolkit):
			continue
		out.append(species)
	return out


## Levanta una cacería, o mete a esta persona en una que ya esté en marcha.
##
## Sumarse va antes que levantar otra, y es lo que hace que la caza mayor se
## vea como lo que es: cuatro personas rodeando un ciervo, no cuatro personas
## acechando cuatro ciervos cada una por su lado.
func _open_hunt(person: Inhabitant) -> Hunt:
	var speciality := person.current_speciality as Profession.Speciality
	if speciality == Profession.Speciality.CAZA_MAYOR:
		for hunt: Hunt in hunts:
			if hunt.phase == Hunt.Phase.DESPIECE \
					or hunt.phase == Hunt.Phase.ACARREO:
				continue
			if hunt.crew.is_empty() \
					or hunt.crew[0].current_speciality != speciality:
				continue
			if hunt.where().distance_to(person.position) < SE_SUMA_A_LA_BATIDA:
				hunt.crew.append(person)
				return hunt

	var species := _huntable_species(speciality)
	if species.is_empty():
		return null
	var animal := _pick_quarry(person, species)
	if animal.is_empty():
		return null

	var hunt := Hunt.create(String(animal["species"]), animal, person)
	hunt.weapon = Fauna.weapon_at_hand(hunt.species, sim.toolkit)
	hunt.counted_day = sim.day
	hunts.append(hunt)
	jornadas_mas_larga = maxi(jornadas_mas_larga, 1)
	return hunt


## A cuál de las que hay se le va.
##
## NO a la más cercana, que es lo que hacía y salió mal: la pieza menuda es la
## más numerosa del valle, así que siempre hay un pato más cerca que un ciervo
## y una cuadrilla de caza mayor se pasaba la partida acechando patos. Medido
## con `CaceriaProbe`: once piezas cobradas en ciento veinte jornadas y las once
## ánades, con la banda a cero raciones desde la jornada treinta y dos.
##
## Se puntúa lo que vale la pieza contra lo que cuesta llegar a ella. Un ciervo
## a doscientos metros gana a un conejo a veinte, y un uro gana a los dos; a
## igualdad de porte, el que esté más cerca. Es la misma cuenta que ya hace
## `sim._quarry_bonus` para elegir coto, aplicada al animal concreto.
func _pick_quarry(person: Inhabitant, species: Array) -> Dictionary:
	var candidates := wildlife.quarries_near(person.position,
		Hunt.BUSCA_PIEZA_M, species)
	var best: Dictionary = {}
	var best_score := 0.0
	for animal: Dictionary in candidates:
		var one := String(animal["species"])
		# Lo que está en el agua no se caza a pie. El ánade se caza con red en
		# el bebedero -ver [Trap.Kind.RED_AVES]-, no metiéndose en el río
		# detrás de él.
		if not _dry_footing(animal["position"]):
			continue
		var distance: float = maxf(
			person.position.distance_to(animal["position"]), 1.0)
		# Las raciones mandan y la distancia sólo desempata: el exponente la
		# deja pesar poco a propósito, porque andar doscientos metros de más
		# por un ciervo sale a cuenta y andarlos por un conejo no.
		var score := Fauna.rations_of(one) / pow(distance, 0.35)
		if score > best_score:
			best_score = score
			best = animal
	return best


## Horas de rastreo que cuesta dar con la siguiente pieza.
##
## Aquí es donde la cacería visible se ata a lo que ya estaba medido. Si una
## jornada perfecta de esta rama cobra `pieces` piezas, cada pieza cuesta
## `SettlementSim.HORAS_UTILES / pieces` horas de jornada perfecta; lo que la persona tenga
## de menos —destreza, temporada floja, mal tiempo, ir sin cuadrilla— alarga
## ese rastreo en la misma proporción en que antes reducía el rendimiento.
##
## Así la cacería no es un sistema nuevo con números nuevos: es el mismo número
## de siempre, gastado donde se ve.
##
## **Y va ANTES del acecho, no dentro.** El primer montaje lo metía dentro:
## hasta cumplir estas horas no se podía llegar a tiro por muy encima que se
## estuviera de la pieza. Medido con `CaceriaProbe` en el sitio 56, ciento
## veinte jornadas y cuatro personas a la caza mayor:
##
##   acecho      441.119 ticks
##   lance           185
##   cobradas          3 piezas en cuatro meses
##
## O sea que la cuadrilla se pasaba la partida entera acechando sin llegar
## nunca, y la banda pasó de 159 raciones guardadas a CERO. Un rastreo de siete
## horas dentro de una jornada de diez no deja acecho, deja un cronómetro.
##
## Puesto delante es lo que de verdad es: el rato que se tarda en cortar un
## rastro. Mientras dura se bate el monte —que se ve, y es lo que hace un
## cazador la mayor parte del día— y cuando se corta el rastro empieza el
## acecho, que ya sí es corto.
## Lo que se acorta el rastreo respecto de lo que sale de la cadena de factores.
##
## Es la HERMANA de [Tajo.HARVEST_SCALE], y existe por lo mismo. La
## cadena de `_tracking_hours` multiplica seis cosas -pericia, saber del sitio,
## estacion, tiempo, cuadrilla y filo- y todas son menores que uno: medida con
## `scripts/tests/JornadaCazadorProbe.gd`, la cadena entera vale 0,043. La
## recoleccion sufre exactamente el mismo desplome -su docstring dice «el
## producto es un 4 % de lo nominal»- y lo compensa multiplicando por 26. El
## rastreo no compensaba nada: DIVIDIA por ese 0,043 y se comia el desplome
## entero.
##
## Lo que salia, medido, doce jornadas y siete cazadores de caza mayor:
##
##   el rastreo pide       81,5 h
##   al dia se trabaja      2,1 h
##   -> una pieza cada     38,9 jornadas de cazador
##
## Treinta y nueve jornadas para LEVANTAR una pieza. Por eso una medida de doce
## dias daba dos o cuatro caceria y el resultado lo decidia si pasaba un uro:
## entre dos pasadas de la misma escalera, el mismo escalon dio 0,00 y 4,37
## raciones por cazador y dia.
##
## **Y LAS TRES CIFRAS DE ARRIBA SON DE DOCE DIAS, QUE ES POCO.** Repetida la
## misma medida a cuarenta jornadas -240 jornadas de cazador, diecisiete
## caceria levantadas- sale otra cosa:
##
##   el rastreo pide       21,0 h     (contra 81,5 a los doce dias)
##   al dia se trabaja      2,6 h
##   -> una pieza cada      8,2 jornadas de cazador
##
## La diferencia es LA PERICIA, que esta dentro de la cadena y es lo unico de
## ella que crece con la partida -es la misma pega que ya tiene apuntada
## [Tajo.PERICIA_DE_REFERENCIA] para la recoleccion-. O sea que este
## numero no puede estar bien en los dos extremos: con la banda torpe se queda
## corto y con la banda hecha se pasa.
##
## **De donde sale el 1,85, que es lo unico elegido aqui.** De que un cazador
## coma 1,69 raciones al dia y tenga que traer algo mas que eso. A cuarenta
## jornadas salen cinco piezas en 240 jornadas de cazador, o sea del orden de
## 1,5 raciones por cazador y dia: JUSTO POR DEBAJO de lo que come. Con lo cual
## la caza mayor, ahora mismo, es un complemento y no un sustento.
##
## Pendiente de playtest, y aqui hay dos decisiones y no una: si la caza mayor
## DEBE dar de comer a quien la hace -entonces este numero sube- o si es un
## golpe de suerte que se busca aparte de la recoleccion -entonces se queda-.
## Eso no lo decide una medida.
##
## Y ojo con el otro mando: a cuarenta dias se pierden DOCE de diecisiete
## caceria en el acecho -ocho de rastro frio, cuatro de vista- contra cinco
## cobradas. El cuello de botella ya no es el rastreo ni el lance, es
## [Hunt.ACECHO_HORAS].
const ESCALA_DEL_RASTREO := 16.4

## --- de donde sale el 16,4, y contra que se ha contrastado ----------------
##
## La cuenta que gobierna lo que trae un cazador al dia es esta:
##
##   raciones/dia = R x p x H / T        T = HORAS_UTILES / (piezas x cadena x ESCALA)
##
## con R las raciones de la pieza, p la parte de caceria que acaban cobradas,
## H las horas que de verdad se trabajan al dia y T las horas de rastreo. Al
## sustituir T, la R se VA: una pieza el doble de grande son la mitad de
## piezas -ahora que las piezas se deducen de las raciones, ver
## [Hunting.pieces_per_day]-. Eso es justo lo que tiene que pasar: el tamaño de
## la pieza decide lo gorda y lo rara que es cada entrada de carne, no el
## promedio. Queda:
##
##   raciones/dia = p x H x RACIONES_POR_JORNADA_PERFECTA x cadena x ESCALA / HORAS_UTILES
##
## Todo lo demas esta MEDIDO con `scripts/tests/JornadaCazadorProbe.gd`:
## p = 0,29 -cinco piezas cobradas de diecisiete caceria en cuarenta jornadas-,
## H = 2,6 h al dia, cadena = 0,040 con la banda recien salida y 0,090 a las
## cuarenta jornadas. Lo unico que se ELIGE es el objetivo, y el objetivo sale
## de abajo.
##
## **La referencia historica, que es lo que se ha pedido contrastar.** De
## memoria y por tanto aproximada -conviene comprobarla antes de apoyarse en
## ella para nada serio-, pero las ordenes de magnitud son estas:
##
##   - HADZA (Hawkes, O'Connell y Blurton Jones, 1991 y 2001): el cazador de
##     pieza grande vuelve de vacio el ~97 % de los dias. Del orden de UNA
##     pieza grande cada treinta jornadas de cazador.
##   - !KUNG / JU'HOANSI (Lee, 1979): la carne es el 30-35 % de las calorias.
##     Se sale a cazar dos o tres dias por semana, no todos.
##   - ACHE (Hill y Hurtado, 1996): bosque con mucha caza, el caso extremo por
##     arriba: ~78 % de las calorias de la caza.
##   - CORDAIN y otros (2000), doscientas veintinueve sociedades del Atlas
##     Etnografico: la mediana de energia que sale de cazar animales terrestres
##     esta en el 26-35 %.
##   - KAPLAN y otros (2000): un forrajeador adulto produce del orden de 1,5 a
##     2 veces lo que come, y los mejores cazadores 3 o 4 veces. NADIE alimenta
##     a una banda entera el solo; lo que sobra es lo que da de comer a los
##     criios y a los viejos.
##
## **Lo que se ha decidido con eso, que es lo pedido:** que al empezar un
## cazador se mantenga a si mismo -come del orden de 2 raciones al dia- y que
## segun sube la pericia llegue a dar de comer a dos o tres mas, que es el
## techo que dan los datos de arriba. Con cinco cazadores, eso es una banda de
## quince comiendo de la caza, que es lo que se pedia leido a nivel de banda y
## no de persona.
##
## Puesto el objetivo de salida en 2,0 raciones por cazador y dia, la cuenta da
## RACIONES_POR_JORNADA_PERFECTA x ESCALA = 592, y con las 36 raciones de
## jornada perfecta de la caza mayor sale 16,4.
##
## Que quede cerca de las 26 de [Tajo.HARVEST_SCALE] NO es casualidad
## y sirve de comprobacion: las dos compensan el mismo desplome -seis factores
## menores que uno multiplicados dan 0,04- y por eso tienen que salir del mismo
## orden. Si una de las dos se fuera a 2 o a 200, estaria mal.
##
## **Lo que esta cuenta NO arregla:** la pericia es el unico de los seis
## factores que crece, asi que un solo numero no puede acertar en los dos
## extremos -es la misma pega que tiene apuntada
## [Tajo.PERICIA_DE_REFERENCIA]-. Con este, la salida da 2,0 raciones
## por cazador y dia y a las cuarenta jornadas 4,5: la banda pasa de comer de
## la recoleccion a comer de la caza, pero para llegar al techo historico de
## 3-4 veces lo que come uno hace falta mas campaña.


## De cada caceria levantada, cuantas acaban con la pieza en el suelo.
##
## MEDIDO con `scripts/tests/JornadaCazadorProbe.gd` a cuarenta jornadas: cinco
## cobradas de diecisiete -ocho se perdieron con el rastro frio, cuatro de
## vista-. No es punteria: casi todo lo que se pierde se pierde ACECHANDO, y
## el mando de eso es [Hunt.ACECHO_HORAS].
const PARTE_QUE_SE_COBRA := 0.29

## Horas que de verdad se trabajan al dia, de las nueve utiles nominales.
##
## MEDIDO en la misma sonda: 2,6 de 24. El resto del dia se duerme -la mitad-,
## se anda -un tercio- y se busca sitio. Es la distancia entre lo que el modelo
## cree que dura una jornada y lo que dura.
const HORAS_QUE_SE_TRABAJAN := 2.6


## Lo que espera traer al dia quien salga a esta rama, en raciones.
##
## Es la cuenta que hace la banda para decidir si merece la pena irse al monte
## varios dias: raciones de la pieza, por lo que se cobra, por lo que se
## trabaja, entre lo que cuesta cortar un rastro. Todo sale de sitios que ya
## existen -[Fauna] pone las raciones, `_tracking_hours` pone el resto- asi que
## sube sola cuando sube la pericia, cuando hay azagayas en el abrigo y cuando
## hay cuadrilla: los tres cambian la cadena.
##
## Existe porque la gente no es tonta. Nadie se va cinco jornadas detras de un
## uro con las manos vacias; con azagaya y tres personas, puede que si.
func raciones_esperadas(person: Inhabitant,
		speciality: Profession.Speciality) -> float:
	# La media se hace sobre lo que SE PUEDE cobrar hoy y de SU porte, no sobre
	# la tabla entera. Sin el filtro, un cazador sin azagaya esperaba las 84
	# raciones del ciervo medio porque `_huntable_species` le devolvia conejos
	# -que son de porte menor pero caben en la lista de la caza mayor- y la
	# lista no salia vacia. Prometia media racion al dia de algo que no puede
	# matar.
	var porte := Hunting.porte_of(speciality)
	var total := 0.0
	var count := 0
	for species: String in _huntable_species(speciality):
		if Fauna.porte_of(species) != porte:
			continue
		total += Fauna.rations_of(species)
		count += 1
	if count == 0:
		return 0.0
	var per_piece := total / float(count)
	var hours := _tracking_hours_for(person, speciality)
	if hours <= 0.0:
		return 0.0
	return per_piece * PARTE_QUE_SE_COBRA * HORAS_QUE_SE_TRABAJAN / hours


func _tracking_hours(person: Inhabitant) -> float:
	return _tracking_hours_for(person,
		person.current_speciality as Profession.Speciality)


## Lo mismo, pero para una rama que a lo mejor no es la que ejerce hoy: hace
## falta para poder COMPARAR antes de elegir. Ver `raciones_esperadas`.
func _tracking_hours_for(person: Inhabitant,
		speciality: Profession.Speciality) -> float:
	var pieces := Hunting.pieces_per_day(speciality, sim.techs)
	if pieces <= 0.0:
		return SettlementSim.HORAS_UTILES

	var chain := person.effectiveness() * sim._knowledge_factor(person)
	chain *= ResourceField.seasonal_factor(person.activity, GameState.season)
	chain *= sim.weather.work_factor()
	chain *= Hunting.crew_factor(speciality, sim.hunters_in(speciality))
	var tool_kind := sim._tool_for(person)
	if tool_kind >= 0:
		chain *= sim.toolkit.efficiency(tool_kind as Tool.Kind,
			sim.workers_in(person.activity))
	if chain <= 0.01:
		return SettlementSim.HORAS_UTILES

	return SettlementSim.HORAS_UTILES / (pieces * chain * ESCALA_DEL_RASTREO)


## La jornada del cazador, fase por fase.
##
## Devuelve sin hacer nada más: quien llama ya no tiene que cosechar aparte.
func _hunt_step(person: Inhabitant, hours: float) -> void:
	# Sin fauna dibujada no hay a quién acechar. Se cae a la tabla de siempre,
	# que es lo que mantiene en pie las pruebas headless y el rato entre que
	# arranca la simulación y se puebla el valle.
	if wildlife == null:
		sim.tajo._harvest(person, hours)
		return

	var hunt := hunt_of(person)

	# Lo que se dejó abierto en el monte va antes que nada: volver a por una
	# espalda de ciervo rinde más que salir a por otro. Quien llega hasta ella
	# se vuelve a enganchar a su cacería, que sigue viva en la lista.
	if hunt == null:
		var pendiente := kill_to_fetch_near(person.position, Tajo.ALCANCE_DEL_TAJO * 3.0)
		if pendiente != null:
			pendiente.crew.append(person)
			hunt = pendiente

	if hunt == null:
		# El rastreo. Es la mayor parte del día de un cazador y es lo que ata
		# la cacería a la cifra ya medida: ver `_tracking_hours`.
		if person.hunt_cooldown > 0.0:
			person.hunt_cooldown -= hours
			sim.tajo._forage_drift(person)
			person.log_deed(person.current_task(), "cortando rastro", false)
			return
		hunt = _open_hunt(person)

	if hunt == null:
		# No hay pieza de la suya a la vista. Se bate el monte -que es lo que
		# se hace- y no se cobra nada: cazar es, sobre todo, no encontrar.
		#
		# Y se espera un rato antes de volver a mirar. Es lo honesto -no se
		# barre el valle sesenta veces por segundo buscando un ciervo- y de paso
		# es lo que hace que esto se pueda pagar: `quarry_near` recorre los
		# ochocientos animales del valle, y por cazador y por tick son ochocientos
		# millones de cuentas en una partida de cuatro meses.
		person.hunt_cooldown = MIRAR_OTRA_VEZ
		sim.tajo._forage_drift(person)
		person.log_deed(person.current_task(), "batiendo el monte", false)
		return

	# El amanecer se pasa AQUI y no dentro del acecho: una cacería que cruza la
	# noche perseguendo o despiezando también amanece, y contándolo sólo en el
	# acecho el fuelle no se reponía y la cuenta de jornadas decía cero.
	_reset_del_dia(hunt)

	match hunt.phase:
		Hunt.Phase.ACECHO:
			_stalk(person, hunt, hours)
		Hunt.Phase.PERSECUCION:
			_chase(person, hunt, hours)
		Hunt.Phase.LANCE:
			_throw(person, hunt)
		Hunt.Phase.DESPIECE:
			_butcher_in_field(person, hunt, hours)
		Hunt.Phase.ACARREO:
			_load_up(person, hunt)
		Hunt.Phase.FALLIDA:
			_close_hunt(hunt)


## Amanecer es rastro nuevo: el presupuesto de acecho se pone a cero.
##
## [Hunt.ACECHO_HORAS] es por JORNADA y no por caceria. Sin esto, una caceria
## que dura dos dias se moria de vieja a media manana del segundo -llegaba con
## las dos horas y media ya gastadas- y las cacerias de varios dias eran
## imposibles por construccion, no por dificiles.
func _reset_del_dia(hunt: Hunt) -> void:
	if hunt.counted_day == sim.day:
		return
	# La primera vez que se la ve no es amanecer: es que la caceria acaba de
	# nacer. Poner a cero ahi borraria lo que se lleve andado en este mismo
	# tick, y ademas mentiria contando una jornada de mas.
	if hunt.counted_day < 0:
		hunt.counted_day = sim.day
		return
	hunt.days_open += 1
	hunt.counted_day = sim.day
	hunt.spent = 0.0
	hunt.chased = 0.0
	jornadas_mas_larga = maxi(jornadas_mas_larga, hunt.days_open)

## Ir hacia la pieza despacio y sin que lo note.
func _stalk(person: Inhabitant, hunt: Hunt, hours: float) -> void:
	hunt.spent += hours
	var quarry := hunt.where()
	var distance := person.position.distance_to(quarry)

	# Se ANDA hasta tenerla cerca y se acecha desde ahí. Nadie cruza dos
	# kilómetros agachado, y además a un tercio del paso no daba el día para
	# llegar. Ver [Hunt.ACECHO_DESDE].
	_follow_quarry(person, hunt, quarry,
		PASO_DE_ACECHO if distance < Hunt.ACECHO_DESDE else 1.0)
	person.log_deed(person.current_task(), hunt.doing_text(), false)

	# El acecho SE ACABA, y hacía falta decirlo: la pieza se mueve, el cazador
	# duerme por el camino y a la mañana siguiente sigue tras un animal que se
	# ha ido al otro lado del valle. Medido con `CaceriaProbe`: 591.631 ticks
	# en acecho contra 133 lances, y cacerías abiertas que se iban acumulando
	# jornada tras jornada sin resolverse.
	#
	# Dos cortes, porque son dos cosas distintas: se pierde de vista -y eso es
	# distancia- o se le hace de noche siguiendo un rastro que se enfría, y eso
	# es tiempo.
	if distance > Hunt.PIERDE_M or hunt.spent > Hunt.ACECHO_HORAS:
		hunt.phase = Hunt.Phase.FALLIDA
		_note_ending("acecho: se fue de vista" if distance > Hunt.PIERDE_M
			else "acecho: se enfrió el rastro")
		person.log_deed(person.current_task(),
			"perdió el rastro de %s"
				% Fauna.species_name(hunt.species).to_lower(), false)
		return
	var reach := Hunt.reach_of(hunt.weapon, sim.techs)

	# ¿Le ha visto? Sólo si está cerca: un ciervo no te huele desde el otro lado
	# del valle, y mientras se va andando no hay nada que notar. Cuanto más
	# cerca, más fácil que sí. El ojeo lo tapa: batir con un plan es exactamente
	# que la pieza no sepa por dónde le viene.
	if distance >= Hunt.ACECHO_DESDE:
		return
	var closeness := clampf(
		reach * Hunt.SE_NOTA_A / maxf(distance, 1.0), 0.0, 1.0)
	var alert := Hunt.NOTA_POR_HORA * hours * closeness
	alert *= 1.0 - person.skill_in(person.current_task()) * 0.6
	if sim.techs != null and sim.techs.has(TechTree.Tech.OJEO):
		alert *= Hunt.OJEO_SIGILO
	if sim._rng.randf() < alert:
		hunt.unseen = false
		hunt.phase = Hunt.Phase.PERSECUCION
		wildlife.spook(hunt.quarry, person.position)
		return

	if distance <= reach:
		hunt.phase = Hunt.Phase.LANCE


## Ya le ha visto y ha arrancado. Ahora es una carrera, y se pierden muchas.
func _chase(person: Inhabitant, hunt: Hunt, hours: float) -> void:
	hunt.chased += hours
	var quarry := hunt.where()

	# La pieza que se echa al agua se ha ido, y punto. Un ciervo cruza un río a
	# nado y una banda sin piragua no; forzarlo era lo que metía al cazador
	# dentro del cauce detrás de un ánade.
	if not _dry_footing(quarry):
		hunt.phase = Hunt.Phase.FALLIDA
		_note_ending("carrera: se echó al agua")
		person.log_deed(person.current_task(),
			"se le fue al agua %s"
				% Fauna.species_name(hunt.species).to_lower(), false)
		return

	_follow_quarry(person, hunt, quarry, 1.0)
	person.log_deed(person.current_task(), hunt.doing_text(), false)

	var distance := person.position.distance_to(quarry)
	if distance > Hunt.PIERDE_M or hunt.chased > Hunt.FUELLE_HORAS:
		hunt.phase = Hunt.Phase.FALLIDA
		_note_ending("carrera: se fue de vista" if distance > Hunt.PIERDE_M
			else "carrera: sin fuelle")
		person.log_deed(person.current_task(),
			"se le fue %s" % Fauna.species_name(hunt.species).to_lower(), false)
		return

	# El susto se le pasa y vuelve a pararse: ahí es cuando se le entra. Y a la
	# carrera se tira desde más lejos que a la parada -[Hunt.TIRO_A_LA_CARRERA]-,
	# porque quien persigue tira a lo que sea antes de perderla. Lo paga en el
	# lance: sin la sorpresa, que es lo que decide.
	if distance <= Hunt.reach_of(hunt.weapon, sim.techs) * Hunt.TIRO_A_LA_CARRERA:
		hunt.phase = Hunt.Phase.LANCE
	elif not wildlife.is_spooked(hunt.quarry) and distance < Hunt.PIERDE_M * 0.4:
		# La ha perdido de vista pero no el rastro: se vuelve a acechar.
		hunt.phase = Hunt.Phase.ACECHO
		hunt.spent = _tracking_hours(person)


## El lance. Una tirada, y de ahí sale todo.
##
## Y es el momento en que se corre el peligro, no antes: un uro es peligroso
## cuando lo tienes a quince metros con una azagaya en la mano, no mientras lo
## sigues. El riesgo VIVIA en `sim._harvest`, y al dejar de pasar la caza por ahí
## se habria quedado muerto sin que se notara: la banda podia mandar a un solo
## cazador contra un uro sin que le pasara nunca nada, que es justo el fallo
## que `Percances._check_hunting_risk` vino a arreglar en su dia.
##
## Se cobra por LANCE y no por fraccion de jornada porque aqui ya no hay
## jornada que fraccionar: hay una tirada. La fraccion equivalente es la de la
## pieza, o sea lo que dura tenerla delante.
func _throw(person: Inhabitant, hunt: Hunt) -> void:
	sim.percances._check_quarry_risk(person, hunt)

	var chance := Hunt.LANCE_BASE
	chance *= 0.55 + person.skill_in(person.current_task()) * 0.9
	if hunt.unseen:
		chance *= Hunt.SORPRESA
	chance *= Hunting.crew_factor(
		person.current_speciality as Profession.Speciality, hunt.crew.size())
	# Sin arma se le entra a lo que no corre, y aun así cuesta.
	if hunt.weapon < 0:
		chance *= 0.6

	# Y se gasta lo que se tira. Una azagaya se parte contra el hueso: ése es
	# su modo de fallo y la razón de que aparezcan a cientos en los yacimientos.
	if hunt.weapon >= 0:
		sim.toolkit.use(hunt.weapon as Tool.Kind,
			Tool.wear_per_day(hunt.weapon as Tool.Kind) * 0.5)
		sim._note_breakage(person, hunt.weapon as Tool.Kind)

	if sim._rng.randf() > clampf(chance, 0.02, 0.95):
		# Fallado. Si queda fuelle se sigue; si no, se acabó.
		hunt.unseen = false
		wildlife.spook(hunt.quarry, person.position)
		hunt.phase = Hunt.Phase.PERSECUCION if hunt.chased < Hunt.FUELLE_HORAS \
			else Hunt.Phase.FALLIDA
		lances_fallados += 1
		if hunt.phase == Hunt.Phase.FALLIDA:
			_note_ending("se acabo el fuelle tras fallar")
		person.log_deed(person.current_task(),
			"falló el lance a %s" % Fauna.species_name(hunt.species).to_lower(),
			false)
		return

	# Cobrada.
	hunt.kill_site = hunt.where()
	hunt.day = sim.day
	hunt.spoils = Hunt.spoils_of(hunt.species)
	hunt.opened = 0.0
	wildlife.taken_by_band(hunt.quarry)
	kills_today.append(hunt)
	_note_ending("cobrada")

	# El sitio se queda con una pieza menos, igual que un avellanar se queda
	# con menos avellanas. Sin esto, un cotarro de caza no se agota nunca.
	if sim.field:
		var cell := sim.field.best_cell(person.activity, person.position,
			Tajo.ALCANCE_DEL_TAJO)
		sim.field.take_from_cell(person.activity, cell,
			Fauna.rations_of(hunt.species) * SettlementSim.DEPLETION_PER_UNIT)

	# Lo pequeño se echa al hombro; lo grande se abre donde cayó. Ver
	# [Hunt.CARGA_ENTERA] para por qué, que no es una comodidad de código.
	hunt.phase = Hunt.Phase.DESPIECE if Hunt.butchered_in_field(hunt.species) \
		else Hunt.Phase.ACARREO

	# El relato se arma AQUI, con los hechos delante, y se cuenta al llegar al
	# abrigo. Ver `sim._deliver` y [Tale].
	if Fauna.porte_of(hunt.species) == Fauna.Porte.MAYOR:
		person.pending_tale = Tale.hunt(person.given_name, hunt.species,
			sim.parajes.place_name(hunt.kill_site, sim.home_position),
			maxi(hunt.crew.size(), 1), hunt.unseen, sim.day, person.current_task())

	var how := "abrirla aquí" if hunt.phase == Hunt.Phase.DESPIECE \
		else "cargar con ella"
	person.log_deed(person.current_task(),
		"cobró %s" % Fauna.species_name(hunt.species).to_lower())
	sim._note(Chronicle.Kind.TIERRA, "%s cobró %s en %s. Toca %s." % [
		person.given_name, Fauna.species_name(hunt.species).to_lower(),
		sim.parajes.place_name(hunt.kill_site, sim.home_position), how],
		2 if Fauna.porte_of(hunt.species) == Fauna.Porte.MAYOR else 0)


## Abrir la pieza donde cayó. Cuesta tiempo y cuesta filo.
func _butcher_in_field(person: Inhabitant, hunt: Hunt, hours: float) -> void:
	_walk_at(person, hunt.kill_site, 1.0)
	if person.position.distance_to(hunt.kill_site) > sim.arrive_radius * 2.0:
		person.log_deed(person.current_task(),
			"yendo a la pieza", false)
		return

	# Sin filo no se despieza. No es que se tarde más: es que no se pasa del
	# cuero, y lo que se saca es lo que se arranca a manotazos.
	var edge := sim.toolkit.efficiency(Tool.Kind.LASCA, hunt.crew.size())
	var fraction := hours / SettlementSim.HORAS_UTILES
	sim.toolkit.use(Tool.Kind.LASCA, fraction * Tool.wear_per_day(Tool.Kind.LASCA))
	sim._note_breakage(person, Tool.Kind.LASCA)

	hunt.opened += fraction * edge
	person.log_deed(person.current_task(), hunt.doing_text(), false)
	if hunt.opened < Hunt.butcher_days(hunt.species):
		return

	# Lo que se saca depende del filo que hubiera. Con una lasca buena se
	# aprovecha la piel y el tendón; a manotazos se saca carne y poco más.
	if edge < 0.6:
		for kind: int in hunt.spoils.keys():
			if kind != int(Materia.Kind.CARNE):
				hunt.spoils[kind] = float(hunt.spoils[kind]) * edge
	hunt.phase = Hunt.Phase.ACARREO


## Cargar lo que quepa. Lo que no cabe se queda en el monte, y eso es lo que
## hace que una pieza grande sea varios viajes y una decisión.
func _load_up(person: Inhabitant, hunt: Hunt) -> void:
	_walk_at(person, hunt.kill_site, 1.0)
	if person.position.distance_to(hunt.kill_site) > sim.arrive_radius * 2.0:
		person.log_deed(person.current_task(), "yendo a por la carga", false)
		return

	var took := false
	for kind: int in hunt.spoils.keys():
		var room_kg := person.carry_limit_kg() - person.load_kg()
		if room_kg <= 0.0:
			break
		var per_unit := maxf(Materia.kg_per_unit(kind as Materia.Kind), 0.001)
		var fits := minf(float(hunt.spoils[kind]), room_kg / per_unit)
		if fits <= 0.0001:
			continue
		person.add_load(kind as Materia.Kind, fits)
		person.log_gain(person.current_task(), kind, fits)
		if Materia.is_food(kind as Materia.Kind):
			person.carrying += fits * Materia.nutrition(kind as Materia.Kind)
		hunt.spoils[kind] = float(hunt.spoils[kind]) - fits
		if hunt.spoils[kind] <= 0.0001:
			hunt.spoils.erase(kind)
		took = true

	if not took:
		# Va lleno: a casa, y lo que queda espera. Ver [Hunt.DIAS_EN_EL_SUELO].
		sim._send_to(person, sim.home_position)
		person.state = Inhabitant.State.VOLVIENDO
		hunt.crew.erase(person)
		return

	if hunt.spoils.is_empty():
		_close_hunt(hunt)
		person.log_deed(person.current_task(),
			"cargó con %s" % Fauna.species_name(hunt.species).to_lower(), false)


## Cierra una cacería: la saca de la lista y suelta a la cuadrilla.
##
## Y les pone el rastreo por delante. Sin esto, quien acaba de perder una pieza
## levanta otra en el tick siguiente y la caza se convierte en una cadena de
## acechos sin respiro, que ni es lo que pasa ni cuadra con lo que se cobra al
## día. Ver `_tracking_hours`.
func _close_hunt(hunt: Hunt) -> void:
	for person: Inhabitant in hunt.crew:
		person.hunt_cooldown = _tracking_hours(person)
	hunt.crew.clear()
	hunts.erase(hunt)


## Si en este punto se puede plantar un pie de verdad.
##
## Mira el TERRENO y no la rejilla, al revés que [sim._can_step_into], y la
## diferencia importa: la rejilla mide celdas de cuarenta metros y un río más
## estrecho que eso le sale transitable. Andando por rutas de la rejilla da
## igual —se va de centro a centro, y el trazado ya rodea— pero una cacería va
## en línea recta detrás del animal, y en línea recta se cruza el cauce por
## donde no hay vado.
##
## Comprobado mirando, que es como salió: un cazador plantado en mitad del río
## con su chapa encima, siguiendo a un ánade. Ver `CaceriaVistaProbe`.
func _dry_footing(point: Vector3) -> bool:
	if sim._terrain == null:
		return true
	return sim._terrain.crossing_difficulty_at(point) <= Hydrography.FORD_WADEABLE


## Cada cuántos metros se comprueba el suelo entre el cazador y su pieza.
##
## Doce: menos que el ancho del cauce más estrecho que hay en el valle, que es
## lo único que esto tiene que detectar.
const TANTEO_DEL_PASO := 12.0

## Cuánto tiene que moverse la pieza para volver a pedirle camino a la rejilla.
const REPLANTEO_DE_CAZA := 30.0


## Si de aquí a allá se puede ir derecho, sin meterse en el agua.
func _straight_line_holds(from_point: Vector3, to_point: Vector3) -> bool:
	var span := from_point.distance_to(to_point)
	var steps := int(span / TANTEO_DEL_PASO)
	for i in range(1, steps + 1):
		var along := from_point.lerp(to_point, float(i) / float(steps + 1))
		if not _dry_footing(along):
			return false
	return _dry_footing(to_point)


## Ir hacia la pieza: derecho si se puede, y rodeando si hay agua de por medio.
##
## Derecho es lo normal y es lo que se quiere: quien corre detrás de un ciervo
## no rodea el canchal, va por donde va el ciervo, y pedir ruta cada tick a algo
## que se mueve sería trazar un camino nuevo sesenta veces por segundo. La ruta
## de un solo hito es lo que evita además que el bloque de movimiento vuelva a
## pedir camino por su cuenta.
##
## Pero cuando entre los dos hay cauce, la línea recta mete a la persona en el
## agua —comprobado mirando—, así que ahí SÍ se le pide camino a la rejilla, y
## se le pide una vez y no en cada tick: hasta que la pieza se mueva de verdad.
func _follow_quarry(person: Inhabitant, hunt: Hunt, point: Vector3,
		pace: float) -> void:
	if _straight_line_holds(person.position, point):
		hunt.routed_to = Vector3.INF
		_walk_at(person, point, pace)
		return

	person.hunt_pace = pace
	if hunt.routed_to == Vector3.INF \
			or hunt.routed_to.distance_to(point) > REPLANTEO_DE_CAZA:
		hunt.routed_to = point
		sim._send_to(person, point)


## Andar derecho hacia un punto, sin pedir camino a la rejilla.
func _walk_at(person: Inhabitant, point: Vector3, pace: float) -> void:
	person.target = point
	person.route = PackedVector3Array([point])
	person.route_step = 0
	person.hunt_pace = pace


## Pasa un día por las piezas que quedaron abiertas en el monte.
##
## Lo que no se acarreó no espera indefinidamente: se pudre y, sobre todo, hay
## lobos. Una res abierta se anuncia sola.
func _age_kills() -> void:
	kills_today.clear()
	var alive: Array[Hunt] = []
	for hunt: Hunt in hunts:
		# Las fallidas se barren aquí y no sólo donde se pierden: quien la
		# perdió puede haberse ido a casa —de noche, o cargado— sin volver a
		# pasar por `_hunt_step`, y entonces la cacería muerta se quedaba en la
		# lista para siempre. Medido: ocho cacerías levantadas y treinta y seis
		# perdidas en la misma partida, con la lista sin vaciarse nunca.
		if hunt.phase == Hunt.Phase.FALLIDA:
			for person: Inhabitant in hunt.crew:
				person.hunt_cooldown = _tracking_hours(person)
			continue
		if hunt.phase != Hunt.Phase.ACARREO 				and hunt.phase != Hunt.Phase.DESPIECE:
			# Y las que se quedaron a medias sin nadie detrás: la pieza se ha
			# ido hace rato.
			if hunt.crew.is_empty():
				continue
			alive.append(hunt)
			continue

		# Cobrada y en el suelo, con cuadrilla o sin ella. Sin este caso, una
		# pieza a medio abrir cuya cuadrilla se fue a dormir se BORRABA con
		# toda su carne dentro, y desde fuera parecia que la caceria no habia
		# cobrado nada. Ahora envejece como cualquier otra: si nadie vuelve, se
		# pierde y se cuenta, que es distinto de desaparecer.
		hunt.days_out += 1.0
		if hunt.days_out < Hunt.DIAS_EN_EL_SUELO:
			alive.append(hunt)
			continue
		if not hunt.spoils.is_empty():
			sim._note(Chronicle.Kind.PENURIA,
				"Lo que quedaba de %s en %s se ha perdido: %.0f kg que nadie "
					% [Fauna.species_name(hunt.species).to_lower(),
						sim.parajes.place_name(hunt.kill_site, sim.home_position),
						hunt.spoils_kg()]
				+ "fue a buscar.", 1)
	hunts = alive


## La pieza cobrada más cercana que todavía tiene carga, o null.
##
## Es lo mismo que hace el trampero con la trampa cebada: lo que ya está
## cobrado va antes que salir a por lo siguiente. Volver a por una espalda de
## ciervo rinde más que cualquier otra cosa de la caza.
##
## Cuenta la que está A MEDIO ABRIR igual que la ya despiezada, y eso no es un
## detalle. Medido con `DespieceProbe`: un uro cobrado a ochenta metros del
## abrigo se quedó DIEZ JORNADAS con el despiece en 0,16 de 0,84 y una sola
## persona en la cuadrilla, agotada y a medio kilómetro. Ciento cuarenta
## raciones —cinco días de comida para toda la banda— tiradas en el monte
## porque abrir una res es trabajo de varios y nadie más podía apuntarse.
func kill_to_fetch_near(point: Vector3, radius: float) -> Hunt:
	var best: Hunt = null
	var best_distance := radius
	for hunt: Hunt in hunts:
		if hunt.phase != Hunt.Phase.ACARREO 				and hunt.phase != Hunt.Phase.DESPIECE:
			continue
		if hunt.spoils.is_empty():
			continue
		var flat := Vector2(point.x - hunt.kill_site.x,
			point.z - hunt.kill_site.z)
		if flat.length() < best_distance:
			best_distance = flat.length()
			best = hunt
	return best


