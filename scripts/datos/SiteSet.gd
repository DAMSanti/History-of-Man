@tool
class_name SiteSet
extends Resource
## Conjunto de emplazamientos ya derivados.
##
## Se guarda en disco porque derivarlos cuesta ~20 s y el resultado es estatico:
## depende solo del DEM, que no cambia en tiempo de juego. Pagarlo en cada
## arranque no tendria sentido.

## Donde vive el conjunto horneado.
const RUTA := "res://data/sites/cantabria_sites.res"

## El conjunto ya leido, con los hipoteticos dentro.
static var _comarca: SiteSet = null


## LA COMARCA ENTERA, Y LA UNICA PUERTA: el conjunto horneado mas los abrigos
## hipoteticos de la costa de la epoca ([SitiosDeLaCosta]).
##
## Se cargaba con `load` en siete sitios distintos —el mapa, la expedicion, el menu, los
## campamentos, las relaciones...—, y con los hipoteticos por medio eso serian siete
## listas que no dicen lo mismo: uno saldria en el mapa y no al guardar la partida. Aqui
## se lee una vez y se reparte (EPOCA_01 §10.2).
static func comarca() -> SiteSet:
	if _comarca != null:
		return _comarca
	var conjunto := load(RUTA) as SiteSet
	if conjunto == null:
		push_error("SiteSet: no se pudo cargar " + RUTA)
		return SiteSet.new()
	# Sobre una COPIA: el recurso cargado se comparte, y anadirle sitios cada vez que se
	# pide dejaria cuatro copias de cada abrigo.
	var comarca_entera := SiteSet.new()
	comarca_entera.sites.assign(conjunto.sites)
	comarca_entera.source_heightmap = conjunto.source_heightmap
	comarca_entera.derived_at_sea_levels = conjunto.derived_at_sea_levels
	for hipotetico: Site in SitiosDeLaCosta.como_sitios():
		comarca_entera.sites.append(hipotetico)
	_comarca = comarca_entera
	return _comarca


@export var sites: Array[Site] = []
@export var source_heightmap: String = ""
@export var derived_at_sea_levels: PackedFloat32Array = PackedFloat32Array()


func playable() -> Array[Site]:
	var out: Array[Site] = []
	for s: Site in sites:
		if s.inside_region:
			out.append(s)
	return out


## Los que ademas se pueden ocupar con la tecnica de una epoca.
## Los demas siguen en el conjunto: no desaparecen, es que todavia no sabes
## como habitarlos.
func available_in(sea_level_m: float, era: Site.Era) -> Array[Site]:
	var out: Array[Site] = []
	for s: Site in sites:
		if s.inside_region and s.is_available(sea_level_m) and s.is_usable_in(era):
			out.append(s)
	return out


## Los disponibles con el mar a una cota dada
func available(sea_level_m: float) -> Array[Site]:
	var out: Array[Site] = []
	for s: Site in sites:
		if s.inside_region and s.is_available(sea_level_m):
			out.append(s)
	return out
