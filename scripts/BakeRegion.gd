extends SceneTree
## Herramienta de horneado de la capa regional.
##
## Deriva emplazamientos, cruza el registro arqueologico real y calcula la
## distancia a la costa de cada epoca. Todo esto depende solo del DEM, que no
## cambia en tiempo de juego, asi que se calcula una vez y se guarda.
##
## Uso:
##   godot --headless --path . --script res://scripts/BakeRegion.gd

const LEVELS := [0.0, -60.0, -120.0]
const DEM := "res://data/dem/cantabria_region.res"
const RECORD := "res://data/sites/cantabria_arqueologia.json"
const OUT_SITES := "res://data/sites/cantabria_sites.res"

## Radio de agrupamiento en km. Es la mitad del mapa local: todo lo que caeria
## dentro del mismo recuadro de 4 km no son asentamientos distintos, es el
## mismo sitio con varias cavidades. Altamira y la Cueva de Estalactitas estan
## a 40 metros.
const CLUSTER_KM := 2.0

## Clasificacion por la primera palabra del nombre.
##
## La etiqueta de OSM no distingue lo que importa: las cuevas celebres van como
## historic=archaeological_site y las simas como natural=cave_entrance, igual
## que un abrigo habitable. Y el 26% del registro son POZOS VERTICALES -torca,
## sima, sumidero- donde no se puede vivir.
##
## Meter "sima" y "torca" en la lista de cavidades fue un error: dejaba los
## emplazamientos paleoliticos dominados por simas de catalogo espeleologico.
const SHELTER_WORDS := ["cueva", "cuevas", "cuevona", "cova", "covacha",
	"covachon", "covachos", "covachota", "abrigo", "cubio", "cubillo", "gruta"]

const SHAFT_WORDS := ["torca", "torcon", "torcas", "sima", "simas", "pozo",
	"sumidero", "hoyo", "chimenea", "tornillo"]

const SPRING_WORDS := ["fuente", "fuentona", "manantial", "surgencia", "ojo"]
const MEGALITH_WORDS := ["tumulo", "tumulos", "dolmen", "menhir", "necropolis"]
const CASTRO_WORDS := ["castro", "castros"]
const ROMAN_WORDS := ["calzada", "villa", "campamento"]
const CULT_WORDS := ["iglesia", "ermita", "monasterio", "capilla", "colegiata",
	"convento", "santuario"]
const DEFENSIVE_WORDS := ["castillo", "torre", "muralla", "fuerte", "fortin",
	"bateria", "atalaya"]
const INDUSTRY_WORDS := ["molino", "molinos", "ferreria", "mina", "minas",
	"calera", "horno", "fabrica", "cantera", "presa"]


func _init() -> void:
	var data := load(DEM) as HeightmapData
	if data == null:
		print("BakeRegion: no se pudo cargar ", DEM)
		quit(1)
		return

	var deriver := SiteDeriver.new()

	# --- derivados: costa actual mas la plataforma glacial ---------------
	deriver.sea_level_m = -120.0
	var shelf: Array[Site] = []
	for s: Site in deriver.derive(data):
		if s.elevation <= 0.0 and s.inside_region:
			shelf.append(s)

	deriver.sea_level_m = 0.0
	var sites: Array[Site] = []
	for s: Site in deriver.derive(data):
		if s.inside_region:
			sites.append(s)
	for s: Site in shelf:
		sites.append(s)
	var derived_count := sites.size()

	# --- registro arqueologico real --------------------------------------
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORD))
	var caves: Array[Vector2] = []
	var attested: Array[Site] = []
	var rejected := 0

	for rec: Dictionary in doc["sites"]:
		var name: String = rec["n"]
		var kind: String = rec["k"]
		var position := Vector2(rec["lon"], rec["lat"])

		var feature_class := _classify(name, kind)
		# Solo un ABRIGO da refugio. Una torca es un pozo vertical.
		if feature_class == Site.Feature.ABRIGO:
			caves.append(position)

		if name.is_empty():
			continue

		var site := deriver.site_at(data, position.x, position.y)
		if site == null or not site.inside_region:
			continue

		# Un emplazamiento solo se funda sobre lo NATURAL. Lo construido -un
		# dolmen, un castro, una ermita- no existia al empezar la partida: es
		# prueba de ocupacion posterior, no un sitio donde plantarse.
		# Y de lo natural, solo el abrigo es habitacion: la sima senala karst
		# pero no se vive dentro, y la surgencia es agua, no cobijo.
		if feature_class != Site.Feature.ABRIGO:
			rejected += 1
			continue

		# El registro manda sobre la heuristica. Un sitio con entrada
		# enciclopedica propia se ocupo de verdad, asi que si mi regla de
		# habitabilidad lo rechaza, la equivocada es la regla: Altamira exigia
		# agua a menos de 2,5 km y la mascara de rios le da 5,9, con lo que se
		# descartaba uno de los yacimientos paleoliticos mas importantes que hay.
		var vouched := int(rec.get("w", 0)) == 1
		if not vouched and not _is_habitable(site):
			rejected += 1
			continue

		site.historical_name = name
		site.notable = int(rec.get("w", 0)) == 1
		site.record_kind = Site.feature_name(feature_class)
		site.record_period = rec["t"]
		site.fidelity = Site.Fidelity.ATESTIGUADO
		attested.append(site)

	# --- quitar derivados que pisan un yacimiento real -------------------
	var kept: Array[Site] = []
	for s: Site in sites:
		var clash := false
		for a: Site in attested:
			if absf(s.lat - a.lat) < 0.007 and absf(s.lon - a.lon) < 0.009:
				clash = true
				break
		if not clash:
			kept.append(s)
	var absorbed := sites.size() - kept.size()
	for a: Site in attested:
		kept.append(a)

	# --- abrigo: distancia a la cavidad real mas cercana -----------------
	for s: Site in kept:
		var best := 99.0
		for c: Vector2 in caves:
			# grados a km a la latitud de Cantabria
			var dx: float = (c.x - s.lon) * 81.0
			var dy: float = (c.y - s.lat) * 111.0
			best = minf(best, sqrt(dx * dx + dy * dy))
		s.shelter_km = best
		s.has_shelter = best < 0.5

	# --- distancia a la costa EN CADA EPOCA ------------------------------
	var km_per_cell := data.meters_per_sample / 1000.0
	for s: Site in kept:
		s.coast_km_by_era.resize(LEVELS.size())
	for e in range(LEVELS.size()):
		var field := deriver.coast_field(data, LEVELS[e])
		for s: Site in kept:
			s.coast_km_by_era[e] = field[s.cell.y * data.width + s.cell.x] * km_per_cell

	# --- agrupar lo que cae en el mismo recuadro local -------------------
	kept = _cluster(kept)

	# --- adjuntar los elementos reales de cada recuadro ------------------
	# TODOS los del registro, no solo los habitables: el filtro decide donde
	# se puede FUNDAR, no que existe. Si hay una cueva en el recuadro, el
	# jugador tiene que verla al entrar.
	var attached := 0
	for site: Site in kept:
		for rec: Dictionary in doc["sites"]:
			var dx: float = (float(rec["lon"]) - site.lon) * 81.0
			var dy: float = (float(rec["lat"]) - site.lat) * 111.0
			if sqrt(dx * dx + dy * dy) > CLUSTER_KM:
				continue
			var name: String = rec["n"]
			site.features.append({
				"name": name if not name.is_empty() else "sin nombre",
				"notable": int(rec.get("w", 0)) == 1,
				"class": _classify(name, rec["k"]),
				"period": rec["t"],
				"lat": rec["lat"],
				"lon": rec["lon"],
			})
			attached += 1

	for i in range(kept.size()):
		kept[i].id = i

	var result := SiteSet.new()
	result.source_heightmap = DEM
	result.derived_at_sea_levels = PackedFloat32Array(LEVELS)
	result.sites = kept
	ResourceSaver.save(result, OUT_SITES)

	_report(kept, attested.size(), derived_count, absorbed, rejected, caves.size())
	quit()


## Funde en uno solo los emplazamientos que caerian en el mismo mapa local.
## Gana el atestiguado; entre iguales, el de mejor puntuacion.
func _cluster(sites: Array[Site]) -> Array[Site]:
	var order: Array[Site] = sites.duplicate()
	# Gana el abrigo con toponimo real. Antes ordenaba por fidelidad y luego por
	# puntuacion, pero los atestiguados tienen puntuacion 0, asi que el primario
	# salia arbitrario: Altamira quedaba absorbida por una sima vecina y el
	# grupo entero tomaba el nombre de la sima.
	order.sort_custom(func(a: Site, b: Site) -> bool:
		var pa := _significance(a)
		var pb := _significance(b)
		if pa != pb:
			return pa > pb
		return a.score > b.score)

	var primaries: Array[Site] = []
	var taken := {}
	for i in range(order.size()):
		if taken.has(i):
			continue
		var primary := order[i]
		primaries.append(primary)
		for j in range(i + 1, order.size()):
			if taken.has(j):
				continue
			var other := order[j]
			var dx: float = (other.lon - primary.lon) * 81.0
			var dy: float = (other.lat - primary.lat) * 111.0
			if sqrt(dx * dx + dy * dy) <= CLUSTER_KM:
				taken[j] = true
				# Si el absorbido tenia nombre real, se conserva como elemento
				if not other.historical_name.is_empty():
					primary.features.append({
						"name": other.historical_name,
						"notable": other.notable,
						"class": _classify(other.historical_name, other.record_kind),
						"period": other.record_period,
						"lat": other.lat,
						"lon": other.lon,
					})
	return primaries


## Cuanto merece un sitio dar nombre a su grupo
func _significance(s: Site) -> int:
	if s.fidelity != Site.Fidelity.ATESTIGUADO:
		return 0
	if s.historical_name.is_empty():
		return 1
	# Un codigo de prospeccion (PG 07, SVSM3, Argumal 108) no es un toponimo
	if _is_catalogue_code(s.historical_name):
		return 2
	# Tener entrada enciclopedica es la senal mas fiable de que este es EL
	# sitio del grupo. Sin ella, entre abrigos con nombre real el desempate
	# caia en la puntuacion, que vale 0 para todos los atestiguados: el
	# primario salia al azar y Altamira quedaba dentro de "Cueva del agua".
	if s.notable:
		return 5
	return 3


## Codigo de prospeccion espeleologica en vez de nombre propio
func _is_catalogue_code(name: String) -> bool:
	var trimmed := name.strip_edges()
	if trimmed.length() <= 3:
		return true
	var words := trimmed.split(" ")
	if words.size() <= 2 and words[words.size() - 1].is_valid_int():
		return true
	return trimmed.to_upper() == trimmed and trimmed.length() < 12


## Clasifica un registro por lo que es y para que sirve
func _classify(name: String, osm_kind: String) -> Site.Feature:
	var lower := _strip_accents(name.to_lower().strip_edges())
	var first := lower.split(" ")[0] if not lower.is_empty() else ""

	if first in SHAFT_WORDS:
		return Site.Feature.SIMA
	if first in SHELTER_WORDS:
		return Site.Feature.ABRIGO
	if first in SPRING_WORDS:
		return Site.Feature.SURGENCIA
	if first in MEGALITH_WORDS:
		return Site.Feature.MEGALITO
	if first in CASTRO_WORDS:
		return Site.Feature.CASTRO
	if first in ROMAN_WORDS:
		return Site.Feature.ROMANO
	if first in CULT_WORDS:
		return Site.Feature.CULTO
	if first in DEFENSIVE_WORDS:
		return Site.Feature.DEFENSIVO
	if first in INDUSTRY_WORDS:
		return Site.Feature.INDUSTRIA

	# Sin palabra reconocible solo queda la etiqueta de OSM. Una boca de cueva
	# con nombre de codigo sigue siendo una cavidad, pero no se puede saber si
	# es abrigo o pozo, asi que NO cuenta como refugio.
	if osm_kind == "ruina":
		return Site.Feature.INDUSTRIA
	if osm_kind == "cueva":
		# Codigo de prospeccion: es una cavidad natural, pero no se sabe si es
		# abrigo o pozo. Existe en el terreno; no sirve como refugio.
		return Site.Feature.CAVIDAD
	return Site.Feature.OTRO


func _strip_accents(text: String) -> String:
	var accented := ["a", "a", "a", "a", "e", "e", "e", "e", "i", "i", "i", "i",
		"o", "o", "o", "o", "u", "u", "u", "u", "n"]
	var source := PackedStringArray([
		char(225), char(224), char(228), char(226),
		char(233), char(232), char(235), char(234),
		char(237), char(236), char(239), char(238),
		char(243), char(242), char(246), char(244),
		char(250), char(249), char(252), char(251), char(241)])
	var out := text
	for i in range(source.size()):
		out = out.replace(source[i], accented[i])
	return out


func _is_habitable(site: Site) -> bool:
	return site.elevation < 700.0 \
		and site.slope_deg < 30.0 \
		and (site.water_km < 2.5 or site.coast_km < 4.0)


func _report(sites: Array[Site], attested: int, derived: int,
		absorbed: int, rejected: int, caves: int) -> void:
	var shelter := 0
	for s: Site in sites:
		if s.has_shelter:
			shelter += 1

	print("--- BakeRegion ---")
	print("cavidades en el registro: %d" % caves)
	print("derivados %d (%d absorbidos por un yacimiento real)" % [derived, absorbed])
	print("cuevas descartadas por inhabitables: %d" % rejected)
	var att := 0
	var feats := 0
	for s: Site in sites:
		if s.fidelity == Site.Fidelity.ATESTIGUADO:
			att += 1
		feats += s.features.size()
	print("tras agrupar a %.1f km: %d emplazamientos" % [CLUSTER_KM, sites.size()])
	print("  ATESTIGUADOS %d · INFERIDOS %d" % [att, sites.size() - att])
	print("  elementos reales adjuntos: %d" % feats)
	print("con abrigo a menos de 500 m: %d" % shelter)

	var by_class := {}
	for s: Site in sites:
		for f: Dictionary in s.features:
			var c := int(f.get("class", Site.Feature.OTRO))
			by_class[c] = by_class.get(c, 0) + 1
	print("elementos por clase:")
	var order_classes: Array[int] = []
	for c: int in by_class.keys():
		order_classes.append(c)
	order_classes.sort()
	for c: int in order_classes:
		var tag := "" if Site.feature_is_natural(c as Site.Feature) else "   construido -> atestiguacion"
		print("  %-12s %5d%s" % [Site.feature_name(c as Site.Feature), by_class[c], tag])

	for era: int in [Site.Era.PALEOLITICO, Site.Era.MESOLITICO, Site.Era.NEOLITICO]:
		var usable := 0
		for s: Site in sites:
			if s.is_available(0.0) and s.is_usable_in(era):
				usable += 1
		print("  ocupables en %-14s %4d" % [Site.era_name(era), usable])

	for e in range(LEVELS.size()):
		var counts := {}
		var available := 0
		for s: Site in sites:
			if not s.is_available(LEVELS[e]):
				continue
			available += 1
			var k := s.kind_at(e)
			counts[k] = counts.get(k, 0) + 1
		var line := "  mar %+4.0f m (%4d):" % [LEVELS[e], available]
		for k: int in [Site.Kind.COSTERO, Site.Kind.VALLE, Site.Kind.ALTURA, Site.Kind.INTERIOR]:
			line += "  %-8s %4d" % [Site.name_of(k), counts.get(k, 0)]
		print(line)
