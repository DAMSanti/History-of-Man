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


## CUÁNTOS RUMBOS SE PRUEBAN al buscar por dónde se cruza. Media vuelta basta: un rumbo y
## su contrario son la misma raya.
const RUMBOS := 16


## POR DÓNDE SE CRUZA EL AGUA Y CUÁNTO MIDE: `{"rumbo": radianes, "ancho": metros}`.
##
## **Barriendo el círculo, no mirando sólo a X y a Z.** Eso era lo que había, y falla justo
## donde el usuario lo vio (2026-09-19): «en los que sólo tocan el río en una esquina, la
## mayoría del tablón está puesto en tierra». Si el cauce cruza la celda EN DIAGONAL, ni el
## ancho medido a lo largo de X ni el medido a lo largo de Z caen sobre el agua de verdad —
## los dos atraviesan la esquina de refilón— y el tablón se tiende sobre tierra firme.
##
## Con dieciséis rumbos se elige el que **menos agua** tiene que salvar, que es por donde
## uno cruzaría un río: la parte más estrecha. Sale bien tanto en un cauce recto como en una
## diagonal, sin regla aparte para cada caso.
##
## Devuelve `{}` sin mapa de cauce o si por ningún rumbo hay agua que cruzar; entonces manda
## lo de siempre, que es contar celdas.
static func por_donde_se_cruza(rio: PackedFloat32Array, res: int, origen: Vector2,
		paso: float, centro: Vector3) -> Dictionary:
	if rio.is_empty() or res <= 1:
		return {}
	var mejor := {}
	for i in range(RUMBOS):
		var rumbo := PI * float(i) / float(RUMBOS)
		var eje := Vector3(cos(rumbo), 0.0, sin(rumbo))
		var ancho := _agua_a_lo_largo(rio, res, origen, paso, centro, eje)
		if ancho <= 0.0:
			continue
		if mejor.is_empty() or ancho < float(mejor["ancho"]):
			mejor = {"rumbo": rumbo, "ancho": ancho}
	return mejor


## Cuántos metros de agua seguidos hay cruzando por `eje` desde `centro`, contando a los dos
## lados. Se para al salir del agua o al llegar al tope: un cauce más ancho que lo que una
## pasarela puede salvar no hace falta medirlo mejor.
static func _agua_a_lo_largo(rio: PackedFloat32Array, res: int, origen: Vector2, paso: float,
		centro: Vector3, eje: Vector3) -> float:
	var tope := Navgrid.CELL * float(Pasarelas.CELDAS_DE_ANCHO) + paso
	var ancho := 0.0
	for signo: float in [1.0, -1.0]:
		var d := paso
		while d <= tope:
			var punto := centro + eje * signo * d
			var ix := int(round((punto.x - origen.x) / paso))
			var iz := int(round((punto.z - origen.y) / paso))
			if ix < 0 or iz < 0 or ix >= res or iz >= res:
				break
			if rio[iz * res + ix] <= 0.0:
				break
			d += paso
		ancho += d
	return ancho


## Lo mismo, preguntándole al terreno por su mapa de cauce.
func _cruce_de(centro: Vector3, terrain: TerrainGenerator) -> Dictionary:
	var maps := terrain.sample_maps()
	var rio: PackedFloat32Array = maps.get("river", PackedFloat32Array())
	var res := int(maps.get("resolution", 0))
	if rio.is_empty() or res <= 1:
		return {}
	var extent: Vector2 = maps["extent"]
	var origen: Vector2 = maps["origin"]
	return por_donde_se_cruza(rio, res, origen, extent.x / float(res - 1), centro)


func _armar(celdas: Array, terrain: TerrainGenerator) -> void:
	if celdas.is_empty():
		return
	var centro := Vector3.ZERO
	for celda: Vector3 in celdas:
		centro += celda
	centro /= float(celdas.size())
	# POR DÓNDE SE CRUZA. Con dos celdas o más lo dicen ellas: están alineadas a lo ancho
	# del cauce, así que el tablón va de la primera a la última. Con UNA celda hay que
	# preguntarle al río, y se le pregunta **barriendo el círculo** —ver
	# [por_donde_se_cruza]—: mirando sólo a X y a Z, un cauce que entra por una esquina en
	# diagonal dejaba el tablón tendido sobre tierra.
	var cruce := _cruce_de(centro, terrain)
	var rumbo := 0.0
	var medido := 0.0
	if celdas.size() > 1:
		var de_punta_a_punta: Vector3 = celdas[celdas.size() - 1] - celdas[0]
		rumbo = atan2(de_punta_a_punta.z, de_punta_a_punta.x)
		medido = Vector2(de_punta_a_punta.x, de_punta_a_punta.z).length()
	elif not cruce.is_empty():
		rumbo = float(cruce["rumbo"])
		medido = float(cruce["ancho"])

	# Y EL LARGO SALE DEL AGUA MEDIDA, no de contar celdas. Ése era el fallo de verdad —«los
	# troncos deben visiblemente atravesar el río que quieren pasar», 2026-09-18—: contar
	# celdas daba 43,2 m para una celda, porque la celda de la rejilla son 40 m, y **en el
	# valle del sitio 56 el cauce medía 54,7 m de agua justo ahí**. La pasarela se quedaba
	# corta y acababa dentro del río; desde arriba parecía un tronco tirado en la orilla.
	var largo := maxf(float(celdas.size()) * Navgrid.CELL, medido) + VUELO * 2.0
	var alto := terrain.get_height_at(centro)
	# Se dice en voz alta porque una pasarela tendida por el rumbo equivocado NO se ve como
	# un fallo: se ve como un tronco tirado en la orilla, y uno se pasa la tarde mirando el
	# relieve. Ver el porqué del rumbo arriba.
	print("Pasarela: %d celda(s) en (%.0f, %.0f), cruza a %.0f grados, %.1f m de largo" % [
		celdas.size(), centro.x, centro.z, rad_to_deg(rumbo), largo])

	# TODO VA GIRADO AL RUMBO DEL CRUCE, tablero y troncos: el tablón se tiende A LO LARGO
	# del rumbo y los leños se separan de lado, perpendiculares a él.
	var giro := Basis(Vector3.UP, -rumbo)
	var de_lado := Vector3(-sin(rumbo), 0.0, cos(rumbo))

	# EL TABLERO, que es lo que la hace legible desde la distancia de gestión: dos troncos
	# de veintiocho centímetros vistos desde doscientos metros son dos rayas. El tejido de
	# ramas es además lo que dice la ficha de la técnica —«dos troncos y un tejido de
	# ramas»—.
	var tablero := MeshInstance3D.new()
	var losa := BoxMesh.new()
	losa.size = Vector3(largo, GRUESO * 0.45, SEPARACION + GRUESO * 2.0)
	tablero.mesh = losa
	var rama := StandardMaterial3D.new()
	rama.albedo_color = Color(0.35, 0.27, 0.17)
	rama.roughness = 1.0
	tablero.material_override = rama
	tablero.transform = Transform3D(giro,
		Vector3(centro.x, alto + GRUESO, centro.z))
	add_child(tablero)

	for i in range(TRONCOS):
		var tronco := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = Vector3(largo, GRUESO, GRUESO)
		tronco.mesh = malla
		var material := StandardMaterial3D.new()
		# Madera descortezada y mojada: ni el ocre del suelo ni la corteza.
		material.albedo_color = Color(0.42, 0.32, 0.21)
		material.roughness = 0.95
		tronco.material_override = material
		var lado := (float(i) - float(TRONCOS - 1) * 0.5) * SEPARACION
		tronco.transform = Transform3D(giro,
			Vector3(centro.x, alto + GRUESO * 0.5, centro.z) + de_lado * lado)
		add_child(tronco)
