class_name GameState
extends RefCounted
## Estado de la partida.
##
## Variables estaticas y no un autoload para no tocar project.godot: el script
## queda cargado entre cambios de escena, que es lo que hace falta para ir del
## mapa regional al local y volver.

## Emplazamiento de arranque, fijado por diseño.
##
## Cueva los pendios, valle del Nansa. Elegido a proposito por anodino: agua a
## 300 m -cantos de cuarcita y bebida-, ladera suave, nueve cavidades, y el mar
## a 12,8 km, lo bastante lejos para que la costa sea una expedicion de verdad.
## Tiene ademas tres yacimientos con entrada enciclopedica a menos de 5 km
## -Chufin, El Soplao, Los Marranos-, asi que la exploracion temprana paga.
const HOME_LAT := 43.28121
const HOME_LON := -4.42823

## Poblacion inicial. Una banda del Paleolitico superior.
## Con cuánta gente empieza la banda.
##
## Veinticinco es la cifra clásica de la etnografía —la "banda magica" de
## Birdsell— pero es el equilibrio al que una banda LLEGA, no del que sale.
## Quince es una familia extensa con algo de margen: descontando crios,
## ancianos y quien este criando, deja unos ocho adultos para jornada larga.
## Por debajo de ocho no se puede formar partida de caza y mantener el
## campamento a la vez.
const START_POPULATION := 15

## Reserva inicial: media estacion. Se empieza con algo, no de cero.
const START_FOOD_RATIO := 0.5

static var era: Site.Era = Site.Era.PALEOLITICO
static var year: int = 1
static var season: Subsistence.Season = Subsistence.Season.PRIMAVERA
static var sea_level_m: float = -120.0

static var home: Site
static var population: int = START_POPULATION
static var food: float = 0.0
static var raw_material: float = 0.0

## Ids de emplazamientos descubiertos. Al empezar, solo el propio.
static var discovered: Dictionary = {}

## Ultimo balance, para poder contarselo al jugador
static var last_report: String = ""

static var started: bool = false


## Arranca una partida en el emplazamiento de casa
static func begin(sites: SiteSet) -> void:
	home = _find_home(sites)
	if home == null:
		push_error("GameState: no se encontro el emplazamiento inicial")
		return

	era = Site.Era.PALEOLITICO
	year = 1
	season = Subsistence.Season.PRIMAVERA
	population = START_POPULATION
	food = Subsistence.consumption(population) * START_FOOD_RATIO
	raw_material = 0.0
	discovered = {home.id: true}
	last_report = "La banda se instala en %s." % home.display_name()
	started = true


static func is_discovered(site: Site) -> bool:
	return discovered.has(site.id)


static func discover(site: Site) -> void:
	discovered[site.id] = true


## Emplazamiento mas cercano a las coordenadas de arranque.
## Se busca por posicion y no por id porque los ids cambian en cada horneado.
static func _find_home(sites: SiteSet) -> Site:
	var best: Site = null
	var best_dist := INF
	for s: Site in sites.sites:
		var dx: float = (s.lon - HOME_LON) * 81.0
		var dy: float = (s.lat - HOME_LAT) * 111.0
		var d: float = sqrt(dx * dx + dy * dy)
		if d < best_dist:
			best_dist = d
			best = s
	return best


## Resuelve una estacion con el reparto de partidas dado y avanza el calendario.
## `assignment` es Activity -> numero de partidas.
static func advance_season(assignment: Dictionary) -> void:
	if home == null:
		return

	var produced := 0.0
	var gathered := 0.0
	var detail: Array[String] = []

	for activity: int in assignment.keys():
		var count: int = assignment[activity]
		if count <= 0:
			continue
		if activity == Subsistence.Activity.MATERIA_PRIMA:
			# No alimenta: produce piedra, asta y piel para la talla
			gathered += float(count) * 140.0
			continue
		# Con techo: mandar mas partidas de las que el sitio aguanta no rinde
		var total := Subsistence.harvest(
			home, season, activity as Subsistence.Activity, count)
		produced += total
		if total > 0.0:
			detail.append("%s %.0f" % [
				Subsistence.activity_name(activity as Subsistence.Activity), total])

	var eaten := Subsistence.consumption(population)
	food += produced - eaten
	raw_material += gathered

	var note := ""
	if food < 0.0:
		# Faltar el sustento de una persona durante toda la estacion cuesta una
		# persona. Se acota al 20% para que un mal año duela sin liquidar la
		# banda: antes un deficit de 800 se llevaba a dieciocho de golpe.
		var starved := mini(
			int(ceil(-food / Subsistence.DAYS_PER_SEASON)),
			maxi(int(float(population) * 0.2), 1))
		starved = mini(starved, population - 1)
		population -= starved
		food = 0.0
		note = "  HAMBRE: mueren %d." % starved
	elif food > Subsistence.consumption(population) * 1.2 			and population < Subsistence.carrying_capacity(home, population):
		# Crece solo si hay reservas Y el sitio da para mas. Por encima de la
		# capacidad de carga hay que expandirse o mejorar la tecnica.
		var born := maxi(population / 20, 1)
		population += born
		note = "  Buen año: nacen %d." % born

	last_report = "%s, año %d — producido %.0f, comido %.0f, reserva %.0f.%s\n%s" % [
		Subsistence.season_name(season), year, produced, eaten, food, note,
		"  ".join(detail)]

	season = ((season + 1) % 4) as Subsistence.Season
	if season == Subsistence.Season.PRIMAVERA:
		year += 1


## Cuantos dias de reserva quedan
static func food_days() -> float:
	if population <= 0:
		return 0.0
	return food / float(population)
