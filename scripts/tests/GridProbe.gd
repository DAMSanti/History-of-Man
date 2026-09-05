extends SceneTree
## Cuanto cuesta la rejilla de navegacion, y cuanto cuestan las busquedas
## ahora que no tocan el terreno.
##
## Es la medida que justifica el cambio: el coste de andar por la comarca
## dejaba de calcularse en mitad de cada busqueda -quince muestras del terreno
## por celda, cientos de celdas por busqueda, varias busquedas por persona y
## dia- y pasa a medirse una sola vez al empezar.

func _initialize() -> void:
	var terrain := FakeTerrain.new()

	var started := Time.get_ticks_usec()
	var grid := Navgrid.from_terrain(terrain, false, false)
	var build_us := Time.get_ticks_usec() - started

	print("=== REJILLA ===")
	print("   %d x %d celdas de %d m  (%d en total)" % [
		grid.wide, grid.tall, int(Navgrid.CELL), grid.wide * grid.tall])
	print("   construirla: %.1f ms" % (float(build_us) / 1000.0))
	print("   transitable: %.0f%% · zonas comunicadas: %d" % [
		grid.open_fraction() * 100.0, grid.areas])

	print("=== BUSQUEDAS ===")
	_time("camino facil", grid, Vector3(300, 0, 700), Vector3(900, 0, 700))
	_time("rodeo del barranco", grid, Vector3(700, 0, 700), Vector3(1350, 0, 700))
	_time("al otro lado del rio", grid, Vector3(700, 0, 700), Vector3(700, 0, 1900))
	_time("de punta a punta", grid, Vector3(60, 0, 60), Vector3(1980, 0, 1400))
	quit()


func _time(what: String, grid: Navgrid, from_point: Vector3, to_point: Vector3) -> void:
	# Cien veces, que una sola no se puede cronometrar
	var started := Time.get_ticks_usec()
	var route := PackedVector3Array()
	for i in range(100):
		route = Wayfinder.find(grid, from_point, to_point)
	var each := float(Time.get_ticks_usec() - started) / 100.0

	print("   %-22s %6.0f us · %5d nodos · %2d hitos%s" % [
		what, each, Wayfinder.last_nodes, route.size(),
		"  (SIN CAMINO)" if route.is_empty() else ""])
