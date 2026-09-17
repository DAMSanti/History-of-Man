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
	"res://scripts/sim/SettlementSim.gd": ["Berrea", "Caceria", "CierreDelDia", "Cumbres", "Despensa", "Destino",
		"Hogar", "Marcha", "Nasas", "Percances", "Pinturas", "Reconocimiento",
		"Reparto", "Rutina", "Tajo", "Taller", "Trampas"],
	"res://scripts/ui/GameUI.gd": ["BarraSuperior", "PanelAlmacen", "PanelRastros",
		"PanelCenso", "PanelOficios", "PanelSitios", "PanelTrabajos"],
	"res://scripts/mundo/TerrainGenerator.gd": ["MallaDelTerreno"],
	"res://scripts/DemoMain.gd": ["Minimapa"],
}


func _init() -> void:
	var malas := 0
	for fachada: String in FACHADAS:
		malas += _revisar(fachada, FACHADAS[fachada])
		malas += _revisar_pasamanos(fachada, FACHADAS[fachada])
	print("")
	print("llamadas huerfanas: %d" % malas)
	quit(1 if malas > 0 else 0)


## El otro fallo, y el que se escapaba: la fachada llama a un metodo que YA NO
## EXISTE en la clase de detras.
##
## [_revisar] mira que una llamada vaya por el campo bueno, pero arma su lista
## con los metodos que EXISTEN; si el metodo desaparece, no hay nada que mirar y
## la herramienta dice cero. Asi se colo el 2026-09-14 borrar
## `PanelTrabajos._materials_of` -iba pegado, sin linea en blanco, al
## `_speciality_picker` muerto que se estaba quitando-: compilaba, la suite
## seguia verde, y la ventana de Territorio reventaba al abrirla porque
## `GameUI._materials_of` seguia pasandole la pelota.
##
## Se mira SOLO dentro de la fachada, que es donde viven los pasamanos: buscar
## `campo.metodo` por todo el repositorio daria falsos por los nombres comunes.
func _revisar_pasamanos(fachada: String, clases: Array) -> int:
	var campo := _campos(fachada, clases)
	var malas := 0
	for clase: String in campo:
		var nombre_del_campo: String = campo[clase]
		var fichero := _fichero_de(clase)
		if fichero.is_empty():
			print("  %s  no se encuentra el fichero de %s" % [fachada, clase])
			malas += 1
			continue
		var suyos: Dictionary = {}
		for nombre: String in _metodos(fichero):
			suyos[nombre] = true
		for nombre: String in _variables(fichero):
			suyos[nombre] = true
		var linea := 0
		for fila: String in _leer(fachada).split("\n"):
			linea += 1
			if fila.strip_edges().begins_with("#"):
				continue
			for pedido: String in _pedidos_a(_sin_cadenas(fila), nombre_del_campo):
				if suyos.has(pedido):
					continue
				print("  %s:%d  «%s.%s» no existe en %s" % [
					fachada, linea, nombre_del_campo, pedido, clase])
				malas += 1
	return malas


## Que se le pide a `campo` en esta linea: los nombres de `campo.loquesea`.
func _pedidos_a(fila: String, campo: String) -> Array[String]:
	var pedidos: Array[String] = []
	var desde := 0
	while true:
		var i := fila.find(campo + ".", desde)
		if i < 0:
			break
		desde = i + campo.length() + 1
		# Que sea el campo entero y no el final de otro nombre: `_trabajos` si,
		# `mis_trabajos` no.
		if i > 0 and _de_nombre(fila[i - 1]):
			continue
		var j := desde
		while j < fila.length() and _de_nombre(fila[j]):
			j += 1
		if j > desde:
			pedidos.append(fila.substr(desde, j - desde))
	return pedidos


func _de_nombre(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") \
		or (c >= "0" and c <= "9")


## Con que NOMBRE guarda la fachada cada clase: `var nasas_line: Nasas`, no
## «nasas». Adivinarlo del nombre de la clase daba falsos positivos.
func _campos(fachada: String, clases: Array) -> Dictionary:
	var campo: Dictionary = {}
	for fila: String in _leer(fachada).split("\n"):
		if not fila.begins_with("var "):
			continue
		var partes := fila.trim_prefix("var ").split(":")
		if partes.size() < 2:
			continue
		var tipo := partes[1].strip_edges().split(" ")[0].split("=")[0].strip_edges()
		if clases.has(tipo):
			campo[tipo] = partes[0].strip_edges()
	return campo


func _revisar(fachada: String, clases: Array) -> int:
	var campo := _campos(fachada, clases)

	var mudados: Dictionary = {}
	# De quién es cada nombre, para no llamar huérfana a una ESTÁTICA pedida por
	# su clase. `PanelTrabajos.ausentes(sim)` es exactamente como se llama a una
	# función estática, y esto la daba por mal puesta: diez falsas el
	# 2026-09-13, con la tanda 3.
	var dueno: Dictionary = {}
	for clase: String in clases:
		var ruta := _fichero_de(clase)
		for nombre: String in _metodos(ruta):
			mudados[nombre] = campo.get(clase, clase.to_lower())
			dueno[nombre] = clase
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
			# no es una llamada. Y los `print` los nombran tambien: el rotulo
			# «TerrainGenerator._create_terrain_mesh (total)» de un cronometro
			# daba positivo estando la llamada de al lado bien puesta.
			if fila.strip_edges().begins_with("#"):
				continue
			fila = _sin_cadenas(fila)
			for nombre: String in mudados:
				# Solo `algo.loquesea`, que es un acceso sobre un objeto: la
				# definicion y los usos internos no interesan.
				if not _accede_a(fila, nombre):
					continue
				if fila.contains(String(mudados[nombre]) + "." + nombre):
					continue
				# Pedida por su propia clase: es una estática, y está bien.
				if dueno.has(nombre) 						and fila.contains(String(dueno[nombre]) + "." + nombre):
					continue
				print("  %s:%d  %s -> se pide por «%s»" % [
					ruta, linea, nombre, mudados[nombre]])
				malas += 1
	return malas


## La linea sin lo que va entre comillas. Lo de dentro es texto, no codigo.
func _sin_cadenas(fila: String) -> String:
	var fuera := ""
	var dentro := false
	var comilla := ""
	for i in range(fila.length()):
		var c := fila[i]
		if dentro:
			if c == comilla:
				dentro = false
			continue
		if c == "\"" or c == "'":
			dentro = true
			comilla = c
			continue
		fuera += c
	return fuera


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
	# Sin retornos de carro: con ficheros en CRLF y en LF mezclados, un `split` por salto
	# de línea dejaba un fichero entero en una sola línea y sus variables sin ver —cinco
	# falsas huérfanas en `Marcha` el 2026-09-15, al pasarla a LF—.
	var s := f.get_as_text().replace("
", "")
	f.close()
	return s


func _scripts() -> Array[String]:
	var out: Array[String] = []
	_barrer("res://scripts", out)
	return out


## Donde vive de verdad el fichero de una clase.
##
## Se adivinaba colgandolo de la carpeta de la fachada
## (`fachada.get_base_dir()/Clase.gd`), y eso es cierto para casi todas pero no
## para [Minimapa], que esta en `scripts/vista/` mientras su fachada `DemoMain`
## esta en `scripts/`. La ruta adivinada no existia, `_metodos` devolvia vacio y
## la herramienta llevaba desde siempre **sin mirar una sola llamada de
## Minimapa** diciendo cero. Visto el 2026-09-14 al anadir [_revisar_pasamanos],
## que la delato con siete falsos positivos.
func _fichero_de(clase: String) -> String:
	if _donde.is_empty():
		for ruta: String in _scripts():
			_donde[ruta.get_file().trim_suffix(".gd")] = ruta
	return String(_donde.get(clase, ""))


var _donde: Dictionary = {}


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
