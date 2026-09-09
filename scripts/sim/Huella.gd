class_name Huella
extends RefCounted
## La forma de verdad de un paraje: la mancha de monte que ocupa.
##
## Un paraje era un punto y un radio, y de ahí la queja del jugador: «¿por qué
## los parajes son círculos? Quiero que puedan ser cualquier forma, así se
## adaptan al río bien también, o a una ribera».
##
## Y tenía razón por partida doble, porque el juego YA sabía dibujar la forma
## buena —[ParajeMarkers] pintaba una mancha irregular sacada del campo de
## recursos— pero era sólo pintura: la simulación seguía preguntando
## `distancia al centro < extent`. Lo que se veía y lo que el juego creía eran
## dos cosas distintas, y la que mandaba era el círculo.
##
## Aquí vive la forma, una sola vez, y la usan los dos.
##
## ## Cómo se saca
##
## De donde de verdad hay lo que hay aquí: las celdillas de alrededor con
## bastante material y con el terreno que le toca al oficio. Irregular por
## construcción, porque el monte lo es. Un paraje de pesca sale como una cinta
## que sigue el cauce; un avellanar, como la mancha de umbría que ocupa.
##
## Pero un paraje es UN SITIO, no un archipiélago. Pintando a pelo lo que da el
## campo salía una mancha agujereada con islas sueltas, y nadie entiende así un
## avellanar: uno dice «el avellanar» señalando un trozo de ladera, con sus
## claros dentro y su borde. Así que la forma se limpia en cuatro pasos, y en
## este orden:
##
##   1. **se ensancha una celdilla**, para que las islas de al lado se peguen
##      al cuerpo en vez de quedarse sueltas —absorberlas, no tirarlas—
##   2. **se vuelve a pasar el filtro de terreno**, porque ensanchar no mira el
##      suelo y el borde de una pesquera se subía a la ladera
##   3. **se queda sólo lo pegado al centro**, que descarta lo que quedó lejos
##      de verdad y es de otro sitio
##   4. **se tapan los agujeros de dentro**, porque un claro en mitad del
##      avellanar sigue siendo avellanar

## Cuánto mide la celdilla de la mancha, en metros.
##
## Veinticinco: fina para que el borde siga la forma del sitio y gruesa para
## que un paraje de doscientos metros no sean mil baldosas.
const CELDILLA := 25.0

## Cuánto se estira la mancha de un sitio DE AGUA a lo largo del cauce.
##
## Es la mitad de lo que pedía el jugador —«así se adaptan al río bien también,
## o a una ribera»— y sale de una medida, no de un gusto. Alrededor de un
## paraje de tierra el campo de recursos es PLANO: «El pasto de la vega» da
## 0,20 en el núcleo y 0,20, 0,20, 0,18 y 0,19 a cuarenta, ochenta, ciento
## veinte y ciento setenta metros. No hay ninguna forma que sacar de ahí, y lo
## que da la forma en tierra es el terreno —el río que la corta, el cantil que
## la para— dentro del radio.
##
## En el agua es lo contrario: «El remanso de la boca» da 0,48 en el núcleo y
## 0,21, 0,09 y 0,05 según se aleja. Hay un cauce de verdad, y una pesquera es
## ESE TRAMO: una cinta, no un disco. Por eso al agua se le deja tres veces su
## radio para estirarse, pero sólo por donde hay agua, que es lo que la hace
## salir cinta y no mancha.
##
## Pendiente de playtest la cifra; lo que no lo está es que el agua se estire y
## la tierra no.
const ESTIRA_LA_CINTA := 3.0

## Esquina de menor x y z del recuadro, en metros.
var origen: Vector3 = Vector3.ZERO

## Celdillas por lado del recuadro.
var lado: int = 0

## Qué celdillas están dentro. Índice `z * lado + x`.
var dentro: PackedByteArray = PackedByteArray()


## Si este punto cae dentro del sitio.
func contiene(point: Vector3) -> bool:
	if lado <= 0:
		return false
	var x := int(floor((point.x - origen.x) / CELDILLA))
	var z := int(floor((point.z - origen.z) / CELDILLA))
	if x < 0 or z < 0 or x >= lado or z >= lado:
		return false
	return dentro[z * lado + x] != 0


## Los centros de las celdillas que ocupa.
func celdas() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for z in range(lado):
		for x in range(lado):
			if dentro[z * lado + x] != 0:
				out.append(origen + Vector3(
					(float(x) + 0.5) * CELDILLA, 0.0,
					(float(z) + 0.5) * CELDILLA))
	return out


## Cuánto ocupa, en metros cuadrados.
func superficie() -> float:
	var cuantas := 0
	for i in range(dentro.size()):
		if dentro[i] != 0:
			cuantas += 1
	return float(cuantas) * CELDILLA * CELDILLA


func vacia() -> bool:
	return lado <= 0 or superficie() <= 0.0


## Hasta dónde puede llegar la mancha de este paraje, en metros.
##
## En tierra, su radio y nada más: sin gradiente en el campo, dejarla crecer es
## dejarla llenar la caja de búsqueda —medido, los parajes de tierra salían
## CUADRADOS, con el lado largo igual al corto y ocupando el 224 % del círculo.
static func alcance_de(paraje: Paraje) -> float:
	if paraje.activity == Subsistence.Activity.PESCA \
			or paraje.activity == Subsistence.Activity.MARISQUEO:
		return paraje.extent * ESTIRA_LA_CINTA
	return paraje.extent


## Saca la forma de un paraje. Es lo caro, y por eso se guarda.
##
## Sin campo de recursos no hay forma que sacar —no se sabe dónde hay qué— y
## sale el disco de siempre, que es lo que había antes de esto.
static func de(paraje: Paraje, field: ResourceField,
		terrain: TerrainGenerator) -> Huella:
	var huella := Huella.new()
	var lejos := alcance_de(paraje)
	var alcance := int(ceil(lejos / CELDILLA)) + 1
	huella.lado = alcance * 2 + 1
	huella.origen = paraje.position - Vector3(
		float(alcance) * CELDILLA + CELDILLA * 0.5, 0.0,
		float(alcance) * CELDILLA + CELDILLA * 0.5)
	huella.origen.y = 0.0

	var crudo := huella._sembrar(paraje, field, terrain, alcance, lejos)
	var crecido := huella._filtrar(paraje, terrain,
		huella._ensanchar(crudo), alcance, lejos)
	var cuerpo := huella._solo_lo_pegado(crecido, alcance)
	huella._tapar_claros(cuerpo)
	huella.dentro = cuerpo

	# Un paraje sin forma no existe para nadie: si el campo no da ni una
	# celdilla —pasa con un sitio recién bautizado en el filo del umbral— se
	# cae al disco de siempre en vez de dejar un sitio al que no se puede ir.
	if huella.vacia():
		huella._disco(paraje, alcance)
	return huella


## Donde hay de verdad algo de lo de este paraje.
func _sembrar(paraje: Paraje, field: ResourceField, terrain: TerrainGenerator,
		alcance: int, lejos: float) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(lado * lado)
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var index := (dz + alcance) * lado + (dx + alcance)
			var centre := paraje.position + Vector3(
				float(dx) * CELDILLA, 0.0, float(dz) * CELDILLA)
			var away := Vector2(centre.x - paraje.position.x,
				centre.z - paraje.position.z).length()
			if away > lejos:
				continue
			if field == null:
				mask[index] = 1
				continue
			var amount := field.seasonal_abundance_at(
				paraje.activity, centre, GameState.season)
			# El umbral sube con la distancia al centro: el corazón del sitio
			# entra aunque esté flojo, y el borde sólo si de verdad sigue
			# habiendo. Y se mide contra EL ALCANCE DE ESTE OFICIO, no contra el
			# radio nominal: si no, la cinta de una pesquera se cortaba a los
			# ochenta metros porque a esa distancia ya se le pedía el listón del
			# borde.
			var needed := lerpf(0.05, 0.16,
				clampf(away / maxf(lejos, 1.0), 0.0, 1.0))
			if amount >= needed and _cuadra_el_terreno(paraje, centre, terrain):
				mask[index] = 1
	return mask


## El disco de siempre, para cuando no hay campo del que sacar la forma.
func _disco(paraje: Paraje, alcance: int) -> void:
	dentro = PackedByteArray()
	dentro.resize(lado * lado)
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var away := Vector2(float(dx), float(dz)).length() * CELDILLA
			if away <= paraje.extent:
				dentro[(dz + alcance) * lado + (dx + alcance)] = 1


## Si esta celdilla es terreno que de verdad pertenece al paraje.
##
## Un avellanar no cruza el río para seguir siendo el mismo avellanar: la otra
## orilla es otro sitio, aunque el campo de recursos —que no sabe de agua ni de
## peñas, sólo de cuánto hay— diga que ahí también abunda. Y una pared vertical
## no es sitio de recolectar ni de cazar: eso sólo vale para la materia prima,
## que es precisamente la que se busca en la roca viva.
static func _cuadra_el_terreno(paraje: Paraje, centre: Vector3,
		terrain: TerrainGenerator) -> bool:
	if terrain == null:
		return true
	var ford := terrain.crossing_difficulty_at(centre)

	# El agua es LO QUE ES EL SITIO para unos y una pared para otros.
	#
	# Un paraje de pesca ES el río y su orilla: hay que dejarlo entrar, y hasta
	# exigirlo. Rechazando todo lo que no se cruce a pie, la mancha de un
	# pescador salía con el cauce recortado por dentro —un agujero justo donde
	# están los peces— y se iba ladera arriba buscando suelo pisable, que es lo
	# contrario de lo que es una pesquera.
	if paraje.activity == Subsistence.Activity.PESCA \
			or paraje.activity == Subsistence.Activity.MARISQUEO:
		return _moja_la_celdilla(centre, terrain)

	if not Hydrography.can_cross(ford, false, false):
		return false
	if paraje.serves(Subsistence.Activity.MATERIA_PRIMA):
		return true
	return absf(terrain.get_slope_at(centre)) <= Traversal.CLIMB_LIMIT


## Cuantas veces se pregunta por el agua dentro de una celdilla, por lado.
##
## Tres por tres, y no una vez en el centro, porque preguntando en el centro EL
## RIO DESAPARECE A TROZOS: el cauce de este valle mide entre cuarenta y ochenta
## metros y la celdilla veinticinco, asi que hay celdillas que el rio cruza por
## una esquina y cuyo centro esta seco.
##
## Sacado a mapa, el agua salia como una LINEA DE PUNTOS ROTA -filas enteras sin
## una gota- y la pesquera se quedaba en la unica celdilla en la que el centro
## habia caido mojado: una sola, el 4 % de su circulo. Es el mismo fallo que ya
## se arreglo en [NavOverlay], donde tramos enteros de rio salian sin pintar.
const CATAS := 3


## Si hay agua EN ALGUN SITIO de esta celdilla, no solo en su centro.
static func _moja_la_celdilla(centre: Vector3, terrain: TerrainGenerator) -> bool:
	for i in range(CATAS):
		for j in range(CATAS):
			var punto := centre + Vector3(
				(float(i) / float(CATAS - 1) - 0.5) * CELDILLA, 0.0,
				(float(j) / float(CATAS - 1) - 0.5) * CELDILLA)
			if terrain.crossing_difficulty_at(punto) > 0.05:
				return true
	return false


## Ensancha la mancha una celdilla en todas direcciones.
##
## Es lo que ABSORBE las islas cercanas: dos trozos separados por un hueco de
## una o dos celdillas se tocan y pasan a ser el mismo sitio, que es lo que de
## verdad son.
func _ensanchar(mask: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(lado * lado)
	for z in range(lado):
		for x in range(lado):
			var on := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					if nx < 0 or nz < 0 or nx >= lado or nz >= lado:
						continue
					if mask[nz * lado + nx] != 0:
						on = true
						break
				if on:
					break
			out[z * lado + x] = 1 if on else 0
	return out


## Vuelve a pasar el filtro sobre una máscara ya crecida.
##
## Hace falta, y por dos motivos: ensanchar abre una celdilla SIN volver a
## mirar nada, así que el borde de una pesquera se subía a la ladera y —lo que
## salía peor— la mancha se comía las esquinas del recuadro y el paraje acababa
## siendo un CUADRADO. Medido: los de tierra ocupaban el 224 % de su círculo
## con el lado largo igual al corto.
##
## Crecer sirve para saltar huecos de RECURSO, no para saltar el terreno ni el
## alcance.
func _filtrar(paraje: Paraje, terrain: TerrainGenerator, mask: PackedByteArray,
		alcance: int, lejos: float) -> PackedByteArray:
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var index := (dz + alcance) * lado + (dx + alcance)
			if mask[index] == 0:
				continue
			var centre := paraje.position + Vector3(
				float(dx) * CELDILLA, 0.0, float(dz) * CELDILLA)
			if Vector2(centre.x - paraje.position.x,
					centre.z - paraje.position.z).length() > lejos:
				mask[index] = 0
				continue
			if terrain != null and not _cuadra_el_terreno(paraje, centre, terrain):
				mask[index] = 0
	return mask


## Se queda sólo con el trozo pegado al centro.
##
## Lo que quedó lejos de verdad no es este paraje: es otro sitio, y si merece
## nombre ya se lo pondrá la banda cuando lo conozca.
func _solo_lo_pegado(mask: PackedByteArray, alcance: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(lado * lado)
	var start := alcance * lado + alcance
	if mask[start] == 0:
		return out

	var stack: Array[int] = [start]
	out[start] = 1
	while not stack.is_empty():
		var cell: int = stack.pop_back()
		var x := cell % lado
		@warning_ignore("integer_division")
		var z := cell / lado
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + step.x
			var nz := z + step.y
			if nx < 0 or nz < 0 or nx >= lado or nz >= lado:
				continue
			var next_cell := nz * lado + nx
			if out[next_cell] != 0 or mask[next_cell] == 0:
				continue
			out[next_cell] = 1
			stack.append(next_cell)
	return out


## Tapa los huecos de dentro.
##
## Se inunda el VACÍO desde el borde del recuadro: lo que el vacío no alcanza
## está rodeado por la mancha, o sea que es un claro de dentro. Un claro en
## mitad del avellanar sigue siendo avellanar.
func _tapar_claros(mask: PackedByteArray) -> void:
	var fuera := PackedByteArray()
	fuera.resize(lado * lado)
	var stack: Array[int] = []
	for i in range(lado):
		for edge: int in [i, (lado - 1) * lado + i, i * lado, i * lado + lado - 1]:
			if mask[edge] == 0 and fuera[edge] == 0:
				fuera[edge] = 1
				stack.append(edge)

	while not stack.is_empty():
		var cell: int = stack.pop_back()
		var x := cell % lado
		@warning_ignore("integer_division")
		var z := cell / lado
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + step.x
			var nz := z + step.y
			if nx < 0 or nz < 0 or nx >= lado or nz >= lado:
				continue
			var next_cell := nz * lado + nx
			if fuera[next_cell] != 0 or mask[next_cell] != 0:
				continue
			fuera[next_cell] = 1
			stack.append(next_cell)

	for i in range(mask.size()):
		if mask[i] == 0 and fuera[i] == 0:
			mask[i] = 1
