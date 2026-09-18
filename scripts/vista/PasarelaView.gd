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


## CUÁNTA AGUA HAY QUE CRUZAR, en metros, a lo largo de X y a lo largo de Z.
##
## Se mide sobre el mapa de cauce del terreno —el mismo que leen [Forest] y [GroundCover]—
## andando a los cuatro lados desde el centro hasta salir del agua.
##
## Hace falta para las dos cosas que salían mal: **por dónde** se cruza y **cuánto** mide el
## puente. Con `Vector2.ZERO` —sin mapa de cauce— se cae a lo de antes, que era contar celdas.
func _ancho_del_agua(centro: Vector3, terrain: TerrainGenerator) -> Vector2:
	var maps := terrain.sample_maps()
	var rio: PackedFloat32Array = maps.get("river", PackedFloat32Array())
	var res := int(maps.get("resolution", 0))
	if rio.is_empty() or res <= 1:
		return Vector2.ZERO
	var extent: Vector2 = maps["extent"]
	var origen: Vector2 = maps["origin"]
	var paso := extent.x / float(res - 1)
	return Vector2(
		_agua_a_lo_largo(rio, res, origen, paso, centro, Vector3.RIGHT),
		_agua_a_lo_largo(rio, res, origen, paso, centro, Vector3.BACK))


## Cuántos metros de agua seguidos hay cruzando por `eje` desde `centro`, contando a los dos
## lados. Se para al salir del agua o al llegar al tope: un cauce más ancho que lo que una
## pasarela puede salvar no hace falta medirlo mejor.
func _agua_a_lo_largo(rio: PackedFloat32Array, res: int, origen: Vector2, paso: float,
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


func _armar(celdas: Array, terrain: TerrainGenerator) -> void:
	if celdas.is_empty():
		return
	var centro := Vector3.ZERO
	for celda: Vector3 in celdas:
		centro += celda
	centro /= float(celdas.size())
	# EL EJE DEL CRUCE. Con dos celdas o más lo dicen ellas: están alineadas a lo ancho del
	# cauce. Con UNA celda no decían nada y el puente se tendía siempre en X, así que ahí se
	# le pregunta al río por dónde es más estrecho.
	var agua := _ancho_del_agua(centro, terrain)
	var a_lo_largo_de_x := true
	if celdas.size() > 1:
		a_lo_largo_de_x = absf(celdas[0].x - celdas[celdas.size() - 1].x) \
			>= absf(celdas[0].z - celdas[celdas.size() - 1].z)
	elif agua != Vector2.ZERO:
		a_lo_largo_de_x = agua.x <= agua.y

	# Y EL LARGO SALE DEL AGUA MEDIDA, no de contar celdas. Ése era el fallo de verdad —«los
	# troncos deben visiblemente atravesar el río que quieren pasar», 2026-09-18—: contar
	# celdas daba 43,2 m para una celda, porque la celda de la rejilla son 40 m, y **en el
	# valle del sitio 56 el cauce medía 54,7 m de agua justo ahí**. La pasarela se quedaba
	# corta y acababa dentro del río; desde arriba parecía un tronco tirado en la orilla. Si
	# el cauce cruza la celda en diagonal, o se sale de ella, contar celdas se queda corto
	# siempre.
	var medido: float = agua.x if a_lo_largo_de_x else agua.y
	var largo := maxf(float(celdas.size()) * Navgrid.CELL, medido) + VUELO * 2.0
	var alto := terrain.get_height_at(centro)
	# Se dice en voz alta porque una pasarela tendida por el eje equivocado NO se ve como un
	# fallo: se ve como un tronco tirado en la orilla, y uno se pasa la tarde mirando el
	# relieve. Ver el porqué del eje arriba.
	print("Pasarela: %d celda(s) en (%.0f, %.0f), cruza en %s, %.1f m de largo" % [
		celdas.size(), centro.x, centro.z, "X" if a_lo_largo_de_x else "Z", largo])

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
