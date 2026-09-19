class_name SalaDeLaCueva
extends Control
## Entrar en la cueva: la pared del fondo, a la luz de la lámpara, con lo que hay
## pintado. SISTEMAS §13 y GRAFICOS §7.2.
##
## **No es un cambio de escena**: es una capa encima de la que haya, con su propio
## mundo 3D. Así ni el sol, ni la niebla, ni el cielo del valle entran en la cueva,
## y al salir no hay nada que reconstruir —cambiar de escena cuesta hoy 18 s de
## vuelta, ESTADO §2—.
##
## Lee la simulación y no la cambia (SPECS §4.7), salvo lo que la simulación
## decide que pasa al entrar: [Pinturas.entrar_a_mirar].

signal cerrada

## Píxeles de la textura de pinturas por metro de pared: ~0,9 cm por píxel, lo
## bastante para el trazo de una aguja de ocre sin pasar de una textura de 1320 px.
const PIXELES_POR_METRO := 110.0

## Cuánto se curva la pared por los bordes hacia la cámara, en metros: un nicho y
## no una pantalla plana.
const CURVA_M := 1.6

const COLORES := {
	"rojo": Color(0.46, 0.11, 0.07),
	"negro": Color(0.09, 0.075, 0.065),
	# El grabado no es pigmento: es la roca rayada, más clara. Se pinta como un
	# blanqueo débil.
	"grabado": Color(1.25, 1.2, 1.1),
}

## La pared que se enseña. Es la de la simulación, no una copia.
var pared: ParedDeLaCueva

## Cuántas figuras se han dibujado en la textura. Para las pruebas.
var figuras_dibujadas: int = 0

## La textura de pinturas tal cual, para las capturas.
var imagen_de_pinturas: Image

var _vista: SubViewport
var _camara: Camera3D
var _lampara: OmniLight3D
var _reloj := 0.0
var _arrastrando := false
var _mirada := Vector2.ZERO
## A qué distancia de la pared arranca la cámara. A 5,5 m una figura de metro y
## medio ocupaba un octavo de la pantalla y una mano no se leía (captura del
## 2026-09-15); a 3,2 m se ven de un vistazo unas cuantas figuras y se acerca con la
## rueda.
var _distancia := 3.2

## Cómo tenía el 3D la ventana de debajo al entrar, para dejarlo igual al salir.
var _tres_d_de_debajo := false

## LO QUE HACE FALTA PARA PINTAR DESDE AQUÍ DENTRO. El botón de pintar vivía en el panel
## de Técnicas, una ventana de gestión, y lo que se pinta es esta pared: se movió aquí el
## 2026-09-19 por decisión del usuario, y **sólo aquí**, que dos botones para lo mismo son
## dos verdades que se separan.
var _sim: SettlementSim
var _cueva: int = -1
var _material: ShaderMaterial
var _pintadero: VBoxContainer
## Cuántas pinturas había la última vez que se miró la pared. Cuando cambia, la pared se
## vuelve a dibujar sin salir de la sala: es «verlo pintado» sin cerrar y volver a entrar.
var _pintadas := -1
var _refresco := 0.0
var _lo_dicho := ""


## Monta la sala de la cueva `cueva` del campamento de `sim`. `nombre` va arriba.
func montar(sim: SettlementSim, cueva: int, nombre: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sim = sim
	_cueva = cueva
	pared = sim.pinturas.pared_de(cueva)
	var arte := sim.pinturas.arte_de(cueva)
	sim.pinturas.entrar_a_mirar(cueva)

	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.msaa_3d = Viewport.MSAA_2X
	contenedor.add_child(_vista)

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.035, 0.025)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.environment = env
	_vista.add_child(entorno)

	var ancho_m := ParedDeLaCueva.ANCHO * ParedDeLaCueva.CELDA_M
	var alto_m := ParedDeLaCueva.ALTO * ParedDeLaCueva.CELDA_M
	var roca := MeshInstance3D.new()
	roca.mesh = _malla_de_la_pared()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/pared_pintada.gdshader")
	var textura_roca := CaveMouth.material_de_roca().albedo_texture
	if textura_roca != null:
		material.set_shader_parameter("roca", textura_roca)
	imagen_de_pinturas = _pintar()
	material.set_shader_parameter("pinturas", ImageTexture.create_from_image(imagen_de_pinturas))
	roca.material_override = material
	_material = material
	_vista.add_child(roca)

	_lampara = OmniLight3D.new()
	_lampara.light_color = Color(1.0, 0.64, 0.32)
	_lampara.light_energy = 2.4
	_lampara.omni_range = 10.0
	_lampara.shadow_enabled = true
	_lampara.position = Vector3(ancho_m * 0.5 - 1.2, alto_m * 0.35, 2.2)
	_vista.add_child(_lampara)

	_camara = Camera3D.new()
	_camara.fov = 55.0
	_vista.add_child(_camara)
	_mirada = _donde_mirar_primero(ancho_m, alto_m)
	_colocar_camara()

	_levantar_rotulos(nombre, arte)
	_pintadas = sim.paintings.size()
	_levantar_el_pintadero()


## Adónde mira la cámara al entrar: al centro de lo pintado, y no al de la pared.
## Las figuras van donde la roca las recalca, que puede ser una esquina, y en las
## capturas del 2026-09-15 la cámara centrada enseñaba roca vacía y las figuras al
## borde. La y de la pared va hacia abajo y la del mundo hacia arriba.
func _donde_mirar_primero(ancho_m: float, alto_m: float) -> Vector2:
	if pared.figuras.is_empty():
		return Vector2(ancho_m * 0.5, alto_m * 0.5)
	var suma := Vector2.ZERO
	for figura: Dictionary in pared.figuras:
		suma += figura["centro"] as Vector2
	var media := suma / float(pared.figuras.size())
	return Vector2(media.x, alto_m - ParedDeLaCueva.CELDA_M - media.y)


## La malla de la roca desde el relieve de la pared: una rejilla con la altura de
## cada celda hacia la cámara, curvada por los bordes.
func _malla_de_la_pared() -> ArrayMesh:
	var herramienta := SurfaceTool.new()
	herramienta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ancho := ParedDeLaCueva.ANCHO
	var alto := ParedDeLaCueva.ALTO
	var celda := ParedDeLaCueva.CELDA_M
	for y in range(alto):
		for x in range(ancho):
			var u := float(x) / float(ancho - 1)
			var v := float(y) / float(alto - 1)
			var curva := CURVA_M * (pow(absf(u - 0.5) * 2.0, 4.0) + 0.5 * pow(absf(v - 0.5) * 2.0, 4.0))
			herramienta.set_uv(Vector2(u, v))
			herramienta.add_vertex(Vector3(x * celda, (alto - 1 - y) * celda,
				pared.relieve[y * ancho + x] + curva))
	for y in range(alto - 1):
		for x in range(ancho - 1):
			var a := y * ancho + x
			var b := a + 1
			var c := a + ancho
			var d := c + 1
			# EN SENTIDO HORARIO visto desde la cámara, que es la cara delantera en
			# Godot. Al revés, la pared quedaba de espaldas: se descartaba y sus
			# normales miraban a la roca, y la primera captura salió negra.
			herramienta.add_index(a)
			herramienta.add_index(b)
			herramienta.add_index(c)
			herramienta.add_index(b)
			herramienta.add_index(d)
			herramienta.add_index(c)
	herramienta.generate_normals()
	return herramienta.commit()


## La textura de pinturas: cada figura en su sitio, la más nueva encima.
func _pintar() -> Image:
	var ancho := int(ParedDeLaCueva.ANCHO * ParedDeLaCueva.CELDA_M * PIXELES_POR_METRO)
	var alto := int(ParedDeLaCueva.ALTO * ParedDeLaCueva.CELDA_M * PIXELES_POR_METRO)
	var datos := PackedByteArray()
	datos.resize(ancho * alto * 4)
	datos.fill(0)
	figuras_dibujadas = 0
	for figura: Dictionary in pared.figuras:
		var motivo := String(figura["motivo"])
		if not Motivos.FIGURAS.has(motivo):
			continue
		var color: Color = COLORES.get(String(figura["color"]), COLORES["rojo"])
		var tecnica := String((Motivos.FIGURAS[motivo] as Dictionary)["tecnica"])
		if tecnica == "mano_negativa":
			_soplar_mano(datos, ancho, alto, figura, color)
		else:
			for forma: Array in Motivos.trazos_de(motivo):
				_rellenar(datos, ancho, alto, _a_pixeles(forma, figura), color, 0.92)
		figuras_dibujadas += 1
	return Image.create_from_data(ancho, alto, false, Image.FORMAT_RGBA8, datos)


## Los anillos de una forma, de coordenadas de figura a píxeles de la textura. La
## misma cuenta que [ParedDeLaCueva.celda_de], para que se pinte donde se midió.
static func _a_pixeles(anillos: Array, figura: Dictionary) -> Array[PackedVector2Array]:
	var lado := float(figura["lado"])
	var giro := float(figura["giro"])
	var c := cos(giro)
	var s := sin(giro)
	var centro: Vector2 = figura["centro"]
	var signo := -1.0 if bool(figura["espejo"]) else 1.0
	var fuera: Array[PackedVector2Array] = []
	for anillo: PackedVector2Array in anillos:
		var puntos := PackedVector2Array()
		puntos.resize(anillo.size())
		for i in range(anillo.size()):
			var x := anillo[i].x * signo
			var y := anillo[i].y
			puntos[i] = (Vector2(x * c - y * s, x * s + y * c) * lado + centro) * PIXELES_POR_METRO
		fuera.append(puntos)
	return fuera


## Rellena anillos por paridad, fila a fila, y funde el color encima de lo que haya.
static func _rellenar(datos: PackedByteArray, ancho: int, alto: int,
		anillos: Array[PackedVector2Array], color: Color, opacidad: float) -> void:
	var y0 := alto
	var y1 := 0
	for anillo: PackedVector2Array in anillos:
		for p: Vector2 in anillo:
			y0 = mini(y0, int(floor(p.y)))
			y1 = maxi(y1, int(ceil(p.y)))
	y0 = maxi(y0, 0)
	y1 = mini(y1, alto - 1)
	for y in range(y0, y1 + 1):
		var fila := float(y) + 0.5
		var cruces := PackedFloat32Array()
		for anillo: PackedVector2Array in anillos:
			var n := anillo.size()
			for i in range(n):
				var a := anillo[i]
				var b := anillo[(i + 1) % n]
				if (a.y <= fila and b.y > fila) or (b.y <= fila and a.y > fila):
					cruces.append(a.x + (fila - a.y) / (b.y - a.y) * (b.x - a.x))
		cruces.sort()
		var k := 0
		while k + 1 < cruces.size():
			var x0 := maxi(int(ceil(cruces[k] - 0.5)), 0)
			var x1 := mini(int(floor(cruces[k + 1] - 0.5)), ancho - 1)
			for x in range(x0, x1 + 1):
				_fundir(datos, (y * ancho + x) * 4, color, opacidad)
			k += 2


static func _fundir(datos: PackedByteArray, i: int, color: Color, opacidad: float) -> void:
	var a_viejo := datos[i + 3] / 255.0
	var a := opacidad + a_viejo * (1.0 - opacidad)
	if a <= 0.0:
		return
	for canal in range(3):
		var nuevo := clampf(color[canal] / 1.3, 0.0, 1.0)
		var viejo := datos[i + canal] / 255.0
		datos[i + canal] = int(clampf((nuevo * opacidad + viejo * a_viejo * (1.0 - opacidad)) / a, 0.0, 1.0) * 255.0)
	datos[i + 3] = int(a * 255.0)


## La mano en negativo: el pigmento soplado alrededor de la mano apoyada, que se
## queda sin pintar. Se rellena la silueta, se emborrona y se quita la silueta.
func _soplar_mano(datos: PackedByteArray, ancho: int, alto: int, figura: Dictionary,
		color: Color) -> void:
	var silueta := _a_pixeles(Motivos.cuerpo_de(String(figura["motivo"])), figura)
	var caja := Rect2(silueta[0][0], Vector2.ZERO)
	for anillo: PackedVector2Array in silueta:
		for p: Vector2 in anillo:
			caja = caja.expand(p)
	# El soplo abarca un tercio del tamaño de la mano alrededor: con menos, el halo
	# eran cinco píxeles apenas teñidos y la mano no se veía en la captura.
	var radio := int(float(figura["lado"]) * PIXELES_POR_METRO * 0.33)
	caja = caja.grow(radio * 2)
	var bx := maxi(int(caja.position.x), 0)
	var by := maxi(int(caja.position.y), 0)
	var bw := mini(int(caja.end.x), ancho) - bx
	var bh := mini(int(caja.end.y), alto) - by
	if bw <= 0 or bh <= 0:
		return
	var mascara := PackedByteArray()
	mascara.resize(bw * bh * 4)
	mascara.fill(0)
	var local: Array[PackedVector2Array] = []
	for anillo: PackedVector2Array in silueta:
		var movido := PackedVector2Array()
		for p: Vector2 in anillo:
			movido.append(p - Vector2(bx, by))
		local.append(movido)
	_rellenar(mascara, bw, bh, local, Color.WHITE, 1.0)
	var dentro := PackedFloat32Array()
	dentro.resize(bw * bh)
	for i in range(bw * bh):
		dentro[i] = mascara[i * 4 + 3] / 255.0
	var soplo := _emborronar(dentro, bw, bh, radio)
	for y in range(bh):
		for x in range(bw):
			var k := y * bw + x
			var cubre := clampf(soplo[k] * 3.0, 0.0, 1.0) * (1.0 - dentro[k]) * 0.95
			if cubre > 0.01:
				_fundir(datos, ((by + y) * ancho + bx + x) * 4, color, cubre)


static func _emborronar(campo: PackedFloat32Array, w: int, h: int, radio: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(campo.size())
	var fuera := PackedFloat32Array()
	fuera.resize(campo.size())
	var n := float(radio * 2 + 1)
	for y in range(h):
		for x in range(w):
			var suma := 0.0
			for d in range(-radio, radio + 1):
				suma += campo[y * w + clampi(x + d, 0, w - 1)]
			tmp[y * w + x] = suma / n
	for y in range(h):
		for x in range(w):
			var suma := 0.0
			for d in range(-radio, radio + 1):
				suma += tmp[clampi(y + d, 0, h - 1) * w + x]
			fuera[y * w + x] = suma / n
	return fuera


func _levantar_rotulos(nombre: String, arte: Dictionary) -> void:
	var arriba := HBoxContainer.new()
	arriba.set_anchors_preset(Control.PRESET_TOP_WIDE)
	arriba.offset_left = 24
	arriba.offset_right = -24
	arriba.offset_top = 16
	add_child(arriba)
	var titulo := Label.new()
	titulo.text = nombre
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.84, 0.68))
	arriba.add_child(titulo)
	var salir := Button.new()
	salir.name = "Salir"
	salir.text = "Salir de la cueva"
	salir.pressed.connect(cerrar)
	arriba.add_child(salir)

	var abajo := Label.new()
	abajo.name = "Relato"
	abajo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	abajo.offset_left = 24
	abajo.offset_right = -24
	abajo.offset_top = -120
	abajo.offset_bottom = -16
	abajo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	abajo.add_theme_font_size_override("font_size", 17)
	abajo.add_theme_color_override("font_color", Color(0.88, 0.8, 0.66))
	var propias := 0
	for figura: Dictionary in pared.figuras:
		if not bool(figura["documentada"]):
			propias += 1
	if not arte.is_empty():
		abajo.text = String(arte["texto"])
	elif propias == 0:
		abajo.text = "La pared está limpia."
	else:
		abajo.text = "%d figuras de la banda en la pared." % propias
	add_child(abajo)


## EL PINTADERO: lo que falta por contar en la pared, con su botón, aquí dentro.
##
## Viene de una petición del usuario del 2026-09-18 —«el botón de pintar, dentro de la
## vista 3D, con la lista de hitos sin pintar»— y de que el sitio donde estaba no era el
## sitio: el panel de Técnicas es una ventana de gestión y la pared es esto. Se **movió**,
## no se duplicó (decisión del usuario del 2026-09-19).
##
## El botón sale SIEMPRE que haya algo pintable, y apagado dice por qué no se puede: sin la
## técnica, sin lámpara, sin ocre, o porque ésta no es la cueva de la banda. La razón la da
## [Pinturas.por_que_no_se_pinta_en] y no se repite aquí.
func _levantar_el_pintadero() -> void:
	if _sim == null or _sim.pinturas == null:
		return
	var marco := PanelContainer.new()
	marco.name = "Pintadero"
	marco.set_anchors_preset(Control.PRESET_TOP_LEFT)
	marco.offset_left = 24
	marco.offset_top = 72
	marco.custom_minimum_size = Vector2(420, 0)
	var fondo := StyleBoxFlat.new()
	# Negro casi opaco: es un rótulo sobre una cueva a oscuras, y el texto tiene que
	# leerse sobre la roca sin iluminarla.
	fondo.bg_color = Color(0.04, 0.035, 0.03, 0.82)
	fondo.content_margin_left = 14
	fondo.content_margin_right = 14
	fondo.content_margin_top = 10
	fondo.content_margin_bottom = 10
	marco.add_theme_stylebox_override("panel", fondo)
	add_child(marco)
	_pintadero = VBoxContainer.new()
	_pintadero.add_theme_constant_override("separation", 6)
	marco.add_child(_pintadero)
	_lo_dicho = _lo_que_dice_el_pintadero()
	_repintar_el_pintadero()


## Rehace la lista. Se llama al montar, al mandar pintar y cuando cambia lo que hay.
func _repintar_el_pintadero() -> void:
	if _pintadero == null:
		return
	for hijo: Node in _pintadero.get_children():
		hijo.queue_free()
	_pintadero.get_parent().visible = true

	var falta := _sim.pinturas.por_que_no_se_pinta_en(_cueva)
	var pendientes := _sim.pinturas.pintables()

	if _sim.painting_queue != null:
		_linea("Pintando: %s" % _sim.painting_queue.title, Color(0.93, 0.78, 0.42), 19)
		_linea("va por el %.0f %%" % (100.0 * _sim.painting_progress
			/ maxf(SettlementSim.PINTURA_JORNADAS, 0.001)), Color(0.8, 0.72, 0.6), 16)
		if pendientes.is_empty():
			return
		_linea("", Color.WHITE, 8)

	if pendientes.is_empty():
		_linea("Nada nuevo que contar en la pared.", Color(0.82, 0.75, 0.62), 17)
		return

	_linea("LO QUE FALTA POR PINTAR", Color(0.93, 0.84, 0.68), 19)
	if not falta.is_empty():
		_linea("No se puede: %s." % falta, Color(0.86, 0.6, 0.45), 16)
	for tale: Tale in pendientes:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_pintadero.add_child(fila)
		var nombre := Label.new()
		nombre.text = tale.title
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nombre.add_theme_font_size_override("font_size", 17)
		nombre.add_theme_color_override("font_color", Color(0.88, 0.8, 0.66))
		fila.add_child(nombre)
		var fecha := Label.new()
		fecha.text = tale.stamp()
		fecha.add_theme_font_size_override("font_size", 15)
		fecha.add_theme_color_override("font_color", Color(0.66, 0.6, 0.5))
		fila.add_child(fecha)
		var boton := Button.new()
		boton.name = "Pintar_%d" % tale.day
		boton.text = "Pintar"
		boton.disabled = not falta.is_empty()
		boton.tooltip_text = "No se puede: %s." % falta if not falta.is_empty() 			else "Pintarlo en esta pared."
		boton.pressed.connect(func() -> void:
			_sim.pinturas.queue_painting(tale)
			_lo_dicho = _lo_que_dice_el_pintadero()
			_repintar_el_pintadero())
		fila.add_child(boton)


func _linea(texto: String, color: Color, tamano: int) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	_pintadero.add_child(etiqueta)


## A pantalla completa **a mano** y no con anclas: colgada de un `CanvasLayer`,
## que es donde va la interfaz, un `Control` no tiene padre del que tomar tamaño y
## las anclas lo dejan en cero —la primera captura salió con la sala invisible y el
## texto en columna, letra a letra—. Y sigue a la ventana si cambia.
##
## **Y apaga el 3D de la ventana de debajo mientras está abierta.** La sala tapa la
## pantalla entera, pero el valle seguía dibujándose detrás: 18 ms de GPU que no se
## ven, encima de los ~2 que cuesta la sala (`CuevaCaptura`, 2026-09-15). Al salir se
## deja como estaba.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_a_pantalla_completa()
		if not get_viewport().size_changed.is_connected(_a_pantalla_completa):
			get_viewport().size_changed.connect(_a_pantalla_completa)
		_tres_d_de_debajo = get_viewport().disable_3d
		get_viewport().disable_3d = true
	elif what == NOTIFICATION_EXIT_TREE:
		get_viewport().disable_3d = _tres_d_de_debajo


func _a_pantalla_completa() -> void:
	if get_parent() is Control:
		return
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size


func cerrar() -> void:
	cerrada.emit()
	queue_free()


func _process(delta: float) -> void:
	if _lampara == null:
		return
	# La llama: dos oscilaciones que no casan, y un poco de temblor de sitio.
	_reloj += delta
	_lampara.light_energy = 2.4 + 0.25 * sin(_reloj * 7.3) + 0.15 * sin(_reloj * 13.1 + 1.7)
	_colocar_camara()
	_ver_como_se_pinta(delta)


## VERLO PINTADO SIN SALIR. Mientras la sala está abierta la simulación sigue corriendo, y
## una pared que se termina de pintar cambia la pared que se está mirando: se rehace la
## textura ahí mismo. Antes había que cerrar la cueva y volver a entrar, que es justo lo
## que la sala existe para no hacer.
##
## Dos veces por segundo y no cada fotograma: [_pintar] recorre todas las figuras y monta
## una imagen de 1320 px, y nada de esto cambia sesenta veces por segundo.
func _ver_como_se_pinta(delta: float) -> void:
	if _sim == null or _pintadero == null:
		return
	_refresco += delta
	if _refresco < 0.5:
		return
	_refresco = 0.0
	var ahora := _sim.paintings.size()
	if ahora != _pintadas:
		_pintadas = ahora
		if _material != null:
			imagen_de_pinturas = _pintar()
			_material.set_shader_parameter("pinturas",
				ImageTexture.create_from_image(imagen_de_pinturas))
	# La lista sólo se rehace si ha cambiado algo de lo que enseña. Rehacerla cada medio
	# segundo pase lo que pase tira los botones que el ratón tuviera encima.
	var ahora_dice := _lo_que_dice_el_pintadero()
	if ahora_dice != _lo_dicho:
		_lo_dicho = ahora_dice
		_repintar_el_pintadero()


## Firma de lo que el pintadero enseña ahora mismo, para no rehacerlo sin motivo.
func _lo_que_dice_el_pintadero() -> String:
	return "%d|%s|%d|%s" % [_sim.paintings.size(),
		_sim.painting_queue.title if _sim.painting_queue != null else "",
		int(_sim.painting_progress * 100.0 / maxf(SettlementSim.PINTURA_JORNADAS, 0.001)),
		_sim.pinturas.por_que_no_se_pinta_en(_cueva)]


## LO QUE CABE EN PANTALLA a esta distancia de la pared, en metros: medio ancho y
## medio alto.
##
## Es lo que faltaba para limitar la cámara. El tope era «un metro antes del
## borde» **medido en el punto al que se mira**, y lo que se ve no es ese punto:
## a 7,5 m con 55° de campo, el encuadre se come 3,9 m más a cada lado, así que
## el borde de la pared entraba en pantalla —queja del usuario del 2026-09-16—.
static func encuadre(distancia: float, fov_grados: float, aspecto: float) -> Vector2:
	var medio_alto := tan(deg_to_rad(fov_grados) * 0.5) * maxf(distancia, 0.001)
	return Vector2(medio_alto * maxf(aspecto, 0.001), medio_alto)


## Lo más lejos que se puede poner la cámara sin que la pared deje de llenar la
## pantalla: en cuanto el encuadre es más alto o más ancho que la pared, se ve el
## borde. Se queda con el que antes se sale de los dos.
static func distancia_maxima(ancho_m: float, alto_m: float, fov_grados: float,
		aspecto: float) -> float:
	var por_el_alto := (alto_m * 0.5) / tan(deg_to_rad(fov_grados) * 0.5)
	var por_el_ancho := (ancho_m * 0.5) / (tan(deg_to_rad(fov_grados) * 0.5)
		* maxf(aspecto, 0.001))
	return minf(por_el_alto, por_el_ancho)


## A dónde se puede mirar sin que asome el borde, con este encuadre.
##
## Si el encuadre es más grande que la pared —una ventana muy apaisada, por
## ejemplo—, se centra: mejor enseñar el borde por los dos lados a la vez que
## dar un tirón contra un tope imposible.
static func mirada_dentro(mirada: Vector2, ancho_m: float, alto_m: float,
		medio: Vector2) -> Vector2:
	var dentro := mirada
	dentro.x = ancho_m * 0.5 if medio.x * 2.0 >= ancho_m 		else clampf(mirada.x, medio.x, ancho_m - medio.x)
	dentro.y = alto_m * 0.5 if medio.y * 2.0 >= alto_m 		else clampf(mirada.y, medio.y, alto_m - medio.y)
	return dentro


func _colocar_camara() -> void:
	if _camara == null:
		return
	var ancho_m := ParedDeLaCueva.ANCHO * ParedDeLaCueva.CELDA_M
	var alto_m := ParedDeLaCueva.ALTO * ParedDeLaCueva.CELDA_M
	var tam := _vista.size if _vista != null else Vector2i(1920, 1080)
	var aspecto := float(tam.x) / maxf(float(tam.y), 1.0)
	# EL TOPE DE ALEJARSE SALE DE LA PARED, no de un número: en cuanto el
	# encuadre pasa de los 4,8 m de alto de la pared, se ve por dónde acaba.
	_distancia = clampf(_distancia, 1.5,
		distancia_maxima(ancho_m, alto_m, _camara.fov, aspecto))
	_mirada = mirada_dentro(_mirada, ancho_m, alto_m,
		encuadre(_distancia, _camara.fov, aspecto))
	_camara.position = Vector3(_mirada.x, _mirada.y, _distancia)
	_camara.look_at(Vector3(_mirada.x, _mirada.y, 0.0), Vector3.UP)


func _gui_input(event: InputEvent) -> void:
	var boton := event as InputEventMouseButton
	if boton != null:
		if boton.button_index == MOUSE_BUTTON_WHEEL_UP and boton.pressed:
			_distancia -= 0.4
		elif boton.button_index == MOUSE_BUTTON_WHEEL_DOWN and boton.pressed:
			_distancia += 0.4
		elif boton.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = boton.pressed
		accept_event()
		return
	var movimiento := event as InputEventMouseMotion
	if movimiento != null and _arrastrando:
		_mirada += Vector2(-movimiento.relative.x, movimiento.relative.y) * 0.004 * _distancia
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla != null and Teclas.es(tecla, "cerrar"):
		get_viewport().set_input_as_handled()
		cerrar()
