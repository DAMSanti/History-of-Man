extends SceneTree
## Hoja de contactos de las obras: todo lo que la banda planta en el mundo,
## fotografiado uno por uno y montado en una lámina.
##
## Es la herramienta de vista que le faltaba a las construcciones pequeñas. El
## censo en el juego —[CensoDeObras]— contesta «¿está puesta y dónde?»; esto
## contesta la otra mitad: «¿y cómo es?». Cuatro tipos de trampa que de lejos
## son cuatro estacas iguales sólo se pueden comparar poniéndolos al lado.
##
## Fotografía los MODELOS DE VERDAD —[TrapMarkers], [NasaMarkers], [Bonfire],
## [Tienda]— y no una reconstrucción: una lámina que dibujara su propia versión
## de un cepo dejaría de decir la verdad en cuanto alguien tocara el cepo.
##
## Correr con:
##   Godot_v4.5.1-stable_win64.exe --path . \
##     --script res://scripts/tools/ObrasAtlas.gd

## Lado de cada foto, en píxeles.
const CELDA := 320

## Se fotografía a este múltiplo y se reduce después: las varas de una trampa
## son de cuatro centímetros y a tamaño final salen aserradas.
const SUPER := 2

## Columnas de la lámina.
const COLUMNAS := 3

const SALIDA := "user://obras.png"

var _view: SubViewport
var _soporte: Node3D
var _camara: Camera3D


func _init() -> void:
	_estudio()
	await process_frame

	var fichas: Array[Dictionary] = []
	for kind: int in Trap.Kind.values():
		fichas.append(await _foto_de_trampa(kind as Trap.Kind))
	fichas.append(await _foto_de_nasa())
	fichas.append(await _foto(_hoguera(), "Hoguera", "el hogar del abrigo"))
	fichas.append(await _foto(_hoguera(BivouacFires.FIRE_SIZE), "Hoguera de vivac",
		"lo mismo, más pequeño: cuatro palos"))
	fichas.append(await _foto(_tienda(), "Tienda de vivac",
		"pieles sobre tres varas"))
	fichas.append(await _foto(_vivac(), "Vivac armado",
		"la noche entera: fuego y tienda"))

	await _lamina(fichas)
	quit()


# ------------------------------------------------------------ el estudio --

## Fondo transparente y luz plana con un punto de lado: lo que se guarda es el
## color propio de la pieza, pero con algo de forma. Sin la lateral, una vara
## cilíndrica sale como un rectángulo de color.
func _estudio() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(CELDA, CELDA) * SUPER
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)

	var mundo := WorldEnvironment.new()
	var ambiente := Environment.new()
	# Fondo OPACO y del color de la piel, no transparente. La llama de una
	# hoguera son tres cuadros con mezcla aditiva -ver [Bonfire]-, y aditivo
	# sobre un fondo transparente suma color sin sumar alfa: la hoguera salía
	# como un rectángulo naranja macizo. Sobre fondo opaco compone bien, y
	# además la celda se funde con la lámina.
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = UISkin.GROUND.lightened(0.06)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.62, 0.62, 0.66)
	ambiente.ambient_light_energy = 1.0
	mundo.environment = ambiente
	_view.add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, -132.0, 0.0)
	sol.light_energy = 1.5
	_view.add_child(sol)

	_soporte = Node3D.new()
	_view.add_child(_soporte)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_view.add_child(_camara)


## Encuadra lo que haya puesto: se mide su caja y se ajusta el zoom.
##
## Se mide en vez de fijarse a ojo porque las piezas van de 0,4 m —un cepo— a
## 3,2 m —la estaca de una trampa—, y con un encuadre fijo la mitad salen como
## un punto y la otra mitad recortadas.
func _encuadrar() -> void:
	var caja := AABB()
	var primera := true
	for nodo: Node in _soporte.get_children():
		for malla: Node in _mallas(nodo):
			var mi := malla as MeshInstance3D
			if mi.mesh == null:
				continue
			var suya := mi.global_transform * mi.mesh.get_aabb()
			caja = suya if primera else caja.merge(suya)
			primera = false
	if primera:
		caja = AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)

	var centro := caja.get_center()
	var lado := maxf(maxf(caja.size.x, caja.size.y), caja.size.z)
	_camara.size = lado * 1.28
	# Tres cuartos y algo de altura: es como se mira una cosa puesta en el
	# suelo, y es el único ángulo en el que un foso se distingue de un cepo.
	var lejos := lado * 3.0 + 2.0
	_camara.global_position = centro + Vector3(0.78, 0.62, 1.0).normalized() * lejos
	_camara.look_at(centro, Vector3.UP)


func _mallas(nodo: Node) -> Array[Node]:
	var out: Array[Node] = []
	if nodo is MeshInstance3D:
		out.append(nodo)
	for hijo: Node in nodo.get_children():
		out.append_array(_mallas(hijo))
	return out


func _vaciar() -> void:
	for hijo: Node in _soporte.get_children():
		_soporte.remove_child(hijo)
		hijo.queue_free()


# ------------------------------------------------------- lo que se posa --

func _hoguera(factor: float = 1.0) -> Node3D:
	var fuego := Bonfire.new()
	fuego.build(20260908, factor)
	fuego.lit = true
	return fuego


func _tienda() -> Node3D:
	var tienda := Tienda.new()
	tienda.build(20260908)
	return tienda


## El vivac entero, que es lo que se ve de verdad en el valle: la tienda con la
## boca al fuego, a un paso.
func _vivac() -> Node3D:
	var campamento := Node3D.new()
	var fuego := _hoguera(BivouacFires.FIRE_SIZE)
	campamento.add_child(fuego)
	var tienda := _tienda()
	tienda.position = Vector3(BivouacFires.TIENDA_M, 0.0, 0.0)
	tienda.rotation.y = deg_to_rad(-90.0)
	campamento.add_child(tienda)
	return campamento


## Una trampa, montada por el MISMO código que la pone en el valle.
func _foto_de_trampa(kind: Trap.Kind) -> Dictionary:
	var trampa := Trap.new()
	trampa.kind = kind
	trampa.position = Vector3.ZERO
	var señales := TrapMarkers.new()
	_soporte.add_child(señales)
	señales.refresh([trampa], null)
	var ficha := await _disparar(Trap.trap_name(kind),
		String(Trap.catches(kind).front()) if not Trap.catches(kind).is_empty()
			else "sin presa declarada")
	_vaciar()
	return ficha


func _foto_de_nasa() -> Dictionary:
	var nasa := Nasa.new()
	nasa.position = Vector3.ZERO
	var señales := NasaMarkers.new()
	_soporte.add_child(señales)
	señales.refresh([nasa], null)
	var ficha := await _disparar("Nasa", "se cala y pesca sola")
	_vaciar()
	return ficha


func _foto(pieza: Node3D, titulo: String, pie: String) -> Dictionary:
	_soporte.add_child(pieza)
	var ficha := await _disparar(titulo, pie)
	_vaciar()
	return ficha


func _disparar(titulo: String, pie: String) -> Dictionary:
	# Ocho cuadros: las llamas de la hoguera son un material animado y en el
	# primero todavía están en su posición de reposo.
	for i in range(8):
		await process_frame
	_encuadrar()
	for i in range(4):
		await process_frame
	var foto := _view.get_texture().get_image()
	foto.convert(Image.FORMAT_RGBA8)
	foto.resize(CELDA, CELDA, Image.INTERPOLATE_LANCZOS)
	print("  %-22s %s" % [titulo, pie])
	return {"img": foto, "titulo": titulo, "pie": pie}


# ---------------------------------------------------------- la lámina --

## Monta la hoja con la piel y la letra del juego.
##
## Se compone con controles y no pegando imágenes porque los pies van escritos
## a mano: la lámina tiene que parecer de este juego y no una hoja de sprites.
## Ver [Pigmento] y [PielTensada].
func _lamina(fichas: Array[Dictionary]) -> void:
	var filas := int(ceil(float(fichas.size()) / float(COLUMNAS)))
	var ancho := COLUMNAS * (CELDA + 18) + 40
	var alto := filas * (CELDA + 74) + 96

	# La lámina va en su PROPIO viewport y no en la pantalla: se compone a
	# 1.054 x 1.278 y la ventana del juego no llega, así que la última fila se
	# quedaba fuera. Un viewport propio no tiene ese techo y además no depende
	# de la escala de la pantalla, que en un monitor a 1,9x descuadraba el
	# recorte.
	var hoja_view := SubViewport.new()
	hoja_view.size = Vector2i(ancho, alto)
	hoja_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(hoja_view)

	var lienzo := Control.new()
	lienzo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lienzo.custom_minimum_size = Vector2(ancho, alto)
	lienzo.size = Vector2(ancho, alto)
	hoja_view.add_child(lienzo)

	var fondo := ColorRect.new()
	fondo.color = UISkin.GROUND.darkened(0.35)
	fondo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fondo.size = Vector2(ancho, alto)
	lienzo.add_child(fondo)

	var piel := PielTensada.new()
	piel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	piel.position = Vector2(PielTensada.DESBORDE, PielTensada.DESBORDE)
	piel.size = Vector2(ancho - PielTensada.DESBORDE * 2.0,
		alto - PielTensada.DESBORDE * 2.0)
	lienzo.add_child(piel)

	var titulo := Label.new()
	titulo.text = "Lo que la banda planta en el valle"
	titulo.position = Vector2(38, 26)
	Pigmento.escribir(titulo, UISkin.OCHRE, 34)
	lienzo.add_child(titulo)

	var rejilla := GridContainer.new()
	rejilla.columns = COLUMNAS
	rejilla.position = Vector2(28, 86)
	rejilla.add_theme_constant_override("h_separation", 18)
	rejilla.add_theme_constant_override("v_separation", 16)
	lienzo.add_child(rejilla)

	for ficha: Dictionary in fichas:
		rejilla.add_child(_celda(ficha))

	for i in range(8):
		await process_frame
	var hoja := hoja_view.get_texture().get_image()
	hoja.save_png(SALIDA)
	print("")
	print("lámina en %s (%d x %d, %d piezas)" % [
		ProjectSettings.globalize_path(SALIDA), ancho, alto, fichas.size()])


func _celda(ficha: Dictionary) -> Control:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)

	var foto := TextureRect.new()
	foto.texture = ImageTexture.create_from_image(ficha["img"] as Image)
	foto.custom_minimum_size = Vector2(CELDA, CELDA)
	columna.add_child(foto)

	var titulo := Label.new()
	titulo.text = String(ficha["titulo"])
	Pigmento.escribir(titulo, UISkin.INK, 22)
	columna.add_child(titulo)

	var pie := Label.new()
	pie.text = String(ficha["pie"])
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.custom_minimum_size = Vector2(CELDA, 0)
	Pigmento.escribir(pie, UISkin.INK_SOFT, 17, Pigmento.carbon())
	columna.add_child(pie)
	return columna
