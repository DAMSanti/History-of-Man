class_name Barbecho
extends RefCounted
## Dejar descansar lo esquilmado, y salir a buscar otro sitio.
##
## Hasta ahora el barbecho era una decisión del JUGADOR: un botón en la ficha
## del paraje. La banda, por su cuenta, se quedaba pescando en un río muerto.
## Medido con `ParajesProbe`, un año con dos pescadores: el tajo de ribera baja
## al 1 % en treinta y dos jornadas y ahí se queda, **con el resto del río al
## 93,9 %**. Había dónde pescar y no iban.
##
## Eso no es una decisión difícil, es una banda tonta. Cualquiera que lleve un
## mes sacando una trucha al día se va río arriba.
##
## Aquí la banda lo hace sola:
##
##   1. Un paraje por debajo de [ESQUILMADO] de lo que tenía **se deja en
##      barbecho**. [SettlementSim._is_resting] ya lo saca del reparto de tajos.
##   2. Se le quita el barbecho cuando pasa de [REPUESTO], que es bastante más
##      arriba: sin esa histéresis el sitio entraría y saldría de descanso cada
##      dos jornadas, trabajado justo hasta el umbral una y otra vez.
##   3. Y si al oficio no le queda ningún sitio conocido, **su cuadrilla sale a
##      buscar**: eso es lo que quiere decir «priorizar encontrar otro paraje».
##
## ## Lo que NO descansa
##
## Las vetas. Una veta de sílex no se repone —ver [Materia.VETAS]— así que
## dejarla descansar no la mejora: sólo hace que la banda no la use. Lo que se
## saca de una veta se saca una vez, y vaciarla del todo es lo correcto; cuando
## se acaba, el paraje desaparece. Ver [Parajes.prune_exhausted].

## Por debajo de esto se deja descansar, en tanto por uno de lo que tenía
## intacto. Petición literal: «un paraje por debajo del 20 % de productos
## sostenibles es un paraje casi esquilmado».
const ESQUILMADO := 0.20

## Y hasta aquí tiene que reponerse para volver.
##
## Más del doble del umbral de salida, y hace falta: con los dos iguales el
## sitio saldría de barbecho al 21 %, se trabajaría hasta el 19 % en una jornada
## y volvería a entrar. Eso no es descansar, es una puerta batiente.
const REPUESTO := 0.55

## Con qué radio se mira lo que queda. El mismo que usa el reparto de tajos
## para puntuar un sitio, o el barbecho y la elección dirían cosas distintas
## del mismo paraje.
const RADIO := 90.0

## Hasta donde se busca sitio nuevo cuando no queda ninguno, en metros.
##
## Trescientos ochenta -el radio de una batida, ver [Reconocimiento.BATIDA_RADIUS]-
## y no los novecientos del tope de jornada. La diferencia importa: novecientos
## metros es lo mas lejos a lo que se PUEDE ir a trabajar un sitio que ya se
## conoce y se sabe bueno; salir a probar suerte tan lejos es gastar la jornada
## en el camino y volver de vacio.
const BUSCAR_HASTA := 380.0

var sim: SettlementSim

## Lo ultimo que se busco para cada oficio, y en que jornada. Ver [donde_buscar].
var _buscado: Dictionary = {}


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Pasa revista a los parajes. Se llama al cerrar la jornada: el agotamiento va
## por jornadas trabajadas, no por fotogramas.
func revisar() -> void:
	if sim.field == null or sim.parajes == null:
		return
	for paraje: Paraje in sim.parajes.list:
		# Las vetas no descansan: no se reponen, así que el barbecho no las
		# arregla y sólo impediría usarlas.
		if not Materia.renews(paraje.kind):
			continue
		var queda := sim.field.stock_fraction_around(
			paraje.activity, paraje.position, RADIO)
		if paraje.resting:
			if queda >= REPUESTO:
				_devolver(paraje, queda)
		elif queda < ESQUILMADO:
			_descansar(paraje, queda)


func _descansar(paraje: Paraje, queda: float) -> void:
	paraje.resting = true
	if paraje.chosen:
		sim.parajes.clear_choice(paraje.activity)
	sim._note(Chronicle.Kind.PENURIA,
		"%s está casi esquilmado (queda un %.0f %%). Se deja descansar y se "
			% [paraje.name_text, queda * 100.0]
		+ "busca en otra parte.", 2)


func _devolver(paraje: Paraje, queda: float) -> void:
	paraje.resting = false
	sim._note(Chronicle.Kind.TIERRA,
		"%s se ha repuesto: vuelve a haber un %.0f %%."
			% [paraje.name_text, queda * 100.0], 1)


## Si a este oficio no le queda dónde trabajar.
##
## Es lo que convierte el barbecho en una decisión de verdad y no en un castigo:
## cuando se deja descansar el único sitio conocido, la cuadrilla no se queda de
## brazos cruzados —sale a buscar—. Lo usa [Reparto] para mandarles a
## reconocer en vez de dejarles ociosos.
func sin_sitio(activity: Subsistence.Activity) -> bool:
	if sim.field == null:
		return false
	var conocidos: Array = sim._known_spots.get(activity, [])
	for spot: Dictionary in conocidos:
		var donde: Vector3 = spot["pos"]
		if sim._is_resting(activity, donde):
			continue
		if sim.field.stock_fraction_around(activity, donde, RADIO) >= ESQUILMADO:
			return false
	return true


## Adónde ir a buscar cuando no queda sitio conocido sin esquilmar.
##
## Es la otra mitad de «priorizar encontrar otro paraje». Barbechar el único
## sitio bueno sin dar una alternativa deja a la cuadrilla ociosa, que es peor
## que dejarla pescando en un río muerto: al menos aquello traía algo.
##
## Lo que se hace es levantar la reja de la FAMILIARIDAD, y sólo para el oficio
## que se ha quedado sin sitio. [Tajo._rank_known_spots] sólo ofrece celdas que
## la banda ya conoce —familiaridad ≥ 0,35— y ésa es exactamente la razón
## medida de que dos pescadores se quedaran un año en un río al 1 % con el
## resto del cauce al 93,9 %: había dónde ir y para el mapa mental de la banda
## no existía.
##
## No es hacer trampa con el saber: es que alguien que lleva un mes sin sacar
## nada SALE A MIRAR. Lo que se devuelve es un sitio candidato; la jornada se
## gasta en llegar y probar, y si trae algo, la familiaridad sube sola.
func donde_buscar(activity: Subsistence.Activity, desde: Vector3) -> Vector3:
	if sim.field == null:
		return Vector3.ZERO
	# Una vez por oficio y jornada. Barrer la rejilla entera midiendo la mancha
	# de cada celda cuesta, y con cuatro recolectores sin sitio se haria cuatro
	# veces para dar la misma respuesta.
	var clave := int(activity)
	var guardado: Dictionary = _buscado.get(clave, {})
	if int(guardado.get("dia", -1)) == sim.day:
		return guardado.get("donde", Vector3.ZERO)

	var mejor := Vector3.ZERO
	var mejor_nota := 0.0
	var tope := SettlementSim.CAZA_LEJOS_M \
		if activity == Subsistence.Activity.CAZA else BUSCAR_HASTA
	for z in range(sim.field.height):
		for x in range(sim.field.width):
			var centre := sim.field.cell_center(x, z)
			var lejos := Vector2(centre.x - desde.x, centre.z - desde.z).length()
			if lejos > tope:
				continue
			var queda := sim.field.stock_fraction_around(activity, centre, RADIO)
			if queda < REPUESTO:
				continue
			if sim._is_resting(activity, centre):
				continue
			var hay := sim.field.abundance_cell(activity, x, z)
			if hay <= 0.05:
				continue
			# Lo mismo que puntúa un tajo: lo que hay contra lo que cuesta
			# llegar. Aquí sin `believed_abundance` porque justamente lo que
			# se está haciendo es ir a ver lo que no se sabe.
			var viaje := 2.0 * sim.marcha.hours_to_walk(lejos)
			# SIN SUELO DE 0,1: un sitio al que no da tiempo a llegar y volver
			# no vale una decima de lo que vale uno cerca, vale CERO. Con el
			# suelo puesto, una celda riquisima a setecientos metros ganaba a
			# una decente a doscientos, y medido en las primeras jornadas el
			# resultado era que A MEDIODIA NADIE ESTABA TRABAJANDO: estaban
			# todos «de camino» o «volviendo», y la despensa perdia veinte al
			# dia sin ganar nada. Ver `ArranqueProbe`.
			var util := clampf(1.0 - viaje / SettlementSim.HORAS_UTILES, 0.0, 1.0)
			if util <= 0.0:
				continue
			# Y el tiempo pesa AL CUADRADO: media jornada andando no deja media
			# jornada de trabajo, deja media hecha con prisa y con la carga a
			# cuestas.
			var nota := hay * util * util * queda
			if nota > mejor_nota:
				mejor_nota = nota
				if sim._terrain:
					centre.y = sim._terrain.get_height_at(centre)
				mejor = centre
	_buscado[clave] = {"dia": sim.day, "donde": mejor}
	return mejor
