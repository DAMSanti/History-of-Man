class_name TestWeather
extends TestCase
## Pruebas del tiempo.
##
## Lo que importa comprobar es que TENGA INERCIA -sin ella sale un cielo
## epileptico que no se parece a ningun sitio real- y que el Cantabrico llueva
## lo que llueve: aqui el orbayu es el estado por defecto, no una rareza.


func suite_name() -> String:
	return "Clima"


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_el_tiempo_tiene_inercia() -> void:
	# Sorteando de cero cada dia, el cielo cambiaria a diario y no se podria
	# planificar nada
	var weather := Weather.new()
	var rng := _rng(7)
	var changes := 0
	var last := weather.kind
	for day in range(200):
		weather.advance(rng, Subsistence.Season.OTONO)
		if weather.kind != last:
			changes += 1
			last = weather.kind
	assert_true(changes < 140, "no cambia todos los dias (%d de 200)" % changes)
	assert_true(changes > 20, "pero cambia (%d de 200)" % changes)


func test_aqui_llueve_lo_que_llueve() -> void:
	# 1.200-1.400 mm al ano en unos 130 dias: mas de un tercio de las jornadas
	# con agua de alguna clase, y en otono mas
	var weather := Weather.new()
	var rng := _rng(3)
	var wet := 0
	for day in range(400):
		weather.advance(rng, Subsistence.Season.OTONO)
		if weather.kind in [Weather.Kind.ORBAYU, Weather.Kind.LLUVIA,
				Weather.Kind.TEMPORAL]:
			wet += 1
	var share := float(wet) / 400.0
	assert_true(share > 0.35, "en otono llueve mas de un tercio (%.0f%%)" % (share * 100.0))


func test_el_verano_es_mas_seco_que_el_otono() -> void:
	var dry := _wet_share(Subsistence.Season.VERANO)
	var wet := _wet_share(Subsistence.Season.OTONO)
	assert_true(wet > dry, "otono %.0f%% contra verano %.0f%%"
		% [wet * 100.0, dry * 100.0])


func _wet_share(season: Subsistence.Season) -> float:
	var weather := Weather.new()
	var rng := _rng(11)
	var wet := 0
	for day in range(400):
		weather.advance(rng, season)
		if weather.kind in [Weather.Kind.ORBAYU, Weather.Kind.LLUVIA,
				Weather.Kind.TEMPORAL]:
			wet += 1
	return float(wet) / 400.0


func test_solo_nieva_en_invierno() -> void:
	for season: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO]:
		assert_eq(int(Weather.ODDS[season][Weather.Kind.NIEVE]), 0,
			"en %s no nieva" % Subsistence.season_name(season as Subsistence.Season))
	assert_true(int(Weather.ODDS[Subsistence.Season.INVIERNO][Weather.Kind.NIEVE]) > 0,
		"en invierno si")


# --- los efectos -----------------------------------------------------------

func test_el_temporal_es_lo_peor_en_todo() -> void:
	var storm := Weather.new()
	storm.kind = Weather.Kind.TEMPORAL
	var clear := Weather.new()
	clear.kind = Weather.Kind.DESPEJADO

	assert_true(storm.work_factor() < clear.work_factor() * 0.5, "se trabaja fatal")
	assert_true(storm.pace_factor() < clear.pace_factor(), "se anda peor")
	assert_true(storm.risk_factor() > 2.0, "y se arriesga el doble o mas")
	assert_true(storm.keeps_indoors(), "con temporal no se sale")


func test_la_niebla_deja_explorar_sin_aprender_nada() -> void:
	# Es lo que la hace interesante: puedes salir, pero no sirve de nada
	var fog := Weather.new()
	fog.kind = Weather.Kind.NIEBLA
	assert_true(fog.sight_factor() < 0.35, "no se ve casi nada")
	assert_true(fog.pace_factor() > 0.7, "pero se anda casi normal")


func test_el_orbayu_molesta_sin_impedir() -> void:
	# Si el estado por defecto de media estacion parara el juego, no se
	# jugaria; tiene que notarse y poco mas
	var drizzle := Weather.new()
	drizzle.kind = Weather.Kind.ORBAYU
	assert_true(drizzle.work_factor() > 0.8, "se sigue trabajando")
	assert_false(drizzle.keeps_indoors(), "y se sale igual")


func test_todo_tiempo_se_puede_contar() -> void:
	for kind: int in Weather.NAMES:
		var weather := Weather.new()
		weather.kind = kind as Weather.Kind
		assert_true(weather.name_text().length() > 0, "tiene nombre")
		assert_true(weather.tell().length() > 10, "y se cuenta")
