@tool
class_name HeightmapData
extends Resource
## Heightmap de elevación real importado de un DEM, con la metadata geográfica
## necesaria para mapearlo al mundo del juego.
##
## Las alturas están en METROS SOBRE EL NIVEL DEL MAR, con el cero en el mar
## real: los valores negativos son fondo marino, no un artefacto. Eso permite
## derivar la costa directamente del dato en vez de inventarla.

## Ancho y alto de la rejilla en muestras
@export var width: int = 0
@export var height: int = 0

## Elevaciones en metros, fila a fila (índice = z * width + x)
@export var elevations: PackedFloat32Array = PackedFloat32Array()

## Rango real de elevación del recuadro importado, en metros
@export var min_elevation: float = 0.0
@export var max_elevation: float = 0.0

## Metros de terreno real que cubre cada muestra
@export var meters_per_sample: float = 0.0

## Recuadro geográfico cubierto (grados decimales)
@export var lat_north: float = 0.0
@export var lat_south: float = 0.0
@export var lon_west: float = 0.0
@export var lon_east: float = 0.0

## Procedencia del dato, para poder citar la fuente y su licencia
@export var source: String = ""

## Version del proceso que genero este recuadro: descarga, despiking, borrado
## de obra humana, cauces. Existe para poder cachear el resultado en disco y
## saber cuando el fichero guardado se ha quedado viejo porque el proceso ha
## cambiado, en vez de tener que acordarse de borrarlo a mano.
@export var pipeline_version: int = 0

## Como estan repartidas las filas.
##
## Las teselas terrarium son Mercator: las filas son lineales en Y de Mercator.
## La rejilla del IGN viene en grados: las filas son lineales en LATITUD. Sobre
## un recuadro de 4 km la diferencia es pequena, pero si no se distingue el
## emplazamiento acaba desplazado respecto a sus cuevas.
@export var geographic_rows: bool = false

## Mascara de cauce 0-1 derivada del propio DEM (ver DEMImporter).
## Existe porque un plano de agua horizontal solo puede representar agua a UNA
## cota: el tramo mareal de una ria. Rio arriba el cauce esta por encima del
## nivel del mar y hay que pintarlo, no inundarlo.
@export var river_mask: PackedFloat32Array = PackedFloat32Array()

## Sentido de la corriente en cada celda, como vector unitario (x hacia el
## este, z hacia el sur, igual que el mundo). Vale cero donde no hay agua o
## donde el agua esta quieta.
##
## Existe porque sin el, el agua solo puede vibrar en el sitio: para que la
## textura desfile rio abajo hay que saber donde esta abajo, y eso del relieve
## no sale gratis. OSM lo da regalado, porque una via de agua se digitaliza
## siempre aguas abajo.
@export var flow_x: PackedFloat32Array = PackedFloat32Array()
@export var flow_z: PackedFloat32Array = PackedFloat32Array()

## Dificultad de cruzar cada celda: 0 en seco, y creciendo con el calado hasta
## pasar de infranqueable. Ver las constantes de [Hydrography].
##
## Un rio no es una textura azul, es un obstaculo, y es lo que decide por donde
## se puede ir andando y por donde hace falta un puente o una barca.
@export var ford_mask: PackedFloat32Array = PackedFloat32Array()

## Cota de la lamina de agua en cada celda de cauce, en metros. Cero fuera.
##
## Existe porque un rio tiene la lamina HORIZONTAL de orilla a orilla y solo
## desciende aguas abajo. Pintando el agua sobre el terreno tal cual, el rio
## subia la ladera con el, que es exactamente lo que no hace un rio.
@export var water_level: PackedFloat32Array = PackedFloat32Array()

## Mascara de region jugable 0-1 (ver RegionBoundary).
## El recuadro de teselas nunca coincide con una frontera real, y ademas hay
## que extenderlo mar adentro para que quepa la costa glacial. Esto separa
## "lo que hay en el DEM" de "lo que es la region".
@export var region_mask: PackedFloat32Array = PackedFloat32Array()


## Tamaño del recuadro en metros reales (ancho, alto)
func get_world_size_meters() -> Vector2:
	return Vector2(float(width) * meters_per_sample, float(height) * meters_per_sample)


## Elevación de una muestra concreta, recortando al borde fuera de rango
func get_elevation(x: int, z: int) -> float:
	if elevations.is_empty():
		return 0.0
	var cx := clampi(x, 0, width - 1)
	var cz := clampi(z, 0, height - 1)
	return elevations[cz * width + cx]


## Elevación interpolada en coordenadas normalizadas (0-1 en ambos ejes).
## Es el punto de entrada para el terreno: la malla del juego casi nunca
## coincide con la rejilla del DEM, así que hay que interpolar.
func sample_bilinear(u: float, v: float) -> float:
	if elevations.is_empty():
		return 0.0

	var fx := clampf(u, 0.0, 1.0) * float(width - 1)
	var fz := clampf(v, 0.0, 1.0) * float(height - 1)

	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, width - 1)
	var z1 := mini(z0 + 1, height - 1)

	var tx := fx - float(x0)
	var tz := fz - float(z0)

	var h0 := lerpf(get_elevation(x0, z0), get_elevation(x1, z0), tx)
	var h1 := lerpf(get_elevation(x0, z1), get_elevation(x1, z1), tx)
	return lerpf(h0, h1, tz)


## Elevación interpolada a partir de una posición en metros dentro del recuadro
func sample_meters(x_meters: float, z_meters: float) -> float:
	var size := get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0
	return sample_bilinear(x_meters / size.x, z_meters / size.y)


## Fraccion horizontal (0 = borde oeste, 1 = este) de una longitud
func u_for_lon(lon: float) -> float:
	var span := lon_east - lon_west
	if absf(span) < 1e-9:
		return 0.0
	return (lon - lon_west) / span


## Fraccion vertical (0 = borde norte, 1 = sur) de una latitud EN ESTA rejilla.
##
## Existe porque las dos fuentes reparten las filas de forma distinta: las
## teselas terrarium son Mercator y la rejilla del IGN viene en grados. Sobre
## 4 km la diferencia es de metros, pero basta para que un emplazamiento acabe
## desplazado respecto a sus propias cuevas.
func v_for_lat(lat: float) -> float:
	if geographic_rows:
		var span := lat_north - lat_south
		return 0.0 if absf(span) < 1e-9 else (lat_north - lat) / span

	var north := DEMImporter.mercator_y(lat_north)
	var south := DEMImporter.mercator_y(lat_south)
	if absf(south - north) < 1e-12:
		return 0.0
	return (DEMImporter.mercator_y(lat) - north) / (south - north)


## Valor de la mascara de cauce en coordenadas normalizadas (0-1)
func sample_river_mask(u: float, v: float) -> float:
	if river_mask.is_empty():
		return 0.0

	var fx := clampf(u, 0.0, 1.0) * float(width - 1)
	var fz := clampf(v, 0.0, 1.0) * float(height - 1)

	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, width - 1)
	var z1 := mini(z0 + 1, height - 1)
	var tx := fx - float(x0)
	var tz := fz - float(z0)

	var m0 := lerpf(river_mask[z0 * width + x0], river_mask[z0 * width + x1], tx)
	var m1 := lerpf(river_mask[z1 * width + x0], river_mask[z1 * width + x1], tx)
	return lerpf(m0, m1, tz)


## Sentido de la corriente en una posicion en metros, como (x, z).
##
## Se toma de la celda mas cercana y no interpolado: entre dos brazos de una
## confluencia la media de dos direcciones opuestas es cero, y ahi el agua se
## quedaria parada justo donde mas corre.
func sample_flow_meters(x_meters: float, z_meters: float) -> Vector2:
	if flow_x.is_empty() or flow_z.is_empty():
		return Vector2.ZERO

	var size := get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO

	var x := clampi(int(round(clampf(x_meters / size.x, 0.0, 1.0) * float(width - 1))),
		0, width - 1)
	var z := clampi(int(round(clampf(z_meters / size.y, 0.0, 1.0) * float(height - 1))),
		0, height - 1)
	var i := z * width + x
	return Vector2(flow_x[i], flow_z[i])


## Dificultad de vadeo en una posicion en metros. Como el sentido de la
## corriente, se toma de la celda mas cercana y no interpolado: interpolar
## contra la orilla suavizaria el obstaculo justo en el borde, que es donde
## importa que sea tajante.
func sample_ford_meters(x_meters: float, z_meters: float) -> float:
	if ford_mask.is_empty():
		return 0.0

	var size := get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0

	var x := clampi(int(round(clampf(x_meters / size.x, 0.0, 1.0) * float(width - 1))),
		0, width - 1)
	var z := clampi(int(round(clampf(z_meters / size.y, 0.0, 1.0) * float(height - 1))),
		0, height - 1)
	return ford_mask[z * width + x]


## Cota de la lamina de agua en una posicion en metros, o 0 si ahi no hay agua.
##
## Se toma de la celda mas cercana y no interpolado: interpolar contra la
## orilla, donde el valor es cero, hundiria la lamina justo en el borde.
func sample_water_level_meters(x_meters: float, z_meters: float) -> float:
	if water_level.is_empty():
		return 0.0

	var size := get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0

	var x := clampi(int(round(clampf(x_meters / size.x, 0.0, 1.0) * float(width - 1))),
		0, width - 1)
	var z := clampi(int(round(clampf(z_meters / size.y, 0.0, 1.0) * float(height - 1))),
		0, height - 1)
	return water_level[z * width + x]


## Valor de la mascara de cauce a partir de una posicion en metros
func sample_river_mask_meters(x_meters: float, z_meters: float) -> float:
	var size := get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0
	return sample_river_mask(x_meters / size.x, z_meters / size.y)


## Valor de la mascara de region en coordenadas normalizadas (0-1)
func sample_region_mask(u: float, v: float) -> float:
	if region_mask.is_empty():
		return 1.0

	var fx := clampf(u, 0.0, 1.0) * float(width - 1)
	var fz := clampf(v, 0.0, 1.0) * float(height - 1)

	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, width - 1)
	var z1 := mini(z0 + 1, height - 1)
	var tx := fx - float(x0)
	var tz := fz - float(z0)

	var m0 := lerpf(region_mask[z0 * width + x0], region_mask[z0 * width + x1], tx)
	var m1 := lerpf(region_mask[z1 * width + x0], region_mask[z1 * width + x1], tx)
	return lerpf(m0, m1, tz)


## Mascara de region a partir de una posicion en metros dentro del recuadro
func sample_region_mask_meters(x_meters: float, z_meters: float) -> float:
	var size := get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return sample_region_mask(x_meters / size.x, z_meters / size.y)


## Fracción de muestras que quedan al nivel del mar o por debajo
func get_water_fraction(sea_level: float = 0.0) -> float:
	if elevations.is_empty():
		return 0.0
	var below := 0
	for e in elevations:
		if e <= sea_level:
			below += 1
	return float(below) / float(elevations.size())


## Resumen legible, útil al importar o depurar
func describe() -> String:
	var size := get_world_size_meters()
	return "%d x %d muestras · %.1f x %.1f km · %.1f m/muestra · elevación %.1f..%.1f m · %s" % [
		width, height, size.x / 1000.0, size.y / 1000.0, meters_per_sample,
		min_elevation, max_elevation, source]
