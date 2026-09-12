extends SceneTree
## Lanzador de pruebas.
##   godot --headless --path . --script res://scripts/tests/RunTests.gd

func _init() -> void:
	var suites: Array[TestCase] = [
		TestSubsistence.new(),
		TestInhabitant.new(),
		TestSiteRecord.new(),
		TestTerrainInpainter.new(),
		TestHydrography.new(),
		TestFording.new(),
		TestBandKnowledge.new(),
		TestResourceField.new(),
		TestErosion.new(),
		TestTraversal.new(),
		TestDiscovery.new(),
		TestProfession.new(),
		TestExploration.new(),
		TestStorehouse.new(),
		TestToolkit.new(),
		TestTaller.new(),
		TestCampProjects.new(),
		TestChronicle.new(),
		TestJobPool.new(),
		TestRelevo.new(),
		TestPartida.new(),
		TestParajes.new(),
		TestMishap.new(),
		TestWayfinder.new(),
		TestVeredas.new(),
		TestNoche.new(),
		TestTermometro.new(),
		TestWeather.new(),
		TestAscent.new(),
		TestTeaching.new(),
		TestFauna.new(),
		TestFishing.new(),
		TestHunting.new(),
		TestJornada.new(),
		TestDespensa.new(),
		TestLobo.new(),
		TestCaceria.new(),
		TestRelato.new(),
		TestIntercambio.new(),
		TestInstantanea.new(),
		(load("res://scripts/tests/TestTechMilestones.gd") as GDScript).new(),
	]

	var passed := 0
	var failed := 0
	var checks := 0
	var failures: Array[String] = []

	for suite: TestCase in suites:
		var result := suite.run()
		passed += result[0]
		failed += result[1]
		checks += suite.checks
		for f: String in suite.failures:
			failures.append(f)
		print("  %-16s %2d pasan, %d fallan, %d comprobaciones" % [suite.suite_name(), result[0], result[1], suite.checks])

	print("")
	if failures.is_empty():
		print("TODO OK — %d pruebas, %d comprobaciones" % [passed, checks])
	else:
		print("FALLAN %d de %d pruebas:" % [failed, passed + failed])
		for f: String in failures:
			print("  x %s" % f)

	quit(0 if failures.is_empty() else 1)
