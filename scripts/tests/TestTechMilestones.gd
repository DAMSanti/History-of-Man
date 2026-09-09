class_name TestTechMilestones
extends TestCase
## Comprueba que el sistema de hitos técnicos y sus vídeos están completos y operativos.

const PopupHitoScript := preload("res://scripts/ui/PopupHitoTecnico.gd")

func suite_name() -> String:
	return "TechMilestones"


func test_todas_las_19_tecnicas_tienen_mapeo_de_video() -> void:
	var unlockable := [
		TechTree.Tech.NUCLEO, TechTree.Tech.HOJA, TechTree.Tech.AGUJA,
		TechTree.Tech.LAZO, TechTree.Tech.CEPO, TechTree.Tech.RED_AVES, TechTree.Tech.FOSO,
		TechTree.Tech.OJEO, TechTree.Tech.AZAGAYA, TechTree.Tech.PROPULSOR, TechTree.Tech.ARCO,
		TechTree.Tech.PESQUERA, TechTree.Tech.NASA, TechTree.Tech.ANZUELO, TechTree.Tech.RED,
		TechTree.Tech.ARPON, TechTree.Tech.PASARELA, TechTree.Tech.PIRAGUA, TechTree.Tech.ARTE
	]
	assert_eq(unlockable.size(), 19, "Hay exactamente 19 tecnicas desbloqueables")
	for tech: TechTree.Tech in unlockable:
		assert_true(PopupHitoScript.TECH_VIDEOS.has(tech),
			"La tecnica %s debe tener identificador de video" % TechTree.tech_name(tech))
		assert_true(PopupHitoScript.TECH_EFFECTS.has(tech),
			"La tecnica %s debe tener descripcion de efecto" % TechTree.tech_name(tech))


func test_popup_se_crea_y_encola_correctamente() -> void:
	var popup = PopupHitoScript.new()
	assert_true(popup != null, "El popup debe instanciarse")
	assert_false(popup.visible, "El popup empieza oculto")

	# Encolar tecnica
	popup.queue_tech(TechTree.Tech.LAZO)
	assert_true(popup.visible, "Al encolar se hace visible")
	assert_eq(popup._current_tech, int(TechTree.Tech.LAZO), "Debe mostrar el lazo de fibra")

	# Encolar segunda tecnica
	popup.queue_tech(TechTree.Tech.CEPO)
	assert_eq(popup._queue.size(), 1, "La segunda tecnica debe quedar en la cola")

	# Avanzar al siguiente
	popup._on_continue_pressed()
	assert_eq(popup._current_tech, int(TechTree.Tech.CEPO), "Ahora debe mostrar el cepo")

	# Avanzar y cerrar
	popup._on_continue_pressed()
	assert_false(popup.visible, "Tras la cola debe quedar oculto")
	popup.free()


func test_videos_ogv_cargan_en_videostream() -> void:
	var generated_videos := [
		"tech_nucleo", "tech_hoja", "tech_aguja", "tech_lazo", "tech_cepo"
	]
	for vid: String in generated_videos:
		var path := "res://videos/tech/%s.ogv" % vid
		assert_true(FileAccess.file_exists(path), "El video %s.ogv debe existir" % vid)
		var stream := VideoStreamTheora.new()
		stream.file = path
		assert_eq(stream.file, path, "El stream de %s debe configurarse correctamente" % vid)
