class_name TestChronicle
extends TestCase
## Pruebas del diario.
##
## Lo único con enjundia aquí es la criba: cuando el diario se llena hay que
## decidir qué se olvida, y olvidar por antigüedad a secas borraría el día que
## se descubrió la cueva para hacer sitio a «se rompió una lasca».


func suite_name() -> String:
	return "Cronica"


func _diario() -> Chronicle:
	return Chronicle.new()


func test_al_empezar_esta_vacio() -> void:
	var log := _diario()
	assert_eq(log.entries.size(), 0, "sin nada anotado")
	assert_eq(log.recent().size(), 0, "y nada que leer")


func test_lo_anotado_sale_de_lo_mas_nuevo_a_lo_mas_viejo() -> void:
	# Un diario se lee por el final: lo que acaba de pasar es lo que importa
	var log := _diario()
	log.record(1, Subsistence.Season.PRIMAVERA, 1, Chronicle.Kind.TIERRA, "primero")
	log.record(2, Subsistence.Season.PRIMAVERA, 1, Chronicle.Kind.TIERRA, "segundo")

	var last := log.recent()
	assert_eq(last.size(), 2, "las dos anotaciones")
	assert_eq(String(last[0]["text"]), "segundo", "la ultima, la primera")


func test_se_puede_filtrar_por_tipo() -> void:
	var log := _diario()
	log.record(1, 0, 1, Chronicle.Kind.TALLER, "se rompio una lasca")
	log.record(1, 0, 1, Chronicle.Kind.HALLAZGO, "una cueva")
	log.record(2, 0, 1, Chronicle.Kind.TALLER, "otra lasca")

	var taller := log.recent(40, Chronicle.Kind.TALLER)
	assert_eq(taller.size(), 2, "solo las del taller")
	var hallazgos := log.recent(40, Chronicle.Kind.HALLAZGO)
	assert_eq(hallazgos.size(), 1, "y una de hallazgos")


func test_cuenta_lo_que_hay_de_cada_tipo() -> void:
	var log := _diario()
	log.record(1, 0, 1, Chronicle.Kind.TALLER, "a")
	log.record(1, 0, 1, Chronicle.Kind.TALLER, "b")
	log.record(1, 0, 1, Chronicle.Kind.PENURIA, "c")

	var counts := log.counts()
	assert_eq(int(counts[Chronicle.Kind.TALLER]), 2, "dos del taller")
	assert_eq(int(counts[Chronicle.Kind.PENURIA]), 1, "una de penurias")


# --- la criba --------------------------------------------------------------

func test_al_llenarse_se_olvida_lo_rutinario_primero() -> void:
	# Es la regla que justifica todo el fichero: lo importante sobrevive a lo
	# rutinario aunque sea mas viejo
	var log := _diario()
	log.record(1, 0, 1, Chronicle.Kind.HALLAZGO, "LA CUEVA", 2)
	for i in range(Chronicle.MAX_ENTRIES):
		log.record(2, 0, 1, Chronicle.Kind.TALLER, "una lasca mas", 0)

	assert_eq(log.entries.size(), Chronicle.MAX_ENTRIES, "no crece sin limite")

	var found := false
	for entry: Dictionary in log.entries:
		if String(entry["text"]) == "LA CUEVA":
			found = true
	assert_true(found, "el hallazgo sigue ahi aunque era el mas viejo")


func test_si_todo_es_importante_se_olvida_lo_mas_viejo() -> void:
	# Sin esta salida, un diario lleno de cosas importantes no admitiria una
	# nueva y dejaria de contar la partida
	var log := _diario()
	for i in range(Chronicle.MAX_ENTRIES + 1):
		log.record(i, 0, 1, Chronicle.Kind.HALLAZGO, "hallazgo %d" % i, 2)

	assert_eq(log.entries.size(), Chronicle.MAX_ENTRIES, "sigue con el tope")
	assert_eq(String(log.entries[0]["text"]), "hallazgo 1",
		"el que se ha ido es el primero")


# --- lo no leido -----------------------------------------------------------

func test_lo_nuevo_se_cuenta_hasta_que_se_lee() -> void:
	var log := _diario()
	log.record(1, 0, 1, Chronicle.Kind.TIERRA, "algo")
	log.record(1, 0, 1, Chronicle.Kind.TIERRA, "algo mas")
	assert_eq(log.unread, 2, "dos sin leer")

	log.mark_read()
	assert_eq(log.unread, 0, "y ninguna despues de mirar")


func test_la_fecha_se_lee_como_una_fecha() -> void:
	var entry := {
		"day": 34, "season": Subsistence.Season.OTONO, "year": 2,
		"kind": Chronicle.Kind.TIERRA, "text": "", "weight": 1,
	}
	var stamp := Chronicle.stamp(entry)
	assert_true(stamp.contains("34"), "lleva el dia")
	assert_true(stamp.contains("Otoño"), "y la estacion")
	assert_true(stamp.contains("2"), "y el año")
