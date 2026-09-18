class_name RelievePrestado
extends RefCounted
## Detalle de relieve REAL, prestado de otro sitio, para lo que el dato no trae.
##
## Depurar del 2026-09-17 (GRAFICOS §3). La plataforma que emerge con el mar bajo sale
## plana: la batimetria va a 111 m y es lisa, y el LiDAR de los valles se acaba en la
## orilla de hoy. Hasta ahora se le ponia RUIDO encima. El usuario: «no te la inventes,
## busca orografia que cuadre con esos mapas, aunque sea de otro lugar, y sticheala para
## que no se note que esta pegada».
##
## **Lo que se presta es el DETALLE, no el terreno entero.** De un trozo de tierra de
## verdad se le quita su forma grande —un emborronado de [RADIO_M]— y queda lo que tiene
## de lomas, vaguadas y resaltes, con media cero. Eso se suma encima de la forma grande
## real del sitio: el fondo marino, que es el suelo de entonces. Asi lo grande es de alli
## y lo pequeño es real de otro lado.
##
## **Y se cose.** El detalle de un punto no sale de un solo trozo: el plano se reparte en
## bloques, cada bloque toma un trozo y un sitio dentro de el —siempre el mismo, por su
## posicion—, y un punto mezcla los cuatro bloques de alrededor. Mezclar campos que no
## tienen que ver entre si baja su amplitud en las juntas, asi que la mezcla se divide
## entre la raiz de la suma de los pesos al cuadrado: la amplitud es la misma en el centro
## de un bloque que en la junta, y la junta no se ve.
##
## Funciona igual a dos escalas: la del mapa regional (111 m, trozos sacados del propio
## relieve regional) y la del valle (5 m, trozos del MDT del IGN).

## Cuanto mide el emborronado que le quita a un trozo su forma grande, en metros.
var radio_m := 3000.0

## Lado de un bloque del cosido, en metros.
var bloque_m := 4000.0

## Los trozos: su detalle, su ancho y alto en muestras, y sus metros por muestra.
var _trozos: Array[Dictionary] = []

## La semilla del reparto: que trozo y que sitio toma cada bloque.
var semilla := 20260917


## Cuantos trozos hay.
func cuantos() -> int:
	return _trozos.size()


## Suma un trozo de tierra real y guarda su detalle.
func sumar_trozo(cotas: PackedFloat32Array, ancho: int, alto: int, metros: float) -> void:
	if cotas.size() != ancho * alto or ancho < 3 or alto < 3:
		return
	var radio := maxi(1, int(round(radio_m / metros)))
	var grande := _emborronar(cotas, ancho, alto, radio)
	var detalle := PackedFloat32Array()
	detalle.resize(cotas.size())
	for i in range(cotas.size()):
		detalle[i] = cotas[i] - grande[i]
	_trozos.append({"detalle": detalle, "ancho": ancho, "alto": alto, "metros": metros})


## El detalle en un punto del plano, en metros de cota. `x_m` y `z_m` en metros.
func detalle(x_m: float, z_m: float) -> float:
	if _trozos.is_empty():
		return 0.0
	var bx := x_m / bloque_m
	var bz := z_m / bloque_m
	var x0 := int(floor(bx - 0.5))
	var z0 := int(floor(bz - 0.5))
	var tx := (bx - 0.5) - float(x0)
	var tz := (bz - 0.5) - float(z0)
	var suma := 0.0
	var pesos2 := 0.0
	for dz in range(2):
		for dx in range(2):
			var w := (tx if dx == 1 else 1.0 - tx) * (tz if dz == 1 else 1.0 - tz)
			if w <= 0.0:
				continue
			suma += w * _del_bloque(x0 + dx, z0 + dz, x_m, z_m)
			pesos2 += w * w
	return suma / sqrt(maxf(pesos2, 1.0e-6))


## Lo que da el bloque (bi, bj) en el punto: su trozo, leido desde su sitio.
func _del_bloque(bi: int, bj: int, x_m: float, z_m: float) -> float:
	var h := hash([semilla, bi, bj])
	var trozo: Dictionary = _trozos[absi(h) % _trozos.size()]
	var metros: float = trozo["metros"]
	var ancho: int = trozo["ancho"]
	var alto: int = trozo["alto"]
	# El sitio del bloque dentro del trozo. Se deja un bloque de margen a cada lado para
	# que el punto, que puede estar hasta un bloque del centro, caiga dentro.
	var margen := bloque_m / metros
	var libre_x := maxf(float(ancho - 1) - 2.0 * margen, 0.0)
	var libre_z := maxf(float(alto - 1) - 2.0 * margen, 0.0)
	var ox := margen + float(absi(h >> 8) % 10007) / 10007.0 * libre_x
	var oz := margen + float(absi(h >> 20) % 10007) / 10007.0 * libre_z
	var centro_x := (float(bi) + 0.5) * bloque_m
	var centro_z := (float(bj) + 0.5) * bloque_m
	var sx := clampf(ox + (x_m - centro_x) / metros, 0.0, float(ancho - 1))
	var sz := clampf(oz + (z_m - centro_z) / metros, 0.0, float(alto - 1))
	return _bilineal(trozo["detalle"], ancho, alto, sx, sz)


static func _bilineal(datos: PackedFloat32Array, ancho: int, alto: int,
		sx: float, sz: float) -> float:
	var x0 := int(floor(sx))
	var z0 := int(floor(sz))
	var x1 := mini(x0 + 1, ancho - 1)
	var z1 := mini(z0 + 1, alto - 1)
	var tx := sx - float(x0)
	var tz := sz - float(z0)
	var a := lerpf(datos[z0 * ancho + x0], datos[z0 * ancho + x1], tx)
	var b := lerpf(datos[z1 * ancho + x0], datos[z1 * ancho + x1], tx)
	return lerpf(a, b, tz)


## Emborronado de caja, tres pasadas por eje: se parece a una gaussiana y cuesta lo mismo
## tenga el radio que tenga.
static func _emborronar(cotas: PackedFloat32Array, ancho: int, alto: int,
		radio: int) -> PackedFloat32Array:
	var a := cotas.duplicate()
	var b := PackedFloat32Array()
	b.resize(a.size())
	for pasada in range(3):
		for z in range(alto):
			var acum := 0.0
			var n := 0
			for x in range(-radio, radio + 1):
				var xx := clampi(x, 0, ancho - 1)
				acum += a[z * ancho + xx]
				n += 1
			for x in range(ancho):
				b[z * ancho + x] = acum / float(n)
				var sale := clampi(x - radio, 0, ancho - 1)
				var entra := clampi(x + radio + 1, 0, ancho - 1)
				acum += a[z * ancho + entra] - a[z * ancho + sale]
		for x in range(ancho):
			var acum := 0.0
			var n := 0
			for z in range(-radio, radio + 1):
				var zz := clampi(z, 0, alto - 1)
				acum += b[zz * ancho + x]
				n += 1
			for z in range(alto):
				a[z * ancho + x] = acum / float(n)
				var sale := clampi(z - radio, 0, alto - 1)
				var entra := clampi(z + radio + 1, 0, alto - 1)
				acum += b[entra * ancho + x] - b[sale * ancho + x]
	return a


## Lo que decide el detalle, en un numero: va en la huella de la plataforma.
static func huella() -> int:
	return hash([FRANJA_NORTE, FRANJA_SUR, FRANJA_OESTE, FRANJA_ESTE, LADO_REGIONAL,
		TECHO_M, 3000.0, 4000.0, 20260917, 1])


## El detalle prestado de la comarca: los trozos de la franja costera del relieve
## regional de verdad. **Uno, y guardado**: lo piden el mapa regional y cada valle
## inventado, y sacarlo son unos cientos de ventanas emborronadas.
##
## Siempre del relieve REAL, no de los datos que se le pasen a quien lo pide: una prueba
## con una rejilla de mentira tiene que ver el mismo detalle que el juego.
static var _de_la_comarca: RelievePrestado = null
static var _cerrojo := Mutex.new()


static func de_la_comarca() -> RelievePrestado:
	_cerrojo.lock()
	if _de_la_comarca == null:
		var regional: HeightmapData = load("res://data/dem/cantabria_region.res")
		_de_la_comarca = de_la_region(regional)
	var hecho := _de_la_comarca
	_cerrojo.unlock()
	return hecho


## LA SABANA DE DETALLE: tierra real a 5 m de la que prestar el relieve fino, para lo que
## se levanta sin MDT propio. La hornea [HornearPrestado] de un valle del IGN ya
## descargado y va en el repositorio; el juego no descarga nada.
##
## Es la respuesta a «aunque sea de otro lugar» (decision del usuario del 2026-09-17): el
## mapa regional a 111 m no tiene nada por debajo de la loma, asi que un valle levantado
## sobre la batimetria necesita el detalle de otra parte. Antes era ruido.
const SABANA := "res://data/sites/detalle_de_tierra.res"

## Como se trocea la sabana: radio del emborronado, bloque del cosido y ventanas. A 5 m,
## 128 muestras son 640 m de trozo y el radio deja pasar lo que mide menos de 300 m.
const RADIO_FINO_M := 150.0
const BLOQUE_FINO_M := 400.0
const LADO_FINO := 128
const PASO_FINO := 64

static var _de_la_tierra: RelievePrestado = null


## El detalle fino de tierra real, uno y guardado. Vacio si no esta la sabana, y entonces
## quien lo pida se queda sin detalle fino en vez de con detalle inventado.
static func de_la_tierra() -> RelievePrestado:
	_cerrojo.lock()
	if _de_la_tierra == null:
		_de_la_tierra = RelievePrestado.new()
		_de_la_tierra.radio_m = RADIO_FINO_M
		_de_la_tierra.bloque_m = BLOQUE_FINO_M
		var sabana: HeightmapData = load(SABANA) if ResourceLoader.exists(SABANA) else null
		if sabana != null:
			for z0 in range(0, sabana.height - LADO_FINO + 1, PASO_FINO):
				for x0 in range(0, sabana.width - LADO_FINO + 1, PASO_FINO):
					var trozo := PackedFloat32Array()
					trozo.resize(LADO_FINO * LADO_FINO)
					for z in range(LADO_FINO):
						for x in range(LADO_FINO):
							trozo[z * LADO_FINO + x] = sabana.elevations[
								(z0 + z) * sabana.width + x0 + x]
					_de_la_tierra.sumar_trozo(trozo, LADO_FINO, LADO_FINO,
						sabana.meters_per_sample)
	var hecho := _de_la_tierra
	_cerrojo.unlock()
	return hecho


# --- los trozos del mapa regional ------------------------------------------------

## Donde se buscan trozos de tierra a 111 m: la franja costera de Cantabria, que es el
## relieve que tendria la plataforma si fuera tierra de hoy. Es la misma costa de la que
## salian las alturas del ruido, pero ahora se presta el relieve entero y no sus
## percentiles.
const FRANJA_NORTE := 43.52
const FRANJA_SUR := 43.20
const FRANJA_OESTE := -4.70
const FRANJA_ESTE := -3.15

## Lado de un trozo del mapa regional, en muestras (a 111 m, unos 5,3 km).
const LADO_REGIONAL := 48

## Lo mas alto que puede tener un trozo: por encima ya es montaña y no costa.
const TECHO_M := 600.0


## Los trozos de la franja costera del mapa regional: ventanas enteras de tierra.
static func de_la_region(regional: HeightmapData) -> RelievePrestado:
	var prestado := RelievePrestado.new()
	if regional == null or regional.elevations.is_empty():
		return prestado
	var x_min := int(clampf(regional.u_for_lon(FRANJA_OESTE), 0.0, 1.0) * float(regional.width - 1))
	var x_max := int(clampf(regional.u_for_lon(FRANJA_ESTE), 0.0, 1.0) * float(regional.width - 1))
	var z_a := int(clampf(regional.v_for_lat(FRANJA_NORTE), 0.0, 1.0) * float(regional.height - 1))
	var z_b := int(clampf(regional.v_for_lat(FRANJA_SUR), 0.0, 1.0) * float(regional.height - 1))
	var z_min := mini(z_a, z_b)
	var z_max := maxi(z_a, z_b)
	var paso := LADO_REGIONAL / 2
	for z0 in range(z_min, z_max - LADO_REGIONAL, paso):
		for x0 in range(x_min, x_max - LADO_REGIONAL, paso):
			var trozo := _ventana_de_tierra(regional, x0, z0, LADO_REGIONAL)
			if not trozo.is_empty():
				prestado.sumar_trozo(trozo, LADO_REGIONAL, LADO_REGIONAL, regional.meters_per_sample)
	return prestado


static func _ventana_de_tierra(datos: HeightmapData, x0: int, z0: int,
		lado: int) -> PackedFloat32Array:
	var trozo := PackedFloat32Array()
	trozo.resize(lado * lado)
	for z in range(lado):
		for x in range(lado):
			var e := datos.elevations[(z0 + z) * datos.width + (x0 + x)]
			if e <= 1.0 or e > TECHO_M:
				return PackedFloat32Array()
			trozo[z * lado + x] = e
	return trozo
