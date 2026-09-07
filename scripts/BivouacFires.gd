class_name BivouacFires
extends Node3D
## Las hogueras de quien pasa la noche fuera.
##
## La simulación ya cobraba la leña del vivac —`SettlementSim._bivouac`, una
## piel de tienda y unos troncos por noche— y no se veía nada: el explorador que
## dormía a dos kilómetros era un punto en la oscuridad, igual que el que se
## había quedado sin nada que quemar. Y son dos noches muy distintas.
##
## Se dibuja lo mismo que el hogar del abrigo —[Bonfire]— pero más pequeño y
## sólo mientras dure la noche. No es una obra: es un fuego que se hace, se
## duerme al lado y se deja apagado por la mañana.

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

var _sim: SettlementSim
var _terrain: TerrainGenerator
var _fires: Array[Bonfire] = []


func setup(sim: SettlementSim, terrain: TerrainGenerator) -> void:
	_sim = sim
	_terrain = terrain
	for i in range(MAX_FIRES):
		var fire := Bonfire.new()
		add_child(fire)
		fire.build(20260907 + i * 17, FIRE_SIZE)
		fire.visible = false
		_fires.append(fire)


func _process(_delta: float) -> void:
	if _sim == null:
		return

	# Quién tiene fuego esta noche: el que acampó fuera y llevaba leña. Ver
	# `Inhabitant.bivouac_fire`, que lo pone la simulación al cobrar la noche.
	var camps: Array[Vector3] = []
	for person: Inhabitant in _sim.people:
		if not person.bivouac_fire:
			continue
		if person.state != Inhabitant.State.DURMIENDO:
			continue
		if person.position.distance_to(_sim.home_position) < 60.0:
			continue
		# Los que acampan juntos comparten hoguera: una partida no enciende
		# cinco fuegos en el mismo claro.
		var shared := false
		for camp: Vector3 in camps:
			if camp.distance_to(person.position) < SHARED_M:
				shared = true
				break
		if shared:
			continue
		camps.append(person.position)
		if camps.size() >= MAX_FIRES:
			break

	for i in range(_fires.size()):
		var fire := _fires[i]
		if i >= camps.size():
			fire.visible = false
			fire.lit = false
			continue
		var spot := camps[i]
		if _terrain != null:
			spot.y = _terrain.get_height_at(spot)
		fire.global_position = spot
		fire.visible = true
		fire.lit = true


## Cuántas hogueras hay encendidas ahora mismo. Para poder comprobarlo sin
## mirar la pantalla.
func lit_count() -> int:
	var count := 0
	for fire: Bonfire in _fires:
		if fire.lit:
			count += 1
	return count
