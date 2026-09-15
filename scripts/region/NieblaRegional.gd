class_name NieblaRegional
extends RefCounted
## Lo que se ha visto de la comarca: la niebla del mapa regional.
##
## SISTEMAS §4, «Spec (2026-09-14): explorar hacia un rumbo, y la niebla del mapa
## regional». Hasta entonces la niebla eran los alfileres —`GameState.discovered`—
## y el relieve, los ríos y la costa se veían enteros: descubrir quitaba chinchetas
## de un mapa que ya se conocía.
##
## **La rejilla es la del relieve regional**, celda a celda: así la textura cae
## exacta sobre el mapa sin reproyectar nada, y una celda son ~111 m, bastante
## para un pasillo de 700 m de medio ancho. Un byte por celda con dos capas:
##
## - [VISTA]: lo que levanta la niebla del mapa regional.
## - [RECORRIDA]: lo que han pisado las expediciones. Es lo que se enseña en el
##   minimapa de una visita, que no es lo mismo: visitar un mapa lo ve entero en
##   el regional, pero no dice nada de sus veredas.
##
## **Se levanta por exceso**: toda celda que la forma toque. Así un sitio que
## está dentro de la forma no cae nunca en una celda con niebla, que es lo que
## promete «bajo la niebla no se elige nada».

const VISTA := 1
const RECORRIDA := 2

## Lo que se le da de más a la media diagonal de una celda al levantar. La celda
## se mide con el coseno de su latitud y la forma con el de la suya, y a 25 km de
## distancia eso descuadra unos 0,3 m: sin holgura, un punto justo en el borde de
## un pasillo caía en una celda sin levantar (lo cazó `TestNieblaRegional`).
const HOLGURA_M := 1.0

## Metros por grado de latitud, los mismos que [Viaje].
const METROS_POR_GRADO := Viaje.METROS_POR_GRADO

var ancho: int = 0
var alto: int = 0
var celdas: PackedByteArray = PackedByteArray()

## La capa vista como imagen L8, llevada al día al levantar. **Por coste**: son
## 2,3 millones de celdas, y rehacerla recorriéndolas en GDScript cada vez que una
## expedición vuelve con el mapa regional abierto sería un tirón por jornada.
var _vista_l8: PackedByteArray = PackedByteArray()

## Sube cada vez que se levanta algo nuevo: quien pinta la niebla sabe así si
## tiene que rehacer su textura.
var version: int = 0

## Los límites y la forma de repartir las filas, en un `HeightmapData` sin cotas:
## sus `u_for_lon` y `v_for_lat` son los del relieve, y no una copia.
var _rejilla: HeightmapData = HeightmapData.new()

## La latitud del centro de cada fila. Las filas del relieve regional son
## Mercator, y el paso de fila a latitud no tiene una cuenta cerrada a mano: se
## busca una vez.
var _lat_de_fila: PackedFloat64Array = PackedFloat64Array()


## Una niebla entera sobre un recuadro. Las pruebas la hacen pequeña.
func _init(columnas: int = 0, filas: int = 0, norte: float = 0.0, sur: float = 0.0,
		oeste: float = 0.0, este: float = 0.0, filas_geograficas: bool = true) -> void:
	ancho = columnas
	alto = filas
	_rejilla.width = columnas
	_rejilla.height = filas
	_rejilla.lat_north = norte
	_rejilla.lat_south = sur
	_rejilla.lon_west = oeste
	_rejilla.lon_east = este
	_rejilla.geographic_rows = filas_geograficas
	celdas.resize(maxi(columnas * filas, 0))
	celdas.fill(0)
	_vista_l8.resize(celdas.size())
	_vista_l8.fill(0)
	_lat_de_fila.resize(maxi(filas, 0))
	for z in range(filas):
		_lat_de_fila[z] = _latitud_de_v((float(z) + 0.5) / float(filas))


## La niebla de la comarca, sobre el relieve regional.
static func de_la_comarca() -> NieblaRegional:
	var relieve := load("res://data/dem/cantabria_region.res") as HeightmapData
	return NieblaRegional.new(relieve.width, relieve.height, relieve.lat_north,
		relieve.lat_south, relieve.lon_west, relieve.lon_east, relieve.geographic_rows)


# --- levantar ----------------------------------------------------------------

## Un cuadrado de `lado_m` centrado en un punto: el recuadro de un mapa.
func levantar_recuadro(lon: float, lat: float, lado_m: float, capa: int = VISTA) -> int:
	var medio := lado_m * 0.5
	return levantar(lon, lat, medio * sqrt(2.0), func(x_m: float, z_m: float) -> float:
		# Distancia de un punto al cuadrado, en metros: cero o menos dentro.
		var fuera_x := maxf(absf(x_m) - medio, 0.0)
		var fuera_z := maxf(absf(z_m) - medio, 0.0)
		return sqrt(fuera_x * fuera_x + fuera_z * fuera_z), capa)


## Un círculo de `radio_m`: lo que se ve desde una cumbre.
func levantar_circulo(lon: float, lat: float, radio_m: float, capa: int = VISTA) -> int:
	return levantar(lon, lat, radio_m, func(x_m: float, z_m: float) -> float:
		return sqrt(x_m * x_m + z_m * z_m) - radio_m, capa)


## Levanta toda celda que toque una forma. Devuelve cuántas celdas eran nuevas.
##
## La forma se da alrededor de un punto: `alcance_m` es hasta dónde llega como
## mucho, y `distancia` dice a cuántos metros está un punto de ella —cero o menos,
## dentro—, con el punto en metros al este (`x`) y al sur (`z`) del centro. Una
## celda se levanta si su centro queda a menos de media diagonal de celda.
func levantar(lon: float, lat: float, alcance_m: float, distancia: Callable,
		capa: int = VISTA) -> int:
	if ancho <= 0 or alto <= 0:
		return 0
	var coseno := cos(deg_to_rad(lat))
	var margen_lon := alcance_m / (METROS_POR_GRADO * maxf(coseno, 0.01))
	var margen_lat := alcance_m / METROS_POR_GRADO
	var x0 := _columna(lon - margen_lon) - 1
	var x1 := _columna(lon + margen_lon) + 1
	var z0 := _fila(lat + margen_lat) - 1
	var z1 := _fila(lat - margen_lat) + 1
	var grados_por_columna := (_rejilla.lon_east - _rejilla.lon_west) / float(ancho)
	var nuevas := 0
	for z in range(maxi(z0, 0), mini(z1, alto - 1) + 1):
		var lat_celda := _lat_de_fila[z]
		var alto_celda_m := absf(_alto_de_fila_en_grados(z)) * METROS_POR_GRADO
		var ancho_celda_m := absf(grados_por_columna) * METROS_POR_GRADO \
			* cos(deg_to_rad(lat_celda))
		var media_diagonal := 0.5 * sqrt(ancho_celda_m * ancho_celda_m
			+ alto_celda_m * alto_celda_m)
		var z_m := (lat - lat_celda) * METROS_POR_GRADO
		for x in range(maxi(x0, 0), mini(x1, ancho - 1) + 1):
			var lon_celda := _rejilla.lon_west + (float(x) + 0.5) * grados_por_columna
			var x_m := (lon_celda - lon) * METROS_POR_GRADO * coseno
			if float(distancia.call(x_m, z_m)) > media_diagonal + HOLGURA_M:
				continue
			var i := z * ancho + x
			if celdas[i] & capa == 0:
				celdas[i] = celdas[i] | capa
				if capa & VISTA != 0:
					_vista_l8[i] = 255
				nuevas += 1
	if nuevas > 0:
		version += 1
	return nuevas


## Suma otra niebla del mismo recuadro: lo visto no se olvida.
func sumar(otra: NieblaRegional) -> void:
	if otra == null or otra.celdas.size() != celdas.size():
		return
	for i in range(celdas.size()):
		celdas[i] = celdas[i] | otra.celdas[i]
	_rehacer_la_vista()


# --- preguntar ---------------------------------------------------------------

## Si el punto está en una celda levantada.
func levantada(lon: float, lat: float, capa: int = VISTA) -> bool:
	var x := _columna(lon)
	var z := _fila(lat)
	if x < 0 or z < 0 or x >= ancho or z >= alto:
		return false
	return celdas[z * ancho + x] & capa != 0


func cuantas(capa: int = VISTA) -> int:
	var n := 0
	for valor: int in celdas:
		if valor & capa != 0:
			n += 1
	return n


## Qué parte del recuadro está levantada, de 0 a 1.
func fraccion(capa: int = VISTA) -> float:
	return float(cuantas(capa)) / float(maxi(celdas.size(), 1))


## Una capa como imagen, blanca donde está levantada. La lee el shader del mapa
## regional.
func imagen(capa: int = VISTA) -> Image:
	if capa == VISTA:
		return Image.create_from_data(ancho, alto, false, Image.FORMAT_L8, _vista_l8)
	var datos := PackedByteArray()
	datos.resize(celdas.size())
	for i in range(celdas.size()):
		datos[i] = 255 if celdas[i] & capa != 0 else 0
	return Image.create_from_data(ancho, alto, false, Image.FORMAT_L8, datos)


# --- guardar -----------------------------------------------------------------

## Lo que se guarda: comprimido, porque son dos millones de bytes casi todos a
## cero.
func a_datos() -> Dictionary:
	return {"ancho": ancho, "alto": alto, "tam": celdas.size(),
		"celdas": celdas.compress(FileAccess.COMPRESSION_ZSTD)}


## Carga lo guardado ENCIMA, sumándolo. Devuelve si cuadraba con este recuadro.
func sumar_datos(datos: Dictionary) -> bool:
	if int(datos.get("ancho", -1)) != ancho or int(datos.get("alto", -1)) != alto:
		return false
	var comprimidas: PackedByteArray = datos.get("celdas", PackedByteArray())
	var leidas := comprimidas.decompress(int(datos.get("tam", 0)),
		FileAccess.COMPRESSION_ZSTD)
	if leidas.size() != celdas.size():
		return false
	for i in range(celdas.size()):
		celdas[i] = celdas[i] | leidas[i]
	_rehacer_la_vista()
	return true


## Rehace la imagen de la vista desde las celdas: sólo al sumar otra niebla, que
## es al cargar.
func _rehacer_la_vista() -> void:
	for i in range(celdas.size()):
		_vista_l8[i] = 255 if celdas[i] & VISTA != 0 else 0
	version += 1


# --- la rejilla ----------------------------------------------------------------

func _columna(lon: float) -> int:
	return int(floor(_rejilla.u_for_lon(lon) * float(ancho)))


func _fila(lat: float) -> int:
	return int(floor(_rejilla.v_for_lat(lat) * float(alto)))


func _alto_de_fila_en_grados(z: int) -> float:
	return _latitud_de_v(float(z) / float(alto)) - _latitud_de_v(float(z + 1) / float(alto))


func _latitud_de_v(v: float) -> float:
	return _rejilla.lat_for_v(v)
