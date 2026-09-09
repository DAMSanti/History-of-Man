class_name Cronista
extends RefCounted
## Quien escribe el [Diario] de cada persona: mira y apunta.
##
## Lo hace desde fuera, mirando cómo cambia cada cual de un tick al siguiente,
## y no repartiendo llamadas por media simulación. Es a propósito: el esqueleto
## de una jornada —despertó, desayunó, salió, llegó, decidió volver, cenó, se
## acostó— YA está en los cambios de estado, así que apuntarlo es leerlos, y
## así no hay que tocar veinte sitios ni arriesgarse a que un camino nuevo se
## olvide de contar lo que hace.
##
## Lo que no se puede leer de un cambio de estado —descubrir un material,
## bautizar un sitio, quedarse sin agua— sí se apunta desde donde pasa, porque
## ahí está el dato: qué se encontró y a qué distancia.

## A partir de qué hora una comida es cena y no desayuno.
##
## No es balance: es el reparto del día que ya usa [SettlementSim] —desayuno a
## primera hora, cena al volver—, y sirve sólo para redactar.
const YA_ES_CENA := 15.0

## Cuánto tiene que crecer la carga para que merezca un apunte, en unidades.
##
## Media unidad. Por debajo de eso son los goteos de una recolección continua
## —una avellana cada pocos segundos— y llenarían el diario con la misma línea
## cien veces; lo que se quiere leer es «recogió avellanas», una vez.
const MERECE_APUNTE := 0.5

## A qué distancia del abrigo empieza a ser una salida, en metros.
##
## Cincuenta, el mismo listón con el que [Inhabitant.JOURNEY_MIN_M] decide si
## una salida merece guardarse. Por debajo son tránsitos de la simulación —el
## destino recalculado, un rodeo de tres pasos— y llenaban el diario de «salió
## de batida, 0 m monte adentro».
const SALIDA_MINIMA := Inhabitant.JOURNEY_MIN_M

var sim: SettlementSim

## Lo que se vio de cada persona la última vez. `id -> {estado, carga, dia}`.
var _antes: Dictionary = {}


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Mira a una persona y apunta lo que haya cambiado.
func mirar(person: Inhabitant) -> void:
	var visto: Dictionary = _antes.get(person.id, {})
	var estado_antes := int(visto.get("estado", -1))
	var estado := int(person.state)

	if estado_antes >= 0 and estado_antes != estado:
		_apuntar_lo_que_se_deja(person, estado_antes as Inhabitant.State)
		_apuntar_el_cambio(person, estado_antes as Inhabitant.State,
			estado as Inhabitant.State)

	_apuntar_lo_recogido(person, visto.get("carga", {}) as Dictionary)

	_antes[person.id] = {
		"estado": estado,
		"carga": person.load.duplicate(),
	}


## Lo que se cuenta de SALIR de un estado, sea cual sea el siguiente.
##
## Despertar y llegar a casa son de aquí y no de allí. Mirando sólo el estado
## nuevo se perdían las dos: quien se levanta y va derecho a desayunar pasa de
## DURMIENDO a COMIENDO sin escala, y quien llega cargado y cena pasa de
## VOLVIENDO a COMIENDO. La crónica salía sin «despertó» y sin «llegó al
## abrigo», que son dos de las líneas que se pidieron por su nombre.
func _apuntar_lo_que_se_deja(person: Inhabitant, de: Inhabitant.State) -> void:
	match de:
		Inhabitant.State.DURMIENDO:
			person.diario.apunta(sim.day, sim.hour, Diario.Que.RUTINA,
				"Despertó.")
		Inhabitant.State.VOLVIENDO:
			if _en_casa(person):
				person.diario.apunta(sim.day, sim.hour, Diario.Que.CAMINO,
					"Llegó al abrigo.")
				# Y POR QUÉ VUELVE DE VACÍO, si vuelve de vacío. Es lo que se
				# pidió: «quiero que me pongas cuándo vuelve de vacío al
				# campamento porque es». Una línea de «volvió de vacío» sin
				# explicación no dice si el problema es el sitio, el camino o
				# la suerte.
				if person.load_kg() < 0.1:
					person.diario.apunta(sim.day, sim.hour, Diario.Que.APURO,
						"Llegó de vacío: %s." % _por_que_de_vacio(person))


## Qué se cuenta de pasar de un estado a otro.
func _apuntar_el_cambio(person: Inhabitant, de: Inhabitant.State,
		a: Inhabitant.State) -> void:
	var diario := person.diario
	var hora := sim.hour
	var dia := sim.day

	match a:
		Inhabitant.State.DURMIENDO:
			if _en_casa(person):
				diario.apunta(dia, hora, Diario.Que.RUTINA, "Se fue a dormir.")
			else:
				# Dormir fuera no es rutina: es lo que se paga al día siguiente.
				diario.apunta(dia, hora, Diario.Que.APURO,
					"Se echó a dormir al raso, a %s del abrigo."
						% _lejos(person))

		Inhabitant.State.COMIENDO:
			if hora >= YA_ES_CENA:
				diario.apunta(dia, hora, Diario.Que.RUTINA, "Cenó.")
			else:
				diario.apunta(dia, hora, Diario.Que.RUTINA, "Desayunó.")

		Inhabitant.State.YENDO:
			# Sin destino de verdad no hay salida que contar. Salía «salió de
			# batida, 0 m monte adentro» cuando el destino era el propio
			# abrigo, que es un tránsito de la simulación y no una jornada.
			if sim.home_position.distance_to(person.target) > SALIDA_MINIMA:
				diario.apunta(dia, hora, Diario.Que.CAMINO,
					"Salió %s." % _adonde(person))

		Inhabitant.State.BUSCANDO:
			diario.apunta(dia, hora, Diario.Que.TRABAJO,
				"Llegó a %s, pero no conoce el sitio: se puso a batirlo para "
					% _sitio(person.position)
				+ "encontrar lo que venía a buscar.")

		Inhabitant.State.TRABAJANDO:
			if de == Inhabitant.State.BUSCANDO:
				diario.apunta(dia, hora, Diario.Que.TRABAJO,
					"Dio con lo que buscaba y se puso a %s." % _oficio(person))
			elif sim.hogar._works_at_camp(person):
				diario.apunta(dia, hora, Diario.Que.TRABAJO,
					"Se puso a %s en el abrigo." % _oficio(person))
			else:
				diario.apunta(dia, hora, Diario.Que.TRABAJO,
					"Llegó a %s y se puso a %s." % [
						_sitio(person.position), _oficio(person)])

		Inhabitant.State.RECONOCIENDO:
			diario.apunta(dia, hora, Diario.Que.TRABAJO,
				"Llegó a %s y empezó a reconocerlo." % _sitio(person.position))

		Inhabitant.State.VOLVIENDO:
			var carga := person.load_kg()
			if carga > 0.5:
				diario.apunta(dia, hora, Diario.Que.CAMINO,
					"Decidió volver al abrigo, con %.1f kg encima." % carga)
			else:
				diario.apunta(dia, hora, Diario.Que.CAMINO,
					"Decidió volver al abrigo de vacío.")


## Lo que se ha echado al zurrón desde la última vez.
func _apuntar_lo_recogido(person: Inhabitant, antes: Dictionary) -> void:
	for kind: int in person.load:
		var ahora := float(person.load[kind])
		var ya := float(antes.get(kind, 0.0))
		# Cuando CRUZA el listón, no cuando crece. Mirando el crecimiento no
		# saltaba nunca: la recolección va por goteo —centésimas por tick— así
		# que ningún paso solo llegaba a media unidad, y en cuanto había algo
		# en el zurrón la línea de «primera vez» lo daba por contado.
		if ahora < MERECE_APUNTE or ya >= MERECE_APUNTE:
			continue
		person.diario.apunta(sim.day, sim.hour, Diario.Que.TRABAJO,
			"Empezó a coger %s en %s." % [
				Materia.material_name(kind as Materia.Kind).to_lower(),
				_sitio(person.position)])


## Por qué no trae nada, con lo que la simulación sabe de esta persona.
func _por_que_de_vacio(person: Inhabitant) -> String:
	if person.unreachable != Vector3.ZERO:
		return "no había forma de llegar al sitio y hubo que darlo por perdido"
	if person.job == Profession.Job.EXPLORACION:
		return "lo suyo es traer mapa, no carga"
	if sim.barbecho != null and sim.barbecho.sin_sitio(person.activity):
		return "no le queda ningún sitio sin esquilmar donde trabajar lo suyo"
	if person.state_name() == "atascado":
		return "se quedó atascado y perdió la jornada"
	return "no encontró nada que mereciera cargar"


## Que se ha descubierto algo, y dónde. Lo llama quien lo detecta.
func hallazgo(person: Inhabitant, texto: String) -> void:
	if person == null or person.diario == null:
		return
	person.diario.apunta(sim.day, sim.hour, Diario.Que.HALLAZGO, texto)


## Que ha pasado algo malo. Lo llama quien lo detecta.
func apuro(person: Inhabitant, texto: String) -> void:
	if person == null or person.diario == null:
		return
	person.diario.apunta(sim.day, sim.hour, Diario.Que.APURO, texto)


## Si esta en casa, con la MISMA regla que usa la simulacion.
##
## Hacia falta y no es un detalle: con un radio propio salia «se echo a dormir
## al raso, a 16 m del abrigo» de gente que estaba durmiendo DENTRO. El abrigo
## no es un punto, es la galeria y la campa -ver [SettlementSim._shelter_reach]-
## y es ahi donde `_home_spot` reparte a la gente por la noche.
func _en_casa(person: Inhabitant) -> bool:
	return sim._at_shelter(person)


## A cuánto está del abrigo, dicho como se dice.
func _lejos(person: Inhabitant) -> String:
	return "%.0f m" % sim.home_position.distance_to(person.position)


## Adónde sale, contado por lo que se sabe del destino.
func _adonde(person: Inhabitant) -> String:
	var lejos := sim.home_position.distance_to(person.target)
	var paraje := sim.parajes.at(person.target) if sim.parajes else null
	if paraje != null:
		return "hacia %s, a %.0f m" % [paraje.name_text, lejos]
	if person.job == Profession.Job.EXPLORACION:
		return "a reconocer, %.0f m monte adentro" % lejos
	# Sin paraje al que ir, lo que se hace es batir: ver [Tanteo].
	return "de batida, %.0f m monte adentro" % lejos


## Cómo se llama el sitio donde está, o a qué distancia si no tiene nombre.
func _sitio(donde: Vector3) -> String:
	var paraje := sim.parajes.at(donde) if sim.parajes else null
	if paraje != null:
		return paraje.name_text
	return "un punto a %.0f m del abrigo" % sim.home_position.distance_to(donde)


## El verbo de lo que hace, para poder escribir «se puso a ...».
func _oficio(person: Inhabitant) -> String:
	match person.activity:
		Subsistence.Activity.RECOLECCION: return "recolectar"
		Subsistence.Activity.CAZA: return "cazar"
		Subsistence.Activity.PESCA: return "pescar"
		Subsistence.Activity.MARISQUEO: return "mariscar"
		Subsistence.Activity.MATERIA_PRIMA: return "sacar materia prima"
		_: return "trabajar"
