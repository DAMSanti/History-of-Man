class_name Parajes
extends RefCounted
## El registro de sitios con nombre que conoce la banda.
##
## Se rellena solo: cada jornada se miran las celdas que la banda ya conoce y
## las que no estaban apuntadas se bautizan. No hay que descubrir nada a mano
## ni tocar la simulación: el conocimiento ya se calculaba, sólo no tenía
## nombre ni sitio donde vivir.

## Familiaridad a partir de la cual una celda merece nombre.
##
## Por encima de `KNOWN_ENOUGH` la banda ya vuelve a ese sitio a propósito en
## vez de tropezárselo, y eso es exactamente lo que distingue un paraje de un
## trozo de monte.
const NAMED_AT := BandKnowledge.KNOWN_ENOUGH

## Abundancia mínima para que valga la pena nombrarlo. Sin esto se bautizaría
## medio valle: casi cualquier celda da ALGO.
const WORTH_NAMING := 0.18

## A qué distancia dos celdas del mismo oficio son EL MISMO sitio, en metros.
##
## Las celdas del campo miden 64 m, y un avellanar de verdad no cabe en una:
## ocupa la ladera entera. Sin agrupar salían tres «avellanares» a 45 m unos
## de otros, que como sitios distintos no significan nada —nadie distingue
## tres manchas de avellano contiguas— y llenaban el valle de chapas.
##
## Antes eran 180 m -un bloque de tres por tres celdas-, y con la
## exploración encontrando de verdad terreno nuevo se quedó corto: un
## mismo bosque de recolección, tres celdas más ancho de lo previsto,
## volvía a salir como dos o tres parajes a la vez. 320 agrupa un bloque de
## cinco por cinco, y no da miedo ensancharlo porque [near] ahora exige
## ADEMÁS estar en el mismo trozo de monte -ver `same_patch`-: lo que de
## verdad separa dos sitios es si se cruza un río o un cantil para ir del
## uno al otro, no un número de metros suelto.
const MERGE_RANGE := 320.0

var list: Array[Paraje] = []
var _by_id: Dictionary = {}

## Los que se han bautizado en la última revisión, para que la crónica pueda
## contarlos y luego se limpian.
var just_found: Array[Paraje] = []


func has(paraje: Paraje) -> bool:
	return _by_id.has(paraje.id())


func add(paraje: Paraje) -> bool:
	if _by_id.has(paraje.id()):
		return false
	paraje.name_text = _free_name(paraje)
	_by_id[paraje.id()] = paraje
	list.append(paraje)
	just_found.append(paraje)
	return true


## Un nombre que no esté cogido.
##
## El nombre sale de la celda por un hash, y con quince palabras de lugar los
## choques son inevitables: salían dos «cantizal de la vega» y el jugador no
## podía distinguirlos, que es justo lo contrario de para lo que sirve
## bautizar un sitio. Al chocar se prueba la siguiente palabra.
func _free_name(paraje: Paraje) -> String:
	var taken := {}
	for other: Paraje in list:
		taken[other.name_text] = true

	for offset in range(Paraje.LUGARES.size()):
		var candidate := Paraje.build_name(
			paraje.cell_x + offset, paraje.cell_z, paraje.kind)
		if not taken.has(candidate):
			return candidate

	# Con las quince agotadas -mucho paraje del mismo material- se numera. Feo,
	# pero un nombre repetido es peor que un número.
	var base := Paraje.build_name(paraje.cell_x, paraje.cell_z, paraje.kind)
	var n := 2
	while taken.has("%s (%d)" % [base, n]):
		n += 1
	return "%s (%d)" % [base, n]


## El paraje del mismo oficio más cercano a un punto, si hay alguno a menos de
## [MERGE_RANGE]. Es lo que evita bautizar tres veces la misma ladera.
##
## `same_patch`, si se da, es un `Callable(Vector3, Vector3) -> bool` que
## dice si dos puntos son EL MISMO trozo de terreno andable -normalmente
## "misma zona de la rejilla de navegacion"-. Sin ella, dos celdas a un
## lado y otro de un rio pueden caer dentro del radio y fundirse en un solo
## paraje que atraviesa el agua, que no es como se lee un sitio de verdad.
## Con ella, el radio de fusion puede ser generoso -un mismo bosque no cabe
## en tres celdas- sin miedo a que el generoso sea el problema: lo que de
## verdad separa dos sitios no es la distancia, es si se puede ir de uno a
## otro sin cruzar nada.
func near(activity: Subsistence.Activity, point: Vector3,
		range_m: float = MERGE_RANGE, same_patch: Callable = Callable()) -> Paraje:
	var best: Paraje = null
	var best_distance := range_m
	for paraje: Paraje in list:
		if not paraje.serves(activity):
			continue
		var flat := Vector2(point.x - paraje.position.x, point.z - paraje.position.z)
		var distance := flat.length()
		if distance >= best_distance:
			continue
		if same_patch.is_valid() and not same_patch.call(paraje.position, point):
			continue
		best_distance = distance
		best = paraje
	return best


## Si este punto YA ES un paraje de este oficio, devuelve cuál.
##
## Es la pregunta de «¿esto es un sitio nuevo o el de siempre?», y la contesta
## LA FORMA del paraje —ver [Huella]— en vez de un radio fijo de trescientos
## veinte metros.
##
## El radio fijo era el motivo de que no naciera un paraje nuevo NUNCA. Con
## ocho parajes repartidos en seiscientos metros alrededor del abrigo, un
## círculo de fusión de 320 m alrededor de cada uno tapaba todo lo que un
## batidor podía alcanzar: medido con `HallazgoProbe`, treinta jornadas con
## CERO celdas libres para bautizar, por muy bien que se conociera el monte.
##
## Y la forma contesta mejor, además. Es autocorrectora: un avellanar ancho
## tiene una huella ancha y se traga las celdas de al lado —que son él mismo—,
## mientras que dos manchas separadas de verdad no se tapan aunque estén a
## doscientos metros. Un paraje recién nacido, que todavía no tiene forma
## sacada, cae al disco de su radio; ver [Paraje.contains].
func cubre(activity: Subsistence.Activity, point: Vector3,
		same_patch: Callable = Callable()) -> Paraje:
	for paraje: Paraje in list:
		if not paraje.serves(activity):
			continue
		# Dentro de su forma, o dentro de su radio nominal: lo que sea mayor.
		#
		# El radio hace falta además de la forma. La forma la recorta el
		# terreno, así que dos celdas del mismo pastizal separadas por un
		# reguero salen fuera la una de la otra y se bautizan por separado:
		# medido, CUATRO «pastos» naciendo a la vez dentro del mismo círculo de
		# doscientos sesenta metros. Un paraje no empieza a doscientos metros
		# del anterior; su radio es lo que mide el sitio.
		if not paraje.contains(point) 				and paraje.distance_from(point) > paraje.extent:
			continue
		if same_patch.is_valid() and not same_patch.call(paraje.position, point):
			continue
		return paraje
	return null


## A qué distancia dos hallazgos son EL MISMO SITIO, aunque sean de oficios
## distintos, en metros.
##
## Más corta que [MERGE_RANGE] a propósito: aquélla agrupa un mismo bosque,
## que es ancho; ésta responde a otra pregunta —«¿es literalmente el mismo
## punto?»— y con celdas de 64 m, 150 cubre el mismo cuadro y el de al lado
## sin tragarse dos sitios que de verdad son distintos.
const SITE_RANGE := 150.0


## El paraje que ocupa este sitio, sea del oficio que sea.
##
## Es lo que impide que un mismo recodo salga tres veces con tres nombres
## -«el pasto», «el raizal» y «el desmogadero» del mismo recodo- cuando lo
## que hay es UN sitio donde se pueden hacer tres cosas.
func at_site(point: Vector3, same_patch: Callable = Callable()) -> Paraje:
	var best: Paraje = null
	var best_distance := SITE_RANGE
	for paraje: Paraje in list:
		var flat := Vector2(point.x - paraje.position.x, point.z - paraje.position.z)
		var distance := flat.length()
		if distance >= best_distance:
			continue
		if same_patch.is_valid() and not same_patch.call(paraje.position, point):
			continue
		best_distance = distance
		best = paraje
	return best


## Los parajes de una actividad, del más cercano al más lejano.
## El paraje cuya mancha cubre este punto, si hay alguno.
##
## A diferencia de `near`, no filtra por actividad ni usa el margen de
## fusion: usa el radio REAL del sitio, que es lo que se pinta en el mundo.
## Es lo que hace que un clic en cualquier trozo de la mancha -no solo en la
## chapa flotante del centro- se entienda como "este paraje" y no como
## terreno suelto.
func at(point: Vector3) -> Paraje:
	var best: Paraje = null
	var best_distance := INF
	for paraje: Paraje in list:
		if not paraje.contains(point):
			continue
		var distance := paraje.distance_from(point)
		if distance < best_distance:
			best_distance = distance
			best = paraje
	return best


func of(activity: Subsistence.Activity, home: Vector3) -> Array[Paraje]:
	var out: Array[Paraje] = []
	for paraje: Paraje in list:
		if paraje.serves(activity):
			out.append(paraje)
	out.sort_custom(func(a: Paraje, b: Paraje) -> bool:
		return a.distance_from(home) < b.distance_from(home))
	return out


## El que el jugador ha elegido para una actividad, o null si no ha elegido.
func chosen_for(activity: Subsistence.Activity) -> Paraje:
	for paraje: Paraje in list:
		if paraje.chosen and paraje.serves(activity):
			return paraje
	return null


## Elige uno y desmarca los que hicieran ALGUNO de sus oficios: la cuadrilla
## de cada cosa va junta o no va, y un sitio que sirve para tres cosas
## sustituye a los tres que hubiera elegidos antes.
func choose(paraje: Paraje) -> void:
	for other: Paraje in list:
		if other == paraje:
			continue
		for activity_key: int in paraje.activities:
			if other.serves(activity_key as Subsistence.Activity):
				other.chosen = false
				break
	paraje.chosen = true
	paraje.resting = false


func clear_choice(activity: Subsistence.Activity) -> void:
	for paraje: Paraje in list:
		if paraje.serves(activity):
			paraje.chosen = false


## Revisa el conocimiento y bautiza lo que se haya ganado un nombre.
##
## Devuelve cuántos se han añadido. Se llama una vez por jornada: recorre las
## celdas del campo, que son 4.096, y hacerlo por fotograma fue lo que se
## comió el rendimiento la primera vez que se intentó algo parecido.
##
## `terrain` es opcional -las pruebas bautizan sin terreno de verdad-, pero
## sin él la posición nace con Y=0: `cell_center` no sabe de relieve. Un
## paraje así es un destino que nadie puede llegar a pisar, porque «llegar»
## se mide en 3D y la persona anda a la altura real del terreno. Se veía como
## una batida que sale, se planta a un puñado de metros del sitio y no hay
## forma de que la jornada se dé nunca por terminada.
##
## `same_patch`, si se da, se pasa tal cual a [near]: ver la nota de ahí
## para por qué la fusión necesita algo más que una distancia.
## Repasa el mapa y bautiza lo que se haya ganado un nombre.
##
## `centro` y `radio` acotan el barrido a un trozo. Sirve para bautizar EN EL
## MOMENTO en que alguien descubre algo —al terminar de reconocer, al dar con lo
## que se venía a buscar— en vez de esperar al cierre de la jornada.
##
## Hacía falta y era la queja del jugador: «los parajes deben aparecer a medida
## que se descubran; ahora mismo aparecen todos a la vez cuando llegan las 12 de
## la noche». Salían de golpe porque el único que bautizaba era el repaso de fin
## de día. Sin acotar, el barrido recorre las 4.096 celdas del campo y hacerlo
## a cada hallazgo se comería el rendimiento; acotado a la vuelta de quien lo ha
## encontrado son unas pocas decenas.
func refresh(field: ResourceField, knowledge: BandKnowledge,
		day: int, activities: Array, terrain: TerrainGenerator = null,
		same_patch: Callable = Callable(),
		centro: Vector3 = Vector3.ZERO, radio: float = 0.0,
		tope: int = 0) -> int:
	if field == null or knowledge == null:
		return 0

	var added := 0
	var candidatas: Array[Dictionary] = []
	for activity_key: int in activities:
		var activity := activity_key as Subsistence.Activity
		# La caza pide mas abundancia que las demas para siquiera nombrarse:
		# sin esto nacian "pastos" -parajes de caza- en cualquier celda con un
		# roce de animales, que es la misma queja que en `fill_contents`.
		var worth := maxf(WORTH_NAMING, threshold_for(activity))
		for z in range(field.height):
			for x in range(field.width):
				if field.abundance_cell(activity, x, z) < worth:
					continue
				var centre := field.cell_center(x, z)
				if radio > 0.0 and Vector2(centre.x - centro.x,
						centre.z - centro.z).length() > radio:
					continue
				if knowledge.familiarity_at(activity, centre) < NAMED_AT:
					continue

				candidatas.append({"act": activity, "x": x, "z": z,
					"centre": centre,
					"hay": field.abundance_cell(activity, x, z)})

	# Y AHORA se bautiza, de lo mejor a lo peor y con tope.
	#
	# El tope es lo que hace que los sitios salgan de uno en uno y no en
	# racimo: una jornada de reconocimiento cubre doscientos sesenta metros y
	# ahi caben siete sitios con nombre, asi que sin tope el jugador ve siete
	# chapas aparecer de golpe -medido: cuatro «pastos» y tres mas, todos a las
	# 16:10 del dia 2-. Quien vuelve de mirar el monte trae UN sitio, y los
	# demas se quedan para la siguiente vuelta.
	#
	# Sin tope -el repaso de fin de jornada- se bautiza todo lo que quede.
	candidatas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["hay"]) > float(b["hay"]))
	for c: Dictionary in candidatas:
		if tope > 0 and added >= tope:
			break
		var activity := c["act"] as Subsistence.Activity
		var centre: Vector3 = c["centre"]
		# Si ya hay uno del mismo oficio cerca Y EN EL MISMO TROZO DE MONTE,
		# es EL MISMO sitio: se deja crecer el que estaba en vez de bautizar
		# el vecino. Varios avellanares a un tiro de piedra son un solo
		# avellanar; uno al otro lado del rio, aunque quede cerca en linea
		# recta, es otro.
		if cubre(activity, centre, same_patch) != null:
			continue

		# Y en el agua no se bautizan avellanares. Se mira ANTES de buscarle
		# sitio: si el suelo no da para esta actividad, no hay paraje que abrir
		# ni al que sumarsela.
		if terrain and not activity_fits(activity,
				terrain.crossing_difficulty_at(centre)):
			continue

		# Si lo que hay en este punto es un paraje de OTRO oficio, tampoco se
		# bautiza otro: se le suma el oficio al que ya esta. Un recodo con
		# caza, raiz y cuerna caida es UN sitio donde se hacen tres cosas, no
		# tres parajes pisandose -«el pasto del recodo», «el raizal del recodo»
		# y «el desmogadero del recodo» eran el mismo trozo de monte tres
		# veces.
		#
		# Pero eso vale entre oficios DE TIERRA: el remanso del rio y el
		# avellanar de la orilla no son el mismo sitio aunque queden a cien
		# metros, y fundirlos daba justo lo que se veia en la partida -un
		# paraje de pesca que abarca tierra, o un avellanar que cruza el rio-.
		# El criterio es el suelo del anfitrion: si la actividad nueva no se
		# puede hacer donde el esta, no es su sitio. Ver [activity_fits].
		var host := at_site(centre, same_patch)
		if host != null and activity_fits(activity, host.ford):
			host.add_activity(activity)
			continue

		if bautizar(field, activity, int(c["x"]), int(c["z"]),
				centre, day, terrain) != null:
			added += 1

	# Y la forma de todos, al dia. No es solo de los recien nacidos -esos ya la
	# sacan en `bautizar`-: la mancha cambia con la estacion -un avellanar en
	# enero no ocupa lo que en octubre- y con lo que se saca. Solo en el repaso
	# COMPLETO: los acotados son muchos al dia y esto se reparte por jornadas.
	if radio <= 0.0:
		retocar_huellas(field, terrain)
	return added


## Cuanto se gasta como mucho en rehacer formas de una vez, en milisegundos.
##
## Sacar la forma de los siete parajes de una partida recien empezada cuesta
## quince milisegundos y medio -medido con `HuellaProbe`-, y eso es un cuadro
## entero de tiron una vez al dia. A velocidad ultra, donde un dia son cuatro
## cuadros, se nota de verdad.
##
## Asi que se reparte, igual que [HornoDeRejillas] amasa las rejillas: cada
## repaso gasta lo suyo y deja el resto para el siguiente. La forma de un sitio
## no tiene por que estar al dia HOY -cambia con la estacion, que dura cuarenta
## y cinco jornadas- pero la de un paraje RECIEN NACIDO si, porque sin ella no
## se puede ir a trabajar a el.
const MS_POR_REPASO := 2.0

## Por donde iba el repaso. Da la vuelta a la lista sin dejarse ninguno.
var _por_retocar: int = 0


## Vuelve a sacar la forma de los parajes, a ratos. Devuelve cuantas ha hecho.
func retocar_huellas(field: ResourceField, terrain: TerrainGenerator) -> int:
	if field == null or list.is_empty():
		return 0

	# Los recien nacidos, siempre y todos: un paraje sin forma no existe para
	# nadie y no se puede trabajar en el.
	var hechas := 0
	for paraje: Paraje in list:
		if paraje.huella == null:
			paraje.retocar(field, terrain)
			hechas += 1

	var hasta := Time.get_ticks_usec() + int(MS_POR_REPASO * 1000.0)
	for vuelta in range(list.size()):
		if Time.get_ticks_usec() >= hasta:
			break
		_por_retocar = (_por_retocar + 1) % list.size()
		list[_por_retocar].retocar(field, terrain)
		hechas += 1
	return hechas


## Qué parte de lo ya encontrado se sabe, de 0 a 1.
##
## Es la cobertura DE LA BATIDA: su trabajo es acabar de conocer los sitios que
## la banda ya ha bautizado, así que cuando no queda incógnita, no hace falta.
## Sin ningún paraje todavía no hay nada que batir y devuelve uno. Ver
## `Reparto._speciality_pressure`.
func fraccion_sabida() -> float:
	if list.is_empty():
		return 1.0
	var suma := 0.0
	for paraje: Paraje in list:
		suma += paraje.known_fraction()
	return clampf(suma / float(list.size()), 0.0, 1.0)


## Abre un paraje en una celda. Devuelve el paraje, o null si no merecio nombre.
##
## Vive aqui y no dentro de `refresh` porque son DOS quienes bautizan: el
## descubrimiento de todos los dias y la vuelta al abrigo del primero -ver
## [Querencia]-. Con el codigo dentro del barrido, la siembra del dia uno tenia
## que llamar al barrido entero para abrir un sitio, y el barrido abre todos los
## que pasen el liston: por eso el jugador veia salir doce parajes el primer dia
## cuando lo pedido era uno de cada oficio.
func bautizar(field: ResourceField, activity: Subsistence.Activity,
		x: int, z: int, centre: Vector3, day: int,
		terrain: TerrainGenerator = null) -> Paraje:
	var punto := centre
	if terrain:
		punto.y = terrain.get_height_at(punto)

	var kind := _kind_for(activity, punto, GameState.season)
	var paraje := Paraje.create(x, z, activity, kind, punto, day)
	# El suelo de debajo, que decide QUE puede haber aqui. Ver
	# `Parajes.material_fits`.
	if terrain:
		paraje.ford = terrain.crossing_difficulty_at(punto)
	# Se rellena lo que hay ahi al bautizarlo, aunque casi todo quede como
	# incognita: la lista de lo que FALTA por saber es la que le da sentido a
	# volver.
	paraje.fill_contents(field, GameState.season)

	# Y el nombre lo pone lo que MAS ABUNDA, no lo que tocaba por actividad: un
	# sitio con cuatro veces mas raiz que avellana es un raizal aunque se
	# bautizara mirando la recoleccion en otoño. Se hace antes de `add`, que es
	# quien fija el rotulo. Sin contar la leña y la fibra, que se meten en TODOS
	# los parajes con una pizca fija de nada: un sitio cuyo unico nombre posible
	# es «el leñero» no es un sitio, es una celda que ha pasado el umbral de otra
	# cosa que ahora mismo no esta -cuerna caida en verano, por ejemplo. Se deja
	# sin bautizar y ya se bautizara cuando de verdad tenga algo.
	var richest := _richest_named(paraje, true)
	if richest < 0:
		return null
	paraje.kind = richest as Materia.Kind
	if not add(paraje):
		return null
	paraje.retocar(field, terrain)
	return paraje


## Por debajo de esto una veta se da por agotada. No es cero: el ultimo 4%
## de un cantizal es polvo y lascas rotas, no piedra de tallar.
const EXHAUSTED := 0.04


## Quita un paraje de la lista. Devuelve si de verdad estaba.
func remove(paraje: Paraje) -> bool:
	var index := list.find(paraje)
	if index < 0:
		return false
	list.remove_at(index)
	_by_id.erase(paraje.id())
	just_found.erase(paraje)
	return true


## Pasa cuenta de las vetas agotadas.
##
## Peticion literal: «si un producto no sostenible se agota y es el que
## nombra un paraje, el paraje desaparece; podra volver a salir un paraje en
## ese punto con otro material».
##
## Lo que se hace es lo unico honrado: si lo que da nombre al sitio es de lo
## que no vuelve a crecer -[Materia.VETAS]- y de verdad ya no queda,
## se seca la mancha en el campo de recursos -[ResourceField.exhaust], que
## le quita la CAPACIDAD y no solo las existencias, para que `regrow` no lo
## resucite- y se le quita el oficio al paraje. Si no le quedaba otro, el
## paraje desaparece; el punto sigue ahi y `refresh` podra volver a
## bautizarlo mas adelante por otra cosa -un avellanar donde estuvo el
## cantizal-, porque ya no hay nada que lo reclame.
##
## Devuelve una lista de `{paraje, kind, gone}` para que la cronica lo
## cuente: perder un sitio con nombre es noticia.
func prune_exhausted(field: ResourceField) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	if field == null:
		return news

	for paraje: Paraje in list.duplicate():
		if Materia.renews(paraje.kind):
			continue
		var activity := activity_for_kind(paraje.kind)
		if activity < 0:
			continue
		# Se mira la celda NUCLEO y no la mancha entera. Una veta de silex no
		# ocupa el redondel completo: al lado puede haber un desmogadero, que
		# se repone cada invierno, y promediando los dos el silex nunca daba
		# por agotado -medido: ochocientos dias, nueve mil unidades sacadas y
		# la mancha estancada en el 5%, subiendo y bajando con la cuerna.
		var act := activity as Subsistence.Activity
		var left := field.stock_fraction(act, paraje.cell_x, paraje.cell_z)
		if left > EXHAUSTED:
			continue

		# Y se seca solo lo que era de ESTE material, no el redondel entero:
		# la cuerna caida del vecino no tiene la culpa de que se acabara el
		# silex.
		var spent := paraje.kind
		# Se seca LA MANCHA, no el redondel: un paraje de pesca que se agota
		# deja seco el tramo de rio que era, no la ladera de al lado.
		for cell: Vector2i in field.cells_within(paraje.position,
				Huella.alcance_de(paraje)):
			var centre := field.cell_center(cell.x, cell.y)
			if not paraje.contains(centre):
				continue
			if _kind_for(act, centre,
					GameState.season as Subsistence.Season) != spent:
				continue
			field.dry_cell(act, cell.x, cell.y)

		# El sitio puede seguir vivo por otra cosa: un cantizal que ademas era
		# pasto no desaparece, deja de ser cantizal.
		_by_id.erase(paraje.id())
		paraje.activities.erase(int(activity))
		paraje.contents.erase(int(spent))
		if paraje.activities.is_empty():
			var index := list.find(paraje)
			if index >= 0:
				list.remove_at(index)
			news.append({"paraje": paraje, "kind": spent, "gone": true})
			continue

		# Y si lo que queda no tiene ni palabra de sitio, tampoco hay sitio:
		# un paraje sin nada que lo nombre no es un paraje.
		#
		# La leña y la fibra no valen para esto. Se meten en TODOS los parajes
		# con una pizca fija, asi que siempre queda algo, y el cantizal
		# agotado sobrevivia como «el leñero del alto»: un sitio nuevo con
		# nombre nuevo que no le importa a nadie, justo donde el jugador
		# tenia que notar una perdida.
		# EL OFICIO PRINCIPAL PASA AL QUE SOBREVIVE, y ANTES de renombrar.
		#
		# Sin esto, el cantizal agotado que ademas era pasto seguia teniendo
		# `activity` en materia prima mientras se le buscaba nombre nuevo, y
		# desde que el nombre sale del oficio -«un sitio de caza se llama por
		# la caza»- se quedaba con el nombre de lo que acababa de agotarse.
		if not paraje.activities.is_empty():
			paraje.activity = paraje.activities[0] as Subsistence.Activity

		var richest := _richest_named(paraje, true)
		if richest < 0:
			var orphan := list.find(paraje)
			if orphan >= 0:
				list.remove_at(orphan)
			news.append({"paraje": paraje, "kind": spent, "gone": true})
			continue

		paraje.activity = paraje.activities[0] as Subsistence.Activity
		paraje.kind = richest as Materia.Kind
		paraje.name_text = _free_name(paraje)
		_by_id[paraje.id()] = paraje
		news.append({"paraje": paraje, "kind": spent, "gone": false})

	return news


## Umbral de abundancia por debajo del cual una actividad NO cuenta en un
## paraje. La caza pide mucho más que las demás a propósito: es la petición
## literal de que solo aparezcan animales si de verdad los hay, no en
## cualquier celda que roce el mínimo general -que es bajo porque casi
## cualquier celda da ALGO de recolección, y eso sí es realista.
const CAZA_THRESHOLD := 0.28
const DEFAULT_THRESHOLD := 0.08

static func threshold_for(activity: Subsistence.Activity) -> float:
	return CAZA_THRESHOLD if activity == Subsistence.Activity.CAZA else DEFAULT_THRESHOLD


## El material MÁS ABUNDANTE de un paraje, de entre los que tienen palabra
## de sitio -[Paraje.APODOS]-. -1 si ninguno la tiene.
##
## Es lo que da nombre: la gente llama a un sitio por lo que más hay en él,
## no por el oficio con el que se dio con él. La leña y la fibra, que se
## meten en todos los parajes con una pizca fija de nada, quedan fuera de la
## puja salvo que no haya otra cosa: si no, medio valle sería «el leñero».
## `sin_relleno` las deja fuera del todo, y no solo con menos peso: sirve
## para decidir si al paraje le queda ALGO que lo nombre, donde «un poco de
## leña» no es respuesta.
static func _richest_named(paraje: Paraje, sin_relleno: bool = false) -> int:
	# DOS VUELTAS: primero lo que es DE SU OFICIO y, si no hay nada, lo que
	# haya.
	#
	# El nombre salia de lo que mas abundara, fuera de la actividad que fuera, y
	# de ahi «El raizal de la vega - Caza»: un sitio bautizado por la caza y
	# llamado por la raiz. Un paraje de caza es un sitio DONDE SE CAZA y se
	# tiene que llamar como lo que se caza; que ademas tenga raiz se ve en su
	# ficha, que para eso esta.
	var suyo := _mas_abundante(paraje, sin_relleno, true)
	if suyo >= 0:
		return suyo
	# Y si de lo suyo todavia no se sabe nada -un cotarro recien encontrado
	# tiene la caza por descubrir-, se llama POR SU OFICIO igual. Un sitio de
	# caza es «el pasto» aunque no se sepa todavia que anda por el; lo que no
	# puede es llamarse «el raizal», porque entonces el jugador lee una cosa y
	# manda alli a otra.
	return material_que_da_nombre(paraje.activity)


## El material con el que se bautiza un oficio cuando no hay nada mejor.
##
## Es el material CARACTERISTICO de la actividad, no el mas abundante del sitio.
## Ver [Paraje.APODOS], que es quien lo convierte en nombre.
static func material_que_da_nombre(activity: Subsistence.Activity) -> int:
	match activity:
		Subsistence.Activity.CAZA: return Materia.Kind.CARNE
		Subsistence.Activity.PESCA: return Materia.Kind.PESCADO
		Subsistence.Activity.MARISQUEO: return Materia.Kind.MARISCO
		Subsistence.Activity.MATERIA_PRIMA: return Materia.Kind.PIEDRA
		_:
			# La recoleccion cambia de cara con el año: en otoño un avellanar y
			# en invierno un raizal. Ver [RECOLECCION_NAMING_BY_SEASON].
			return int(RECOLECCION_NAMING_BY_SEASON.get(
				GameState.season, Materia.Kind.RAIZ))


static func _mas_abundante(paraje: Paraje, sin_relleno: bool,
		solo_del_oficio: bool) -> int:
	var best := -1
	var best_amount := -1.0
	for kind_key: int in paraje.contents:
		if not Paraje.APODOS.has(kind_key):
			continue
		if solo_del_oficio and activity_for_kind(kind_key as Materia.Kind) 				!= int(paraje.activity):
			continue
		var relleno := kind_key == Materia.Kind.LENA or kind_key == Materia.Kind.FIBRA
		if relleno and sin_relleno:
			continue
		var amount := float((paraje.contents[kind_key] as Dictionary)["abundancia"])
		if relleno:
			amount *= 0.1
		if amount > best_amount:
			best_amount = amount
			best = kind_key
	return best


## En qué estaciones se puede encontrar cada extra, aparte de lo que ya
## varía por sí solo -RECOLECCION_NAMING_BY_SEASON, que decide el que da
## nombre-. Lo que no aparece aquí se considera de todo el año -corteza,
## leña, fibra, piedra...-.
##
## Petición explícita: "los cuernos caídos de los animales solo ocurren en
## una temporada, o hay temporadas en las que no hay ciertos materiales".
## El desmogue -las cuernas que se le caen al ciervo- es a finales de
## invierno, no un recurso permanente del cantizal; la miel es de verano,
## la bellota y la seta de otoño, el huevo de la cría en primavera.
## FRUTO_SECO SÍ está, desde el repaso del calendario. Antes no estaba porque
## `_gathering_yields` le daba rendimiento en las cuatro estaciones y la fila
## habría dicho una cosa mientras el zurrón hacía otra. Ahora las dos dicen lo
## mismo: la avellana es de otoño y en marzo no hay.
const SEASONAL_EXTRAS := {
	Materia.Kind.ASTA: [Subsistence.Season.INVIERNO],
	Materia.Kind.MIEL: [Subsistence.Season.VERANO],
	Materia.Kind.BELLOTA: [Subsistence.Season.OTONO],
	Materia.Kind.SETA: [Subsistence.Season.OTONO],
	Materia.Kind.HUEVO: [Subsistence.Season.PRIMAVERA],
	Materia.Kind.CARACOL: [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO],
	# La baya YA NO es de primavera: la mora es de agosto, la endrina de
	# octubre y el madroño de noviembre. En primavera el zarzal está en flor.
	Materia.Kind.BAYA: [Subsistence.Season.VERANO, Subsistence.Season.OTONO],
	# Y el fruto seco entra aquí, que es donde tenía que haber estado: la
	# avellana es de septiembre. Salía las cuatro estaciones -seis puñados por
	# jornada en marzo- y era la mitad de la comida del año.
	Materia.Kind.FRUTO_SECO: [Subsistence.Season.OTONO],
	Materia.Kind.RESINA: [Subsistence.Season.VERANO],
}


## Si este material se puede encontrar en esta estación. Los que no están
## en [SEASONAL_EXTRAS] son de todo el año.
static func in_season(kind: Materia.Kind, season: Subsistence.Season) -> bool:
	if not SEASONAL_EXTRAS.has(kind):
		return true
	return (SEASONAL_EXTRAS[kind] as Array).has(season)


## Qué materiales de esta actividad EXISTEN de verdad en este mapa.
##
## No es el surtido teórico de [EXTRAS_BY_ACTIVITY] -eso es el mismo en
## cualquier partida-: es lo que de verdad sale en ESTE campo de recursos,
## mirando cada celda que llega al umbral de nombrarse y lo que
## [_kind_for]/[extra_materials_at] pondrían ahí. Sirve de denominador para
## "cuánto conoce la banda de lo que hay", que si no contaría como
## desconocido un material que ni siquiera existe en este valle.
##
## En recolección se recorren las cuatro estaciones -el avellanar de otoño
## y la raíz de invierno son sitios que aún no se han vivido pero existen
## igual-; en el resto el nombre no cambia con la estación y basta una.
static func materials_on_map(activity: Subsistence.Activity,
		field: ResourceField) -> Array[Materia.Kind]:
	var found: Dictionary = {}
	var worth := maxf(WORTH_NAMING, threshold_for(activity))
	var seasons: Array = [GameState.season] if activity != Subsistence.Activity.RECOLECCION \
		else [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]

	for z in range(field.height):
		for x in range(field.width):
			if field.abundance_cell(activity, x, z) < worth:
				continue
			var centre := field.cell_center(x, z)
			for season: int in seasons:
				var primary := _kind_for(activity, centre, season as Subsistence.Season)
				found[primary] = true
				for extra: Materia.Kind in extra_materials_at(activity, centre, primary):
					found[extra] = true

	var out: Array[Materia.Kind] = []
	for kind: int in found:
		out.append(kind as Materia.Kind)
	return out


## El material que da nombre al sitio segun la temporada. Es el
## característico de la actividad —no todo lo que se saca, un avellanar da
## también leña y fibra— y en recolección cambia de verdad con la estación:
## en marzo no hay avellana que recoger, hay raíz.
const RECOLECCION_NAMING_BY_SEASON := {
	Subsistence.Season.PRIMAVERA: Materia.Kind.RAIZ,
	Subsistence.Season.VERANO: Materia.Kind.BAYA,
	Subsistence.Season.OTONO: Materia.Kind.FRUTO_SECO,
	Subsistence.Season.INVIERNO: Materia.Kind.RAIZ,
}

## Materia prima SÍ varía por sitio y no por estación -una piedra no sabe
## qué mes es-: un cantizal, una veta de sílex, una veta de ocre y un
## desmogadero son cuatro sitios distintos aunque las cuatro sean "materia
## prima". Se elige determinista por posición, igual que la fauna.
const MATERIA_PRIMA_NAMES := [Materia.Kind.PIEDRA, Materia.Kind.SILEX,
	Materia.Kind.OCRE, Materia.Kind.ASTA]

## La bolsa de la que se saca cuál de los cuatro es cada sitio.
##
## No es la lista de arriba tal cual porque el sorteo no es a partes iguales:
## a cuatro nombres con la misma papeleta salía un cantizal de cada cuatro
## sitios de materia prima, y el valle se llenaba de cantizales. Petición
## literal: «hay demasiado cantizal, reduce ligeramente su proporción». La
## cuarcita baja de uno de cada cuatro a uno de cada cinco; los otros tres se
## reparten lo que suelta.
const MATERIA_PRIMA_POOL := [
	Materia.Kind.PIEDRA, Materia.Kind.PIEDRA, Materia.Kind.PIEDRA,
	Materia.Kind.SILEX, Materia.Kind.SILEX, Materia.Kind.SILEX,
	Materia.Kind.SILEX,
	Materia.Kind.OCRE, Materia.Kind.OCRE, Materia.Kind.OCRE,
	Materia.Kind.OCRE,
	Materia.Kind.ASTA, Materia.Kind.ASTA, Materia.Kind.ASTA,
	Materia.Kind.ASTA,
]

## Lo que ADEMÁS puede haber en un paraje de esta actividad, aparte de lo que
## le da nombre. No decide el nombre: solo dice qué más se encontraría
## pasando por ahí, para que un paraje no sea un único material repetido
## De donde sale cada material: del agua, de tierra firme, o de cualquiera.
##
## Es la regla que faltaba. `Paraje.fill_contents` recorre las CINCO
## actividades y mete lo que pase el umbral de cada una sin mirar el suelo que
## hay debajo, asi que una celda del cauce que llegue al umbral de recoleccion
## sale con corteza, bellota, resina y ocre EN MEDIO DEL RIO. Medido en el
## sitio 56 con `scripts/tests/ParajeProbe.gd`: los 41 parajes que caen en agua
## llevaban material de tierra, 272 entradas en total, y 103 parajes de tierra
## llevaban pescado o marisco.
##
## Lo que NO esta en ninguna de las dos listas vale en los dos sitios, y eso es
## deliberado: la piedra de un vado son cantos rodados -que es justo lo que se
## coge de un rio- y el hueso, la piel o la pluma salen de un animal, que puede
## haber caido en cualquier parte.
const SOLO_DE_AGUA := [Materia.Kind.PESCADO, Materia.Kind.MARISCO,
	Materia.Kind.CONCHA, Materia.Kind.AGUA]

const SOLO_DE_TIERRA := [Materia.Kind.CORTEZA, Materia.Kind.BELLOTA,
	Materia.Kind.FRUTO_SECO, Materia.Kind.RAIZ, Materia.Kind.SETA,
	Materia.Kind.MIEL, Materia.Kind.BAYA, Materia.Kind.LENA, Materia.Kind.YESCA,
	Materia.Kind.RESINA, Materia.Kind.ASTA, Materia.Kind.OCRE,
	Materia.Kind.FIBRA]

## Los dos umbrales de mojado, que NO son el mismo y por eso hay dos.
##
## [EN_EL_AGUA] es donde se deja de cruzar sin mojarse -el mismo
## [Hydrography.FORD_WADEABLE] con el que anda la banda-. Sirve para decidir si
## se puede TRABAJAR ahi: se vadea, se marisquea con los pies dentro.
##
## [SUELO_SECO] es donde deja de haber agua, y va mucho mas abajo: es el mismo
## 0,15 con el que `SettlementSim._water_beside` dice «aqui hay agua». Sirve
## para decidir si CRECE algo: una planta no distingue entre agua que te llega
## al tobillo y agua que te llega a la cintura, en las dos se ahoga.
##
## Con un umbral solo -el de vadear- quedaban 113 entradas de corteza, resina y
## ocre en puntos de vadeo 0,32: agua somera, por debajo del limite de cruzar,
## donde no hay arbol que descortezar.
const EN_EL_AGUA := Hydrography.FORD_WADEABLE
const SUELO_SECO := 0.15


## Si este material puede salir de un punto con este vadeo.
static func material_fits(kind: Materia.Kind, ford: float) -> bool:
	if ford > SUELO_SECO and SOLO_DE_TIERRA.has(kind):
		return false
	# Y en seco no hay pescado. La orilla SI cuenta como agua para esto: se
	# marisquea con los pies en el borde, no nadando.
	if ford <= 0.05 and SOLO_DE_AGUA.has(kind):
		return false
	return true


## Si esta actividad se puede hacer en un punto con este vadeo.
##
## Un paraje de pescadores cubre el rio y su orilla y no se estira ladera
## arriba; uno de recoleccion no se mete en el cauce. Sin esto, un mismo punto
## del rio se bautizaba como avellanar, como cotarro de caza y como pesquera a
## la vez, y las tres cosas eran mentira menos una.
static func activity_fits(activity: Subsistence.Activity, ford: float) -> bool:
	match activity:
		Subsistence.Activity.PESCA, Subsistence.Activity.MARISQUEO:
			# Hace falta agua, aunque sea la del borde.
			return ford > 0.05
		Subsistence.Activity.RECOLECCION, Subsistence.Activity.CAZA:
			# Y aqui hace falta suelo SECO, no solo suelo que se pueda vadear.
			#
			# Estuvo en [EN_EL_AGUA] -0,35, el limite de cruzar sin nadar- y eso
			# deja bautizar avellanares con el agua por el tobillo: un sitio que
			# se puede CRUZAR no es un sitio donde CRECE algo. La queja del
			# jugador -«parajes de recoleccion que cruzan el rio»- sale de aqui.
			# El umbral bueno es el mismo con el que se decide si una planta se
			# ahoga. Ver [SUELO_SECO].
			return ford <= SUELO_SECO
		_:
			# La materia prima sale de los dos: cantos del vado y cuarcita del
			# canchal son la misma columna del almacen.
			return true


## Lo que ADEMAS se encuentra en un sitio de cada actividad, aparte de lo que
## lo bautiza. El surtido teorico: es el mismo en cualquier partida, y lo que
## de verdad sale en ESTE valle lo dice `materials_on_map`.
const EXTRAS_BY_ACTIVITY := {
	Subsistence.Activity.RECOLECCION: [Materia.Kind.SETA, Materia.Kind.MIEL,
		Materia.Kind.CARACOL, Materia.Kind.HUEVO, Materia.Kind.CORTEZA,
		Materia.Kind.BELLOTA, Materia.Kind.FRUTO_SECO, Materia.Kind.BAYA,
		Materia.Kind.RAIZ,
		# La yesca y la resina las trae el de leña y fibra, que es
		# recolección aunque suenen a materia prima. Estaban solo en la
		# lista de materia prima, así que las traía a casa y no salían en
		# la ficha de ningún prado.
		Materia.Kind.YESCA, Materia.Kind.RESINA],
	Subsistence.Activity.CAZA: [Materia.Kind.PIEL, Materia.Kind.HUESO,
		Materia.Kind.TENDON, Materia.Kind.GRASA],
	# La grasa del salmon grande. Sale solo con arpon y con red -ver
	# `Fishing`-, pero tiene que estar en la lista igual: lo que se puede
	# traer de un sitio tiene que salir en la ficha del sitio.
	Subsistence.Activity.PESCA: [Materia.Kind.GRASA],
	Subsistence.Activity.MARISQUEO: [Materia.Kind.CONCHA, Materia.Kind.CARACOL],
	Subsistence.Activity.MATERIA_PRIMA: [Materia.Kind.YESCA, Materia.Kind.RESINA],
}

## Cuántos extras como mucho, aparte del que da nombre.
##
## No es cuántos materiales hay: es cuántos hay EN CANTIDAD. Lo demás del
## surtido de la actividad también está —y también se lo trae quien pasa por
## allí— pero de rebusca, en la proporción de [DE_PASO].
const MAX_EXTRAS := 2

## Lo que se saca de rebusca, respecto a lo que da el material principal.
##
## Petición literal: «no sé de dónde están sacando frutos secos, bayas,
## bellotas, setas... cuando ningún paraje muestra que lo tiene; deberían
## aparecer en los parajes».
##
## Y tenía razón: la cosecha da la cesta ENTERA de la especialidad en
## cualquier sitio —`SettlementSim.SPECIALITY_YIELDS`— mientras la ficha del
## paraje enseñaba el material que lo bautiza y dos extras. Ocho cosas en el
## zurrón y tres en la ficha. Ahora sale todo lo que de verdad se puede sacar
## allí; lo que no es principal ni extra sale con esta pizca, que es poca a
## propósito: sirve para que la ficha no mienta, no para que todos los prados
## del valle parezcan el mismo.
const DE_PASO := 0.15


## A qué actividad pertenece un material, para poder preguntar cuánto queda
## de él -ver `SettlementSim.remaining_units`, que necesita la actividad y
## no solo el material-. -1 si no viene de ninguna en concreto: la leña y la
## fibra salen de cualquier sitio de paso, no tienen actividad propia.
static func activity_for_kind(kind: Materia.Kind) -> int:
	match kind:
		Materia.Kind.CARNE: return Subsistence.Activity.CAZA
		Materia.Kind.PESCADO: return Subsistence.Activity.PESCA
		Materia.Kind.MARISCO: return Subsistence.Activity.MARISQUEO

	if MATERIA_PRIMA_NAMES.has(kind):
		return Subsistence.Activity.MATERIA_PRIMA
	for season_kind: Materia.Kind in RECOLECCION_NAMING_BY_SEASON.values():
		if season_kind == kind:
			return Subsistence.Activity.RECOLECCION
	for activity: int in EXTRAS_BY_ACTIVITY:
		if (EXTRAS_BY_ACTIVITY[activity] as Array).has(kind):
			return activity
	return -1


## El material que da nombre al sitio. Determinista por sitio y estación
## -en recolección- o por sitio solo -en materia prima-: la misma celda da
## siempre el mismo nombre en la misma estación, igual que antes.
static func _kind_for(activity: Subsistence.Activity, position: Vector3,
		season: Subsistence.Season) -> Materia.Kind:
	match activity:
		Subsistence.Activity.CAZA: return Materia.Kind.CARNE
		Subsistence.Activity.PESCA: return Materia.Kind.PESCADO
		Subsistence.Activity.MARISQUEO: return Materia.Kind.MARISCO
		Subsistence.Activity.MATERIA_PRIMA:
			return _pick_deterministic(MATERIA_PRIMA_POOL, position, 0)
		_:
			return RECOLECCION_NAMING_BY_SEASON.get(season, Materia.Kind.FRUTO_SECO)


## Qué más hay en un paraje de esta actividad, aparte de lo que le da
## nombre. Hasta [MAX_EXTRAS], determinista por sitio: el mismo paraje no
## cambia de surtido mirándolo dos veces.
static func extra_materials_at(activity: Subsistence.Activity, position: Vector3,
		primary: Materia.Kind) -> Array[Materia.Kind]:
	var pool: Array = (EXTRAS_BY_ACTIVITY.get(activity, []) as Array).duplicate()
	pool.erase(primary)
	if pool.is_empty():
		return []

	var seed_value := absi(int(position.x) * 73856093 ^ int(position.z) * 19349663
		^ int(activity) * 26261 ^ 999331)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var count := rng.randi_range(0, mini(MAX_EXTRAS, pool.size()))
	var picked: Array[Materia.Kind] = []
	for _i in range(count):
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


## Un pick determinista de una lista, por posición y una sal para no repetir
## la misma tirada que otro sorteo que también use la posición.
static func _pick_deterministic(pool: Array, position: Vector3, salt: int) -> Materia.Kind:
	var seed_value := absi(int(position.x) * 73856093 ^ int(position.z) * 19349663
		^ salt * 83492791)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return pool[rng.randi_range(0, pool.size() - 1)]


## Los rumbos, como se dicen. No «norte»: «hacia el norte» suena a brujula y
## una banda no lleva brujula. Se usan los nombres de viento, que es como se
## ha hablado del rumbo en la costa cantabrica desde siempre.
const RUMBOS := [
	"al norte", "al nordeste", "a levante", "al sudeste",
	"al sur", "al sudoeste", "a poniente", "al noroeste",
]


## Como se llama un punto cualquiera del mapa, tenga nombre o no.
##
## Es lo que hace que la cronica se lea. «Sale partida hacia un punto a 900 m
## del abrigo» no se recuerda; «sale partida a poniente, mas alla del avellanar
## del recodo» si, porque situa el sitio respecto a algo que el jugador conoce.
##
## Por orden: si cae encima de un paraje, ese paraje. Si hay uno cerca, se
## nombra respecto a el. Y si no hay nada conocido, el rumbo y la distancia,
## que es exactamente lo que sabria decir alguien que no ha estado.
func place_name(point: Vector3, home: Vector3) -> String:
	for paraje: Paraje in list:
		var flat := Vector2(point.x - paraje.position.x, point.z - paraje.position.z)
		if flat.length() < MERGE_RANGE:
			return paraje.name_text

	var closest: Paraje = null
	var closest_distance := 700.0
	for paraje: Paraje in list:
		var flat := Vector2(point.x - paraje.position.x, point.z - paraje.position.z)
		var distance := flat.length()
		if distance < closest_distance:
			closest_distance = distance
			closest = paraje

	if closest != null:
		return "%s de %s" % [bearing(closest.position, point), closest.name_text]

	var away := Vector2(point.x - home.x, point.z - home.z).length()
	return "%s del abrigo, a %d m" % [bearing(home, point), int(away)]


## El rumbo de un punto respecto a otro, dicho con nombre de viento.
static func bearing(from_point: Vector3, to_point: Vector3) -> String:
	var delta := Vector2(to_point.x - from_point.x, to_point.z - from_point.z)
	if delta.length() < 1.0:
		return "en"
	# En coordenadas de mundo, -Z es el norte del mapa
	var angle := atan2(delta.x, -delta.y)
	var index := int(round(angle / (TAU / 8.0))) % 8
	if index < 0:
		index += 8
	return RUMBOS[index]
