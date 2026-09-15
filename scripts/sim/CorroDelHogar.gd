class_name CorroDelHogar
extends RefCounted
## Los troncos alrededor de la hoguera, y dónde se sienta cada cual.
##
## Petición del usuario del 2026-09-13: «quiero unos troncos a modo de banco
## alrededor de la hoguera, donde se siente la banda cuando esté en el abrigo».
##
## La geometría vive AQUÍ y no en la vista porque la preguntan dos: quien
## planta los troncos en el mundo —[ObrasDelAbrigo]— y quien coloca a la gente
## en el abrigo —`SettlementSim._home_spot`—. Con dos copias, la banda se
## sentaría al lado de los troncos y no encima.

## Cuántos troncos hay alrededor del fuego.
##
## Cinco y no un corro cerrado: un corro entero es un cercado y además no deja
## acercarse a atizar. Cinco leños dejan los huecos por los que se entra.
const TRONCOS := 5

## A qué distancia del fuego, en metros. El corro de piedras mide 1,1 m de radio
## —[Bonfire.RING_RADIUS]—, así que esto deja un paso justo entre las piedras y
## las rodillas de quien se sienta.
const RADIO := 2.4

## Lo que mide un tronco de banco: largo y grueso, en metros. Un leño de sentarse
## es medio metro de diámetro mal desbastado, no un banco cepillado.
const LARGO := 1.7
const GRUESO := 0.42

## Cuántos caben en cada tronco.
const POR_TRONCO := 2

## Por dónde se abre el corro, en vueltas: el hueco por el que se entra queda
## mirando a la boca de la cueva.
const ARRANQUE := 0.08


## Los troncos: dónde va cada uno y hacia dónde mira.
##
## `centro` es la hoguera. El ángulo es el del RADIO, o sea que el tronco se
## planta atravesado a él, que es como se sienta uno mirando al fuego.
static func troncos(centro: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(TRONCOS):
		var vuelta := ARRANQUE + float(i) / float(TRONCOS)
		var angulo := TAU * vuelta
		out.append({
			"pos": centro + Vector3(cos(angulo), 0.0, sin(angulo)) * RADIO,
			"angulo": angulo,
		})
	return out


## Los sitios donde se sienta la gente: [POR_TRONCO] por leño, repartidos a lo
## largo de él y un palmo por delante, que es donde caen las rodillas.
static func asientos(centro: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for tronco: Dictionary in troncos(centro):
		var angulo: float = tronco["angulo"]
		# A lo largo del leño, que está atravesado al radio.
		var largo_dir := Vector3(-sin(angulo), 0.0, cos(angulo))
		for j in range(POR_TRONCO):
			var t := (float(j) + 0.5) / float(POR_TRONCO) - 0.5
			out.append((tronco["pos"] as Vector3) + largo_dir * (LARGO * t))
	return out


## El asiento que le toca al que hace el número `puesto` de la banda, o
## `Vector3.ZERO` si ya no quedan.
##
## Por el puesto en la banda y no por `id`: los ids crecen con cada nacimiento
## y con veinte partos el corro se quedaría vacío teniendo diez sitios. Quien no
## coge sitio se queda por la campa, como siempre; que haya menos sitios que
## gente es lo que hace del corro un sitio y no una cuadrícula.
static func asiento_de(centro: Vector3, puesto: int) -> Vector3:
	var sitios := asientos(centro)
	if puesto < 0 or puesto >= sitios.size():
		return Vector3.ZERO
	return sitios[puesto]
