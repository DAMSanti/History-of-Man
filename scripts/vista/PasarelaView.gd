class_name PasarelaView
extends Node3D
## Las pasarelas de troncos, sobre el terreno.
##
## La obra existe en la simulación desde el 2026-09-13 —[Pasarelas]: abre su
## cruce todo el año y una crecida se la lleva— y sin esto no se vería: el
## jugador tendría gente cruzando el río por un sitio donde no hay nada. Es la
## misma idea que [Tienda], que dibujó el vivac que ya se cobraba.
##
## **Sólo lee.** Cada vez que cambia la lista de pasarelas —`Pasarelas.version`—
## se rehacen los troncos; no hay estado propio que pueda discrepar de la
## simulación. Ver SPECS §4.7.

## Dos troncos por pasarela, que es lo que dice su nombre.
const TRONCOS := 2

## Grosor de un tronco, en metros: un pino joven descortezado.
const GRUESO := 0.28

## Separación entre los dos troncos, de eje a eje.
const SEPARACION := 0.55

## Cuánto sobresale por cada orilla, para que apoye en tierra firme.
const VUELO := 1.6

var _version: int = -1


## Repinta si la lista ha cambiado. Se llama cada jornada desde [DemoMain].
func refresh(pasarelas: Pasarelas, terrain: TerrainGenerator) -> void:
	if pasarelas == null or terrain == null or pasarelas.version == _version:
		return
	_version = pasarelas.version
	for child: Node in get_children():
		child.queue_free()
	for puente: Array in pasarelas.puentes:
		_armar(puente, terrain)


## Un puente sobre las celdas que salva. Se tiende a lo largo del cauce más
## corto: por el eje en que la obra mide menos.
func _armar(celdas: Array, terrain: TerrainGenerator) -> void:
	if celdas.is_empty():
		return
	var centro := Vector3.ZERO
	for celda: Vector3 in celdas:
		centro += celda
	centro /= float(celdas.size())
	# El cauce va a lo ancho de las celdas que ocupa: si son dos, el puente
	# cruza por el eje en que están alineadas.
	var a_lo_largo_de_x := true
	if celdas.size() > 1:
		a_lo_largo_de_x = absf(celdas[0].x - celdas[celdas.size() - 1].x) \
			>= absf(celdas[0].z - celdas[celdas.size() - 1].z)
	var largo := float(celdas.size()) * Navgrid.CELL + VUELO * 2.0
	var alto := terrain.get_height_at(centro)

	# EL TABLERO, que es lo que la hace legible desde la distancia de gestión:
	# dos troncos de veintiocho centímetros vistos desde doscientos metros son
	# dos rayas. El tejido de ramas es además lo que dice la ficha de la
	# técnica —«dos troncos y un tejido de ramas»—.
	var tablero := MeshInstance3D.new()
	var losa := BoxMesh.new()
	var ancho_tablero := SEPARACION + GRUESO * 2.0
	if a_lo_largo_de_x:
		losa.size = Vector3(largo, GRUESO * 0.45, ancho_tablero)
	else:
		losa.size = Vector3(ancho_tablero, GRUESO * 0.45, largo)
	tablero.mesh = losa
	var rama := StandardMaterial3D.new()
	rama.albedo_color = Color(0.35, 0.27, 0.17)
	rama.roughness = 1.0
	tablero.material_override = rama
	tablero.position = Vector3(centro.x, alto + GRUESO, centro.z)
	add_child(tablero)

	for i in range(TRONCOS):
		var tronco := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = Vector3(largo, GRUESO, GRUESO) if a_lo_largo_de_x \
			else Vector3(GRUESO, GRUESO, largo)
		tronco.mesh = malla
		var material := StandardMaterial3D.new()
		# Madera descortezada y mojada: ni el ocre del suelo ni la corteza.
		material.albedo_color = Color(0.42, 0.32, 0.21)
		material.roughness = 0.95
		tronco.material_override = material
		var lado := (float(i) - float(TRONCOS - 1) * 0.5) * SEPARACION
		tronco.position = Vector3(
			centro.x + (0.0 if a_lo_largo_de_x else lado),
			alto + GRUESO * 0.5,
			centro.z + (lado if a_lo_largo_de_x else 0.0))
		add_child(tronco)
