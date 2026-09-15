class_name TestRepintado
extends TestCase
## El repintado de las ventanas con el ratón encima: INTERFAZ §8.
##
## Queja del usuario del 2026-09-15: «los tooltips de las técnicas se cierran al
## segundo». Con la partida en marcha el porcentaje de una casilla cambia, la ventana
## se rehacía entera y el control bajo el ratón —con su aviso abierto— dejaba de
## existir. Lo que sólo cambia de texto se escribe encima.


func suite_name() -> String:
	return "Repintado"


func _casilla(texto: String, aviso: String) -> VBoxContainer:
	var cuerpo := VBoxContainer.new()
	var fila := HBoxContainer.new()
	cuerpo.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.tooltip_text = aviso
	fila.add_child(etiqueta)
	var boton := Button.new()
	boton.text = "Ver"
	fila.add_child(boton)
	return cuerpo


func test_si_solo_cambia_el_texto_el_control_es_el_mismo() -> void:
	var visible := _casilla("43 %", "Se aprende: 12 de 30 jornadas")
	var rehecha := _casilla("44 %", "Se aprende: 13 de 30 jornadas")
	(rehecha.get_child(0).get_child(1) as Button).disabled = true
	var etiqueta := visible.get_child(0).get_child(0) as Label
	var hecho := GameUI.copiar_encima(rehecha, visible)
	var texto := etiqueta.text
	var aviso := etiqueta.tooltip_text
	var sigue := etiqueta == visible.get_child(0).get_child(0)
	var apagado := (visible.get_child(0).get_child(1) as Button).disabled
	visible.free()
	rehecha.free()
	assert_true(hecho, "misma forma: se escribe encima")
	assert_true(sigue, "la etiqueta bajo el ratón es la misma, y su aviso no se cierra")
	assert_eq(texto, "44 %", "con el texto nuevo")
	assert_eq(aviso, "Se aprende: 13 de 30 jornadas", "y el aviso nuevo")
	assert_true(apagado, "y el botón, apagado como en la rehecha")


func test_si_cambia_la_forma_no_toca_nada() -> void:
	var visible := _casilla("43 %", "a")
	var rehecha := _casilla("dominada", "b")
	rehecha.add_child(Label.new())
	var hecho := GameUI.copiar_encima(rehecha, visible)
	var texto := (visible.get_child(0).get_child(0) as Label).text
	visible.free()
	rehecha.free()
	assert_false(hecho, "una fila más: se rehace la ventana")
	assert_eq(texto, "43 %", "y la visible queda como estaba")


func test_un_color_distinto_tambien_es_otra_forma() -> void:
	# Una técnica que se domina cambia el color de su título: eso no se escribe encima,
	# porque además gana el clic que abre su hito.
	var visible := _casilla("Lasca", "a")
	var rehecha := _casilla("Lasca", "a")
	(rehecha.get_child(0).get_child(0) as Label).add_theme_color_override("font_color", Color.RED)
	var hecho := GameUI.copiar_encima(rehecha, visible)
	visible.free()
	rehecha.free()
	assert_false(hecho, "otro color de letra: se rehace")
