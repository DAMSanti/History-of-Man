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
