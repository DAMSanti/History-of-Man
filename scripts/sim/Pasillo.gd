class_name Pasillo
extends RefCounted
## El pasillo que recorre una expedición: desde su campamento, hacia un rumbo, lo
## que se anda en la mitad de las jornadas, y de vuelta por el mismo sitio.
##
## SISTEMAS §4, «Plan técnico: rumbo y niebla». **Una sola geometría** para las
## tres preguntas: qué sitios descubre la expedición al volver, qué niebla levanta
## y qué enseña la flecha antes de mandarla. Si la flecha trazara su pasillo con
## otra cuenta, un día enseñaría uno y se descubriría otro.

## Metros a cada lado del rumbo que se ven al pasar. **Decisión del usuario
## (2026-09-14)**: la mitad del alcance desde una cumbre
## (`Cumbres.ASCENT_SIGHT_RANGE`, 1 400 m), porque desde el fondo de un valle se
## ve menos.
const MEDIO_ANCHO_M := 700.0

## Las jornadas que se pueden elegir: de 4 a 24, de 2 en 2, para que la ida sea
## justo la mitad. Decisión del usuario (2026-09-14).
const JORNADAS_MINIMAS := 4
const JORNADAS_MAXIMAS := 24
const JORNADAS_DE_PASO := 2

var lon: float = 0.0
var lat: float = 0.0

## Grados desde el norte, en el sentido de las agujas del reloj: 90 es el este.
var rumbo: float = 0.0
var jornadas: int = 0

## Hasta dónde llega la ida, en metros sobre el terreno, y el punto donde se da la
## vuelta.
var largo_m: float = 0.0
var fin_lon: float = 0.0
var fin_lat: float = 0.0


## Si se pueden elegir tantas jornadas.
static func jornadas_validas(cuantas: int) -> bool:
	return cuantas >= JORNADAS_MINIMAS and cuantas <= JORNADAS_MAXIMAS \
		and cuantas % JORNADAS_DE_PASO == 0


## El pasillo de una salida. Se anda por el rumbo tramo a tramo sobre el relieve
## regional, con la misma cuenta que el viaje entre campamentos
## ([Viaje.andar_un_tramo]), hasta gastar las horas útiles de la mitad de las
## jornadas —**decisión del usuario**: el andar de siempre, y por la montaña se
## llega menos lejos—. Sin carga que frene: el vivac va repartido y no es una
## mudanza.
##
## **Se para en la costa de la época** (`mar_m`) y en el borde del relieve: nadie
## anda por el mar, y la primera versión lo cruzaba hasta el filo del mapa —la
## cazó `TestNieblaRegional`—.
static func trazar(desde_lon: float, desde_lat: float, hacia: float, cuantas: int,
		metros_por_hora: float = Viaje.METROS_POR_HORA_EN_LLANO,
		mar_m: float = GameState.sea_level_m) -> Pasillo:
	var pasillo := Pasillo.new()
	pasillo.lon = desde_lon
	pasillo.lat = desde_lat
	pasillo.rumbo = fposmod(hacia, 360.0)
	pasillo.jornadas = cuantas
	var horas_de_ida := float(cuantas) * 0.5 * SettlementSim.HORAS_UTILES
	var este := sin(deg_to_rad(pasillo.rumbo))
	var norte := cos(deg_to_rad(pasillo.rumbo))
	var coseno := cos(deg_to_rad(desde_lat))
	var relieve := _relieve()
	var horas := 0.0
	var andado := 0.0
	var aqui_lon := desde_lon
	var aqui_lat := desde_lat
	var cota := Viaje.cota(aqui_lat, aqui_lon)
	# Tope de tramos por si una cuenta degenerara: mil kilómetros. La ida de 24
	# jornadas en llano pasaría de 500 —12 jornadas de 11 horas a 4,5 km/h—, pero
	# la comarca mide 190 km y el mar o el borde la cortan antes.
	for _i in range(4000):
		var sig_lon := aqui_lon + este * Viaje.TRAMO_M / (Viaje.METROS_POR_GRADO * coseno)
		var sig_lat := aqui_lat + norte * Viaje.TRAMO_M / Viaje.METROS_POR_GRADO
		if relieve != null and (sig_lon < relieve.lon_west or sig_lon > relieve.lon_east
				or sig_lat > relieve.lat_north or sig_lat < relieve.lat_south):
			break
		var otra := Viaje.cota(sig_lat, sig_lon)
		if otra < mar_m:
			break
		var tramo := Viaje.andar_un_tramo(cota, otra, Viaje.TRAMO_M, 0.0, metros_por_hora)
		var cuesta := float(tramo["horas"])
		if horas + cuesta >= horas_de_ida:
			# El último tramo, sólo lo que dé de sí lo que queda.
			var parte := (horas_de_ida - horas) / maxf(cuesta, 0.0001)
			aqui_lon = lerpf(aqui_lon, sig_lon, parte)
			aqui_lat = lerpf(aqui_lat, sig_lat, parte)
			andado += Viaje.TRAMO_M * parte
			break
		horas += cuesta
		andado += Viaje.TRAMO_M
		aqui_lon = sig_lon
		aqui_lat = sig_lat
		cota = otra
	pasillo.largo_m = andado
	pasillo.fin_lon = aqui_lon
	pasillo.fin_lat = aqui_lat
	return pasillo


static func _relieve() -> HeightmapData:
	return load("res://data/dem/cantabria_region.res") as HeightmapData


## A cuántos metros del eje del pasillo está un punto, menos el medio ancho: cero
## o menos, dentro. El eje es el tramo de ida; los dos extremos, redondos.
func distancia_m(punto_lon: float, punto_lat: float) -> float:
	var coseno := cos(deg_to_rad(lat))
	var px := (punto_lon - lon) * Viaje.METROS_POR_GRADO * coseno
	var pz := (punto_lat - lat) * Viaje.METROS_POR_GRADO
	var fx := (fin_lon - lon) * Viaje.METROS_POR_GRADO * coseno
	var fz := (fin_lat - lat) * Viaje.METROS_POR_GRADO
	var largo2 := fx * fx + fz * fz
	var t := 0.0
	if largo2 > 0.0001:
		t = clampf((px * fx + pz * fz) / largo2, 0.0, 1.0)
	var dx := px - fx * t
	var dz := pz - fz * t
	return sqrt(dx * dx + dz * dz) - MEDIO_ANCHO_M


func contiene(punto_lon: float, punto_lat: float) -> bool:
	return distancia_m(punto_lon, punto_lat) <= 0.0


## Levanta en una niebla lo que el pasillo cubre. Devuelve las celdas nuevas.
##
## La distancia se pregunta con [distancia_m] y no con otra cuenta: las celdas que
## se levantan son las del mismo pasillo que [contiene].
func levantar_en(niebla: NieblaRegional, capa: int) -> int:
	var centro_lon := (lon + fin_lon) * 0.5
	var centro_lat := (lat + fin_lat) * 0.5
	var coseno := cos(deg_to_rad(centro_lat))
	return niebla.levantar(centro_lon, centro_lat, largo_m * 0.5 + MEDIO_ANCHO_M,
		func(x_m: float, z_m: float) -> float:
			# Del convenio de [NieblaRegional.levantar] —metros al este y al sur del
			# centro— a una longitud y una latitud.
			return distancia_m(centro_lon + x_m / (Viaje.METROS_POR_GRADO * coseno),
				centro_lat - z_m / Viaje.METROS_POR_GRADO), capa)


## El pasillo ya trazado, para levantarlo después sin volver a andarlo: lo que se
## levanta en la barrera es exactamente lo que se contó en el paso.
func a_datos() -> Dictionary:
	return {"lon": lon, "lat": lat, "rumbo": rumbo, "jornadas": jornadas,
		"largo": largo_m, "fin_lon": fin_lon, "fin_lat": fin_lat}


static func de_datos(datos: Dictionary) -> Pasillo:
	var pasillo := Pasillo.new()
	pasillo.lon = float(datos.get("lon", 0.0))
	pasillo.lat = float(datos.get("lat", 0.0))
	pasillo.rumbo = float(datos.get("rumbo", 0.0))
	pasillo.jornadas = int(datos.get("jornadas", 0))
	pasillo.largo_m = float(datos.get("largo", 0.0))
	pasillo.fin_lon = float(datos.get("fin_lon", pasillo.lon))
	pasillo.fin_lat = float(datos.get("fin_lat", pasillo.lat))
	return pasillo

