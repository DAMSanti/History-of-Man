class_name TestNiebla
extends TestCase
## La niebla del mapa regional: qué emplazamientos ve el jugador al empezar.
##
## Esto **no se construye aquí: ya estaba**, y esta prueba existe para dejarlo
## medido y para que no se caiga sin que nadie se entere.
##
## `SISTEMAS.md` §4 y la FASE A1 del ROADMAP daban la capa regional por «no
## construida» y decían que «hoy se ven los 862 emplazamientos de golpe». No es
## cierto desde hace tiempo: `GameState.discovered` es un diccionario de ids,
## `GameState.begin` lo arranca con **sólo la cueva**, y `RegionMap` filtra por
## él. Lo que de verdad falta —y es la tarea E3— es **quién descubre**: hoy
## nadie llama a `GameState.discover` desde la partida, así que la niebla no se
## levanta nunca.
##
## Se prueba contra los datos de verdad (`data/sites/cantabria_sites.res`) y no
## contra un conjunto de mentira, porque la cifra que importa es la de la
## partida real. Ver EPOCA_01 §10.1, tanda 2, frente 5.


## La cota del mar del Magdaleniense final. Ver EPOCAS.md §2.
const MAR_PALEOLITICO := -120.0

var _sitios: SiteSet = null
var _antes_descubierto: Dictionary = {}
var _antes_empezada := false
var _antes_casa: Site = null


func suite_name() -> String:
	return "Niebla"


func _conjunto() -> SiteSet:
	if _sitios == null:
		_sitios = load("res://data/sites/cantabria_sites.res") as SiteSet
	return _sitios


## `GameState` es estático y lo comparte toda la suite: lo que se toque aquí
## hay que devolverlo, o la prueba siguiente hereda una partida a medias.
func _guardar_el_estado() -> void:
	_antes_descubierto = GameState.discovered.duplicate()
	_antes_empezada = GameState.started
	_antes_casa = GameState.home


func _devolver_el_estado() -> void:
	GameState.discovered = _antes_descubierto
	GameState.started = _antes_empezada
	GameState.home = _antes_casa


# ------------------------------------------------------- lo que se mide --

func test_al_empezar_solo_se_conoce_la_cueva() -> void:
	# EL CRITERIO DEL FRENTE 5: «el jugador no ve los 862 de golpe». Está
	# cumplido, y de sobra: se ve UNO.
	var conjunto := _conjunto()
	assert_true(conjunto != null, "los emplazamientos horneados se cargan")
	if conjunto == null:
		return

	_guardar_el_estado()
	GameState.begin(conjunto)
	var conocidos := GameState.discovered.size()
	var casa_conocida := GameState.home != null
	_devolver_el_estado()

	assert_eq(conocidos, 1, "al empezar se conoce un solo emplazamiento")
	assert_true(casa_conocida, "y es la cueva en la que se instala la banda")


func test_los_862_NO_son_los_de_esta_epoca() -> void:
	# HALLAZGO, y corrige una cifra que se repite en varios documentos: «862
	# emplazamientos» es el conjunto ENTERO, de todas las épocas y con el mar de
	# hoy. Con el mar del Magdaleniense a −120 m y filtrando por época
	# utilizable quedan **72**, medido el 2026-09-12.
	#
	# Importa para el frente 5: lo que una expedición puede descubrir son esos
	# 72, no 862, y el criterio de «puntos regionales nuevos» que cierra la fase
	# se mide contra ese número.
	var conjunto := _conjunto()
	if conjunto == null:
		return
	var del_paleolitico := conjunto.available_in(MAR_PALEOLITICO,
		Site.Era.PALEOLITICO).size()
	assert_gt(float(del_paleolitico), 20.0,
		"hay decenas de emplazamientos detrás de la niebla, no un puñado")
	assert_lt(float(del_paleolitico), 200.0,
		"pero ni de lejos los 862 del conjunto entero")
	assert_eq(del_paleolitico, 72, "los del Paleolítico, medidos")
	# 869 y no los 862 que repetían los documentos. Medido el 2026-09-13: no
	# hay ninguno de prueba horneado —ningún id de 9000 para arriba—; el de
	# Torrelavega lo añadía el mapa regional al abrirse, y ya no existe.
	assert_eq(conjunto.sites.size(), 869, "y el conjunto horneado entero")


func test_no_queda_ningun_sitio_de_prueba() -> void:
	# Decisión del usuario del 2026-09-13: «quita Torrelavega». Ni en el conjunto
	# horneado ni añadido por el mapa regional al abrirse, que es donde vivía.
	var conjunto := _conjunto()
	if conjunto != null:
		# Un solo assert y no uno por sitio: 869 comprobaciones de golpe
		# inflarían el suelo de la suite sin comprobar nada más.
		var de_prueba := 0
		for site: Site in conjunto.sites:
			if site.id >= 9000:
				de_prueba += 1
		assert_eq(de_prueba, 0, "ningún id de sitio de prueba horneado")
	var mapa := load("res://scripts/region/RegionMap.gd") as GDScript
	assert_false(mapa.get_script_constant_map().has("DEV_PLACES"),
		"el mapa regional no lleva sitios de prueba")
	var propiedades: Array = []
	for propiedad: Dictionary in mapa.get_script_property_list():
		propiedades.append(propiedad["name"])
	assert_false("dev_sites" in propiedades, "ni el interruptor para ponerlos")


func test_descubrir_levanta_la_niebla_de_uno_y_solo_de_uno() -> void:
	var conjunto := _conjunto()
	if conjunto == null or conjunto.sites.is_empty():
		return

	_guardar_el_estado()
	GameState.begin(conjunto)
	var antes := GameState.discovered.size()
	var otro: Site = null
	for s: Site in conjunto.sites:
		if not GameState.is_discovered(s):
			otro = s
			break
	if otro != null:
		GameState.discover(otro)
	var despues := GameState.discovered.size()
	var ese_si := otro != null and GameState.is_discovered(otro)
	_devolver_el_estado()

	assert_eq(despues, antes + 1, "descubrir uno sube la cuenta en uno")
	assert_true(ese_si, "y es el que se descubrió")


func test_descubrir_el_mismo_dos_veces_no_lo_cuenta_dos_veces() -> void:
	# Importa porque la cuenta de descubiertos es uno de los tres criterios que
	# cierran la fase: si contara repetidos, se cerraría mandando la misma
	# expedición al mismo sitio.
	var conjunto := _conjunto()
	if conjunto == null or conjunto.sites.is_empty():
		return

	_guardar_el_estado()
	GameState.begin(conjunto)
	var otro: Site = null
	for s: Site in conjunto.sites:
		if not GameState.is_discovered(s):
			otro = s
			break
	if otro != null:
		GameState.discover(otro)
		GameState.discover(otro)
	var cuantos := GameState.discovered.size()
	_devolver_el_estado()

	assert_eq(cuantos, 2, "la cueva y el descubierto, no tres")
