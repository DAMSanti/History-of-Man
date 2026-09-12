class_name Vereda
extends RefCounted
## Un camino que la banda ya sabe andar, con la rejilla que lo trazó pegada.
##
## Es lo que la banda SABE, no un surco en el suelo: se descartó a propósito la
## senda física —que el paso repetido abarate la celda del terreno— porque el
## jugador lo describió como conocimiento. Ver docs/SISTEMAS.md §18.
##
## ## Por qué lleva el sello pegado, y no basta con tirarlas al rehornear
##
## [Navgrid] se rehorna una vez por estación, porque el caudal y el
## encharcamiento cambian qué se vadea y qué es marisma: un vado que no existe
## en primavera existe en verano. Una vereda trazada con la rejilla de mayo
## puede dar, en agosto, una vuelta que ya no hace falta.
##
## Eso HOY no pasa, porque `Marcha.forget_routes` vacía la memoria en cada
## cambio de rejilla. Pero eso es un aviso, y un aviso se olvida de llamar: la
## regla «ninguna vereda sobrevive a su rejilla» no se podía comprobar con una
## prueba, sólo confiar en que nadie tocara ese camino. Con el sello pegado al
## dato, la vereda de otra rejilla **se descarta al leerla** aunque nadie haya
## avisado, y la regla pasa a ser comprobable.
##
## Se sella con el par caudal/encharque y no con el objeto rejilla porque es lo
## que de verdad decide por dónde se pasa: dos rejillas horneadas con el mismo
## río son la misma rejilla a estos efectos.

## Los puntos del camino, en orden. El último es el destino.
var hitos: PackedVector3Array = PackedVector3Array()

## El `Navgrid.built_with_caudal` de la rejilla que la trazó.
var caudal: float = 1.0

## El `Navgrid.built_with_encharque` de la rejilla que la trazó.
var encharque: float = 0.0

## Cuántas veces se ha andado. Lo usa el afinado para saber si ya convergió.
var recorridos: int = 0


## Una vereda recién trazada, sellada con la rejilla que la trazó.
static func de(camino: PackedVector3Array, grid: Navgrid) -> Vereda:
	var nueva := Vereda.new()
	nueva.hitos = camino
	if grid != null:
		nueva.caudal = grid.built_with_caudal
		nueva.encharque = grid.built_with_encharque
	return nueva


## Si esta vereda vale con la rejilla de hoy.
##
## Sin rejilla se da por buena: es el caso de las pruebas y del arranque, donde
## no hay terreno y nadie va a andar nada.
func sirve_en(grid: Navgrid) -> bool:
	if grid == null:
		return true
	var mismo_rio := is_equal_approx(caudal, grid.built_with_caudal)
	var mismo_charco := is_equal_approx(encharque, grid.built_with_encharque)
	return mismo_rio and mismo_charco


## Metros por celda de la clave de una vereda.
##
## Mas gruesa que la de navegacion -que mide cuarenta- a proposito: lo que se
## quiere es que dos tajos a veinte metros el uno del otro compartan vereda en
## vez de tener una cada uno. Era `SettlementSim.LANE_CELL` y se movio aqui el
## 2026-09-12, cuando la clave dejo de ser el par origen-destino y paso a ser
## solo el destino: la granularidad es de la vereda, no del simulador.
##
## EL 48 ES EL HEREDADO Y NO SE HA AFINADO. Se intento barrerlo -16, 24, 32,
## 48- y el barrido no valia: las corridas iban SIN SEMILLA FIJA, o sea que
## cada una era una partida distinta y las cifras no se podian comparar entre
## si. Queda apuntado para que nadie lo repita: toda medida comparativa lleva
## `SEMILLA=`. Ver ARQUITECTURA.md §5.1.
const CELDA := 48.0


## La clave de una vereda: el par ORIGEN-DESTINO, en cubos de [CELDA].
##
## ## Se intento que fuera solo el destino, y NO SALE. Queda medido.
##
## La idea era que una vereda fuese «el camino al avellanar» y no «el camino de
## aqui al avellanar», de modo que la compartieran todos los que van alli
## vinieran de donde vinieran, enganchandose a ella por donde les pillara. Es
## lo que pedia la spec -EPOCA_01 §10.1, frente 1- y **es lo que no funciona**.
##
## Medido con `AtascoProbe`, `SEMILLA=42`, ocho jornadas en el sitio 56, pasos
## que el terreno corta teniendo camino trazado:
##
##   sin memoria de veredas ....................... 10
##   clave por PAR origen-destino ................. 17
##   clave por PAR, con enganche y remate catados . 33
##   clave por DESTINO, remate sin catar .......... 803
##   clave por DESTINO, enganche y remate catados . 2.295
##
## El motivo es geometrico y no se arregla afinando: con el par, quien reusa la
## vereda esta SIEMPRE dentro del cubo de origen, o sea a setenta metros como
## mucho del primer hito, y el tramo de enganche es corto. Con la clave por
## destino, quien la reusa puede estar a kilometros, y el enganche pasa a ser
## una recta larguisima que ninguna cata razonable cubre: `linea_limpia` mira
## el eje cada veinte metros, y lo que se anda no es el eje -cada uno va por su
## carril, hasta `SettlementSim.LANE_SPREAD` al lado-.
##
## Lo que si se queda de aquel intento son las dos catas -[enganchar] y
## [remate]-, que sobre el par salen casi gratis y quitan los tramos que nadie
## comprobaba: 33 pasos cortados contra 17, pero 0 atascos contra 1 y menos
## proporcion de caminos que no merecen andarse.
##
## ## Y la costura que el par tiene, que no es nueva
##
## Dos destinos en celdas distintas de la rejilla pueden caer en el mismo cubo
## de [CELDA] y prestarse el camino. Es la queja: «siguiendo el camino de otros
## pobladores que van a sitios diferentes». Lo probado y descartado, medido en
## su dia: afinar la clave a la celda de la rejilla hundia el reuso y subia los
## atascos de 3 a 243; exigirle al camino prestado que mereciera andarse dejaba
## 353 atascos porque dos personas se lo sobrescribian por turnos. El arreglo
## de verdad es extender el arbol de Dijkstra del abrigo a los viajes que no lo
## tocan, no afinar esta clave.
static func clave_de(desde: Vector3, hasta: Vector3) -> String:
	return "%d_%d>%d_%d" % [
		int(desde.x / CELDA), int(desde.z / CELDA),
		int(hasta.x / CELDA), int(hasta.z / CELDA)]


## Cuantos hitos se catan buscando por donde engancharse a la vereda.
##
## Cada cata es una [Wayfinder.linea_limpia], que muestrea la recta cada media
## celda: no es gratis, y sin tope una vereda larga costaria mas que la
## busqueda que ahorra. Seis es lo que hace falta para que el enganche caiga
## cerca sin que la cata se note.
const CATAS_DE_ENGANCHE := 6


## Los hitos de esta vereda desde el punto por el que conviene entrar en ella.
##
## Una vereda es el camino AL SITIO, no el de un viaje concreto: quien va alli
## se engancha a ella por donde le pilla. Se elige el hito por el que menos se
## anda EN TOTAL -lo que cuesta llegar hasta el, mas lo que queda de vereda
## desde el- y se cata que de aqui alli se vea en linea limpia. Engancharse por
## el hito bueno es lo que evita andar hacia atras hasta el principio.
##
## ## Si ningun hito se ve limpio se entrega la vereda entera, y eso NO es peor
##
## Es exactamente lo que hacia la cache que habia antes: el camino guardado no
## empezaba donde estaba la persona -se compartia por cubos de 48 m- asi que la
## recta de ahi al primer hito no la comprobaba nadie. De ahi salian los pasos
## que el terreno corta con camino trazado: medido, comprobar esa recta los
## bajaba de 481 a 187 en cuatro jornadas.
##
## Lo que NO se puede hacer es caer en una busqueda cuando la cata falla: eso
## se probo y agota el bote de nodos del cuadro, con media banda esperando -de
## 1 atasco en ocho jornadas a 2.567 en cuatro-. Asi que fallar la cata
## devuelve la vereda entera, que es el comportamiento de siempre, y acertarla
## la mejora.
func enganchar(desde: Vector3, grid: Navgrid) -> PackedVector3Array:
	if hitos.size() <= 1 or grid == null:
		return hitos

	# Lo que queda de vereda desde cada hito, acumulado desde el final.
	var resto := PackedFloat32Array()
	resto.resize(hitos.size())
	resto[hitos.size() - 1] = 0.0
	for i in range(hitos.size() - 2, -1, -1):
		resto[i] = resto[i + 1] + Traversal.en_llano(hitos[i], hitos[i + 1])

	# Se ordenan los candidatos por lo que costaria el viaje entero
	# enganchandose por ahi. Esto no toca la rejilla: es aritmetica.
	var orden: Array[int] = []
	for i in range(hitos.size()):
		orden.append(i)
	orden.sort_custom(func(a: int, b: int) -> bool:
		var va := Traversal.en_llano(desde, hitos[a]) + resto[a]
		var vb := Traversal.en_llano(desde, hitos[b]) + resto[b]
		return va < vb)

	# Y SOLO AHORA se cata, los mejores primero y como mucho [CATAS_DE_ENGANCHE].
	for cata in range(mini(CATAS_DE_ENGANCHE, orden.size())):
		var i: int = orden[cata]
		if not Wayfinder.linea_limpia(grid, desde, hitos[i]):
			continue
		return hitos if i == 0 else hitos.slice(i)
	return hitos


## La vereda lista para andarla hasta un punto exacto, o vacia si no sirve.
##
## Junta las dos catas: por donde se entra -[enganchar]- y por donde se sale.
## El ultimo hito de la vereda es el del SITIO, no el del punto al que va esta
## persona, y entre los dos puede haber hasta [CELDA] y medio de terreno que
## nadie ha mirado.
##
## Devolver vacio significa «esta vereda no te sirve, buscate el camino»: sale
## mas caro que entregarla igual, pero entregar un remate sin comprobar es
## mandar a alguien derecho contra una pared con un camino debajo.
func remate(desde: Vector3, hasta: Vector3, grid: Navgrid) -> PackedVector3Array:
	var trozo := enganchar(desde, grid)
	if trozo.is_empty():
		return trozo
	var ultimo := trozo[trozo.size() - 1]
	if Traversal.en_llano(ultimo, hasta) < Navgrid.CELL * 0.5:
		# Ya esta encima: se remata sin mas, que es lo que hacia siempre.
		var justo := PackedVector3Array(trozo)
		justo[justo.size() - 1] = hasta
		return justo
	if grid != null and not Wayfinder.linea_limpia(grid, ultimo, hasta):
		return PackedVector3Array()
	var con_remate := PackedVector3Array(trozo)
	con_remate.append(hasta)
	return con_remate
