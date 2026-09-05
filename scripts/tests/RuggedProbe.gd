extends SceneTree
## Comprueba que una comarca ACCIDENTADA no se trocea en islas.
##
## La sospecha: con la regla vieja -si cualquiera de las cinco muestras de la
## celda no se pasa, la celda no se pasa- una pena de quince metros bloqueaba
## los cuarenta enteros. En la meseta de prueba no se notaba; en terreno de
## verdad trocea la comarca, y entonces `connected` dice que no y los
## exploradores no salen del campamento.

func _initialize() -> void:
	print("=== COMARCA ACCIDENTADA ===")
	for roughness in [0.15, 0.35, 0.6]:
		var terrain := RuggedTerrain.new()
		terrain.roughness = roughness
		var grid := Navgrid.from_terrain(terrain, false, false)

		# Desde el centro, a cuantos sitios del mapa se llega
		var home := Vector3(1024.0, 0.0, 1024.0)
		var reachable := 0
		var tried := 0
		for z in range(4, grid.tall - 4, 3):
			for x in range(4, grid.wide - 4, 3):
				tried += 1
				if grid.connected(home, grid.point_of(z * grid.wide + x)):
					reachable += 1

		print("   aspereza %.2f: transitable %2.0f%% · zonas %3d · desde casa se llega al %2.0f%%" % [
			roughness, grid.open_fraction() * 100.0, grid.areas,
			100.0 * float(reachable) / float(maxi(tried, 1))])
	quit()
