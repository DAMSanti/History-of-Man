class_name SitiosDeLaCosta
extends RefCounted
## Los abrigos hipotéticos de la costa del Paleolítico, escritos a mano.
##
## EPOCA_01 §10.2. Con el mar a −120 m la costa estaba diez o quince kilómetros al
## norte de la de hoy, sobre la plataforma emergida, y allí no hay ningún yacimiento en
## el catálogo: lo que hubiera está bajo el mar y no se ha excavado. **Estos cuatro son
## hipótesis de juego**, y el juego lo dice (`Site.Fidelity.HIPOTETICO`).
##
## **Van en código y no en el conjunto horneado** porque son cuatro y puestos a mano:
## así se leen en una revisión sin hornear nada.
##
## Cada uno está en la desembocadura de la época de un río —el mismo que se dibuja en el
## mapa regional (`RiosDeLaRegion`)—, sobre un resalte a menos de 250 m del mar. Los
## puntos los propuso `CostaCaptura` el 2026-09-16 buscando el mejor resalte alrededor de
## cada desembocadura, y **los confirmó el usuario** sobre sus capturas.
##
## El Pas queda tres kilómetros al oeste del Saja-Besaya y no en su propia boca: **con el
## mar bajo los dos desembocan juntos**, y dos abrigos en el mismo sitio no son dos
## sitios.

## Ids lejos de los del catálogo, que llega a 868.
const PRIMERO := 90001

## Cota sobre el mar de la época a la que se abre el abrigo. La cota del sitio sale del
## relieve de la plataforma; ésta es sólo para decirlo en la ficha.
const LOS_SITIOS := [
	{"rio": "Nansa", "lon": -4.4669, "lat": 43.4845, "cota": -58.0, "del_mar_km": 0.22},
	{"rio": "Saja-Besaya", "lon": -4.0519, "lat": 43.5493, "cota": -52.0, "del_mar_km": 0.25},
	{"rio": "Pas", "lon": -4.0821, "lat": 43.5722, "cota": -55.0, "del_mar_km": 0.22},
	{"rio": "Asón", "lon": -3.3649, "lat": 43.5682, "cota": -77.0, "del_mar_km": 0.16},
]

## Lo que se dice de ellos en la ficha, y por qué son hipótesis.
const POR_QUE := "Hipotético: lo que hubo en esta costa está hoy bajo el mar y no se " \
	+ "ha excavado. El abrigo es una hipótesis de juego, no un yacimiento."


## Los cuatro, como emplazamientos.
static func como_sitios() -> Array[Site]:
	var fuera: Array[Site] = []
	for i in range(LOS_SITIOS.size()):
		var datos: Dictionary = LOS_SITIOS[i]
		var sitio := Site.new()
		sitio.id = PRIMERO + i
		sitio.lon = float(datos["lon"])
		sitio.lat = float(datos["lat"])
		sitio.elevation = float(datos["cota"])
		sitio.kind = Site.Kind.COSTERO
		sitio.fidelity = Site.Fidelity.HIPOTETICO
		sitio.inside_region = true
		sitio.has_shelter = true
		sitio.shelter_km = 0.0
		sitio.notable = false
		sitio.record_kind = "abrigo"
		sitio.historical_name = "Abrigo de la ría del %s" % datos["rio"]
		# A ras del agua salada y del río: es lo que lo hace un sitio de costa.
		sitio.coast_km = float(datos["del_mar_km"])
		sitio.water_km = float(datos["del_mar_km"])
		# La ladera del resalte, y lo que sobresale de lo que tiene alrededor. Son las
		# cifras con las que se eligió el punto (`CostaCaptura`).
		sitio.slope_deg = 12.0
		sitio.prominence = 35.0
		sitio.features = [{
			"class": Site.Feature.ABRIGO,
			"name": "Abrigo de la ría del %s" % datos["rio"],
			"lat": float(datos["lat"]),
			"lon": float(datos["lon"]),
			"period": "",
		}]
		fuera.append(sitio)
	return fuera
