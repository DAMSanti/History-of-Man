class_name TestTextos
extends TestCase
## Que ningún texto del juego lleve un nombre de código dentro.
##
## El 2026-09-13 el jugador leyó en la crónica «Nadie se quedó al cuidado del
## sim.hogar»: al sacar los subsistemas de `SettlementSim` —`hogar` pasó a ser
## `sim.hogar`— un buscar-y-reemplazar entró también en las frases. Salieron
## **siete**: seis de hogar y una de `sim.reconocimiento`. Arreglarlas a mano no
## impide que vuelva a pasar la próxima vez que se trocee algo, así que esto
## recorre todos los textos entre comillas de `scripts/` y falla si alguno lleva
## `sim.` dentro.
##
## Se lee el TEXTO de cada cadena y no la línea: en una misma línea puede haber
## código con `sim.` fuera de las comillas, y eso está bien.


func suite_name() -> String:
	return "Textos"


func test_ningun_texto_lleva_un_identificador_de_la_simulacion() -> void:
	var colados: Array[String] = []
	for ruta: String in _scripts("res://scripts"):
		if ruta.begins_with("res://scripts/tests/"):
			continue
		# Las herramientas no son el juego —SPECS §4.8— y alguna nombra `sim.`
		# a propósito: `CosteIndireccion` mide cuánto cuesta llamar a través de
		# él. Lo que no puede llevarlo es lo que lee el jugador.
		if ruta.begins_with("res://scripts/tools/"):
			continue
		var fichero := FileAccess.open(ruta, FileAccess.READ)
		if fichero == null:
			continue
		var numero := 0
		while not fichero.eof_reached():
			var linea := fichero.get_line()
			numero += 1
			var limpia := linea.strip_edges()
			# Los comentarios nombran código a propósito.
			if limpia.begins_with("#"):
				continue
			for cadena: String in _cadenas(linea):
				if cadena.contains("sim."):
					colados.append("%s:%d «%s»" % [ruta, numero, cadena])
		fichero.close()
	assert_eq(colados.size(), 0,
		"textos con un nombre de código dentro: %s" % str(colados))


## Lo que va entre comillas en una línea, sin las comillas.
func _cadenas(linea: String) -> Array[String]:
	var fuera: Array[String] = []
	var dentro := false
	var actual := ""
	var i := 0
	while i < linea.length():
		var c := linea[i]
		if dentro:
			if c == "\\" and i + 1 < linea.length():
				actual += linea[i + 1]
				i += 2
				continue
			if c == "\"":
				fuera.append(actual)
				actual = ""
				dentro = false
			else:
				actual += c
		else:
			# Un comentario al final de la línea cierra lo que queda.
			if c == "#":
				break
			if c == "\"":
				dentro = true
		i += 1
	return fuera


func _scripts(carpeta: String) -> Array[String]:
	var todos: Array[String] = []
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return todos
	for nombre: String in dir.get_files():
		if nombre.ends_with(".gd"):
			todos.append(carpeta.path_join(nombre))
	for sub: String in dir.get_directories():
		todos.append_array(_scripts(carpeta.path_join(sub)))
	return todos
