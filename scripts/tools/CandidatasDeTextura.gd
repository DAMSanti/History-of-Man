extends SceneTree
## LAS CANDIDATAS A TEXTURA DEL SUELO, para elegir sobre una hoja de contacto. GRAFICOS
## §7.7, tarea 4.
##
## Baja de ambientCG —CC0— las candidatas de cada capa que se quiere cambiar, y compone
## **una imagen por capa** con la textura de hoy arriba y las candidatas debajo, cada una
## con su **color** y su **altura** (el `Displacement`, que es lo que ahora manda en el
## relieve). Así se elige mirando las dos cosas, que es de lo que iba todo esto.
##
##   godot --headless --path . --script res://scripts/tools/CandidatasDeTextura.gd
##
## La descarga la hace `curl`, como [TerrainTextureIngest] y por el mismo motivo: en modo
## `--script` el módulo TLS del motor no se registra.

const BASE_URL := "https://ambientcg.com/get?file=%s_1K-JPG.zip"
const CURL_ARGS := ["-sSL", "--fail", "--retry", "2", "--max-time", "300"]
const TRABAJO := "user://candidatas"

## Qué se busca para cada capa, con la de hoy la primera. Los ids son de ambientCG.
const CANDIDATAS := {
	"Roquedo calizo": ["Rock030", "Rock020", "Rock023", "Rock029"],
	"Canchal": ["Rocks006", "Rocks002", "Rocks004", "Rocks007"],
	"Pradera": ["Grass007", "Grass001", "Grass003", "Grass004"],
	"Suelo de bosque": ["Ground037", "Ground003", "Ground013", "Ground041"],
}

## Lado de cada muestra en la hoja de contacto.
const MUESTRA := 384


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRABAJO))
	for capa: String in CANDIDATAS:
		var filas: Array[Image] = []
		var nombres: Array[String] = []
		for asset: String in CANDIDATAS[capa]:
			var mapas := _traer(asset)
			if mapas.is_empty():
				print("   %s: no se pudo traer" % asset)
				continue
			filas.append(_fila(mapas))
			nombres.append(asset)
		if filas.is_empty():
			continue
		var hoja := _hoja(filas)
		var ruta := "user://candidatas_%s.png" % capa.to_lower().replace(" ", "_")
		hoja.save_png(ruta)
		print("%s: %s → %s" % [capa, ", ".join(nombres),
			ProjectSettings.globalize_path(ruta)])
	quit()


## Baja el asset si hace falta y saca el color y la altura.
func _traer(asset: String) -> Dictionary:
	var zip_path := "%s/%s.zip" % [TRABAJO, asset]
	if not FileAccess.file_exists(zip_path):
		var args := CURL_ARGS.duplicate()
		args.append("-o")
		args.append(ProjectSettings.globalize_path(zip_path))
		args.append(BASE_URL % asset)
		var salida: Array = []
		if OS.execute("curl", args, salida, true) != 0:
			return {}
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return {}
	var color := _imagen(zip, "%s_1K-JPG_Color.jpg" % asset)
	var altura := _imagen(zip, "%s_1K-JPG_Displacement.jpg" % asset)
	zip.close()
	if color == null or altura == null:
		return {}
	return {"color": color, "altura": altura}


func _imagen(zip: ZIPReader, nombre: String) -> Image:
	var datos := zip.read_file(nombre)
	if datos.is_empty():
		return null
	var imagen := Image.new()
	if imagen.load_jpg_from_buffer(datos) != OK:
		return null
	return imagen


## Una fila: el color a la izquierda y la altura a la derecha.
func _fila(mapas: Dictionary) -> Image:
	var fila := Image.create(MUESTRA * 2, MUESTRA, false, Image.FORMAT_RGB8)
	var color: Image = mapas["color"]
	var altura: Image = mapas["altura"]
	color.resize(MUESTRA, MUESTRA)
	altura.resize(MUESTRA, MUESTRA)
	color.convert(Image.FORMAT_RGB8)
	altura.convert(Image.FORMAT_RGB8)
	fila.blit_rect(color, Rect2i(0, 0, MUESTRA, MUESTRA), Vector2i.ZERO)
	fila.blit_rect(altura, Rect2i(0, 0, MUESTRA, MUESTRA), Vector2i(MUESTRA, 0))
	return fila


func _hoja(filas: Array[Image]) -> Image:
	var hoja := Image.create(MUESTRA * 2, MUESTRA * filas.size(), false, Image.FORMAT_RGB8)
	for i in range(filas.size()):
		hoja.blit_rect(filas[i], Rect2i(0, 0, MUESTRA * 2, MUESTRA),
			Vector2i(0, i * MUESTRA))
	return hoja
