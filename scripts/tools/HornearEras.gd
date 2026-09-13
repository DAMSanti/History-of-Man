extends SceneTree
## Hornea las máscaras de territorio por cota del mar: `cantabria_eras.res`.
##
## La herramienta que lo hacía era el `BakeRegion` viejo, y ya no existía: el
## 2026-09-13 hubo que rehacerla para que la frontera llegue hasta el agua (frente
## 18 de EPOCA_01 §10.1, tanda 4). Reutiliza las cotas que ya tenía el fichero, y
## si no hay fichero, las de siempre.
##
##   godot --headless --path . --script res://scripts/tools/HornearEras.gd

const RELIEVE := "res://data/dem/cantabria_region.res"
const FRONTERA := "res://data/boundaries/cantabria.res"
const SALIDA := "res://data/sites/cantabria_eras.res"

## Las cotas si no hay fichero del que sacarlas: de hoy a lo más bajo del
## Paleolítico que el juego usa.
const COTAS_POR_DEFECTO := [0.0, -20.0, -40.0, -60.0, -80.0, -100.0, -120.0]


func _init() -> void:
	var relieve: HeightmapData = load(RELIEVE)
	var frontera: RegionBoundary = load(FRONTERA)
	if relieve == null or frontera == null:
		print("faltan el relieve o la frontera")
		quit(1)
		return

	var cotas: PackedFloat32Array = PackedFloat32Array(COTAS_POR_DEFECTO)
	if ResourceLoader.exists(SALIDA):
		var viejas: RegionEras = load(SALIDA)
		if viejas != null and not viejas.sea_levels.is_empty():
			cotas = viejas.sea_levels

	var eras := RegionEras.new()
	eras.sea_levels = cotas
	eras.width = relieve.width
	eras.height = relieve.height
	for cota: float in cotas:
		var t0 := Time.get_ticks_msec()
		var mascara := frontera.build_playable_mask(relieve, cota)
		var bytes := PackedByteArray()
		bytes.resize(mascara.size())
		var dentro := 0
		for i in range(mascara.size()):
			bytes[i] = 255 if mascara[i] > 0.5 else 0
			if mascara[i] > 0.5:
				dentro += 1
		eras.masks.append(bytes)
		print("cota %+.0f m: %d celdas dentro, %d ms" % [cota, dentro,
			Time.get_ticks_msec() - t0])

	var error := ResourceSaver.save(eras, SALIDA)
	print("horneado en %s (%s)" % [SALIDA, "bien" if error == OK else "error %d" % error])
	quit(0 if error == OK else 1)
