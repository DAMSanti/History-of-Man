extends SceneTree
## Hoja de contactos de los arrays del terreno, para mirarlos antes de creerse
## que están bien.
##
## Que la ingesta diga «32 MB guardados» sólo prueba que escribió bytes. Lo que
## hay que ver es si el limo parece limo, si el ORM lleva algo en cada canal y
## si Rock063 —que viene en 1024x512— salió REPETIDO y no estirado.
##
## Una fila por tanda: color, normal y ORM. El ORM se enseña en crudo, así que
## se lee por colores: el rojo es oclusión, el verde rugosidad y el azul, que
## está a cero, hace que lo mate salga amarillo.

const CELL := 256
const OUT := "user://terrain_sheet.png"


func _init() -> void:
	var arrays: TerrainTextureArrays = load(TerrainLayers.ARRAYS_PATH)
	if arrays == null:
		print("no hay arrays en %s" % TerrainLayers.ARRAYS_PATH)
		quit(1)
		return
	if not arrays.is_usable():
		print("los arrays no sirven: %d capas" % arrays.layers)
		quit(1)
		return

	var rows := [arrays.albedo_images, arrays.normal_images, arrays.orm_images]
	var sheet := Image.create(CELL * TerrainLayers.COUNT, CELL * rows.size(),
		false, Image.FORMAT_RGBA8)

	for row in range(rows.size()):
		var images: Array[Image] = rows[row]
		for column in range(images.size()):
			var cell := (images[column] as Image).duplicate() as Image
			# Vienen en BC7; hay que deshacer la compresión para poder pegarlas
			if cell.is_compressed():
				cell.decompress()
			cell.convert(Image.FORMAT_RGBA8)
			cell.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(cell, Rect2i(0, 0, CELL, CELL),
				Vector2i(column * CELL, row * CELL))

	sheet.save_png(OUT)

	print("capas, en orden:")
	for i in range(TerrainLayers.COUNT):
		print("  %d  %-18s %s" % [i, TerrainLayers.CATALOGUE[i]["name"],
			TerrainLayers.CATALOGUE[i]["asset"]])
	print("filas: color · normal · ORM")
	print("hoja en %s" % ProjectSettings.globalize_path(OUT))
	quit()
