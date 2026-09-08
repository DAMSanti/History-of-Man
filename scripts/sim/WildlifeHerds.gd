class_name WildlifeHerds
extends Node3D
## La fauna que de verdad anda por el mapa: comportamiento, no sólo marcador.
##
## Antes eran cápsulas sin especie ni comportamiento -pastaban las mismas
## celdas de caza del [ResourceField] fuera cual fuera el bicho-. Ahora cada
## especie de [Fauna] que tiene malla real -ver `scripts/tools/FaunaAtlas.gd`
## para de dónde sale- se dibuja como la banda, un `MultiMesh` por especie
## (ver [BandaCrowd] para el porqué del truco), y tiene NECESIDADES: come
## -pasta mientras vaga por el prado, que es donde ya sesgaba `_new_target`-,
## bebe -busca el agua más cercana cuando tiene sed de verdad- y, si es
## carnívora, CAZA a la presa más próxima en vez de vagar sin más.
##
## Las cinco especies menudas -liebre, conejo, urogallo, perdiz, ánade- se
## cazan con trampa (`Hunting.gd`, rama `Trampas`: cada `Trap.Kind` coge las
## suyas -lazo para liebre y conejo, red de aves para perdiz/ánade/urogallo-)
## y esa rama nunca necesitó verlas correr por el monte para funcionar. Aquí
## se dibujan de todos modos, con lo que hay: no existe malla CC0 descargable
## de liebre ni conejo -águila, pájaro pequeño y pato sí, y `FaunaAtlas.gd` ya
## los horneó-.
##
## Estuvieron tomando prestado EL ESQUELETO DEL LOBO a escala 0,028 y 0,022: un
## lobo del tamaño de una liebre, con silueta de lobo. Ahora llevan el gato del
## mismo pack -Quaternius Vol.2, CC0, con ciclo de marcha propio-, que tampoco
## es una liebre pero es un cuadrúpedo pequeño de lomo curvo y paso corto, y a
## la distancia a la que se juega eso ya no se lee como «lobo diminuto». Es el
## mismo apaño que uro/ciervo/corzo/rebeco, declarado igual de a la vista.

## --- Cuánta fauna hay en el valle ---------------------------------------
##
## El valle tenía unos cien animales en cuatro kilómetros cuadrados, que es un
## zoológico vacío: se cruzaba el mapa entero sin ver una manada. Estos dos
## números multiplican lo que dice cada especie en `SPECIES_VISUAL`, para poder
## subir la población entera sin retocar doce entradas.
##
## Lo que hacía imposible subirla no era dibujar —van en `MultiMesh`, salen casi
## gratis— sino que la búsqueda de depredador recorría la lista COMPLETA por
## cada herbívoro y por fotograma. Con eso, seiscientos animales eran
## trescientas mil comprobaciones por cuadro. Ver `_nearest_predator`.
##
## Pendiente de playtest: son cifras de densidad, y la densidad de caza es lo
## que decide si la banda come.
const HERD_SCALE := 4
const GROUP_SCALE := 2

## Radio de querencia de una manada alrededor de su centro, en metros
const HOME_RANGE_M := 220.0

## Cada cuánto se replantea el rumbo un animal, en segundos
const RETHINK_SECONDS := 3.5

## Por debajo de esto no hace falta beber ni comer; por encima, sí.
const THIRSTY_AT := 65.0
const HUNGRY_AT := 70.0

## Cuándo se da por saciado el que está bebiendo, y a qué ritmo bebe.
##
## Hacía falta una SALIDA del estado de beber, y no la había: el animal llegaba
## a la charca, se ponía a beber y ahí se quedaba para siempre. `_move` no mueve
## a quien bebe, así que el primero que llegaba al río no volvía al pasto en
## toda la partida, y el valle se iba vaciando hacia el agua. Con estos dos
## números se bebe hasta saciar y se vuelve a la querencia, que es de donde se
## vino.
const SATED_AT := 15.0
const DRINK_RATE := 30.0

## A qué distancia un lobo detecta presa y a qué distancia una presa siente el
## lobo. La de huida es mayor: un ciervo nota antes de lo que un lobo alcanza
## a perseguir, que es justo lo que le deja escapar alguna vez.
const HUNT_RADIUS_M := 90.0
const FLEE_RADIUS_M := 130.0
const CATCH_RADIUS_M := 3.5

## Cuántos puntos del recorrido se le guardan a un animal, y cada cuántos
## metros se apunta uno.
##
## Existe para que el censo pueda contestar la misma pregunta que ya contesta
## de la banda —por dónde ha andado éste— sobre un uro o un lobo. Sin esto un
## animal sólo tiene la posición de ahora, y con la posición de ahora no se
## distingue un rebaño que repite querencia de uno al que el lobo ha echado
## del prado tres veces.
##
## Ciento veinte puntos cada seis metros son unos setecientos de recorrido: a
## la velocidad de un herbívoro, un buen rato de pasto. Y son 120 vectores por
## animal, que con el centenar largo que hay en el valle no es nada.
const TRAIL_LIMIT := 120
const TRAIL_STEP_M := 6.0

enum State { VAGANDO, BEBIENDO, CAZANDO, HUYENDO }

## Especie de [Fauna] -> de qué malla horneada sale, a qué escala real, con
## qué tinte y a qué velocidad anda. `model` puede repetirse -ciervo y
## caballo comparten esqueleto de caballo, corzo y rebeco el de oveja- porque
## no hay malla propia para todo: ver la nota del docstring.
##
## ACTUALIZADO: la caza mayor ya no anda prestada de caballo ni de oveja. Ver
## `FaunaAtlas.gd` para qué malla lleva ahora cada una y qué sigue faltando.
##
## `escala` sale de medir la caja del primer fotograma horneado y calibrarla
## contra el tamaño real de la especie -no es un número puesto a ojo-, igual
## que `BandaCrowd.HEIGHT_SCALE`.
const SPECIES_VISUAL := {
	# Y el PERRO, que es una especie aparte y no un lobo teñido: desde que hay
	# camino del perro -ver [ElLobo]- el hito de la partida es justo que el
	# lobo deja de ser lobo, y enseñarlo con la misma silueta se lo come.
	"perro": {"model": "dog", "scale": 0.15, "tint": Color(0.62, 0.54, 0.42),
		"diet": "carnivoro", "speed": 8.0, "herd": 1, "groups": 1},
	"lobo": {"model": "wolf", "scale": 0.16, "tint": Color(0.55, 0.53, 0.48),
		"diet": "carnivoro", "speed": 8.5, "herd": 2, "groups": 3},
	"caballo": {"model": "horse", "scale": 0.29, "tint": Color(0.55, 0.42, 0.30),
		"diet": "herbivoro", "speed": 6.5, "herd": 5, "groups": 2},
	"uro": {"model": "cow", "scale": 0.25, "tint": Color(0.20, 0.17, 0.15),
		"diet": "herbivoro", "speed": 5.5, "herd": 4, "groups": 2},
	# La caza mayor ya no anda prestada de caballo, oveja ni cerdo. Las tallas
	# se han recalculado para que cada especie mida EN PANTALLA lo mismo que
	# medía antes -ver `scripts/tools/FaunaTallaProbe.gd`, que da la caja del
	# primer fotograma horneado-: lo que cambia es la silueta y el paso, no el
	# equilibrio visual del valle.
	"ciervo": {"model": "stag", "scale": 0.36, "tint": Color(0.50, 0.32, 0.18),
		"diet": "herbivoro", "speed": 6.5, "herd": 4, "groups": 3},
	"jabali": {"model": "bull", "scale": 0.158, "tint": Color(0.16, 0.13, 0.11),
		"diet": "herbivoro", "speed": 4.5, "herd": 3, "groups": 3},
	"corzo": {"model": "deer", "scale": 0.143, "tint": Color(0.55, 0.35, 0.20),
		"diet": "herbivoro", "speed": 6.5, "herd": 3, "groups": 3},
	"rebeco": {"model": "deer", "scale": 0.19, "tint": Color(0.62, 0.60, 0.52),
		"diet": "herbivoro", "speed": 6.0, "herd": 3, "groups": 2},
	# --- pieza menuda: se cazan con trampa, no al acecho, pero se dibujan
	# igual -ver el docstring para de dónde sale cada malla-.
	# La liebre y el conejo eran un LOBO encogido al 2,8 % y al 2,2 %: la
	# silueta de un lobo del tamaño de una liebre. El gato no es una liebre
	# -queda anotado en CREDITOS- pero es un cuadrupedo pequeño de lomo curvo y
	# paso corto, que a la distancia a la que se juega es otra cosa.
	"liebre": {"model": "cat", "scale": 0.30, "tint": Color(0.58, 0.46, 0.32),
		"diet": "herbivoro", "speed": 5.0, "herd": 4, "groups": 2},
	"conejo": {"model": "cat", "scale": 0.23, "tint": Color(0.42, 0.34, 0.26),
		"diet": "herbivoro", "speed": 4.5, "herd": 5, "groups": 2},
	"urogallo": {"model": "eagle", "scale": 0.11, "tint": Color(0.15, 0.13, 0.12),
		"diet": "herbivoro", "speed": 4.0, "herd": 2, "groups": 2},
	"perdiz": {"model": "bird", "scale": 0.045, "tint": Color(0.55, 0.42, 0.28),
		"diet": "herbivoro", "speed": 4.0, "herd": 4, "groups": 2},
	"anade": {"model": "duck", "scale": 0.00095, "tint": Color(0.35, 0.32, 0.22),
		"diet": "herbivoro", "speed": 4.0, "herd": 4, "groups": 2},
}

## Especies que viven junto al agua -no en el prado- y por eso arrancan en
## una charca en vez de en una querencia de caza: un ánade no pasta.
const WATERSIDE_SPECIES := ["anade"]

## Qué clip usa cada especie según cómo se mueve.
##
## Aquí estaba el fallo de «no mueven las patas al andar»: el pack de granja
## sólo horneó reposo y salto para cerdo y oveja, así que jabalí, corzo y rebeco
## caían siempre en `idle` -tanto andando como huyendo- y cruzaban el valle en
## pose de estar quietos. Ya no: los tres han pasado a mallas del pack «Ultimate
## Animated Animals», que traen marcha y galope de verdad. Ver `FaunaAtlas.gd`.
const MOVE_CLIP := {
	"wolf": {"slow": "walk", "fast": "walk"},
	"dog": {"slow": "walk", "fast": "walk"},
	"cat": {"slow": "walk", "fast": "walk"},
	"horse": {"slow": "walk", "fast": "run"},
	"cow": {"slow": "walk", "fast": "run"},
	"deer": {"slow": "walk", "fast": "run"},
	"stag": {"slow": "walk", "fast": "run"},
	"bull": {"slow": "walk", "fast": "run"},
	# Sin marcha, y ya no los usa ninguna especie de caza: el pack de granja
	# sólo horneó reposo y salto. Se dejan porque las mallas siguen ahí.
	"pig": {"slow": "idle", "fast": "idle"},
	"sheep": {"slow": "idle", "fast": "idle"},
	# El águila SÍ tiene un «rápido» de verdad: volar. Es la única especie
	# menuda que al huir cambia de cuerpo entero, no sólo de paso.
	# El águila es la única ave con aleteo horneado, así que la usa también
	# para moverse: ver «Las que no tienen marcha».
	"eagle": {"slow": "fly", "fast": "fly"},
	"bird": {"slow": "idle", "fast": "idle"},
	"duck": {"slow": "idle", "fast": "idle"},
}
const IDLE_CLIP := {
	"wolf": "idle", "horse": "idle", "cow": "idle", "pig": "idle", "sheep": "idle",
	"eagle": "idle", "bird": "idle", "duck": "idle",
	"deer": "idle", "stag": "idle", "bull": "idle",
}

## Cuánto hay que girar cada malla para que su morro coincida con el rumbo.
##
## No todas vienen mirando al mismo sitio. Medido con
## `scripts/tools/FaunaRumboProbe.gd`, que pone a cada bicho un rumbo conocido y
## una bola blanca donde debería quedarle la cabeza: el lobo del pack viene
## tumbado un cuarto de vuelta respecto a los demás, así que lobo, liebre y
## conejo -las tres usan esa malla- cruzaban el valle andando de costado. El
## rumbo se calculaba bien; lo que no cuadraba era la malla.
const MODEL_YAW := {"wolf": -PI * 0.5}


## --- Las que no tienen marcha ---------------------------------------------
##
## Medido con `scripts/tests/PatasProbe.gd`: de las doce especies, nueve andan
## con paso propio y tres —urogallo, perdiz y ánade— cruzan el prado con la pose
## de estar quietas. No es un cableado mal hecho: no existe ciclo de marcha en
## las mallas CC0 de ave que se pudieron conseguir, igual que no lo había para
## cerdo y oveja.
##
## Lo que sí se puede arreglar es que no parezcan estatuas deslizándose. Un ave
## pequeña no cruza un prado andando: lo cruza a saltos cortos de vuelo. Así que
## mientras se mueven se les da ese salto —despegar, planear, posarse— y, si su
## malla trae aleteo (el águila lo trae), se usa.
##
## Queda escrito como lo que es: un apaño hasta que aparezca un ave CC0 con
## ciclo de marcha, no una solución.

## Cuánto se levantan del suelo en el salto, en metros.
const HOP_HEIGHT := 2.6

## Cuántos saltos por segundo. Cortos y rápidos, que es como vuela una perdiz.
const HOP_SPEED := 1.9

var _hop_phase := 0.0


## Si esta malla no tiene ciclo de marcha: su paso lento ES la pose de reposo.
static func _walks(model: String) -> bool:
	var clips: Dictionary = MOVE_CLIP.get(model, {})
	return String(clips.get("slow", "idle")) != String(IDLE_CLIP.get(model, "idle"))

var _terrain: TerrainGenerator
var _field: ResourceField
var _rng := RandomNumberGenerator.new()

var _groups: Dictionary = {}   ## especie -> AnimatedMultiMeshInstance3D
var _counts: Dictionary = {}   ## especie -> cuántos huecos usados
var _waterholes: Array[Vector3] = []

## Un animal: especie, hueco en su `MultiMesh`, posición, estado, necesidades.
var _animals: Array[Dictionary] = []

## Los carnívoros, aparte. Es la misma lista de siempre filtrada, y existe por
## coste: ver `_nearest_predator`.
var _predators: Array[Dictionary] = []


func setup(terrain: TerrainGenerator, field: ResourceField, herds: int = 5) -> void:
	_terrain = terrain
	_field = field
	_rng.seed = 20260903

	_raise_groups()
	_find_waterholes()

	# Más querencias que antes: si no, las manadas de más se apilarían en las
	# mismas diez manchas y el valle seguiría vacío entre ellas.
	var grounds := _pick_grounds(herds * 2 * GROUP_SCALE)
	if grounds.is_empty():
		return

	var species_keys: Array = SPECIES_VISUAL.keys()
	for i in range(species_keys.size()):
		var species: String = species_keys[i]
		var config: Dictionary = SPECIES_VISUAL[species]
		# El ánade vive en la orilla, no en el prado: arranca en una charca.
		var beside_water := WATERSIDE_SPECIES.has(species) and not _waterholes.is_empty()
		var pool: Array[Vector3] = _waterholes if beside_water else grounds
		var groups: int = mini(_groups_of(config), pool.size())
		for g in range(groups):
			var anchor: Vector3 = pool[(i * 7 + g * 3) % pool.size()]
			for _n in range(_herd_of(config)):
				_spawn(species, anchor)


## Cuántos animales por manada y cuántas manadas, ya escalados.
static func _herd_of(config: Dictionary) -> int:
	return maxi(int(config["herd"]) * HERD_SCALE, 1)


static func _groups_of(config: Dictionary) -> int:
	return maxi(int(config["groups"]) * GROUP_SCALE, 1)


## Cuántos animales pone en el valle esta configuración. Para poder contarlos
## sin montar el terreno.
static func population_size() -> int:
	var total := 0
	for species: String in SPECIES_VISUAL:
		var config: Dictionary = SPECIES_VISUAL[species]
		total += _herd_of(config) * _groups_of(config)
	return total


## Monta un `AnimatedMultiMeshInstance3D` por especie, con el mismo mallado
## que dibuja la banda -[BandaCrowd]-, aquí una vez por especie de caza.
func _raise_groups() -> void:
	var mesh_cache: Dictionary = {}
	var material_cache: Dictionary = {}
	var anims_cache: Dictionary = {}

	for species: String in SPECIES_VISUAL:
		var config: Dictionary = SPECIES_VISUAL[species]
		var model: String = config["model"]
		if not mesh_cache.has(model):
			var mesh: ArrayMesh = load("res://models/animals/%s_mesh.res" % model)
			if mesh == null:
				push_error("WildlifeHerds: falta %s_mesh.res; ¿se corrió FaunaAtlas.gd?" % model)
				continue
			mesh_cache[model] = mesh
			material_cache[model] = load("res://models/animals/%s_material.tres" % model)
			anims_cache[model] = _clip_table(model)

		var node := AnimatedMultiMeshInstance3D.new()
		node.name = "Fauna_%s" % species
		var material: ShaderMaterial = (material_cache[model] as ShaderMaterial).duplicate()
		material.set_shader_parameter("tint", config["tint"])
		node.material_override = material
		node.sampling_fps = 12.0

		var multi := MultiMesh.new()
		multi.mesh = mesh_cache[model]
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		# Al máximo de golpe: cambiar `instance_count` más tarde BORRA las
		# transformadas puestas -ver el mismo aviso, ya cazado una vez, en
		# `BandaCrowd.setup`-.
		var capacity: int = _herd_of(config) * _groups_of(config)
		multi.instance_count = maxi(capacity, 1)
		multi.visible_instance_count = 0
		node.multimesh = multi
		for key: String in (anims_cache[model] as Dictionary):
			var entry: Array = anims_cache[model][key]
			node.animation_list[key] = MultimeshAnimationData.new().set_values(
				entry[0], entry[1])

		add_child(node)
		_groups[species] = node
		_counts[species] = 0


## Los fotogramas de cada clip, calculados por `FaunaAtlas.gd` y pegados aquí
## a mano -mismo motivo que en `BandaCrowd.CLIPS`-.
static func _clip_table(model: String) -> Dictionary:
	match model:
		"wolf": return {"idle": [0, 20], "walk": [20, 20]}
		# Del mismo pack y con el mismo horneado que el lobo, asi que la misma
		# tabla. Ver la salida de `FaunaAtlas.gd`, que la imprime.
		"dog": return {"idle": [0, 20], "walk": [20, 20]}
		"cat": return {"idle": [0, 20], "walk": [20, 20]}
		"horse": return {"idle": [0, 75], "walk": [75, 33], "run": [108, 10]}
		"cow": return {"idle": [0, 75], "walk": [75, 40], "run": [115, 17]}
		"pig": return {"idle": [0, 75]}
		"sheep": return {"idle": [0, 75]}
		"deer": return {"idle": [0, 40], "walk": [40, 14], "run": [54, 7]}
		"stag": return {"idle": [0, 40], "walk": [40, 14], "run": [54, 7]}
		"bull": return {"idle": [0, 40], "walk": [40, 14], "run": [54, 8]}
		"eagle": return {"idle": [0, 20], "fly": [20, 15]}
		"bird": return {"idle": [0, 9]}
		"duck": return {"idle": [0, 60]}
		_: return {}


## Un puñado de charcas: celdas donde el vadeo ya moja pero no ahoga, lo
## bastante repartidas para que no todos los animales converjan en la misma.
func _find_waterholes() -> void:
	var candidates: Array[Vector3] = []
	var step := 24
	for z in range(0, _terrain.terrain_size.y, step):
		for x in range(0, _terrain.terrain_size.x, step):
			var point := Vector3(float(x), 0.0, float(z))
			var wet := _terrain.crossing_difficulty_at(point)
			if wet > 0.03 and wet <= Hydrography.FORD_WADEABLE:
				candidates.append(point)
	candidates.shuffle()
	for candidate in candidates:
		if _waterholes.size() >= 24:
			break
		var far_enough := true
		for taken in _waterholes:
			if taken.distance_to(candidate) < 80.0:
				far_enough = false
				break
		if far_enough:
			candidate.y = _terrain.get_height_at(candidate)
			_waterholes.append(candidate)


## Elige las querencias: las celdas con más caza, separadas entre sí para que
## las manadas no se amontonen todas en el mismo prado.
func _pick_grounds(count: int) -> Array[Vector3]:
	var candidates: Array[Dictionary] = []
	# Sin campo de recursos no hay querencias que elegir. Pasa en las pruebas,
	# que montan la fauna a mano para poder cazarla sin levantar un valle
	# entero; quien llama ya sabe qué hacer con una lista vacía.
	if _field == null:
		return []
	for z in range(_field.height):
		for x in range(_field.width):
			var value := _field.abundance_cell(Subsistence.Activity.CAZA, x, z)
			if value > 0.35:
				candidates.append({"pos": _field.cell_center(x, z), "value": value})

	candidates.sort_custom(func(a, b): return a["value"] > b["value"])

	var chosen: Array[Vector3] = []
	for candidate: Dictionary in candidates:
		if chosen.size() >= count:
			break
		var spot: Vector3 = candidate["pos"]
		var far_enough := true
		for taken: Vector3 in chosen:
			if taken.distance_to(spot) < HOME_RANGE_M * 1.2:
				far_enough = false
		if far_enough:
			chosen.append(spot)
	return chosen


func _spawn(species: String, anchor: Vector3) -> void:
	if not _groups.has(species):
		return
	var group: AnimatedMultiMeshInstance3D = _groups[species]
	var index: int = _counts[species]
	_counts[species] += 1
	if index >= group.multimesh.instance_count:
		return
	group.multimesh.visible_instance_count = index + 1

	var offset := Vector3(
		_rng.randf_range(-HOME_RANGE_M, HOME_RANGE_M) * 0.4, 0.0,
		_rng.randf_range(-HOME_RANGE_M, HOME_RANGE_M) * 0.4)
	var start := _clamped(anchor + offset)
	start.y = _terrain.get_height_at(start)

	var animal := {
		"species": species, "slot": index, "position": start, "target": start,
		"anchor": anchor, "timer": _rng.randf() * RETHINK_SECONDS,
		"state": State.VAGANDO, "heading": _rng.randf() * TAU,
		"hunger": _rng.randf_range(0.0, HUNGRY_AT), "thirst": _rng.randf_range(0.0, THIRSTY_AT),
		"trail": PackedVector3Array([start]),
	}
	_animals.append(animal)
	if String((SPECIES_VISUAL[species] as Dictionary)["diet"]) == "carnivoro":
		_predators.append(animal)


## El reloj de la partida, para andar a su compas.
##
## La fauna corria con el `delta` del motor a pelo, o sea que seguia pastando,
## bebiendo y huyendo con el juego EN PAUSA: se paraba el tiempo para mirar
## algo con calma y los ciervos se iban andando. Y al acelerar pasaba lo
## contrario, que la banda corria y los animales no.
##
## Va contra la escala de la simulacion y no contra `Engine.time_scale`, por lo
## mismo que explica `SettlementSim.time_scale`: congelar el motor congelaria
## tambien la camara y la interfaz.
var sim: SettlementSim = null


func _process(delta: float) -> void:
	if sim != null:
		delta *= sim.time_scale
	if delta <= 0.0:
		return
	_hop_phase += delta * TAU * HOP_SPEED
	if _terrain == null:
		return

	for animal: Dictionary in _animals:
		var config: Dictionary = SPECIES_VISUAL[animal["species"] as String]
		_think(animal, config, delta)
		_move(animal, config, delta)
		_draw(animal, config)


## Decide el ESTADO: huir manda sobre todo lo demás, luego cazar o beber,
## y vagando -que ya implica pastar, porque el destino sesga a la hierba- de
## sobra.
func _think(animal: Dictionary, config: Dictionary, delta: float) -> void:
	var diet: String = config["diet"]
	animal["thirst"] = minf(100.0, float(animal["thirst"]) + delta * 0.9)
	if animal["state"] != State.CAZANDO:
		animal["hunger"] = minf(100.0, float(animal["hunger"]) + delta * 0.6)

	# El susto que le ha dado una PERSONA. Va antes que todo lo demás y con
	# reloj propio, y ninguna de las dos cosas es un capricho:
	#
	#  - antes, porque si no el bloque de abajo lo devuelve a VAGANDO en el
	#    tick siguiente -«si no hay lobo cerca, deja de huir»- y la pieza que
	#    acaba de arrancar delante del cazador se para en seco a pastar;
	#  - con reloj, porque un animal levantado no se calma al perder de vista
	#    a quien lo levantó: sigue corriendo un rato. Sin eso no hay
	#    persecución que perseguir. Ver [Hunt].
	var spooked := float(animal.get("spooked", 0.0)) - delta
	if spooked > 0.0:
		animal["spooked"] = spooked
		animal["state"] = State.HUYENDO
		return
	if animal.has("spooked"):
		animal["spooked"] = 0.0

	if diet == "herbivoro":
		var predator: Dictionary = _nearest_predator(animal)
		if not predator.is_empty() and float(predator["_dist"]) < FLEE_RADIUS_M:
			animal["state"] = State.HUYENDO
			var away: Vector3 = (animal["position"] - predator["position"]).normalized()
			animal["target"] = _clamped(animal["position"] + away * 60.0)
			animal["timer"] = 1.2
			return
		if animal["state"] == State.HUYENDO:
			animal["state"] = State.VAGANDO
			animal["timer"] = 0.0

		# El que ya está bebiendo bebe hasta saciarse y SE VUELVE AL PASTO.
		# Ver `SATED_AT`: sin esta salida el estado se quedaba puesto y el
		# animal no se movía de la orilla nunca más.
		if animal["state"] == State.BEBIENDO:
			animal["thirst"] = maxf(0.0,
				float(animal["thirst"]) - delta * DRINK_RATE)
			if float(animal["thirst"]) > SATED_AT:
				return
			animal["state"] = State.VAGANDO
			animal["target"] = _new_target(animal["anchor"])
			animal["timer"] = RETHINK_SECONDS
			return

		if float(animal["thirst"]) > THIRSTY_AT and not _waterholes.is_empty():
			var hole := _nearest(animal["position"], _waterholes)
			if animal["position"].distance_to(hole) < CATCH_RADIUS_M:
				animal["state"] = State.BEBIENDO
				return
			animal["state"] = State.VAGANDO
			animal["target"] = hole
			return
		return

	# --- carnívoro: el lobo caza en vez de vagar cuando tiene hambre --------
	if float(animal["hunger"]) > HUNGRY_AT * 0.6:
		var prey: Dictionary = _nearest_prey(animal)
		if not prey.is_empty():
			animal["state"] = State.CAZANDO
			animal["target"] = prey["position"]
			if animal["position"].distance_to(prey["position"]) < CATCH_RADIUS_M:
				_catch(prey)
				animal["hunger"] = 0.0
				animal["state"] = State.VAGANDO
				animal["timer"] = 0.0
			return
	if animal["state"] == State.CAZANDO:
		animal["state"] = State.VAGANDO
		animal["timer"] = 0.0


func _move(animal: Dictionary, config: Dictionary, delta: float) -> void:
	if animal["state"] == State.BEBIENDO:
		return

	var timer := float(animal["timer"]) - delta
	if animal["state"] == State.VAGANDO:
		_rethink_if_due(animal, timer)
	else:
		animal["timer"] = timer

	var position: Vector3 = animal["position"]
	var target: Vector3 = animal["target"]
	var to_target := target - position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= 1.5:
		return

	var speed: float = float(config["speed"])
	if animal["state"] == State.CAZANDO or animal["state"] == State.HUYENDO:
		speed *= 1.6
	var step := to_target.normalized() * speed * delta
	var next := position + step
	if _terrain.crossing_difficulty_at(next) <= Hydrography.FORD_WADEABLE:
		position = next
		animal["heading"] = atan2(step.x, step.z)
	elif animal["state"] == State.VAGANDO:
		animal["timer"] = 0.0

	position.y = _terrain.get_height_at(position)
	animal["position"] = position
	_note_trail(animal, position)


## Apunta por dónde va, cada TRAIL_STEP_M metros.
##
## Por distancia y no por tiempo: un animal parado a la orilla bebiendo no
## tiene que gastar el rastro entero en un punto, y uno que corre huyendo no
## debe dejar el trecho sin apuntar. Lo que interesa del rastro es el camino,
## no el reloj.
func _note_trail(animal: Dictionary, point: Vector3) -> void:
	var trail: PackedVector3Array = animal["trail"]
	if not trail.is_empty():
		if trail[trail.size() - 1].distance_to(point) < TRAIL_STEP_M:
			return
	trail.append(point)
	while trail.size() > TRAIL_LIMIT:
		trail.remove_at(0)
	animal["trail"] = trail


func _rethink_if_due(animal: Dictionary, timer: float) -> void:
	animal["timer"] = timer
	if timer > 0.0:
		return
	animal["timer"] = RETHINK_SECONDS * _rng.randf_range(0.6, 1.6)
	animal["target"] = _new_target(animal["anchor"])


func _draw(animal: Dictionary, config: Dictionary) -> void:
	var species: String = animal["species"]
	if not _groups.has(species):
		return
	var group: AnimatedMultiMeshInstance3D = _groups[species]
	var scale: float = float(config["scale"])
	var model: String = config["model"]
	# El rumbo, más lo que haya que corregir por venir la malla girada. Ver
	# `MODEL_YAW`.
	var yaw := float(animal["heading"]) + float(MODEL_YAW.get(model, 0.0))
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)

	# El salto de las que no tienen marcha. Ver `HOP_HEIGHT`.
	var spot: Vector3 = animal["position"]
	var travel: Vector3 = (animal["target"] as Vector3) - spot
	travel.y = 0.0
	if not _walks(model) and travel.length() > 3.0:
		spot.y += absf(sin(_hop_phase + float(animal["slot"]) * 1.7)) * HOP_HEIGHT
	group.multimesh.set_instance_transform(
		int(animal["slot"]), Transform3D(basis, spot))

	var clip: String
	match animal["state"] as State:
		State.BEBIENDO:
			clip = IDLE_CLIP.get(model, "idle")
		State.CAZANDO, State.HUYENDO:
			clip = (MOVE_CLIP.get(model, {}) as Dictionary).get("fast", "idle")
		_:
			var to_target: Vector3 = (animal["target"] as Vector3) - (animal["position"] as Vector3)
			to_target.y = 0.0
			clip = IDLE_CLIP.get(model, "idle") if to_target.length() < 1.5 \
				else (MOVE_CLIP.get(model, {}) as Dictionary).get("slow", "idle")
	group.play(int(animal["slot"]), clip)


## El depredador vivo más cercano a esta presa, o `null` si no hay ninguno
## dentro de lo razonable. Guarda la distancia en `_dist` para no calcularla
## dos veces.
func _nearest_predator(animal: Dictionary) -> Dictionary:
	var position: Vector3 = animal["position"]
	var best: Dictionary = {}
	var best_dist := INF
	# Sólo los carnívoros, y no la lista entera. Recorrer los seiscientos
	# animales del valle por cada herbívoro y por fotograma es lo que hacía que
	# subir la población no fuera una opción: seis lobos contra quinientas
	# presas son tres mil comprobaciones, y contra todos eran trescientas mil.
	for other: Dictionary in _predators:
		var dist: float = position.distance_to(other["position"])
		if dist < best_dist:
			best_dist = dist
			best = other
	if best.is_empty():
		return {}
	best["_dist"] = best_dist
	return best


## La presa viva más cercana a este depredador, dentro del radio de caza.
func _nearest_prey(animal: Dictionary) -> Dictionary:
	var position: Vector3 = animal["position"]
	var best: Dictionary = {}
	var best_dist := HUNT_RADIUS_M
	for other: Dictionary in _animals:
		if (SPECIES_VISUAL[other["species"] as String] as Dictionary)["diet"] != "herbivoro":
			continue
		var dist: float = position.distance_to(other["position"])
		if dist < best_dist:
			best_dist = dist
			best = other
	return best


## Una pieza cazada no desaparece del mundo -sería un hueco en su `MultiMesh`
## que nadie ocupa-: reaparece como un individuo nuevo en otra querencia de su
## especie, que es lo que de verdad pasa con una manada de verdad.
func _catch(prey: Dictionary) -> void:
	var grounds := _pick_grounds(3)
	var anchor: Vector3 = grounds[_rng.randi() % grounds.size()] if not grounds.is_empty() \
		else prey["anchor"]
	prey["anchor"] = anchor
	var offset := Vector3(
		_rng.randf_range(-HOME_RANGE_M, HOME_RANGE_M) * 0.4, 0.0,
		_rng.randf_range(-HOME_RANGE_M, HOME_RANGE_M) * 0.4)
	var start := _clamped(anchor + offset)
	if _terrain != null:
		start.y = _terrain.get_height_at(start)
	prey["position"] = start
	prey["target"] = start
	prey["hunger"] = 0.0
	prey["thirst"] = 0.0
	prey["state"] = State.VAGANDO
	# Y el rastro se empieza de cero. La presa cazada no muere: reaparece en
	# otra querencia, que puede estar a dos kilómetros. Conservándole el rastro,
	# el censo le pintaba una recta cruzando el valle entero —el salto— como si
	# el bicho hubiera hecho ese camino andando.
	prey["trail"] = PackedVector3Array([start])


func _nearest(from: Vector3, points: Array[Vector3]) -> Vector3:
	var best := points[0]
	var best_dist := from.distance_to(best)
	for point in points:
		var dist := from.distance_to(point)
		if dist < best_dist:
			best_dist = dist
			best = point
	return best


## Un destino nuevo dentro de la querencia, en terreno pisable y no empinado.
func _new_target(anchor: Vector3) -> Vector3:
	for attempt in range(8):
		var angle := _rng.randf() * TAU
		var radius := _rng.randf() * HOME_RANGE_M
		var candidate := _clamped(anchor + Vector3(cos(angle), 0.0, sin(angle)) * radius)
		candidate.y = _terrain.get_height_at(candidate)
		if _terrain.crossing_difficulty_at(candidate) > Hydrography.FORD_WADEABLE:
			continue
		# Un herbivoro pasta en el llano, no en el canchal
		if _terrain.get_slope_at(candidate) > 0.35:
			continue
		return candidate
	return anchor


func _clamped(point: Vector3) -> Vector3:
	if _terrain == null:
		return point
	return Vector3(
		clampf(point.x, 5.0, float(_terrain.terrain_size.x) - 5.0), point.y,
		clampf(point.z, 5.0, float(_terrain.terrain_size.y) - 5.0))


## Dónde está cada animal, para que el minimapa los pinte
func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for animal: Dictionary in _animals:
		out.append(animal["position"])
	return out


## Los animales que hay ahora mismo, para el censo de depuración.
##
## Se devuelve la lista de verdad y no una copia: el censo la lee mientras la
## ficha está abierta y copiar un centenar de diccionarios varias veces por
## segundo para no tocar nada sería trabajo tirado. Quien la reciba sólo mira.
func animals() -> Array[Dictionary]:
	return _animals


# --- lo que la banda le pide a la fauna ----------------------------------
#
# Tres cosas, y las tres son de la caza de verdad: encontrar una pieza, darle
# un susto y cobrarla. Ver [Hunt] y `SettlementSim._hunt_step`.

## Cuánto dura el susto que da una persona, en segundos de juego.
##
## Corto: lo que tarda en dejar de verla y volver a bajar la cabeza. Si durara
## mucho, un cazador levantaría el valle entero de paso hacia su tajo.
const SUSTO_SEGUNDOS := 9.0

## Cuánto se aleja de un tirón cuando la levantan.
const SUSTO_M := 90.0


## Pone un animal donde se le diga, sin dibujarlo.
##
## Es para las PRUEBAS, y se dice: montar el valle entero —terreno, campo de
## recursos, mallas horneadas— para comprobar que un cazador acecha bien es
## desproporcionado, y sin poder comprobarlo la cacería sería el único sistema
## grande del juego sin una sola prueba detrás.
##
## No tiene hueco en ningún `MultiMesh` -`slot` a -1-, así que `_draw` no lo
## toca: existe para la simulación y no para la pantalla.
func place_for_test(species: String, at: Vector3) -> Dictionary:
	var animal := {
		"species": species, "slot": -1, "position": at, "target": at,
		"anchor": at, "timer": 0.0, "state": State.VAGANDO, "heading": 0.0,
		"hunger": 0.0, "thirst": 0.0, "trail": PackedVector3Array([at]),
	}
	_animals.append(animal)
	return animal


## Las piezas vivas al alcance de un punto, de entre unas especies dadas.
##
## Devuelve los diccionarios DE VERDAD de los animales, no copias: quien los
## reciba va a seguir a uno mientras se mueve, y con una copia estaría
## persiguiendo el sitio donde estaba hace un rato.
##
## Es una LISTA y no la más cercana, y eso es lo que arregló la cacería: quien
## elige tiene que poder mirar qué pieza es, no sólo a qué distancia está.
## Medido con `CaceriaProbe`, con la versión que devolvía la más cercana: once
## piezas cobradas en ciento veinte jornadas y las once ánades, porque la pieza
## menuda es la más numerosa del valle y siempre hay una más cerca que el
## ciervo. Una cuadrilla de caza mayor acechando patos no es una cuadrilla de
## caza mayor.
func quarries_near(point: Vector3, radius: float,
		species: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for animal: Dictionary in _animals:
		if not species.has(animal["species"]):
			continue
		if point.distance_to(animal["position"]) < radius:
			out.append(animal)
	return out


## La pieza viva más cercana a un punto. Se conserva porque es lo que quiere
## quien sólo pregunta «¿hay algo ahí?», y no todo el que pregunta elige.
func quarry_near(point: Vector3, radius: float, species: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := radius
	for animal: Dictionary in quarries_near(point, radius, species):
		var dist: float = point.distance_to(animal["position"])
		if dist < best_dist:
			best_dist = dist
			best = animal
	return best


## Levantarla: arranca en dirección contraria a quien la ha visto.
func spook(animal: Dictionary, from_point: Vector3) -> void:
	if animal.is_empty():
		return
	animal["spooked"] = SUSTO_SEGUNDOS
	animal["state"] = State.HUYENDO
	var away: Vector3 = animal["position"] - from_point
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(1.0, 0.0, 0.0)
	animal["target"] = _clamped(animal["position"] + away.normalized() * SUSTO_M)
	animal["timer"] = 2.0


## Si está levantada y corriendo.
func is_spooked(animal: Dictionary) -> bool:
	return float(animal.get("spooked", 0.0)) > 0.0


## Se la ha llevado la banda: la pieza MUERE.
##
## Antes reaparecía en otra querencia —lo decía el comentario de aquí mismo—, y
## era defendible mientras la caza no importara porque mantenía el valle
## poblado. Pero convierte el coto en un grifo: se puede cazar el mismo valle
## mil años y el censo no se mueve. Ahora el que cae, cae, y lo que repone la
## manada es la cría. Ver [Poblaciones].
func taken_by_band(animal: Dictionary) -> void:
	if animal.is_empty():
		return
	var especie := String(animal.get("species", ""))
	retirar(animal)
	if poblaciones != null:
		poblaciones.cobrada(especie)


## La población de cada especie, que decide quién nace. La pone [DemoMain] al
## montar la fauna; sin ella la caza sigue restando y no repone nadie.
var poblaciones: Poblaciones = null


## Quita un animal del valle y libera su hueco del `MultiMesh`.
##
## El hueco se rellena con el ÚLTIMO de su especie —intercambio y recorte— en
## vez de dejarlo vacío: los huecos se pintan por índice y `visible_instance_count`
## corta por el final, así que un agujero en medio dejaría un animal fantasma
## clavado donde murió el otro.
func retirar(animal: Dictionary) -> void:
	var species := String(animal.get("species", ""))
	if not _groups.has(species):
		return
	var slot := int(animal.get("slot", -1))
	var ultimo: Dictionary = {}
	for otro: Dictionary in _animals:
		if String(otro["species"]) != species:
			continue
		if int(otro["slot"]) == _counts[species] - 1:
			ultimo = otro
	_animals.erase(animal)
	_predators.erase(animal)
	if not ultimo.is_empty() and ultimo != animal:
		ultimo["slot"] = slot
	_counts[species] = maxi(int(_counts[species]) - 1, 0)
	var group: AnimatedMultiMeshInstance3D = _groups[species]
	group.multimesh.visible_instance_count = _counts[species]


## Nace uno de esta especie, en la querencia de los suyos. Devuelve si cupo.
##
## Nace DONDE HAY MÁS de su especie y no en un sitio al azar: una camada sale
## donde está la manada, y sembrarla en la otra punta del valle convertiría la
## cría en teletransporte.
func nacer(species: String) -> bool:
	if not _groups.has(species) or _terrain == null:
		return false
	var group: AnimatedMultiMeshInstance3D = _groups[species]
	if int(_counts[species]) >= group.multimesh.instance_count:
		return false
	var anchor := Vector3.ZERO
	for animal: Dictionary in _animals:
		if String(animal["species"]) == species:
			anchor = animal["anchor"]
			break
	if anchor == Vector3.ZERO:
		return false
	_spawn(species, anchor)
	return true


## Cuántos hay de cada especie. Es lo que rellena la lista del censo sin tener
## que recorrer los animales una vez por especie.
func tally() -> Dictionary:
	var out: Dictionary = {}
	for animal: Dictionary in _animals:
		var species: String = animal["species"]
		out[species] = int(out.get(species, 0)) + 1
	return out
