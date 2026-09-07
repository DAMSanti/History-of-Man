class_name Hunting
extends RefCounted
## Cómo caza la banda, y cómo va mejorando.
##
## Tres ramas, y no son tres niveles de lo mismo: son tres oficios que se
## llevan mal entre sí y que el jugador reparte.
##
## - **Trampas.** Se arman una vez y cobran solas mientras la banda hace otra
##   cosa. Poca pieza y muy segura. Es la única forma de traer carne sin
##   gastar una jornada por pieza, y por eso es la que sostiene el invierno.
## - **Caza menor.** Al acecho, uno o dos, con azagaya o arco. Corzo, rebeco,
##   ave grande. Rinde a diario y no se juega el pellejo.
## - **Caza mayor.** Cuadrilla, jornada larga y riesgo de verdad. Ciervo,
##   jabalí, caballo, uro. Una sola pieza cambia la semana de la banda, y el
##   despiece —piel, hueso, tendón, grasa— es la mitad del taller.
##
## Lo que da cada rama NO sale de una tabla de materiales: sale de la PIEZA.
## Se decide qué animal cae —de lo que de verdad anda por ese sitio en esa
## estación, [Fauna]— y se despieza. Por eso un cotarro de aves da plumas y
## no piel, y por eso el jugador prefiere unos parajes a otros.
##
## Y la técnica se nota en la CANTIDAD de piezas, no en inventar animales: un
## cazador con propulsor no encuentra ciervos donde no los hay, cobra más de
## los que encuentra.

## Cuántas piezas cobra una jornada entera y perfecta, por rama y sin
## técnicas. Es el número que luego pasa por la cadena de penalizaciones de
## `SettlementSim._harvest`, igual que todo lo demás.
##
## Parecen pocas y lo son: cazar es fallar. Media pieza mayor por jornada
## perfecta significa, con las penalizaciones de verdad encima, que una
## cuadrilla trae un ciervo cada varios días —que es exactamente lo que dice
## la arqueología de un abrigo cantábrico.
## Medido en el sitio 56, sesenta jornadas: con 1,30 y 0,55 la caza menor
## traia 1,43 raciones por jornada-persona y la mayor 0,09, contra las 9,35
## de la recoleccion. El encargo dice lo contrario -«debe dar mas raciones que
## la recoleccion»- y ademas es lo cierto: una banda cantabrica del
## Magdaleniense vivia de la carne, no de la avellana. Estas cifras la ponen
## por encima sin hacerla gratis, porque el riesgo y el desperdicio siguen
## ahi.
const PIEZAS_POR_JORNADA := {
	Profession.Speciality.CAZA_MENOR: 4.40,
	Profession.Speciality.CAZA_MAYOR: 1.60,
}

## Lo que multiplica cada técnica, y a qué rama.
##
## No se suman: se multiplican, y por eso el salto de tener las tres es
## grande. La azagaya es la que abre la caza mayor de verdad —sin ella se
## caza al acecho y con trampa, no se mata un uro—, el propulsor dobla el
## alcance útil y el arco cambia el acecho entero.
const MEJORAS := {
	Profession.Speciality.CAZA_MENOR: [
		{"tech": TechTree.Tech.AZAGAYA, "factor": 1.25},
		{"tech": TechTree.Tech.ARCO, "factor": 1.70},
	],
	Profession.Speciality.CAZA_MAYOR: [
		{"tech": TechTree.Tech.AZAGAYA, "factor": 1.60},
		{"tech": TechTree.Tech.PROPULSOR, "factor": 1.45},
		{"tech": TechTree.Tech.OJEO, "factor": 1.35},
		{"tech": TechTree.Tech.ARCO, "factor": 1.20},
	],
}

## Cuántas raciones daría una jornada perfecta de esta rama en este sitio.
##
## Es lo que vale el sitio PARA ESTA RAMA, y sirve para elegir adónde ir. Se
## calcula de verdad y no con un premio a ojo: un cotarro de conejos no es
## «malo para la caza mayor», es exactamente 1,4 raciones por pieza, y esa
## cifra ya ordena bien la lista sin inventarse ningún factor.
static func rations_at(speciality: Profession.Speciality, position: Vector3,
		season: Subsistence.Season, techs: TechTree,
		toolkit: Toolkit = null) -> float:
	var total := 0.0
	var yields := yields_at(speciality, position, season, techs, toolkit)
	for kind: int in yields:
		if Materia.is_food(kind as Materia.Kind):
			total += float(yields[kind]) * Materia.nutrition(kind as Materia.Kind)
	return total


## Cuántas piezas cobra hoy una jornada perfecta de esta rama.
##
## El «sin azagaya se caza mal» NO se cobra aquí: ya lo cobra el filo
## disponible en `SettlementSim._harvest`, que mira las azagayas que hay en el
## abrigo para la gente que sale. Cobrarlo dos veces —por no tener la PIEZA y
## por no saber la TÉCNICA— dejaba a una banda con siete azagayas hechas
## cazando al 45%. Lo que sí va aquí son las MEJORAS: saber hacer una azagaya
## de asta no es lo mismo que tenerla, y el propulsor y el arco cambian cómo
## se caza, no con qué.
static func pieces_per_day(speciality: Profession.Speciality,
		techs: TechTree) -> float:
	var base: float = float(PIEZAS_POR_JORNADA.get(speciality, 0.0))
	if base <= 0.0:
		return 0.0

	for entry: Dictionary in (MEJORAS.get(speciality, []) as Array):
		if techs != null and techs.has(entry["tech"] as TechTree.Tech):
			base *= float(entry["factor"])
	return base


## Cuánta gente hace falta para que la rama rinda de verdad.
##
## La caza menor se hace al acecho, solo o de a dos, y una cuadrilla no
## acecha mejor que un cazador solo: de sobra con uno, y por eso no tiene
## curva -devuelve 1,0 tenga quien tenga al lado-. La caza mayor es la
## BATIDA -varias manos que acorralan y rematan-, y un cazador solo contra
## un uro no trae un uro: vuelve con la azagaya rota, con suerte. Sin este
## factor un cazador solo de caza mayor cobraba lo mismo por cabeza que una
## cuadrilla entera, y «cuadrilla» se quedaba en el docstring sin pasar al
## juego.
##
## No es lineal a propósito: por debajo de cuatro manos la partida no rodea
## de verdad al animal, así que el rendimiento por debajo de eso cae fuerte;
## de cuatro para arriba ya hay brazos de sobra y una quinta persona no
## ayuda a acorralar mejor.
const CREW := {
	Profession.Speciality.CAZA_MAYOR: [0.20, 0.45, 0.75, 1.0],
}

static func crew_factor(speciality: Profession.Speciality, crew_size: int) -> float:
	var curve: Array = CREW.get(speciality, [])
	if curve.is_empty():
		return 1.0
	var index: int = clampi(crew_size, 1, curve.size()) - 1
	return float(curve[index])


## Las técnicas de esta rama que ya se dominan, para poder decírselo al
## jugador sin que tenga que cruzar dos pantallas.
static func known_improvements(speciality: Profession.Speciality,
		techs: TechTree) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in (MEJORAS.get(speciality, []) as Array):
		if techs != null and techs.has(entry["tech"] as TechTree.Tech):
			out.append(TechTree.tech_name(entry["tech"] as TechTree.Tech))
	return out


## La siguiente técnica que le falta a esta rama, o -1 si están todas.
static func next_improvement(speciality: Profession.Speciality,
		techs: TechTree) -> int:
	for entry: Dictionary in (MEJORAS.get(speciality, []) as Array):
		if techs == null or not techs.has(entry["tech"] as TechTree.Tech):
			return int(entry["tech"])
	return -1


## El porte de pieza que persigue cada rama.
static func porte_of(speciality: Profession.Speciality) -> int:
	match speciality:
		Profession.Speciality.CAZA_MAYOR: return Fauna.Porte.MAYOR
		Profession.Speciality.CAZA_MENOR: return Fauna.Porte.MENOR
		_: return Fauna.Porte.MENUDA


## Qué se cobra en un sitio, en materiales, por una jornada perfecta.
##
## Es la tabla de rendimiento de la rama, pero calculada de la PIEZA y no
## escrita a mano: se mira qué animales de ese porte andan por ahí esta
## estación, se reparte la jornada entre ellos y se despieza cada uno. De ahí
## salen la carne, la piel, el hueso, el tendón, la grasa, el asta —y la
## PLUMA de las aves, que no dan piel.
##
## Si en ese punto no hay nada de su porte, la rama devuelve lo justo: algo
## se topa uno siempre, pero poco, y de lo más humilde que haya.
static func yields_at(speciality: Profession.Speciality, position: Vector3,
		season: Subsistence.Season, techs: TechTree,
		toolkit: Toolkit = null) -> Dictionary:
	var pieces := pieces_per_day(speciality, techs)
	if pieces <= 0.0:
		return {}

	# Se caza lo que hay, hasta el porte de uno. HACIA ABAJO y no hacia
	# arriba: un batidor de caza mayor que se topa un corzo lo mata, y uno de
	# caza menor que se topa un uro lo deja pasar —con azagaya de mano no se
	# mata un uro, se muere uno.
	#
	# Antes el porte era un filtro exclusivo, y eso abria un agujero: en un
	# cotarro de «perdiz y conejo» un cazador de pieza menor no encontraba
	# NADA de lo suyo. Medido: 1,8 raciones de jornada perfecta contra las
	# 14,2 de un recolector, o sea que cazar era el peor oficio de la banda
	# por un detalle de clasificacion.
	#
	# Y ademas se caza lo que se PUEDE cazar. A un uro no se le entra con las
	# manos vacias, asi que un cotarro de uros sin una azagaya en el abrigo no
	# es un mal sitio de caza: es ningun sitio de caza. La puerta esta en
	# [Fauna.huntable_with] y no aqui porque es una propiedad del animal -de lo
	# que hace falta para matarlo-, no de quien sale a por el.
	#
	# Va como FILTRO y no como penalizacion a proposito: media pieza de uro sin
	# azagaya no es media pieza, es una cuadrilla que vuelve corriendo. Y ver
	# `SettlementSim._trapline`, que se lo salta: un foso coge un jabali sin que
	# nadie le tenga que entrar, y esa es la razon de ser del foso.
	var porte := porte_of(speciality)
	var species: Array[String] = []
	var best_porte := -1
	for one: String in Fauna.species_at(position, season):
		if Fauna.porte_of(one) > porte:
			continue
		if not Fauna.huntable_with(one, toolkit):
			continue
		species.append(one)
		best_porte = maxi(best_porte, Fauna.porte_of(one))
	if species.is_empty():
		return {}

	# Ir montado para una cosa y cobrar otra cunde menos: la cuadrilla que
	# sale a por ciervo y vuelve con liebres ha gastado la jornada entera en
	# batir un monte que no hacia falta batir.
	var mismatch := porte - best_porte
	if mismatch == 1:
		pieces *= 0.70
	elif mismatch >= 2:
		pieces *= 0.50

	var per_species := pieces / float(species.size())
	var out := {}
	for one: String in species:
		_add(out, Materia.Kind.CARNE, Fauna.rations_of(one) * per_species)
		for kind: int in Fauna.spoils_of(one):
			_add(out, kind as Materia.Kind,
				float(Fauna.spoils_of(one)[kind]) * per_species)
	return out


## Lo que anda por este sitio y esta rama NO puede cobrar por falta de arma.
##
## Es la mitad que faltaba de la puerta: cerrarla sin decirlo deja al jugador
## con una cuadrilla que vuelve de vacio de un cotarro lleno de ciervos y
## ninguna forma de saber por que. Cada entrada trae la especie y que falta.
static func out_of_reach(speciality: Profession.Speciality, position: Vector3,
		season: Subsistence.Season, toolkit: Toolkit) -> Array[Dictionary]:
	return Fauna.out_of_reach_at(position, season,
		porte_of(speciality) as Fauna.Porte, toolkit)


## Dicho para leerlo: «el ciervo pasa y no hay azagaya». "" si no falta nada.
static func out_of_reach_text(speciality: Profession.Speciality,
		position: Vector3, season: Subsistence.Season,
		toolkit: Toolkit) -> String:
	var blocked := out_of_reach(speciality, position, season, toolkit)
	if blocked.is_empty():
		return ""
	var parts: Array[String] = []
	for entry: Dictionary in blocked:
		parts.append("%s (%s)" % [
			Fauna.species_name(String(entry["species"])).to_lower(),
			String(entry["missing"])])
	return "se deja pasar: %s" % ", ".join(parts)


## El riesgo medio de una jornada de esta rama en este sitio: lo que puede
## costarle a quien la hace. Un uro no es un conejo.
##
## `crew_size` reparte el peligro, no sólo el trabajo: ir en cuadrilla no es
## sólo más pieza -[crew_factor]- sino también más seguro, porque cuatro
## batidores no corren cada uno el riesgo entero del que va solo. Pedirlo
## aparte y no dentro de [crew_factor] es a propósito: uno decide CUÁNTO se
## caza, el otro CUÁNTO CUESTA, y son preguntas distintas aunque compartan
## el mismo número de gente.
static func risk_at(speciality: Profession.Speciality, position: Vector3,
		season: Subsistence.Season, crew_size: int = 1,
		toolkit: Toolkit = null) -> float:
	# Lo que no se caza no cuesta. Sin azagaya no se le entra al uro, asi que
	# tampoco se corre su riesgo: la cuadrilla lo ve pasar. Sin esto, una banda
	# desarmada se llevaba las cornadas de una caza que no estaba haciendo.
	var species: Array[String] = []
	for one: String in Fauna.species_at(position, season):
		if Fauna.porte_of(one) > porte_of(speciality):
			continue
		if not Fauna.huntable_with(one, toolkit):
			continue
		species.append(one)
	if species.is_empty():
		return 0.0
	var total := 0.0
	for one: String in species:
		total += Fauna.risk_of(one)
	return (total / float(species.size())) / float(maxi(crew_size, 1))


static func _add(into: Dictionary, kind: Materia.Kind, units: float) -> void:
	if units <= 0.0:
		return
	into[int(kind)] = float(into.get(int(kind), 0.0)) + units
