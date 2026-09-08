extends SceneTree
## Busca llamadas a metodos que se mudaron a otra clase.
##
## Al sacar un sistema de `SettlementSim` o de `GameUI` hay que redirigir las
## llamadas de fuera. Lo que no se redirige NO da error de compilacion: GDScript
## solo se entera al ejecutar, y si el que llama es una prueba, la prueba
## revienta antes de su primera comprobacion y SE CUENTA COMO QUE PASA.
##
## Asi se colaron seis llamadas a `sim._report_spoilage` al sacar [Despensa]:
## la suite seguia diciendo 716 pruebas en verde con cinco de ellas sin
## comprobar nada. Se vio porque el total de comprobaciones bajo de 5.171 a
## 5.164; si nadie mira ese numero, no se ve.
##
##   godot --headless --path . --script res://scripts/tools/LlamadasHuerfanas.gd

## Las fachadas y las clases que salieron de ellas.
const FACHADAS := {
	"res://scripts/sim/SettlementSim.gd": ["Caceria", "Cumbres", "Despensa",
		"Hogar", "Nasas", "Percances", "Pinturas", "Reconocimiento", "Reparto",
		"Tajo", "Taller", "Trampas"],
	"res://scripts/ui/GameUI.gd": ["PanelAlmacen", "PanelRastros", "PanelTrabajos"],
}


func _init() -> void:
	var malas := 0
	for fachada: String in FACHADAS:
		malas += _revisar(fachada, FACHADAS[fachada])
	print("")
	print("llamadas huerfanas: %d" % malas)
	quit(1 if malas > 0 else 0)


func _revisar(fachada: String, clases: Array) -> int:
	# Con que NOMBRE guarda la fachada cada clase: `var nasas_line: Nasas`, no
	# «nasas». Adivinarlo del nombre de la clase daba falsos positivos.
	var campo: Dictionary = {}
	for fila: String in _leer(fachada).split("
"):
		if not fila.begins_with("var "):
			continue
		var partes := fila.trim_prefix("var ").split(":")
		if partes.size() < 2:
			continue
		var tipo := partes[1].strip_edges().split(" ")[0].split("=")[0].strip_edges()
		if clases.has(tipo):
			campo[tipo] = partes[0].strip_edges()

	var mudados: Dictionary = {}
	for clase: String in clases:
		var ruta := fachada.get_base_dir().path_join(clase + ".gd")
		for nombre: String in _metodos(ruta):
			mudados[nombre] = campo.get(clase, clase.to_lower())
		# Y las VARIABLES, que es por donde entro el peor de estos fallos:
		# `sim.wildlife = herds` estuvo meses sin conectar la fauna a la caza
		# porque asignar una propiedad que no existe no da error hasta que
		# corre, y ni siquiera entonces si nadie mira la consola.
		for nombre: String in _variables(ruta):
			mudados[nombre] = campo.get(clase, clase.to_lower())
	# Lo que la fachada conserva -pasamanos- no cuenta: sigue siendo suyo.
	for nombre: String in _metodos(fachada):
		mudados.erase(nombre)

	var malas := 0
	for ruta: String in _scripts():
		# El fichero de la propia clase no cuenta: alli sus cosas son suyas.
		if clases.has(ruta.get_file().trim_suffix(".gd")):
			continue
		var texto := _leer(ruta)
		if texto.is_empty():
			continue
		var linea := 0
		for fila: String in texto.split("\n"):
			linea += 1
			# La documentacion NOMBRA metodos a proposito -«ver `_harvest`»- y eso
			# no es una llamada.
			if fila.strip_edges().begins_with("#"):
				continue
			for nombre: String in mudados:
				# Solo `algo.loquesea`, que es un acceso sobre un objeto: la
				# definicion y los usos internos no interesan.
				if not _accede_a(fila, nombre):
					continue
				if fila.contains(String(mudados[nombre]) + "." + nombre):
					continue
				print("  %s:%d  %s -> se pide por «%s»" % [
					ruta, linea, nombre, mudados[nombre]])
				malas += 1
	return malas


## Si la linea accede de verdad a ese nombre sobre un objeto.
##
## Pide el punto delante y que detras no siga el nombre: sin lo segundo,
## «nasas_line» daba positivo por «nasas».
func _accede_a(fila: String, nombre: String) -> bool:
	var busca := "." + nombre
	var desde := 0
	while true:
		var i := fila.find(busca, desde)
		if i < 0:
			return false
		var fin := i + busca.length()
		if fin >= fila.length():
			return true
		var siguiente := fila[fin]
		if not (siguiente.is_valid_identifier() or siguiente == "_"
				or (siguiente >= "0" and siguiente <= "9")):
			return true
		desde = i + 1
	return false


func _metodos(ruta: String) -> Array[String]:
	var out: Array[String] = []
	for fila: String in _leer(ruta).split("\n"):
		if not fila.begins_with("func ") and not fila.begins_with("static func "):
			continue
		var resto := fila.trim_prefix("static ").trim_prefix("func ")
		var corte := resto.find("(")
		if corte > 0:
			out.append(resto.substr(0, corte))
	return out


## Las variables que declara un script, para poder buscarlas igual que los
## metodos.
func _variables(ruta: String) -> Array[String]:
	var out: Array[String] = []
	for fila: String in _leer(ruta).split("
"):
		if not fila.begins_with("var ") and not fila.begins_with("@export"):
			continue
		var resto := fila.trim_prefix("@export ").trim_prefix("var ")
		var nombre := resto.split(":")[0].split(" ")[0].split("=")[0].strip_edges()
		if not nombre.is_empty() and nombre != "sim" and nombre != "ui":
			out.append(nombre)
	return out


func _leer(ruta: String) -> String:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _scripts() -> Array[String]:
	var out: Array[String] = []
	_barrer("res://scripts", out)
	return out


func _barrer(carpeta: String, out: Array[String]) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		var ruta := carpeta.path_join(nombre)
		if dir.current_is_dir():
			_barrer(ruta, out)
		elif nombre.ends_with(".gd"):
			out.append(ruta)
		nombre = dir.get_next()
	dir.list_dir_end()
