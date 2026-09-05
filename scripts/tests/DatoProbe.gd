extends SceneTree
## De que resolucion es el dato de relieve que hay descargado.
##
## Importa para saber si el ruido de detalle rellena un hueco real o se suma
## encima de LiDAR bueno: el MDT05 del IGN mide cada 5 m y el terrarium de
## reserva cada 13,9 m, y la malla local va a 4 m por vertice.


func _init() -> void:
	for path: String in [
			"res://data/dem/local/site_56.res",
			"res://data/dem/local/site_9000.res",
			"res://data/dem/local/site_56_surround.res",
			"res://data/dem/local/ign_test.res"]:
		if not ResourceLoader.exists(path):
			print("%-46s no existe" % path)
			continue
		var hm: HeightmapData = load(path)
		if hm == null:
			print("%-46s no carga" % path)
			continue
		var size_m := hm.get_world_size_meters()
		print("%-46s %5d x %5d muestras · %6.2f m/muestra · %.0f x %.0f m · pipeline v%d" % [
			path.get_file(), hm.width, hm.height, hm.meters_per_sample,
			size_m.x, size_m.y, hm.pipeline_version])
	print("")
	print("malla local: %d m de lado a resolucion 825 -> %.2f m/vertice" % [
		Expedition.local_size_m, float(Expedition.local_size_m) / 824.0])
	quit()
