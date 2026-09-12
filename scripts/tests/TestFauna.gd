class_name TestFauna
extends TestCase
## Pruebas de qué especie de caza aparece en un paraje.
##
## Lo que hay que asegurar es que sea ESTABLE -el mismo sitio en la misma
## estación da siempre lo mismo, igual que el nombre del paraje- y que
## varíe de verdad con la estación y con el lugar.

func suite_name() -> String:
	return "Fauna"


func test_el_mismo_sitio_en_la_misma_estacion_da_lo_mismo() -> void:
	var point := Vector3(1234.0, 0.0, 5678.0)
	var first := Fauna.species_at(point, Subsistence.Season.OTONO)
	var again := Fauna.species_at(point, Subsistence.Season.OTONO)
	assert_eq(first, again, "el mismo paraje no cambia de fauna mirándolo dos veces")


func test_nunca_sale_vacio_si_la_estacion_tiene_pool() -> void:
	for season: int in Subsistence.Season.values():
		var species := Fauna.species_at(Vector3(100.0, 0.0, 200.0), season as Subsistence.Season)
		assert_gt(float(species.size()), 0.0,
			"la estación %d siempre da alguna especie" % season)


func test_no_repite_especie_dentro_del_mismo_paraje() -> void:
	var species := Fauna.species_at(Vector3(777.0, 0.0, 333.0), Subsistence.Season.INVIERNO)
	var seen := {}
	for name: String in species:
		assert_false(seen.has(name), "«%s» salió dos veces en el mismo paraje" % name)
		seen[name] = true


func test_sitios_distintos_pueden_dar_fauna_distinta() -> void:
	# No hace falta que TODOS los pares difieran, pero si de treinta puntos
	# salen todos iguales, el sorteo no esta mirando la posicion de verdad
	var first := Fauna.species_text(Vector3(0.0, 0.0, 0.0), Subsistence.Season.PRIMAVERA)
	var any_different := false
	for i in range(30):
		var point := Vector3(float(i) * 97.0, 0.0, float(i) * 53.0)
		if Fauna.species_text(point, Subsistence.Season.PRIMAVERA) != first:
			any_different = true
			break
	assert_true(any_different, "sitios distintos no dan siempre la misma fauna")


func test_species_text_coincide_con_species_at() -> void:
	# Busca un punto que de una sola especie y otro que de varias, y
	# comprueba que el texto sea coherente con la lista en los dos casos
	var solo: Vector3 = Vector3.ZERO
	var varias: Vector3 = Vector3.ZERO
	var found_solo := false
	var found_varias := false
	for i in range(60):
		var point := Vector3(float(i) * 61.0, 0.0, float(i) * 41.0)
		var species := Fauna.species_at(point, Subsistence.Season.OTONO)
		if species.size() == 1 and not found_solo:
			solo = point
			found_solo = true
		elif species.size() > 1 and not found_varias:
			varias = point
			found_varias = true
		if found_solo and found_varias:
			break

	if found_solo:
		var species := Fauna.species_at(solo, Subsistence.Season.OTONO)
		# La CLAVE es un identificador sin tilde -"jabali"- y el ROTULO es lo
		# que se lee -«jabalí»-. El texto usa el rotulo, que es lo suyo.
		assert_eq(Fauna.species_text(solo, Subsistence.Season.OTONO),
			Fauna.species_name(species[0]).to_lower(),
			"con una sola especie, el texto es esa sola")
	if found_varias:
		var text := Fauna.species_text(varias, Subsistence.Season.OTONO)
		assert_true(text.contains(" y "), "varias especies se dicen con 'y': %s" % text)


# --- que la caza mayor ande de verdad ------------------------------------
#
# El fallo: jabalí, corzo y rebeco usaban mallas de cerdo y oveja, y ese pack
# sólo horneó reposo y salto. `MOVE_CLIP` los mandaba a "idle" tanto andando
# como huyendo, así que cruzaban el valle en pose de estar quietos.

const CAZA_MAYOR := ["ciervo", "caballo", "uro", "jabali", "corzo", "rebeco"]


func test_toda_la_caza_mayor_tiene_ciclo_de_marcha() -> void:
	for species: String in CAZA_MAYOR:
		var config: Dictionary = WildlifeHerds.SPECIES_VISUAL[species]
		var model: String = config["model"]
		var clips: Dictionary = WildlifeHerds.MOVE_CLIP.get(model, {})
		assert_true(clips.get("slow", "idle") != "idle",
			"%s anda con paso propio, no con la pose de reposo" % species)
		assert_true(clips.get("fast", "idle") != "idle",
			"%s huye con paso propio" % species)


func test_los_clips_de_marcha_existen_en_lo_horneado() -> void:
	# Apuntar a un clip que no se horneó deja al animal en el fotograma cero,
	# que es peor que la pose de reposo: es una estatua.
	for species: String in WildlifeHerds.SPECIES_VISUAL:
		var config: Dictionary = WildlifeHerds.SPECIES_VISUAL[species]
		var model: String = config["model"]
		var table := WildlifeHerds._clip_table(model)
		assert_false(table.is_empty(), "%s tiene tabla de fotogramas" % model)
		for key: String in ["slow", "fast"]:
			var clip: String = (WildlifeHerds.MOVE_CLIP.get(model, {}) as Dictionary).get(key, "idle")
			assert_true(table.has(clip),
				"%s: el clip %s (%s) esta horneado" % [model, key, clip])
		assert_true(table.has(WildlifeHerds.IDLE_CLIP.get(model, "idle")),
			"%s tiene reposo" % model)


func test_ciervo_corzo_y_rebeco_no_comparten_malla_con_caballo_ni_oveja() -> void:
	for species: String in ["ciervo", "corzo", "rebeco"]:
		var model: String = (WildlifeHerds.SPECIES_VISUAL[species] as Dictionary)["model"]
		assert_true(model != "horse" and model != "sheep",
			"%s ya no lleva silueta prestada de caballo ni de oveja (%s)" % [
				species, model])


func test_la_malla_girada_lleva_su_correccion() -> void:
	# Medido con `scripts/tools/FaunaRumboProbe.gd`: la malla del lobo viene
	# tumbada un cuarto de vuelta respecto a las demas, asi que lobo, liebre y
	# conejo cruzaban el valle andando de costado.
	assert_true(WildlifeHerds.MODEL_YAW.has("wolf"),
		"el lobo necesita correccion de rumbo")
	assert_true(is_equal_approx(float(WildlifeHerds.MODEL_YAW["wolf"]), -PI * 0.5),
		"y es un cuarto de vuelta")
	for model: String in ["horse", "cow", "deer", "stag", "bull"]:
		assert_false(WildlifeHerds.MODEL_YAW.has(model),
			"%s ya viene mirando a +Z" % model)

# --- en pausa no se mueve nada -------------------------------------------
#
# Pausar es la forma de MIRAR. La fauna corria con el `delta` del motor a
# pelo, o sea que seguia pastando y huyendo con el juego parado: se paraba el
# tiempo para seguir a un ciervo y el ciervo se iba andando. Medido en el
# sitio 56 con `scripts/tests/PausaProbe.gd`: 41 m de media por animal
# andando, y 0,00 en pausa.

func test_la_fauna_va_al_compas_de_la_partida() -> void:
	var herds := WildlifeHerds.new()
	var sim := SettlementSim.new()
	herds.sim = sim

	sim.time_scale = 0.0
	var still := herds._hop_phase
	herds._process(0.5)
	assert_eq(herds._hop_phase, still, "en pausa no pasa el tiempo de la fauna")

	sim.time_scale = 1.0
	herds._process(0.5)
	assert_gt(herds._hop_phase, still, "andando si")
	herds.free()


func test_sin_partida_la_fauna_anda_por_su_cuenta() -> void:
	# Las sondas de fauna montan manadas sueltas, sin simulacion que las mande.
	var herds := WildlifeHerds.new()
	var still := herds._hop_phase
	herds._process(0.5)
	assert_gt(herds._hop_phase, still, "sin reloj al que atender, se anda")
	herds.free()


# --- La fauna anda al paso de la partida, no al del fotograma ------------
#
# docs/specs/LO_MISMO_MAS_DEPRISA.md, paso 0. Las manadas pensaban y se movían
# en su propio `_process`, con el `delta` del fotograma, y la cacería las lee:
# con eso la misma semilla no daba la misma caza.

## Tres caballos puestos a mano sobre la meseta de mentira, sin mallas: lo que
## se prueba es por dónde andan, no cómo se pintan.
func _manada_suelta(semilla: int) -> WildlifeHerds:
	var herds := WildlifeHerds.new()
	herds._terrain = FakeTerrain.new()
	herds._rng.seed = semilla
	for i in range(3):
		var inicio := Vector3(300.0 + float(i) * 40.0, 200.0, 300.0)
		var animal := {
			"species": "caballo", "slot": i, "position": inicio,
			"target": inicio + Vector3(400.0, 0.0, 0.0), "anchor": inicio,
			"timer": 1.0, "state": WildlifeHerds.State.VAGANDO, "heading": 0.0,
			"hunger": 0.0, "thirst": 0.0, "trail": PackedVector3Array([inicio]),
		}
		herds._animals.append(animal)
		herds._prey.append(animal)
	return herds


func _suelta(herds: WildlifeHerds) -> void:
	herds._terrain.free()
	herds.free()


func test_con_partida_el_fotograma_solo_pinta() -> void:
	var herds := _manada_suelta(5)
	var sim := SettlementSim.new()
	sim.time_scale = 20.0
	herds.sim = sim
	var antes: Vector3 = herds._animals[0]["position"]
	herds._process(0.5)
	assert_eq(herds._animals[0]["position"], antes,
		"con partida, el fotograma no mueve a nadie: sólo pinta")
	herds.avanzar(0.5 * 20.0)
	assert_true(herds._animals[0]["position"] != antes,
		"lo mueve el paso de la partida")
	_suelta(herds)
	sim.free()


func test_el_mismo_paso_lleva_al_mismo_sitio() -> void:
	var a := _manada_suelta(5)
	var b := _manada_suelta(5)
	for i in range(60):
		a.avanzar(0.6667)
		b.avanzar(0.6667)
	for i in range(a._animals.size()):
		assert_eq(a._animals[i]["position"], b._animals[i]["position"],
			"el animal %d acaba en el mismo sitio" % i)
	assert_eq(a._rng.state, b._rng.state, "con las mismas tiradas")
	_suelta(a)
	_suelta(b)


## Un vado somero cada pocas celdas: muchas charcas candidatas, así que el
## orden en que se barajen decide cuáles salen.
class Somero extends FakeTerrain:
	func crossing_difficulty_at(world_pos: Vector3) -> float:
		return 0.1 if int(world_pos.x / 24.0) % 3 == 0 else 0.0


func test_las_charcas_salen_siempre_las_mismas() -> void:
	# Se barajaban con el azar global del motor, que no siembra nadie: cada
	# corrida, otras charcas, y con ellas otras rutas de las manadas.
	var a := WildlifeHerds.new()
	var b := WildlifeHerds.new()
	a._terrain = Somero.new()
	b._terrain = Somero.new()
	var azar := a._rng.state
	a._find_waterholes()
	b._find_waterholes()
	assert_gt(float(a._waterholes.size()), 1.0, "hay charcas entre las que elegir")
	assert_eq(a._waterholes, b._waterholes, "las mismas y en el mismo orden")
	assert_eq(a._rng.state, azar,
		"sin gastar ninguna tirada del azar de las manadas, que va detrás")
	_suelta(a)
	_suelta(b)
