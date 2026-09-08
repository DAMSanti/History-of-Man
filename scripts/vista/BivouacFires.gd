class_name BivouacFires
extends Node3D
## Los vivacs de quien pasa la noche fuera: la hoguera y la tienda.
##
## La simulación ya cobraba la leña del vivac —`SettlementSim._bivouac`, una
## piel de tienda y unos troncos por noche— y no se veía nada: el explorador que
## dormía a dos kilómetros era un punto en la oscuridad, igual que el que se
## había quedado sin nada que quemar. Y son dos noches muy distintas.
##
## Se dibuja lo mismo que el hogar del abrigo —[Bonfire]— pero más pequeño y
## sólo mientras dure la noche. No es una obra: es un fuego que se hace, se
## duerme al lado y se deja apagado por la mañana.
##
## Y con él la TIENDA —[Tienda]—, que llevaba cobrándose desde siempre y no se
## dibujaba: en pantalla, el que se había cargado una piel de doce kilos y el
## que salió a pelo dormían igual. Si el vivac se armó mal
## —`Inhabitant.bivouac_botched`— la tienda sale torcida, que es lo que se ve
## desde fuera de un paraviento mal plantado.

## Cuántas hogueras puede haber a la vez. Se reparten entre quien acampa: con
## más gente fuera que fuegos, los que sobran duermen a la luz del de al lado,
## que es lo que pasa de verdad —una partida hace UNA hoguera, no una por
## cabeza—.
const MAX_FIRES := 6

## Cómo de grande es respecto al hogar del abrigo. Una hoguera de vivac es
## cuatro palos: alumbra el corro y poco más.
const FIRE_SIZE := 0.55

## A qué distancia del fuego se considera que dos que acampan comparten hoguera.
const SHARED_M := 14.0

## Cuánto se tuerce una tienda mal armada, en grados. Suficiente para que se
## note de un vistazo y poco para que siga leyéndose como una tienda.
const TORCIDA := 9.0

## A qué distancia de la hoguera se planta la tienda. Ni encima —arde— ni lejos
## —no calienta—: a un paso largo, que es donde se pone.
const TIENDA_M := 2.2

var _sim: SettlementSim
var _terrain: TerrainGenerator
var _fires: Array[Bonfire] = []
var _tiendas: Array[Tienda] = []


func setup(sim: SettlementSim, terrain: TerrainGenerator) -> void:
	_sim = sim
	_terrain = terrain
	for i in range(MAX_FIRES):
		var fire := Bonfire.new()
		add_child(fire)
		fire.build(20260907 + i * 17, FIRE_SIZE)
		fire.visible = false
		_fires.append(fire)

		var tienda := Tienda.new()
		add_child(tienda)
		tienda.build(20260908 + i * 23)
		tienda.visible = false
		_tiendas.append(tienda)


func _process(_delta: float) -> void:
	if _sim == null:
		return

	# Quién tiene fuego esta noche: el que acampó fuera y llevaba leña. Ver
	# `Inhabitant.bivouac_fire`, que lo pone la simulación al cobrar la noche.
	var camps: Array[Vector3] = []
	var tents: Array[bool] = []
	var lumbre: Array[bool] = []
	var botched: Array[bool] = []
	for person: Inhabitant in _sim.people:
		# La hoguera pide leña y la tienda pide piel: son dos condiciones
		# distintas, así que quien duerme fuera CON tienda y sin fuego también
		# tiene que salir. Antes se filtraba por el fuego y ése no se veía.
		if not person.bivouac_fire and not person.bivouac_tent:
			continue
		if person.state != Inhabitant.State.DURMIENDO:
			continue
		if person.position.distance_to(_sim.home_position) < 60.0:
			continue
		# Los que acampan juntos comparten hoguera: una partida no enciende
		# cinco fuegos en el mismo claro.
		var shared := -1
		for c in range(camps.size()):
			if camps[c].distance_to(person.position) < SHARED_M:
				shared = c
				break
		if shared >= 0:
			# Comparten claro: basta con que UNO haya traído piel para que haya
			# tienda en ese campamento.
			tents[shared] = tents[shared] or person.bivouac_tent
			lumbre[shared] = lumbre[shared] or person.bivouac_fire
			botched[shared] = botched[shared] and person.bivouac_botched
			continue
		camps.append(person.position)
		tents.append(person.bivouac_tent)
		lumbre.append(person.bivouac_fire)
		botched.append(person.bivouac_botched)
		if camps.size() >= MAX_FIRES:
			break

	for i in range(_fires.size()):
		var fire := _fires[i]
		var tienda := _tiendas[i]
		if i >= camps.size():
			fire.visible = false
			fire.lit = false
			tienda.visible = false
			continue
		var spot := camps[i]
		if _terrain != null:
			spot.y = _terrain.get_height_at(spot)
		fire.global_position = spot
		# Sin leña se duerme igual, pero a oscuras: el que acampó con tienda y
		# sin fuego tiene que verse SIN fuego, que es la mitad de la noticia.
		fire.visible = lumbre[i]
		fire.lit = lumbre[i]

		tienda.visible = tents[i]
		if not tienda.visible:
			continue
		var donde := spot + Vector3(TIENDA_M, 0.0, 0.0)
		if _terrain != null:
			donde.y = _terrain.get_height_at(donde)
		tienda.global_position = donde
		# La boca mira al fuego, que es para lo que se pone el fuego.
		tienda.rotation.y = deg_to_rad(-90.0)
		tienda.rotation.z = deg_to_rad(TORCIDA if botched[i] else 0.0)


## Cuántas hogueras hay encendidas ahora mismo. Para poder comprobarlo sin
## mirar la pantalla.
func lit_count() -> int:
	var count := 0
	for fire: Bonfire in _fires:
		if fire.visible and fire.lit:
			count += 1
	return count


## Cuántas tiendas hay plantadas ahora mismo, por lo mismo.
func tent_count() -> int:
	var count := 0
	for tienda: Tienda in _tiendas:
		if tienda.visible:
			count += 1
	return count
